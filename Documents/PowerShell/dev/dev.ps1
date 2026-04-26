param(
    [string]$name,
    [string]$action = "start"
)

if ([string]::IsNullOrEmpty($name)) {
    Write-Host "Usage: dev.ps1 <environment_name> [start|stop|restart|status|logs]"
    exit 1
}

$action = $action.ToLowerInvariant()
$valid = @("start","stop","restart","status","logs")
if ($valid -notcontains $action) {
    Write-Host "Invalid action: $action"
    Write-Host "Usage: dev.ps1 <environment_name> [start|stop|restart|status|logs]"
    exit 1
}

# Determine whether this is a path-based workspace (local directory) or a volume-based one
$isPathWorkspace = Test-Path -Path "$PWD\$name"

if ($isPathWorkspace) {
    $envFile = "$PSScriptRoot/.env.last"
    $composeArgs = "-f `"$PSScriptRoot/docker-compose.yml`" -f `"$PSScriptRoot/docker-compose.path.yml`""
    # For path workspaces we expose the path
    $env:WORKSPACE_PATH = "$PWD\$name"
} else {
    $envFile = "$PSScriptRoot/$name.env"
    $composeArgs = "-f `"$PSScriptRoot/docker-compose.yml`" -f `"$PSScriptRoot/docker-compose.volume.yml`""
}

# Helper to invoke docker compose with the chosen env file and compose files
function Invoke-Compose {
    param([string]$cmd)
    $full = "docker compose --env-file `"$envFile`" $composeArgs $cmd"
    Invoke-Expression $full
}

switch ($action) {
    "start" {
        if ($isPathWorkspace) {
            # start path-based workspace
            Invoke-Compose "up -d"
        } else {
            # ensure env exists (call dev-init if missing)
            $devInitCalled = $false
            if (-not (Test-Path "$envFile")) {
                . "$PSScriptRoot/dev-init.ps1" -name $name
                $devInitCalled = $true
            }

            $env:WORKSPACE_VOLUME = $name
            Invoke-Compose "up -d"
        }

        # Attach to the dev container (blocks until detach)
        docker attach dev
    }

    "stop" {
        if (-not $isPathWorkspace -and -not (Test-Path "$envFile")) {
            Write-Host "Environment file '$envFile' is missing. Run 'start' to initialize the workspace first."
            exit 1
        }

        if ($isPathWorkspace) { $env:WORKSPACE_PATH = "$PWD\$name" } else { $env:WORKSPACE_VOLUME = $name }
        Invoke-Compose "down"
    }

    "restart" {
        if ($isPathWorkspace) {
            # full restart for path-based
            Invoke-Compose "down"
            Invoke-Compose "up -d"
        } else {
            # ensure env exists for restart
            if (-not (Test-Path "$envFile")) {
                . "$PSScriptRoot/dev-init.ps1" -name $name
            }
            $env:WORKSPACE_VOLUME = $name
            Invoke-Compose "down"
            Invoke-Compose "up -d"
        }

        # Attach after restart (same as start)
        docker attach dev
    }

    "status" {
        if (-not $isPathWorkspace -and -not (Test-Path "$envFile")) {
            Write-Host "Environment file '$envFile' is missing. Run 'start' to initialize the workspace first."
            exit 1
        }
        if ($isPathWorkspace) { $env:WORKSPACE_PATH = "$PWD\$name" } else { $env:WORKSPACE_VOLUME = $name }
        Invoke-Compose "ps"
    }

    "logs" {
        # Follow live logs
        if (-not $isPathWorkspace -and -not (Test-Path "$envFile")) {
            Write-Host "Environment file '$envFile' is missing. Run 'start' to initialize the workspace first."
            exit 1
        }
        if ($isPathWorkspace) { $env:WORKSPACE_PATH = "$PWD\$name" } else { $env:WORKSPACE_VOLUME = $name }
        Invoke-Compose "logs -f"
    }
}
