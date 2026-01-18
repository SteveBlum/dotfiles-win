## Autosuggestions
## Install-Module PSReadLine -RequiredVersion 2.3.5
Import-Module PSReadLine
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -HistorySearchCursorMovesToEnd
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
Set-PSReadLineOption -Colors @{ InlinePrediction = '#875f5f'}

# Navigation key bindings
Set-PSReadLineKeyHandler -Chord "Ctrl+LeftArrow" -Function BackwardWord
Set-PSReadLineKeyHandler -Chord "Ctrl+RightArrow" -Function ForwardWord

## Set aliases
Set-Alias -Name dev -Value "$PSScriptRoot/dev/dev.ps1"
Set-Alias -Name dev-init -Value "$PSScriptRoot/dev/dev-init.ps1"
