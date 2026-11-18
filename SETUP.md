# Claude Code environment setup — runbook

**If you are a Claude Code agent reading this file: this is your task list.**
The human fetched it on a fresh machine so that you can rebuild their working
environment without them explaining it again.

How to run it:

- Work through the steps in order. Steps 1-6 are the environment; 7-9 are optional
  extras the human may decline.
- **Ask before:** anything with `sudo`, installing or downloading Quartus, changing
  files outside `$HOME`, and before pushing to any git remote.
- Run the verification block at the end of each step. If it fails, stop and report
  rather than improvising around it.
- Nothing here needs network access to the human's other machine. Everything is
  installed from upstream.
- **Talk to the human in Polish.** This file is English only because the repository
  it lives in is.
- Four things are theirs to decide, so ask early (step 0) and carry the answers
  through: note language (`NOTES_LANG`), whether to install `rtk`, whether Quartus
  is present and in which edition, and the URL of their private notes repository.

## What you are building

| Element | Purpose |
| --- | --- |
| Claude Code (native install) | the agent itself, CLI + VS Code extension |
| jCodeMunch MCP | code index: who uses a symbol, what a change breaks |
| WEFT MCP | FPGA tooling (lint, simulate, Quartus) **and** the RAG engine over PDFs |
| BGE-M3 (ONNX) | embedding model, makes document search semantic rather than textual |
| notes-sync (this repo) | `SessionEnd` hook that writes a note per session, `/summarize-day` skill |
| rtk (optional) | condenses Bash output before it reaches the model |

Reference environment: Ubuntu 24.04, also valid under WSL2. Earlier the same set ran on
Ubuntu 22.04; where 24.04 differs, this file uses the 24.04 form.

## Step 0 — preflight and plan

```bash
. /etc/os-release && echo "$PRETTY_NAME"
uname -r                                  # contains "microsoft-standard-WSL2" under WSL
echo "$PATH" | tr ':' '\n' | grep -c '\.local/bin'
command -v claude pipx uv podman git jq curl python3
nproc && free -g | head -2 && df -h "$HOME" | tail -1
```

Report what is already present and what you intend to install, then ask the human the
four questions from the header. Disk budget: ~2.2 GB model, ~2 GB container image,
Quartus separately (tens of GB).

## Step 1 — system packages

```bash
sudo apt update
sudo apt install -y git jq curl pipx podman
pipx ensurepath
```

`~/.local/bin` must be on `PATH`; if it is not: `echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc`.

On WSL2, enable systemd once (helps podman) and restart the distro from Windows with
`wsl --shutdown`:

```bash
grep -q 'systemd=true' /etc/wsl.conf 2>/dev/null || printf '[boot]\nsystemd=true\n' | sudo tee -a /etc/wsl.conf
```

## Step 2 — Claude Code

```bash
curl -fsSL https://claude.ai/install.sh | bash
claude --version
```

The human logs in themselves (`claude`, browser flow). Under WSL the browser opens through
`wslview`; if it does not, hand them the URL to paste. In VS Code the Claude Code extension
must be installed **in the WSL context** (Remote-WSL), not on the Windows side.

Then, with their agreement, settle the basics: model `claude-opus-5`, dark theme, automatic
updates off. The complete `~/.claude/settings.json` is in step 6 — write it there, once the
hooks it references exist.

```bash
python3 - <<'PY'
import json, os
p = os.path.expanduser('~/.claude.json')
d = json.load(open(p)); d['autoUpdates'] = False
json.dump(d, open(p, 'w'), indent=2)
PY
```

**Start the two slow downloads now, in the background** — steps 4 and 5 need them:

```bash
DIR=~/.local/share/weft/models/bge-m3
mkdir -p $DIR/onnx
nohup bash -c 'for f in onnx/model.onnx onnx/model.onnx_data tokenizer.json; do
  curl -sLo '"$DIR"'/$f https://huggingface.co/BAAI/bge-m3/resolve/main/$f; done' > ~/bge-m3.log 2>&1 &
```

Verify later with `du -sh ~/.local/share/weft/models/bge-m3` → ~2.2 GB.

## Step 3 — jCodeMunch MCP (code index)

