Invoke-Expression (&starship init powershell)
Invoke-Expression (zoxide init powershell | Out-String)

# Upgrade dotfiles and WinGet packages; pinned packages stay.
function update {
    chezmoi update
    if ($LASTEXITCODE -eq 0) {
        winget upgrade --all --accept-package-agreements --accept-source-agreements
    }
}
