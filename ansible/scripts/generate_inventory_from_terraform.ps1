param(
    [string]$TerraformDir = "..\\terraform\\aws",
    [string]$InventoryFile = ".\\inventories\\production\\hosts.ini",
    [string]$AnsibleUser = "ec2-user"
)

$ErrorActionPreference = "Stop"

Push-Location $TerraformDir
try {
    $tfOutput = terraform output -json | ConvertFrom-Json
    $ips = @($tfOutput.swarm_public_ips.value)
}
finally {
    Pop-Location
}

if ($ips.Count -lt 3) {
    throw "Expected at least 3 swarm_public_ips values from Terraform output."
}

$managerIp = $ips[0]
$workerIps = $ips[1..($ips.Count - 1)]

$lines = @()
$lines += "[manager]"
$lines += "manager1 ansible_host=$managerIp ansible_user=$AnsibleUser"
$lines += ""
$lines += "[workers]"

for ($i = 0; $i -lt $workerIps.Count; $i++) {
    $workerIndex = $i + 1
    $lines += "worker$workerIndex ansible_host=$($workerIps[$i]) ansible_user=$AnsibleUser"
}

$lines += ""
$lines += "[swarm:children]"
$lines += "manager"
$lines += "workers"

$inventoryDir = Split-Path -Path $InventoryFile -Parent
if (-not (Test-Path $inventoryDir)) {
    New-Item -Path $inventoryDir -ItemType Directory -Force | Out-Null
}

Set-Content -Path $InventoryFile -Value ($lines -join [Environment]::NewLine) -Encoding UTF8
Write-Host "Inventory generated at $InventoryFile"
