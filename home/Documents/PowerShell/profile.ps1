# Terminals opened before WinGet added these to PATH lack them until restarted.
if (Get-Command starship -ErrorAction SilentlyContinue) {
    Invoke-Expression (&starship init powershell)
}

if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (zoxide init powershell | Out-String)
}

if (Get-Command mise -ErrorAction SilentlyContinue) {
    Invoke-Expression (mise activate pwsh | Out-String)
}

# Upgrade dotfiles, WinGet packages, mise tools and Rust toolchains; pinned packages stay.
function update {
    chezmoi update
    if ($LASTEXITCODE -eq 0) {
        winget upgrade --all --accept-package-agreements --accept-source-agreements
        mise upgrade
        rustup update
    }
}
