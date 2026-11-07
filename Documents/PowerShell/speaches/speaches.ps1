param(
    [string]$action = "start"
)

$action = $action.ToLowerInvariant()
$valid = @("start", "stop", "restart", "status", "logs")
if ($valid -notcontains $action) {
    Write-Host "Invalid action: $action"
    Write-Host "Usage: speaches.ps1 [start|stop|restart|status|logs]"
    exit 1
}

$variant = $env:SPEACHES_VARIANT
if ([string]::IsNullOrEmpty($variant)) {
    $variant = "cpu"
}
$variant = $variant.ToLowerInvariant()

switch ($variant) {
    { $_ -in @("cuda", "gpu") } {
        $variant = "cuda"
        $composeFile = Join-Path $PSScriptRoot "docker-compose.cuda.yml"
    }
    "cpu" {
        $composeFile = Join-Path $PSScriptRoot "docker-compose.yml"
    }
    default {
        Write-Host "Unknown variant '$variant' (set via `$env:SPEACHES_VARIANT), falling back to cpu"
        $variant = "cpu"
        $composeFile = Join-Path $PSScriptRoot "docker-compose.yml"
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
}
