#Requires -Version 7.5
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
Set-StrictMode -Version Latest

if (!$IsWindows) {
    throw 'Use tests/verify-ubuntu.sh in the verification container on Ubuntu.'
}

$repository = Split-Path -Parent $PSScriptRoot
$chezmoi = (Get-Command chezmoi -CommandType Application -ErrorAction Stop).Source

function Assert {
    param([bool]$Condition, [string]$Message)

    if (!$Condition) {
        throw $Message
    }
}

$temporary = [IO.Directory]::CreateTempSubdirectory('dotfiles-verify-')
try {
    $checkout = Join-Path $temporary.FullName 'checkout [apps] 日本語'
    $destination = Join-Path $temporary.FullName 'home with spaces'
    $null = [IO.Directory]::CreateDirectory($checkout)
    $null = [IO.Directory]::CreateDirectory($destination)
    foreach ($file in '.chezmoiroot', '.chezmoiversion', 'home', 'winget.json') {
        Copy-Item -LiteralPath (Join-Path $repository $file) -Destination $checkout -Recurse
    }
    $options = @('--config', (Join-Path $temporary.FullName 'config.toml'), '--destination', $destination,
        '--persistent-state', (Join-Path $temporary.FullName 'state.boltdb'),
        '--cache', (Join-Path $temporary.FullName 'cache'), '--no-tty', '--no-pager')
    foreach ($empty in 'Git name= ,Git email=test@example.invalid', 'Git name=Test User,Git email= ') {
        $null = & $chezmoi @options init --source $checkout --promptString $empty 2>&1
        Assert ($LASTEXITCODE -ne 0) 'Empty Git identity was accepted.'
    }
    $name = 'Test "User" \ 日本語'
    & $chezmoi @options init --source $checkout --promptString ('"Git name=' + $name.Replace('"', '""') + '",Git email=test@example.invalid')
    Assert ($LASTEXITCODE -eq 0) 'chezmoi init failed.'

    # Replace only WinGet in the copied hook; record each call and fail on demand.
    $hook = Join-Path $checkout 'home/.chezmoiscripts/windows/run_onchange_after_install-apps.ps1.tmpl'
    $mock = @'
function winget.exe {
    if (![IO.File]::Exists((Join-Path $env:CHEZMOI_DEST_DIR '.gitconfig'))) {
        throw 'Installer ran before configuration.'
    }
    [IO.File]::AppendAllText((Join-Path $env:CHEZMOI_DEST_DIR 'winget.log'), "$args`n")
    $global:LASTEXITCODE = if ([IO.File]::Exists((Join-Path $env:CHEZMOI_DEST_DIR 'fail'))) { 37 } else { 0 }
}

'@
    [IO.File]::WriteAllText($hook, $mock + [IO.File]::ReadAllText($hook))
    $log = Join-Path $destination 'winget.log'
    $gitconfig = Join-Path $destination '.gitconfig'
    $profile = Join-Path $destination 'Documents/PowerShell/profile.ps1'

    [IO.File]::WriteAllText((Join-Path $destination 'fail'), '')
    $output = (& $chezmoi @options apply 2>&1) -join "`n"
    Assert ($LASTEXITCODE -ne 0 -and $output.Contains('exit 37')) "WinGet failure was not reported: $output"
    [IO.File]::Delete((Join-Path $destination 'fail'))
    [IO.File]::Delete($log)

    & $chezmoi @options apply
    Assert ($LASTEXITCODE -eq 0) 'Apply failed.'
    $winget = Join-Path $checkout 'winget.json'
    $expected = @(
        "import --import-file $winget --no-upgrade --accept-package-agreements --accept-source-agreements --disable-interactivity",
        'pin add --id Celsys.ClipStudioPaint --exact --version 5.0.4 --force --accept-source-agreements --disable-interactivity'
    )
    Assert ((Compare-Object $expected ([IO.File]::ReadAllLines($log)) -SyncWindow 0) -eq $null) 'WinGet calls changed.'
    & $chezmoi @options apply
    Assert ($LASTEXITCODE -eq 0 -and [IO.File]::ReadAllLines($log).Count -eq 2) 'Unchanged winget.json ran WinGet again.'
    [IO.File]::AppendAllText($winget, "`n")
    & $chezmoi @options apply
    Assert ($LASTEXITCODE -eq 0 -and [IO.File]::ReadAllLines($log).Count -eq 4) 'Changed winget.json did not rerun WinGet.'

    foreach ($relative in '.bash_aliases', '.config/mise') {
        Assert (!(Test-Path -LiteralPath (Join-Path $destination $relative))) "Ubuntu-only $relative was applied."
    }
    Assert ((& git config --file $gitconfig --get user.name) -ceq $name) 'Git name was not quoted correctly.'
    [IO.File]::WriteAllText((Join-Path $destination '.gitconfig.local'), "[user]`n    name = Local User`n")
    Assert ((& git config --file $gitconfig --includes --get user.name) -ceq 'Local User') 'Local Git settings did not win.'

    # The profile initializes optional tools only when present and defines update.
    & {
        $previousPath = $env:PATH
        try {
            $env:PATH = ''
            . $profile
            $script:ShellInit = [Collections.Generic.List[string]]::new()
            function starship { '$script:ShellInit.Add("starship")' }
            function zoxide { '$script:ShellInit.Add("zoxide")' }
            . $profile
            Assert (($script:ShellInit -join ',') -ceq 'starship,zoxide') 'Shell initialization failed.'
            Assert ([bool](Get-Command update -CommandType Function)) 'update is missing.'
        } finally {
            $env:PATH = $previousPath
        }
    }
    & $chezmoi @options verify
    Assert ($LASTEXITCODE -eq 0) 'Target verification failed.'
    Write-Output 'Windows: identity, WinGet import and pins, reruns, profile and Git configuration passed.'
} finally {
    $temporary.Delete($true)
}
