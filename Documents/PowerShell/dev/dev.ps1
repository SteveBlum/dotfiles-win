param([string]$name)

if ([string]::IsNullOrEmpty($name)) {
    Write-Host "Usage: dev.ps1 <environment_name>"
    exit 1
}

if (Test-Path -Path $PWD\$name) {
    $env:WORKSPACE_PATH="$PWD\$name"; docker compose --env-file "$PSScriptRoot/.env.last" -f "$PSScriptRoot/docker-compose.yml" -f "$PSScriptRoot/docker-compose.path.yml" up -d
} else {
  $devInitCalled = $false
  if (-not (Test-Path "$PSScriptRoot/$name.env")) {
      . "$PSScriptRoot/dev-init.ps1" -name $name
      $devInitCalled = $true
  }

  # Check if docker compose services are already running
  $env:WORKSPACE_VOLUME="$name"; $runningServices = docker compose --env-file "$PSScriptRoot/$name.env" -f "$PSScriptRoot/docker-compose.yml" -f "$PSScriptRoot/docker-compose.volume.yml" ps --status running -q

  if ($devInitCalled -or ([string]::IsNullOrEmpty($runningServices))) {
    $env:WORKSPACE_VOLUME="$name"; docker compose --env-file   "$PSScriptRoot/$name.env" -f "$PSScriptRoot/docker-compose.yml" -f "$PSScriptRoot/docker-compose.volume.yml" up -d
  }
}
docker attach dev