On Ubuntu 24.04 the system Python is externally managed (PEP 668), so `pip install --user`
is refused. Use pipx; the entry point still lands in `~/.local/bin`, which is what the hooks
in step 6 reference.

```bash
pipx install jcodemunch-mcp
jcodemunch-mcp init --client claude-code --claude-md global --hooks --no-share-savings -y
jcodemunch-mcp install-status
claude mcp get jcodemunch
```

This registers the MCP server at `user` scope, appends a "Code Exploration Policy" section to
`~/.claude/CLAUDE.md`, installs the index hooks, and opts out of usage statistics. Indexes live
in `~/.code-index/` and are built on demand — do not pre-index anything.

Do **not** pass `--strict`: it blocks ordinary file reads inside indexed repositories.

## Step 4 — WEFT MCP (FPGA tooling + RAG)

```bash
curl -fsSL https://astral.sh/uv/install.sh | sh && . ~/.bashrc
git clone https://github.com/FPGArtktic/weft-mcp ~/.local/src/weft-mcp
mkdir -p ~/fpga                      # the workspace: the only directory WEFT can see
cd ~/.local/src/weft-mcp && ./setup.sh --workspace ~/fpga
weft --version && ./setup.sh --check
```

`setup.sh` installs the package with `uv` and builds the `weft-tools` container image
(Verilator, Icarus, GHDL, Verible, Tesseract; no network inside). Ubuntu 24.04 ships Python
3.12, so no separate interpreter is needed. Pass `--no-image` to defer the slow image build.

**If the image build fails with a user-namespace denial**, Ubuntu 24.04's AppArmor restriction
is the likely cause:

```bash
cat /proc/sys/kernel/apparmor_restrict_unprivileged_userns   # 1 = restricted
```

Ask the human before relaxing it (`sudo sysctl kernel.apparmor_restrict_unprivileged_userns=0`
lowers isolation machine-wide). Under WSL2 AppArmor is often inactive and this does not arise.

Now write the configuration. **This machine uses Quartus Prime Lite**, so the edition is
`lite` — confirm the actual install path first (`ls ~/intelFPGA_lite`):

```bash
mkdir -p ~/.config/weft
cat > ~/.config/weft/weft.toml <<EOF
[workspace]
root = "$HOME/fpga"

[container]
image = "weft-tools"

[quartus]
# State the edition explicitly: a Lite install ships the Pro-only binaries as
# stubs, so WEFT cannot tell the editions apart by looking for files. Lite
# synthesises with quartus_map, Pro with quartus_syn.
edition = "lite"

[quartus.lite]
root = "$HOME/intelFPGA_lite/25.1std/quartus"

[questa]
# With Lite this is Questa - Altera FPGA Starter Edition.
root = "$HOME/intelFPGA_lite/25.1std/questa_fse"
# A free Starter licence is required for mixed Verilog/VHDL simulation:
# env = { SALT_LICENSE_SERVER = ";$HOME/.altera.quartus/questa_lic.dat" }

[jobs]
timeout_s = 7200

[rag]
library = "$HOME/Documents/fpga-docs"
model_path = "$HOME/.local/share/weft/models/bge-m3"
database = "$HOME/.local/share/weft/documents.sqlite"
EOF
claude mcp add --scope user weft -- ~/.local/bin/weft \
  --transport stdio --config ~/.config/weft/weft.toml
claude mcp list        # jcodemunch and weft: connected
```

Quartus notes to pass on:

- Lite is free and needs **no licence**. The `~/.altera.quartus/quartus2.ini` file with
  `LICENSE_FREE_MODE` is Pro-only; do not create it for Lite.
- **Lite does not support Agilex 5.** The human's `ghrd` project targets `A5ED065BB32AE6SR0`
  (`FAMILY "Agilex 5"`), so it cannot be compiled on a Lite-only machine; that needs Pro.
  Lint, simulation, the code index, generated documentation and the whole RAG are unaffected.
- WEFT never installs Quartus and has no `program_device` tool. Under WSL2, JTAG programming
  is a dead end anyway (USB-Blaster needs `usbipd-win` and rarely cooperates with `jtagd`).
- Under WSL2 keep Quartus, the workspace and the indexes on the ext4 filesystem (`$HOME`),
  never under `/mnt/c`.

