param([string]$name)

if ([string]::IsNullOrEmpty($name)) {
    Write-Host "Usage: dev.ps1 <environment_name>"
    exit 1
}

$devInitCalled = $false
if (-not (Test-Path "$PSScriptRoot/$name.env")) {
    . "$PSScriptRoot/dev-init.ps1" -name $name
    $devInitCalled = $true
}

# Check if docker compose services are already running
$runningServices = docker compose --env-file "$PSScriptRoot/$name.env" -f "$PSScriptRoot/docker-compose.dev.yml" ps --status running -q

if ($devInitCalled -or ([string]::IsNullOrEmpty($runningServices))) {
    docker compose --env-file "$PSScriptRoot/$name.env" -f "$PSScriptRoot/docker-compose.dev.yml" up -d
}
docker attach dev
