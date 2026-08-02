# Redcoder

An **offline, local AI coding agent** for your own machine — a Claude-Code-style terminal
agent driven entirely by a local model through [Ollama](https://ollama.com). It reads,
writes, and edits files, runs shell commands, and works through multi-step tasks — all on
your box, with **nothing logged to disk**. Ships with two front ends that share the same
local model:

| Front end | What it is | Launch |
|---|---|---|
| **CLI agent** | A terminal coding agent with live tool streaming, a model switcher, and optional voice input. | `redcoder` |
| **Web chat** | A clean browser chat UI (conversation only, no tools). | `Start Redcoder Web.cmd` |

Redcoder is designed for local software work and **authorized** security-lab use on your
own machine and your own isolated VMs. It's self-contained: the CLI is pure Python standard
library (no pip installs), talks only to `127.0.0.1`, and works with the network off.

---

## Highlights

- **Agentic tool loop** like Claude Code: `read_file`, `write_file`, `edit_file`,
  `list_dir`, `glob`, `grep`, `run_shell` (PowerShell).
- **Live streaming UI** — the model's text streams as it's written, file writes and edits
  render as a live green `+` / red `-` diff, and an animated spinner runs while it thinks,
  so you always see what's happening. **Ctrl-C** interrupts to interject; context is kept.
- **Model switcher** — `/model` opens an interactive picker of your installed Ollama models.
- **Voice input (optional)** — hold **Space** at an empty prompt to talk; releases to
  transcribe locally with [Whisper](https://github.com/openai/whisper) on your GPU. The
  recording is deleted right after.
- **No logging by design** — no transcript, history, or telemetry; the conversation lives in
  RAM and is gone on exit. The only thing ever written is the files you ask for (plus an
  opt-in `/save` checkpoint).
- **Auto-compaction** — near the context limit, older turns are summarized in memory so
  sessions can run indefinitely.
- **Offline** — everything targets local Ollama; turn the network off and nothing changes.

---

## Requirements

- **[Ollama](https://ollama.com)** running locally.
- **Python 3.11+**.
- An **abliterated** (refusal-removed) coding model in Ollama — see below.
- *(Optional, for voice)* **ffmpeg** on PATH, a microphone, and
  `pip install openai-whisper` with a working PyTorch (GPU recommended).

---

## Setup

```powershell
# 1. Pull an abliterated coder base model (examples — pick one your GPU can run):
ollama pull huihui_ai/qwen2.5-coder-abliterate:14b     # ~9 GB, fits a 12 GB card
#   or, newer/stronger (MoE, ~18 GB, splits across GPU+RAM):
ollama pull huihui_ai/qwen3-coder-abliterated:30b

# 2. Build the tuned Redcoder model(s) from the Modelfiles:
ollama create redcoder     -f config/Modelfile.redcoder       # 14B build
ollama create redcoder-max -f config/Modelfile.redcoder-max   # 30B build

# 3. Run it:
python redcoder.py
```

To type `redcoder` from anywhere, put `redcoder.cmd` on a folder that's on your `PATH`
(it locates `redcoder.py` next to itself), or add the repo folder to your `PATH`.

---

## Usage

```powershell
redcoder                                  # start in the current directory
redcoder "refactor utils.py"              # start with a task
redcoder --dangerously-skip-permissions   # never ask before writes/edits/shell
redcoder -p "explain scan.py"             # one-shot: print the answer and exit
git diff | redcoder -p "review this diff" # pipe content in via stdin
redcoder -m redcoder                       # use a specific model
```

**Flags:** `-p/--print`, `-y/--auto` (aka `--dangerously-skip-permissions`, `--yolo`),
`-m/--model NAME`, `-C/--cwd DIR`, `--no-color`, `--no-voice`, `-v/--version`, `-h/--help`.

**In-session commands:** `/help  /clear  /auto  /model [NAME]  /save  /resume  /cwd [PATH]  /exit`.

**Permissions:** read-only tools run automatically; writes, edits, and shell commands ask
for approval first (`Y`/`n`/`a`=always). Skip prompts with `--dangerously-skip-permissions`
or `/auto`.

---

## The model

The `redcoder` Ollama model is built from an abliterated coder base plus a tuned system
prompt and VRAM-tuned context (see `config/Modelfile.redcoder*`). "Abliterated" means the
model's refusal direction has been removed, so it answers offensive-security and coding
questions directly. It's a copilot, not an oracle — verify its commands.

Rebuild or retune anytime with `ollama create redcoder -f config/Modelfile.redcoder`.
On a bigger GPU, swap the `FROM` line for a larger abliterated build.

---

## Web chat

`server.py` serves the chat UI at `http://127.0.0.1:7331`, bound to loopback only (not
exposed on your network). It's conversation only — it does not touch your files. History
lives in the browser tab's memory and is gone when you close it.

---

## Privacy

- The CLI writes nothing to disk except the files you ask it to change (and an opt-in
  `/save` checkpoint, `redcoder.md`).
- Prompts typed at the `>` prompt go through Python's `input()` with no readline/history
  module, so they're never persisted.
- The web UI keeps history in memory only (no `localStorage`, no database); HTTP request
  logging is suppressed.
- Voice recordings are deleted immediately after transcription.
- Note: passing a prompt as a *command-line argument* may be recorded by your shell's own
  history — type it at the `>` prompt to avoid that.

---

## Optional: isolated VirtualBox lab

`scripts/lab-setup.ps1` and `scripts/verify-airgap.ps1` build and audit a pair of VMs on a
VirtualBox **internal network** (no NAT/bridged adapter → no route to the host or internet),
for authorized security testing against machines you own. `verify-airgap.ps1` fails loudly
if it ever finds an internet path.

---

## License

MIT — see [LICENSE](LICENSE).

This tool is for local development and **authorized** security testing on systems you own or
have explicit permission to test. You are responsible for how you use it.