## Step 5 — RAG over documents

```bash
mkdir -p ~/Documents/fpga-docs                      # the human's PDFs go here
du -sh ~/.local/share/weft/models/bge-m3            # ~2.2 GB from step 2
```

If the background download did not finish, run it in the foreground:

```bash
DIR=~/.local/share/weft/models/bge-m3; mkdir -p $DIR/onnx
for f in onnx/model.onnx onnx/model.onnx_data tokenizer.json; do
    curl -Lo $DIR/$f https://huggingface.co/BAAI/bge-m3/resolve/main/$f
done
```

Nothing is indexed automatically. Once the human drops a PDF in, index it (`index_document`),
then search (`search_docs`); `list_indexed_docs` shows what is in the index. Code in the
workspace is a separate index (`index_project` + `search_code`).

The search result states whether it answered semantically or textually. Without a usable
`model_path` WEFT silently falls back to text matching, so check that line before claiming
semantic search works. An empty result almost always means "not indexed", not "not there".

## Step 6 — settings, hooks, permissions

Write `~/.claude/settings.json`. Replace `$HOME` with the real path (JSON does not expand it).
Drop the `rtk hook claude` entry if step 8 is skipped, and the whole `SessionEnd` block if step
7 is skipped. If the file already has content, merge rather than overwrite.

```json
{
  "syntaxHighlightingDisabled": true,
  "theme": "dark",
  "agentPushNotifEnabled": true,
  "model": "claude-opus-5",
  "permissions": { "allow": ["mcp__jcodemunch", "mcp__weft"] },
  "hooks": {
    "PreToolUse": [
      { "matcher": "Bash", "hooks": [{ "type": "command", "command": "rtk hook claude" }] },
      { "matcher": "Read|Grep|Glob|Bash", "hooks": [{ "type": "command", "command": "$HOME/.local/bin/jcodemunch-mcp hook-pretooluse" }] }
    ],
    "PostToolUse": [
      { "matcher": "Edit|Write", "hooks": [{ "type": "command", "command": "$HOME/.local/bin/jcodemunch-mcp hook-posttooluse" }] }
    ],
    "WorktreeCreate": [
      { "matcher": "", "hooks": [{ "type": "command", "command": "$HOME/.local/bin/jcodemunch-mcp hook-event create" }] }
    ],
    "WorktreeRemove": [
      { "matcher": "", "hooks": [{ "type": "command", "command": "$HOME/.local/bin/jcodemunch-mcp hook-event remove" }] }
    ],
    "PreCompact": [
      { "matcher": "", "hooks": [{ "type": "command", "command": "$HOME/.local/bin/jcodemunch-mcp hook-precompact" }] }
    ],
    "SessionStart": [
      { "matcher": "compact|resume|fork", "hooks": [{ "type": "command", "command": "$HOME/.local/bin/jcodemunch-mcp hook-sessionstart" }] }
    ],
    "TaskCompleted": [
      { "matcher": "", "hooks": [{ "type": "command", "command": "$HOME/.local/bin/jcodemunch-mcp hook-taskcomplete" }] }
    ],
    "SubagentStart": [
      { "matcher": "", "hooks": [{ "type": "command", "command": "$HOME/.local/bin/jcodemunch-mcp hook-subagent-start" }] }
    ],
    "SessionEnd": [
      { "matcher": "", "hooks": [{ "type": "command", "command": "$HOME/.claude/hooks/session-note.sh", "timeout": 30 }] }
    ]
  }
}
```

Hook order matters: `rtk hook claude` comes first for `Bash`. Hooks, `CLAUDE.md` and MCP
servers are read at session start, so the human must restart Claude Code afterwards.

Plugins and connectors need nothing installed: logging in with the same account brings the
synced plugins and the Claude Docs connector (`/mcp`, `/plugin` show them).

## Step 7 — session notes (optional)

This repository is the mechanism. Clone it, configure it, install it:

```bash
git clone --recurse-submodules https://github.com/matchupikchu/claude-notes-sync.git ~/notes-sync
cd ~/notes-sync
$EDITOR notes-sync.conf      # NOTES_DIR, NOTES_SUMMARY_DIR, NOTES_LANG, NOTES_REMOTE, NOTES_BRANCH
./install.sh
```

