#Requires -Version 7.5
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
Set-StrictMode -Version Latest
if (!$IsWindows) { throw 'Use bash tests/verify-ubuntu.sh on Ubuntu.' }
$repository = Split-Path -Parent $PSScriptRoot
$chezmoi = (Get-Command chezmoi -CommandType Application -ErrorAction Stop).Source
$null = Get-Content -LiteralPath (Join-Path $repository 'winget.json') -Raw | ConvertFrom-Json

function Assert {
    param([bool]$Condition, [string]$Message)
    if (!$Condition) { throw $Message }
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
    $identityPrompt = '"Git name=' + $name.Replace('"', '""') + '",Git email=test@example.invalid'
    & $chezmoi @options init --source $checkout --promptString $identityPrompt
    Assert ($LASTEXITCODE -eq 0) 'chezmoi init failed.'
    & $chezmoi @options init
    Assert ($LASTEXITCODE -eq 0) 'Reinitialization did not reuse the Git identity.'

    # Add only a command-boundary mock to the copied hook; run the real hook body.
    $hook = Join-Path $checkout 'home/.chezmoiscripts/run_onchange_after_install-windows-apps.ps1.tmpl'
    $mock = @'
function winget.exe {
    $expected = @('import', '--import-file', (Join-Path $env:CHEZMOI_WORKING_TREE 'winget.json'),
        '--no-upgrade', '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity')
    if ((ConvertTo-Json @($args) -Compress) -cne (ConvertTo-Json $expected -Compress)) {
        throw 'WinGet arguments changed.'
    }
    foreach ($path in '.gitconfig', 'Documents/PowerShell/profile.ps1') {
        if (![IO.File]::Exists((Join-Path $env:CHEZMOI_DEST_DIR $path))) { throw 'Installer ran before configuration.' }
    }
    [IO.File]::AppendAllText((Join-Path $env:CHEZMOI_DEST_DIR 'imports'), "run`n")
    Write-Output 'WinGet output'
    $global:LASTEXITCODE = if (Test-Path -LiteralPath (Join-Path $env:CHEZMOI_DEST_DIR 'fail-import')) { 37 } else { 0 }
}

'@
    [IO.File]::WriteAllText($hook, $mock + [IO.File]::ReadAllText($hook))
    $gitconfig = Join-Path $destination '.gitconfig'
    $profile = Join-Path $destination 'Documents/PowerShell/profile.ps1'
    $imports = Join-Path $destination 'imports'
    $null = & $chezmoi @options diff
    Assert ($LASTEXITCODE -eq 0) 'Diff failed.'
    $null = & $chezmoi @options apply --dry-run
    Assert ($LASTEXITCODE -eq 0 -and ![IO.File]::Exists($gitconfig)) 'Preview changed the destination.'
    & $chezmoi @options apply --exclude scripts,externals
    Assert ($LASTEXITCODE -eq 0 -and ![IO.File]::Exists($imports)) 'Configuration-only apply installed apps.'
    Assert (![IO.File]::Exists((Join-Path $destination '.bash_aliases'))) 'Ubuntu aliases were applied on Windows.'
    Assert ((& git config --file $gitconfig --get user.name) -ceq $name) 'Git name was not quoted correctly.'
    Assert ((& git config --file $gitconfig --get user.email) -ceq 'test@example.invalid') 'Git email changed.'
    $expectedGit = [IO.File]::ReadAllText($gitconfig)
    $expectedProfile = [IO.File]::ReadAllText($profile)

    # Common initialization works both before and after the optional tools are installed.
    & {
        $previousPath = $env:PATH
        try {
            $env:PATH = ''
            . $profile
            $script:ShellInit = [Collections.Generic.List[string]]::new()
            function starship { '$script:ShellInit.Add("starship")' }
            function zoxide { '$script:ShellInit.Add("zoxide")' }
            $cdBefore = (Get-Alias cd).Definition
            . $profile
            Assert (($script:ShellInit -join ',') -ceq 'starship,zoxide') 'Shell initialization failed.'
            Assert ((Get-Alias cd).Definition -ceq $cdBefore) 'The profile changed cd.'
        } finally { $env:PATH = $previousPath }
    }

    [IO.File]::Delete($profile)
    [IO.Directory]::Delete((Join-Path $destination 'Documents/PowerShell'))
    [IO.Directory]::Delete((Join-Path $destination 'Documents'))
    [IO.File]::Delete($gitconfig)
    $linkTarget = [IO.Directory]::CreateDirectory((Join-Path $temporary.FullName 'link target'))
    foreach ($relative in '.gitconfig', 'Documents', 'Documents/PowerShell', 'Documents/PowerShell/profile.ps1') {
        $conflict = Join-Path $destination $relative
        $null = [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($conflict))
        Assert ($conflict.StartsWith($destination + [IO.Path]::DirectorySeparatorChar)) 'Fixture escaped the destination.'
        foreach ($kind in 'Junction', 'Collision') {
            $directory = $kind -eq 'Junction' -or $relative -in '.gitconfig', 'Documents/PowerShell/profile.ps1'
            if ($kind -eq 'Junction') {
                $null = New-Item -ItemType Junction -Path $conflict -Target $linkTarget.FullName
            } elseif ($directory) {
                $null = [IO.Directory]::CreateDirectory($conflict)
            } else {
                [IO.File]::WriteAllText($conflict, 'unmanaged')
            }
            try {
                $null = & $chezmoi @options apply --force 2>&1
                Assert ($LASTEXITCODE -ne 0) "Accepted $kind at $relative."
                Assert (![IO.File]::Exists($imports)) 'A conflict ran the installer.'
                if ($relative -ne '.gitconfig') { Assert (![IO.File]::Exists($gitconfig)) 'A conflict changed configuration.' }
                Assert (@($linkTarget.EnumerateFileSystemInfos()).Count -eq 0) 'Apply wrote through a junction.'
                if ($kind -eq 'Junction') {
                    Assert ((Get-Item -LiteralPath $conflict -Force).LinkType -eq 'Junction') 'A junction changed.'
                } elseif (!$directory) {
                    Assert ([IO.File]::ReadAllText($conflict) -ceq 'unmanaged') 'An unmanaged file changed.'
                } else {
                    Assert ([IO.Directory]::Exists($conflict)) 'An unmanaged directory changed.'
                }
            } finally {
                if ($directory) { [IO.Directory]::Delete($conflict) }
                else { [IO.File]::Delete($conflict) }
            }
        }
    }

    $personal = Join-Path $destination '.gitconfig.local'
    Assert (![IO.File]::Exists($personal)) 'Personal Git configuration was created automatically.'
    [IO.File]::WriteAllText($personal, "[user]`n    name = Local User`n    email = local@example.invalid`n")
    $preserved = @{
        '.gitconfig.local' = [IO.File]::ReadAllText($personal)
        '.bash_aliases' = '# Unmanaged aliases'
        'Documents/PowerShell/Microsoft.PowerShell_profile.ps1' = '# Personal console settings'
        'Documents/PowerShell/Microsoft.VSCode_profile.ps1' = '# Personal VS Code settings'
        'keep' = 'unrelated'
    }
    foreach ($relative in $preserved.Keys) {
        [IO.File]::WriteAllText((Join-Path $destination $relative), $preserved[$relative])
    }
    $failure = Join-Path $destination 'fail-import'
    [IO.File]::WriteAllText($failure, '')
    $output = (& $chezmoi @options apply --force 2>&1) -join "`n"
    Assert ($LASTEXITCODE -ne 0 -and $output.Contains('exit 37')) "WinGet failure was not reported: $output"
    Assert ($output.Contains('WinGet output')) 'WinGet output was hidden.'
    Assert ([IO.File]::ReadAllText($gitconfig) -ceq $expectedGit) 'Failure lost Git configuration.'
    Assert ([IO.File]::ReadAllText($profile) -ceq $expectedProfile) 'Failure lost the common profile.'
    [IO.File]::Delete($failure)
    & $chezmoi @options apply
    Assert ($LASTEXITCODE -eq 0) 'Failed installation was not retried.'
    & $chezmoi @options apply
    Assert ($LASTEXITCODE -eq 0 -and [IO.File]::ReadAllLines($imports).Count -eq 2) 'Unchanged installation ran again.'
    foreach ($changed in (Join-Path $checkout 'winget.json'), $hook) {
        $before = [IO.File]::ReadAllLines($imports).Count
        $change = if ($changed -eq $hook) { "# Changed hook.`n" } else { "`n" }
        [IO.File]::AppendAllText($changed, $change)
        & $chezmoi @options apply --force
        Assert ($LASTEXITCODE -eq 0 -and [IO.File]::ReadAllLines($imports).Count -eq ($before + 1)) 'Changed input did not rerun the hook.'
    }
    & $chezmoi @options verify
    Assert ($LASTEXITCODE -eq 0) 'Target verification failed.'
    Assert ((& git config --file $gitconfig --includes --get user.name) -ceq 'Local User') 'Local Git settings did not win.'
    foreach ($relative in $preserved.Keys) {
        Assert ([IO.File]::ReadAllText((Join-Path $destination $relative)) -ceq $preserved[$relative]) "Changed $relative."
    }
    Write-Output 'Windows: identity, previews, configuration, imports, retries, conflicts and preservation passed.'
} finally {
    # This test owns the absolute temporary directory; junctions are removed above.
    $temporary.Delete($true)
}
