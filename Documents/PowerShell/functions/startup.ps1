# Checks whether a our script was already run by using a flag file. 
function Test-ScriptRunOnce {
    $ScriptName = "startup"
    $flagFile = Join-Path $env:TEMP "$($ScriptName)_run.flag"
    $lastBoot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
    if (Test-Path $flagFile) {
        $fileCreated = (Get-Item $flagFile).CreationTime
        
        if ($fileCreated -gt $lastBoot) {
            # Script has already run since the last boot
            return $true
        }
    }
    New-Item -Path $flagFile -ItemType File -Force | Out-Null
    return $false
}

function Add-ToPath {
    param (
        [Parameter(Mandatory=$true)]
        [string]$NewPath
    )

    # 1. Normalize the path (resolves relative paths and removes trailing slashes)
    $NormalizedPath = (Resolve-Path -Path $NewPath -ErrorAction SilentlyContinue).Path
    if (-not $NormalizedPath) {
        $NormalizedPath = $NewPath
    }

    # 2. Check if directory exists; if not, create it
    if (-not (Test-Path -Path $NormalizedPath)) {
        Write-Host "Directory '$NormalizedPath' does not exist. Creating it..." -ForegroundColor Cyan
        New-Item -ItemType Directory -Path $NormalizedPath -Force | Out-Null
    }

    # 3. Get current PATH and split into an array
    $CurrentPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $PathArray = $CurrentPath -split ";"

    # 4. Check if the path is already in the array (case-insensitive)
    if ($PathArray -contains $NormalizedPath) {
        Write-Host "Path '$NormalizedPath' is already in the User PATH." -ForegroundColor Yellow
    }
    else {
        # 5. Append and Save
        $NewPathString = "$CurrentPath;$NormalizedPath"
        [Environment]::SetEnvironmentVariable("Path", $NewPathString, "User")
        
        # Update current session as well
        $env:Path = "$env:Path;$NormalizedPath"
        
        Write-Host "Successfully added '$NormalizedPath' to the User PATH." -ForegroundColor Green
    }
}

if(-not (Test-ScriptRunOnce)) {
  gpg-connect-agent /bye
  Add-ToPath -NewPath "$HOME\bin"
  Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
  Install-Module -Name BurntToast -Scope CurrentUser

  function Confirm-FileExists {
      param (
          [Parameter(Mandatory=$true)]
          [string]$FileName,

          [Parameter(Mandatory=$true)]
          [string]$DownloadUrl
      )

      if (-not (Test-Path -Path "$FileName")) {
          # Define the button that opens the URL
          $Button = New-BTButton -Content "Download $FileName" -Arguments $DownloadUrl
          $Header = New-BTHeader -Id 'FileCheck' -Title 'File Not Found'
          New-BurntToastNotification -Text "The required file '$FileName' is missing from the directory $HOME\bin" -Button $Button -Header $Header
      }
  }

  Confirm-FileExists -FileName "$HOME\bin\npiperelay.exe" -DownloadUrl "https://github.com/albertony/npiperelay/releases/download/v1.9.2/npiperelay_windows_amd64.exe"
  Confirm-FileExists -FileName "$HOME\bin\wsl-ssh-pageant-amd64-gui.exe" -DownloadUrl "https://github.com/benpye/wsl-ssh-pageant/releases/download/20201121.2/wsl-ssh-pageant-amd64-gui.exe"
  New-BurntToastNotification -Text "Startup Complete"
}