`NOTES_LANG` is the language of the notes themselves (`pl` by default — ask, do not assume).
`install.sh` links the hook, the `/summarize-day` skill and the `push-notes` command; the
`SessionEnd` entry in `settings.json` is step 6's job.

The notes themselves live in a separate, private repository. The human must add this machine's
SSH key to GitHub before `push-notes` can work:

```bash
ssh-keygen -t ed25519 -C "$(hostname)"      # if there is no key yet
cat ~/.ssh/id_ed25519.pub                   # they add it: GitHub → Settings → SSH and GPG keys
ssh -T git@github.com                       # must greet them by name
git clone git@github.com:<user>/<notes-repo>.git ~/notatki-claude
```

Ask for the notes repository URL; it is private, so it is not written down here. Under WSL,
`wsl --shutdown` kills the background summariser, so a note may be missing for the session
that was interrupted that way.

## Step 8 — rtk (optional)

A `PreToolUse` hook that rewrites Bash commands into condensed equivalents
(`git status` → `rtk git status`), saving context. Only affects Bash; `Read`, `Grep` and `Glob`
go around it.

```bash
# binary from https://github.com/rtk-ai/rtk releases (guide: https://rtk-ai.app/guide)
install -m 755 ./rtk ~/.local/bin/rtk
rtk --version
rtk init --global --agent claude    # writes the hook and ~/.claude/RTK.md
rtk telemetry                        # the human keeps this off
```

Known interaction: in auto mode the rtk hook rewrites a command *after* the classifier has
judged it, so occasionally a call must be reissued verbatim. That is expected; it can be
silenced per command via `[hooks] exclude_commands` in `~/.config/rtk/config.toml`.

## Step 9 — the human's own instructions (optional)

`~/.claude/CLAUDE.md` is loaded in every project; after steps 3 and 8 it already holds the
jCodeMunch policy and `@RTK.md`. Per-project memory lives in
`~/.claude/projects/<slug>/memory/` with a `MEMORY.md` index and grows on its own — create
nothing by hand. The slug is the project path with `/` replaced by `-`, so memories do not
follow a project that moves.

## Verification

```bash
claude --version
claude mcp list                                   # jcodemunch, weft: connected
jcodemunch-mcp install-status
weft --version && (cd ~/.local/src/weft-mcp && ./setup.sh --check)
podman images | grep weft-tools
du -sh ~/.local/share/weft/models/bge-m3          # ~2.2 GB
ls ~/.claude/hooks ~/.claude/skills               # session-note.sh, summarize-day
rtk --version && rtk gain                         # only if step 8 was done
```

Then, in a session inside a project under `~/fpga`:

1. `/mcp` — both servers plus the account's connectors.
2. "Who uses function X?" — jCodeMunch indexes and answers.
3. "Lint the counter project." — WEFT answers through the container
   (`~/.local/src/weft-mcp/examples/counter` is a good first subject; copy it into `~/fpga`).
4. "Index this PDF, then ask it something." — RAG answers and names its mode.
5. End the session, then check `~/notatki-claude/<summary dir>/$(date -u +%F)/` for a note.

## Pitfalls

- **Order.** `jcodemunch-mcp init` and `rtk init` append to Claude Code's files; run them after
  step 2, never before.
- **PEP 668.** `pip install --user` fails on 24.04. pipx, not pip.
- **AppArmor userns** can block rootless podman on 24.04; ask before relaxing it.
- **`/mnt/c` under WSL** destroys I/O performance and breaks case sensitivity. Keep everything
  in `$HOME`.
- **WEFT's workspace is sealed.** A project must live *inside* `~/fpga`; a symlink will not do.
- **Nothing indexes itself.** Empty search results usually mean "not indexed".
- **Without the model, RAG is textual** — and only the result line says so.
- **`SessionEnd` has 30 s**, so the summary runs detached; do not make it synchronous.
- **Quartus Lite cannot build Agilex 5 designs.** Say so before a compile is attempted.

## Report when done

Tell the human, in Polish: what was installed with versions, which steps they declined, every
verification that failed and why, and what is left for them personally — logging in, adding the
SSH key, the Questa Starter licence, installing Quartus, and restarting Claude Code so the hooks
load.
