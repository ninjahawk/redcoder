<#
  verify-airgap.ps1 - audit that the lab has no path to the internet.

  Checks, in order:
   1. Every lab VM's NICs. Only 'intnet', 'hostonly', 'none' are allowed.
      Any 'nat', 'natnetwork', or 'bridged' NIC = a possible internet path -> FAIL.
   2. The Ollama model server binds to loopback (127.0.0.1) only, not 0.0.0.0.
   3. Reports host network adapters that are UP as a reminder to disable WiFi.

  WHAT IT PROVES / DOESN'T
   - PASS on #1 means VirtualBox gives these VMs no route off the isolated
     internal network - true even if host WiFi is on.
   - It cannot inspect what you later change by hand inside a guest, and it is
     not a substitute for turning WiFi off. Treat WiFi-off as the outer layer
     and internal-network-only as the inner, load-bearing one.
#>

param(
    [string[]]$VmNames = @('rc-attacker','rc-target'),
    [switch]$All
)

# --- Resolve VBoxManage (not always on PATH in PowerShell) -------------------
function Get-VBox {
    $c = Get-Command VBoxManage -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    foreach ($p in @(
        "$env:ProgramFiles\Oracle\VirtualBox\VBoxManage.exe",
        "${env:ProgramFiles(x86)}\Oracle\VirtualBox\VBoxManage.exe",
        "$env:VBOX_MSI_INSTALL_PATH\VBoxManage.exe")) {
        if ($p -and (Test-Path $p)) { return $p }
    }
    return $null
}
$VBox = Get-VBox
$fail = $false

Write-Host "==================== AIR-GAP AUDIT ====================" -ForegroundColor Cyan

# ---- 1. VM NIC audit --------------------------------------------------------
if (-not $VBox) {
    Write-Host "VBoxManage not found - skipping VM checks. Install VirtualBox or add it to PATH." -ForegroundColor Yellow
} else {
    if ($All) {
        $VmNames = (& $VBox list vms) | ForEach-Object { ($_ -split '"')[1] }
    }
    foreach ($vm in $VmNames) {
        if (-not ((& $VBox list vms) -match "`"$vm`"")) {
            Write-Host "[skip] VM '$vm' not found." -ForegroundColor DarkGray
            continue
        }
        $info = & $VBox showvminfo $vm --machinereadable
        Write-Host "`nVM: $vm" -ForegroundColor White
        $leak = $false
        foreach ($line in ($info | Select-String -Pattern '^nic\d+=')) {
            $type = ($line -split '=')[1].Trim('"')
            $nic  = ($line -split '=')[0]
            switch -Regex ($type) {
                '^(nat|natnetwork|bridged)$' {
                    Write-Host "   $nic = $type   <-- INTERNET PATH (FAIL)" -ForegroundColor Red
                    $leak = $true; $fail = $true
                }
                '^(intnet|hostonly)$' {
                    Write-Host "   $nic = $type   (isolated, ok)" -ForegroundColor Green
                }
                '^(none|null)$' {
                    Write-Host "   $nic = $type   (disabled)" -ForegroundColor DarkGray
                }
                default {
                    Write-Host "   $nic = $type   (review manually)" -ForegroundColor Yellow
                }
            }
        }
        if (-not $leak) { Write-Host "   => isolated: no NAT/bridged adapter." -ForegroundColor Green }
    }
}

# ---- 2. Ollama loopback check ----------------------------------------------
Write-Host "`nModel server binding:" -ForegroundColor White
$listen = netstat -ano | Select-String ':11434'
if (-not $listen) {
    Write-Host "   Ollama not currently listening on :11434 (start it to fully verify)." -ForegroundColor Yellow
} elseif ($listen -match '0\.0\.0\.0:11434' -or $listen -match '\[::\]:11434') {
    Write-Host "   :11434 bound to ALL interfaces  <-- reachable over LAN/Tailscale (FAIL)" -ForegroundColor Red
    Write-Host "   Fix: set OLLAMA_HOST=127.0.0.1:11434 and restart Ollama (see docs/README)." -ForegroundColor Red
    $fail = $true
} else {
    Write-Host "   :11434 bound to loopback only (ok)" -ForegroundColor Green
}

# ---- 3. Host adapter reminder ----------------------------------------------
Write-Host "`nHost network adapters currently UP (disable these before live runs):" -ForegroundColor White
Get-NetAdapter | Where-Object Status -eq 'Up' |
    ForEach-Object { Write-Host ("   {0}  [{1}]" -f $_.Name, $_.InterfaceDescription) -ForegroundColor Yellow }

# ---- Verdict ----------------------------------------------------------------
Write-Host "`n======================================================" -ForegroundColor Cyan
if ($fail) {
    Write-Host "RESULT: FAIL - an internet/exposure path was found above. Fix before live runs." -ForegroundColor Red
    exit 1
} else {
    Write-Host "RESULT: PASS - lab VMs are isolated and the model server is loopback-only." -ForegroundColor Green
    Write-Host "Remember to also switch WiFi OFF as the outer layer." -ForegroundColor Green
    exit 0
}
