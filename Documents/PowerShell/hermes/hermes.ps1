param(
    [string]$action = "start"
)

$action = $action.ToLowerInvariant()
$valid = @("start", "stop", "restart", "status", "logs", "setup")
if ($valid -notcontains $action) {
    Write-Host "Invalid action: $action"
    Write-Host "Usage: hermes.ps1 [start|stop|restart|status|logs|setup]"
    exit 1
}

$variant = $env:HERMES_VARIANT
if ([string]::IsNullOrEmpty($variant)) {
    $variant = "directory"
}
$variant = $variant.ToLowerInvariant()

switch ($variant) {
    { $_ -in @("directory", "dir", "bind") } {
        $variant = "directory"
        $composeFile = Join-Path $PSScriptRoot "docker-compose.directory.yml"
    }
    "volume" {
        $composeFile = Join-Path $PSScriptRoot "docker-compose.yml"
    }
    default {
        Write-Host "Unknown variant '$variant' (set via `$env:HERMES_VARIANT), falling back to directory"
        $variant = "directory"
        $composeFile = Join-Path $PSScriptRoot "docker-compose.directory.yml"
    }
}

Write-Host "Using '$variant' variant ($composeFile)."

function Invoke-Compose {
    param([string]$cmd)
    $full = "docker compose -f `"$composeFile`" $cmd"
    Invoke-Expression $full
}

switch ($action) {
    "start"   { Invoke-Compose "up -d" }
    "stop"    { Invoke-Compose "down" }
    "restart" {
        Invoke-Compose "down"
        Invoke-Compose "up -d"
    }
    "status"  { Invoke-Compose "ps" }
    "logs"    { Invoke-Compose "logs -f" }
    "setup"   { Invoke-Compose "run --rm --name hermes-setup hermes setup" }
}
