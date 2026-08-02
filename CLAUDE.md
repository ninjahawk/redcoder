# Redcoder — notes for Claude Code / contributors

Redcoder is an offline, local AI coding agent (a Claude-Code-style terminal loop) plus a
web chat, both driven by a local model through Ollama.

## Layout
- `redcoder.py` — the CLI agent (pure Python standard library, no third-party imports in the
  core; Whisper/torch are imported lazily only if voice is used). Single file.
- `server.py` + `webui/index.html` — the loopback web chat (streams from Ollama; no tools).
- `config/Modelfile.redcoder*` — Ollama Modelfiles that build the tuned models.
- `scripts/*.ps1` — helpers to launch the model and build/audit an isolated VirtualBox lab.

## Design rules (please keep these)
- **Standard library only** in the CLI core. Voice (Whisper/ffmpeg) is optional and gated by
  `voice_available()`; never make it a hard dependency.
- **No logging.** The agent must not persist conversation content anywhere except the files
  the user explicitly asks for and the opt-in `/save` checkpoint (`redcoder.md`). No
  transcripts, history files, or telemetry.
- **Offline.** Only talk to `127.0.0.1:11434` (Ollama). Never add network calls to third
  parties.
- **Tool-call protocol.** The model emits a single JSON object (often in a ```json fence) with
  `{"name","arguments"}`. `extract_action()` parses it with a brace-balanced scanner (not a
  regex) so payloads containing `}` (e.g. f-string braces) don't break parsing.
- **Live UI.** `StreamPrinter` must always show activity while the model generates: prose
  streams live, `write_file`/`edit_file` stream as a colored diff, and any other tool keeps a
  spinner running. Don't reintroduce silent buffering.

## Testing without a model
Most display logic (`render_markdown`, `show_diff`, `StreamPrinter`, `input_bar`) can be unit
-tested by feeding synthetic input and capturing stdout with color forced on
(`redcoder._C = True`). The agent loop needs a running Ollama with a `redcoder` model.

## Run
```
python redcoder.py            # interactive
python redcoder.py -p "..."   # one-shot
```
