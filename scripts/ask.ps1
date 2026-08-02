<#
  ask.ps1 — one-shot query to the offline Redcoder model.
  Usage:  .\scripts\ask.ps1 "how would I enumerate SMB shares on 10.13.37.20"
#>
param([Parameter(Mandatory=$true, ValueFromRemainingArguments=$true)][string[]]$Prompt)

$env:OLLAMA_HOST = '127.0.0.1:11434'
$text = ($Prompt -join ' ')
& ollama run redcoder $text
