param([string]$name)

if ([string]::IsNullOrEmpty($name)) {
    Write-Host "Usage: dev-init.ps1 <environment_name>"
    exit 1
}

$templateFilePath = Join-Path $PSScriptRoot ".env.template"
$outputFilePath = Join-Path $PSScriptRoot "$name.env"
$lastEnvFilePath = Join-Path $PSScriptRoot ".env.last"

if (-not (Test-Path $templateFilePath)) {
    Write-Error "Error: .env.template not found at '$templateFilePath'."
    exit 1
}

$templateContent = Get-Content $templateFilePath
$newContent = @()

$lastEnvVars = @{}
if (Test-Path $lastEnvFilePath) {
    Write-Host "Existing '$lastEnvFilePath' found. Its values will be used as defaults if not overridden."
    (Get-Content $lastEnvFilePath) | ForEach-Object {
        if ($_ -match '^\s*([a-zA-Z0-9_]+)=(.*)') {
            $key = $matches[1]
            $value = $matches[2]
            if ($value -match '^"(.*)"$' -or $value -match "^'(.*)'$") {
                $value = $matches[1]
            }
            $lastEnvVars[$key] = $value
        }
    }
}

$existingEnvVars = @{}
if (Test-Path $outputFilePath) {
    Write-Host "Existing '$outputFilePath' found. Its values will be prioritized as defaults."
    (Get-Content $outputFilePath) | ForEach-Object {
        if ($_ -match '^\s*([a-zA-Z0-9_]+)=(.*)') {
            $key = $matches[1]
            $value = $matches[2]
            if ($value -match '^"(.*)"$' -or $value -match "^'(.*)'$") {
                $value = $matches[1]
            }
            $existingEnvVars[$key] = $value
        }
    }
}

Write-Host "Creating or updating '$outputFilePath' from '$templateFilePath'."
Write-Host "Priority for default values: '$outputFilePath' > '$lastEnvFilePath' > '$templateFilePath'."
Write-Host "Please provide values for the environment variables. Press Enter to keep the current value."

foreach ($line in $templateContent) {
    if ($line -match '^\s*([a-zA-Z0-9_]+)=(.*)') {
        $key = $matches[1]
        $templateValue = $matches[2] 
        if ($templateValue -match '^"(.*)"$' -or $templateValue -match "^'(.*)'$") {
            $templateValue = $matches[1]
        }
        
        $defaultValue = $templateValue

        if ($lastEnvVars.ContainsKey($key)) {
            $defaultValue = $lastEnvVars[$key]
        }
        
        if ($existingEnvVars.ContainsKey($key)) {
            $defaultValue = $existingEnvVars[$key]
        }
        
        $prompt = "Enter value for '$key' (current: '$defaultValue'): "
        $userInput = Read-Host $prompt

        if ([string]::IsNullOrEmpty($userInput)) {
            $newContent += "$key=$defaultValue"
        } else {
            $newContent += "$key=$userInput"
        }
    } else {
        $newContent += $line
    }
}

Set-Content -Path $outputFilePath -Value $newContent
Write-Host "Successfully created '$outputFilePath'."

Set-Content -Path $lastEnvFilePath -Value $newContent
Write-Host "Saved current configuration to '$lastEnvFilePath'."

