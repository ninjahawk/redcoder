<#
  start-model.ps1 — bring up the offline Redcoder model.

  Sets Ollama to bind to loopback only (no LAN/internet exposure), enables
  VRAM-saving flash attention + q8 KV cache, builds the tuned model from the
  Modelfile, and warms it so the first real query is instant.

  Safe to run with WiFi OFF — everything below is local once the base model
  has been pulled.
#>

$ErrorActionPreference = 'Stop'
$Root  = Split-Path -Parent $PSScriptRoot
$Model = 'redcoder'                            # tuned model name we create/use
$Base  = 'huihui_ai/qwen2.5-coder-abliterate:14b'

Write-Host "== Redcoder model launcher ==" -ForegroundColor Cyan

# --- Local-only + VRAM tuning (session scope) --------------------------------
$env:OLLAMA_HOST          = '127.0.0.1:11434'  # loopback ONLY — never 0.0.0.0
$env:OLLAMA_FLASH_ATTENTION = '1'
$env:OLLAMA_KV_CACHE_TYPE = 'q8_0'
$env:OLLAMA_KEEP_ALIVE    = '60m'
$env:OLLAMA_NOPRUNE       = '1'
# Best-effort: silence Ollama's update ping (moot when WiFi is off, belt+braces).
$env:OLLAMA_NOHISTORY     = '1'

# --- Make sure the Ollama server is up ---------------------------------------
if (-not (Get-Process ollama -ErrorAction SilentlyContinue)) {
    Write-Host "Starting Ollama server (loopback only)..." -ForegroundColor Yellow
    Start-Process -WindowStyle Hidden ollama 'serve'
    Start-Sleep -Seconds 3
}

# --- Confirm the abliterated base is present ---------------------------------
$have = (& ollama list) -match 'qwen2.5-coder-abliterate'
if (-not $have) {
    Write-Host "Base model '$Base' not found. Pull it while ONLINE with:" -ForegroundColor Red
    Write-Host "    ollama pull $Base" -ForegroundColor Red
    exit 1
}

# --- Build the tuned model from the Modelfile --------------------------------
Write-Host "Building tuned model '$Model' from Modelfile..." -ForegroundColor Yellow
& ollama create $Model -f (Join-Path $Root 'config\Modelfile.redcoder')

# --- Warm it (loads into VRAM) -----------------------------------------------
Write-Host "Warming model into VRAM..." -ForegroundColor Yellow
& ollama run $Model "ok" | Out-Null

Write-Host ""
Write-Host "Model '$Model' is loaded and ready (loopback 127.0.0.1:11434)." -ForegroundColor Green
Write-Host "Ask it something with:  .\scripts\ask.ps1 ""your prompt""" -ForegroundColor Green
Write-Host "VRAM check:             nvidia-smi" -ForegroundColor DarkGray
