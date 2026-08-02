<#
  lab-setup.ps1 — configure an air-gapped attacker/target pair in VirtualBox.

  ISOLATION MODEL
  ---------------
  Both VMs get a single NIC on a VirtualBox INTERNAL NETWORK ("redcoderlab").
  An internal network is isolated from the host AND from the internet: frames
  only move between VMs that share the internal-network name. There is NO NAT
  and NO bridged adapter anywhere, so no VM can reach the internet even if the
  host WiFi is on. WiFi-off is then a second, redundant layer.

  WHAT THIS DOES / DOESN'T DO
  ---------------------------
  - Creates the two VM shells (if missing) with a blank disk, ready to install.
  - Forces isolated networking and disables NICs 2-4 so nothing can leak.
  - Attaches an install ISO if you pass one.
  - It does NOT install the guest OS for you — that step is interactive
    (boot the ISO in the VirtualBox GUI and install as normal).

  USAGE
    .\scripts\lab-setup.ps1 -AttackerIso "C:\isos\kali.iso" -TargetIso "C:\isos\metasploitable.iso"
    .\scripts\lab-setup.ps1                 # just (re)apply isolated networking to existing VMs
#>

param(
    [string]$AttackerName = 'rc-attacker',
    [string]$TargetName   = 'rc-target',
    [string]$AttackerIso  = '',
    [string]$TargetIso    = '',
    [string]$NetName      = 'redcoderlab',
    [int]$DiskGB          = 20
)

$ErrorActionPreference = 'Stop'

function Get-VBox {
    $c = Get-Command VBoxManage -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    foreach ($p in @(
        "$env:ProgramFiles\Oracle\VirtualBox\VBoxManage.exe",
        "${env:ProgramFiles(x86)}\Oracle\VirtualBox\VBoxManage.exe",
        "$env:VBOX_MSI_INSTALL_PATH\VBoxManage.exe")) {
        if ($p -and (Test-Path $p)) { return $p }
    }
    throw "VBoxManage not found. Install VirtualBox or add it to PATH."
}
$VBox = Get-VBox
$Root = Split-Path -Parent $PSScriptRoot
$VmDir = Join-Path $Root 'lab\vms'
New-Item -ItemType Directory -Force -Path $VmDir | Out-Null

function Test-Vm($name) { (& $VBox list vms) -match "`"$name`"" }

function New-IsolatedVm($name, $iso) {
    if (-not (Test-Vm $name)) {
        Write-Host "Creating VM '$name'..." -ForegroundColor Yellow
        & $VBox createvm --name $name --basefolder $VmDir --ostype Linux_64 --register
        & $VBox modifyvm $name --memory 2048 --cpus 2 --vram 32
        # blank disk
        $disk = Join-Path $VmDir "$name\$name.vdi"
        & $VBox createmedium disk --filename $disk --size ($DiskGB * 1024) --format VDI
        & $VBox storagectl $name --name SATA --add sata --controller IntelAhci
        & $VBox storageattach $name --storagectl SATA --port 0 --device 0 --type hdd --medium $disk
        & $VBox storagectl $name --name IDE --add ide
    } else {
        Write-Host "VM '$name' already exists — reapplying isolated networking." -ForegroundColor DarkGray
    }

    # --- THE ISOLATION: internal network only, all other NICs OFF ---
    & $VBox modifyvm $name --nic1 intnet --intnet1 $NetName --cableconnected1 on
    & $VBox modifyvm $name --nic2 none --nic3 none --nic4 none

    if ($iso -and (Test-Path $iso)) {
        Write-Host "Attaching ISO '$iso' to '$name'..." -ForegroundColor Yellow
        if (-not ((& $VBox showvminfo $name --machinereadable) -match 'storagecontrollername.*IDE')) {
            & $VBox storagectl $name --name IDE --add ide
        }
        & $VBox storageattach $name --storagectl IDE --port 0 --device 0 --type dvddrive --medium $iso
    }
}

Write-Host "== Building isolated lab on internal network '$NetName' ==" -ForegroundColor Cyan
New-IsolatedVm $AttackerName $AttackerIso
New-IsolatedVm $TargetName   $TargetIso

Write-Host ""
Write-Host "Done. VMs configured with ISOLATED internal networking (no internet path)." -ForegroundColor Green
Write-Host "Next:" -ForegroundColor Green
Write-Host "  1. Open VirtualBox, boot each VM, install the OS from its ISO." -ForegroundColor Green
Write-Host "  2. Inside the guests, set static IPs on the same subnet, e.g.:" -ForegroundColor Green
Write-Host "        attacker: 10.13.37.10/24     target: 10.13.37.20/24" -ForegroundColor Green
Write-Host "  3. Verify isolation:  .\scripts\verify-airgap.ps1" -ForegroundColor Green
