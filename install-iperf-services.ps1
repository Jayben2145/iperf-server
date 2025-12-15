#requires -RunAsAdministrator
<#
    Creates multiple iperf3 Windows services (one per port) using NSSM.

    Example:
      powershell -ExecutionPolicy Bypass -File .\install-iperf-services.ps1 `
        -Count 20 -StartPort 5000 `
        -IperfPath "C:\iperf3\iperf3.exe" `
        -NssmPath "C:\nssm\nssm.exe" `
        -LogDir "C:\iperf3\logs"
#>

[CmdletBinding()]
param (
    [int]$Count = 20,
    [int]$StartPort = 5000,
    [string]$IperfPath = "C:\iperf3\iperf3.exe",
    [string]$NssmPath = "C:\nssm\nssm.exe",
    [string]$LogDir = "C:\iperf3\logs"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Info($message) {
    Write-Host "[info] $message"
}

function Ensure-FileExists([string]$path, [string]$displayName) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "$displayName not found at $path"
    }
}

Ensure-FileExists -path $IperfPath -displayName "iperf3 executable"
Ensure-FileExists -path $NssmPath -displayName "nssm executable"

if (-not (Test-Path -LiteralPath $LogDir)) {
    Write-Info "Creating log directory at $LogDir"
    New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
}

$endPort = $StartPort + $Count - 1

Write-Info "Setting up $Count iperf3 services on ports $StartPort-$endPort"

for ($i = 0; $i -lt $Count; $i++) {
    $port = $StartPort + $i
    $serviceName = "iperf3-$port"
    $stdout = Join-Path $LogDir "$serviceName.out.log"
    $stderr = Join-Path $LogDir "$serviceName.err.log"

    $existing = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Info "Service $serviceName already exists; removing so it can be recreated"
        & $NssmPath stop $serviceName | Out-Null
        & $NssmPath remove $serviceName confirm | Out-Null
    }

    Write-Info "Installing $serviceName on port $port"
    & $NssmPath install $serviceName $IperfPath "-s -p $port" | Out-Null
    & $NssmPath set $serviceName Start SERVICE_AUTO_START | Out-Null
    & $NssmPath set $serviceName AppStdout $stdout | Out-Null
    & $NssmPath set $serviceName AppStderr $stderr | Out-Null
    & $NssmPath set $serviceName AppRotateFiles 1 | Out-Null
    & $NssmPath set $serviceName AppRotateOnline 1 | Out-Null
    & $NssmPath set $serviceName AppRotateSeconds 86400 | Out-Null

    Start-Service $serviceName
}

# Single firewall rule for the whole range
Write-Info "Ensuring Windows Firewall allows TCP $StartPort-$endPort"
New-NetFirewallRule `
    -DisplayName "iperf3 $StartPort-$endPort" `
    -Direction Inbound `
    -Action Allow `
    -Protocol TCP `
    -LocalPort "$StartPort-$endPort" `
    -Profile Any `
    -ErrorAction SilentlyContinue | Out-Null

Write-Info "Done. Services created:"
Get-Service -Name "iperf3-*"
