#Requires -Version 7.5
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
Set-StrictMode -Version Latest

if (!$IsWindows) {
    throw 'These dotfiles support Windows only.'
}

$repository = Split-Path -Parent $PSScriptRoot
$chezmoi = (Get-Command chezmoi -CommandType Application -TotalCount 1 -ErrorAction Stop).Source

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
    foreach ($file in '.chezmoiroot', 'home') {
        Copy-Item -LiteralPath (Join-Path $repository $file) -Destination $checkout -Recurse
    }
    $source = Join-Path $checkout 'home'
    $options = @('--config', (Join-Path $temporary.FullName 'config.toml'), '--destination', $destination,
        '--persistent-state', (Join-Path $temporary.FullName 'state.boltdb'),
        '--cache', (Join-Path $temporary.FullName 'cache'), '--no-tty', '--no-pager')

    $null = & $chezmoi @options execute-template --init --override-data '{"chezmoi":{"os":"linux"}}' `
        --file (Join-Path $source '.chezmoi.toml.tmpl') 2>&1
    Assert ($LASTEXITCODE -ne 0) 'Another OS was accepted.'
    foreach ($empty in 'Git name= ,Git email=test@example.invalid', 'Git name=Test User,Git email= ') {
        $null = & $chezmoi @options init --source $checkout --promptString $empty 2>&1
        Assert ($LASTEXITCODE -ne 0) 'Empty Git identity was accepted.'
    }
    $name = 'Test "User" \ 日本語'
    & $chezmoi @options init --source $checkout --promptString ('"Git name=' + $name.Replace('"', '""') + '",Git email=test@example.invalid')
    Assert ($LASTEXITCODE -eq 0) 'chezmoi init failed.'

    # Each tool file holds one tool named after the file, with known settings only.
    $data = Join-Path $source '.chezmoidata'
    Assert (!(Get-ChildItem -LiteralPath $data -Directory)) 'Tool files must not be nested.'
    $names = (Get-ChildItem -LiteralPath $data -File).Name
    $files = & $chezmoi @options execute-template ('{{ $files := dict }}' + (($names | ForEach-Object {
        "{{ `$_ := set `$files `"$_`" (include `".chezmoidata/$_`" | fromToml) }}" }) -join '') + '{{ $files | toJson }}') |
        ConvertFrom-Json -AsHashtable
    Assert ($LASTEXITCODE -eq 0 -and $files.Count -eq $names.Count -and $files.Count -gt 0) 'Tool files could not be read.'
    $tools = @{}
    $settingNames = 'winget', 'source', 'version', 'override', 'mise', 'mise_name', 'human', 'upgrade'
    foreach ($file in $files.GetEnumerator()) {
        $tool = $file.Key -replace '\.toml$'
        Assert ($file.Key -ceq "$tool.toml" -and $tool -cmatch '^[a-z0-9]+(-[a-z0-9]+)*$') "$($file.Key) is not a lowercase .toml name."
        Assert (($file.Value.Keys -join ',') -ceq 'tools' -and ($file.Value.tools.Keys -join ',') -ceq $tool) "$($file.Key) must define only tools.$tool."
        $settings = $file.Value.tools[$tool]
        foreach ($setting in $settings.GetEnumerator()) {
            Assert ($setting.Key -cin $settingNames -and $setting.Value -is [string] -and $setting.Value) "$($file.Key) has an unknown or malformed setting: $($setting.Key)."
        }
        Assert ($settings.Contains('winget') -or $settings.Contains('mise')) "$($file.Key) installs nothing."
        Assert (!$settings.Contains('source') -or $settings.source -in 'winget', 'msstore') "$($file.Key) has an unknown source."
        Assert (!$settings.Contains('mise_name') -or $settings.Contains('mise')) "$($file.Key) names a mise tool without a version."
        Assert (!($settings.Contains('version') -or $settings.Contains('override') -or $settings.Contains('source')) -or $settings.Contains('winget')) "$($file.Key) sets WinGet options without a package."
        $tools[$tool] = $settings
    }

    # Replace WinGet and mise in the copied hook; record each call, fail on demand and report installed packages.
    $hook = Join-Path $source '.chezmoiscripts/run_onchange_after_install.ps1.tmpl'
    $mock = @'
function winget.exe {
    if (![IO.File]::Exists((Join-Path $env:CHEZMOI_DEST_DIR '.gitconfig'))) {
        throw 'Installer ran before configuration.'
    }
    [IO.File]::AppendAllText((Join-Path $env:CHEZMOI_DEST_DIR 'install.log'), "$args`n")
    $global:LASTEXITCODE = if ([IO.File]::Exists((Join-Path $env:CHEZMOI_DEST_DIR 'fail'))) { 37 }
        elseif ($args[0] -ne 'install') { 0 }
        elseif ([IO.File]::Exists((Join-Path $env:CHEZMOI_DEST_DIR 'reboot'))) { -1978334967 } else { -1978335135 }
}
function mise {
    [IO.File]::AppendAllText((Join-Path $env:CHEZMOI_DEST_DIR 'install.log'), "mise $args`n")
    $global:LASTEXITCODE = 0
}

'@
    [IO.File]::WriteAllText($hook, $mock + [IO.File]::ReadAllText($hook))
    $log = Join-Path $destination 'install.log'
    $gitconfig = Join-Path $destination '.gitconfig'
    $profile = Join-Path $destination 'Documents/PowerShell/profile.ps1'

    [IO.File]::WriteAllText((Join-Path $destination 'fail'), '')
    $output = (& $chezmoi @options apply 2>&1) -join "`n"
    Assert ($LASTEXITCODE -ne 0 -and $output.Contains('exit 37')) "WinGet failure was not reported: $output"
    [IO.File]::Delete((Join-Path $destination 'fail'))
    [IO.File]::Delete($log)

    & $chezmoi @options apply
    Assert ($LASTEXITCODE -eq 0) 'Apply failed.'
    [string[]]$names = $tools.Keys
    [Array]::Sort($names, [StringComparer]::Ordinal)
    $expected = foreach ($tool in $names | Where-Object { $tools[$_].Contains('winget') }) {
        $settings = $tools[$tool]
        $call = "install --id $($settings.winget) --exact --source $($settings['source'] ?? 'winget') --no-upgrade"
        if ($settings.Contains('version')) { $call += " --version $($settings.version)" }
        if ($settings.Contains('override')) { $call += " --override $($settings.override)" }
        "$call --accept-package-agreements --accept-source-agreements --disable-interactivity"
        if ($settings.Contains('version')) {
            "pin add --id $($settings.winget) --exact --version $($settings.version) --force --accept-source-agreements --disable-interactivity"
        }
    }
    $expected = @($expected) + 'mise install'
    $calls = [IO.File]::ReadAllLines($log)
    Assert (($expected -join "`n") -ceq ($calls -join "`n")) "Install calls changed: $($calls -join "`n")"
    foreach ($call in 'install --id XPFCC4CD725961 --exact --source msstore --no-upgrade',
        'pin add --id Celsys.ClipStudioPaint --exact --version 5.0.4',
        'install --id Microsoft.VisualStudio.BuildTools --exact --source winget --no-upgrade --override --quiet --wait --norestart --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended') {
        Assert (@($calls | Where-Object { $_.StartsWith($call) }).Count -eq 1) "Missing install call: $call"
    }
    & $chezmoi @options apply
    Assert ($LASTEXITCODE -eq 0 -and [IO.File]::ReadAllLines($log).Count -eq $calls.Count) 'Unchanged tools ran the installers again.'
    [IO.File]::WriteAllText((Join-Path $data 'test-package.toml'), "[tools.test-package]`nwinget = `"Test.Package`"`n")
    & $chezmoi @options apply
    $rerun = [IO.File]::ReadAllLines($log) | Select-Object -Skip $calls.Count
    Assert ($LASTEXITCODE -eq 0 -and $rerun.Count -eq $calls.Count + 1 -and ($rerun -match '^install --id Test\.Package ').Count -eq 1) 'A new package did not rerun the installers.'
    $count = [IO.File]::ReadAllLines($log).Count
    [IO.File]::WriteAllText((Join-Path $data 'test-runtime.toml'), "[tools.test-runtime]`nmise = `"1`"`n")
    & $chezmoi @options apply
    Assert ($LASTEXITCODE -eq 0 -and [IO.File]::ReadAllLines($log).Count -gt $count) 'A new mise tool did not rerun mise.'
    Assert ([IO.File]::ReadAllText((Join-Path $destination '.config/mise/config.toml')).Contains('"test-runtime" = "1"')) 'mise configuration missed a tool.'
    $count = [IO.File]::ReadAllLines($log).Count
    [IO.File]::WriteAllText((Join-Path $destination 'reboot'), '')
    [IO.File]::Delete((Join-Path $data 'test-runtime.toml'))
    $output = (& $chezmoi @options apply 2>&1) -join "`n"
    Assert ($LASTEXITCODE -eq 0 -and $output.Contains('Reboot to finish installing') -and [IO.File]::ReadAllLines($log).Count -gt $count) "A pending reboot stopped the install: $output"
    [IO.File]::Delete((Join-Path $destination 'reboot'))
    [IO.File]::Delete((Join-Path $data 'test-package.toml'))
    & $chezmoi @options apply
    Assert ($LASTEXITCODE -eq 0) 'Apply after removing test tools failed.'

    $mise = [IO.File]::ReadAllText((Join-Path $destination '.config/mise/config.toml'))
    $entries = foreach ($tool in $names | Where-Object { $tools[$_].Contains('mise') }) {
        "`"$($tools[$tool]['mise_name'] ?? $tool)`" = `"$($tools[$tool].mise)`""
    }
    Assert ($mise -ceq "[tools]`n$($entries -join "`n")`n") "mise configuration is wrong: $mise"
    Assert ($mise.Contains('"npm:cf" = ') -and !$mise.Contains('"cf" = ')) 'cf resolves to the Cloud Foundry CLI.'
    Assert ((& git config --file $gitconfig --get user.name) -ceq $name) 'Git name was not quoted correctly.'
    Assert ((& git config --file $gitconfig --get core.sshCommand) -ceq 'C:/Windows/System32/OpenSSH/ssh.exe') 'Git does not use Windows OpenSSH.'
    Assert ((& git config --file $gitconfig --type bool --get core.longPaths) -ceq 'true') 'Git does not allow long paths.'
    [IO.File]::WriteAllText((Join-Path $destination '.gitconfig.local'), "[user]`n    name = Local User`n")
    Assert ((& git config --file $gitconfig --includes --get user.name) -ceq 'Local User') 'Local Git settings did not win.'

    # Agents get nothing from the profile; people get their setup.
    $agent = & pwsh -NoProfile -Command ". '$($profile.Replace("'", "''"))'; [bool](Get-Command update -ErrorAction Ignore)"
    Assert ($LASTEXITCODE -eq 0 -and $agent -ceq 'False') 'The profile set up an agent shell.'
    $statements = [Management.Automation.Language.Parser]::ParseFile($profile, [ref]$null, [ref]$null).EndBlock.Statements
    Assert ($statements[0] -is [Management.Automation.Language.IfStatementAst] -and $statements[0].Clauses[0].Item2.Extent.Text -match '^\{\s*return\s*\}$') 'The profile does not start with the agent guard.'
    & {
        $script:ShellInit = [Collections.Generic.List[string]]::new()
        function zoxide {
            Assert ("$args" -ceq 'init powershell --cmd cd') 'zoxide does not replace cd for people.'
            '$script:ShellInit.Add("zoxide")'
        }
        . ([scriptblock]::Create((@($statements | Select-Object -Skip 1).Extent.Text -join "`n")))
        Assert (($script:ShellInit -join ',') -ceq 'zoxide') 'Shell initialization failed.'
        Assert ((Get-Alias ls).Definition -ceq 'Show-Directory') 'ls does not use eza for people.'
        Assert ((Get-Command yolo -CommandType Function).Definition.Contains('claude --dangerously-skip-permissions')) 'yolo is missing for people.'
        $update = (Get-Command update -CommandType Function).Definition
        Assert ($update.Contains('mise upgrade') -and $update.Contains('rustup update')) 'update misses tool upgrades.'
    }

    # The environment script touches the real user environment, so only a disposable CI runner runs it.
    $environmentScript = Join-Path $temporary.FullName 'environment.ps1'
    & $chezmoi @options execute-template --override-data '{"chezmoi":{"destDir":"/","homeDir":"/"}}' `
        --file (Join-Path $source '.chezmoiscripts/run_onchange_after_environment.ps1.tmpl') > $environmentScript
    $errors = $null
    $null = [Management.Automation.Language.Parser]::ParseFile($environmentScript, [ref]$null, [ref]$errors)
    Assert ($errors.Count -eq 0) "Environment script does not parse: $errors"
    if ($env:GITHUB_ACTIONS -eq 'true') {
        $key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Environment')
        try {
            $original = "$($key.GetValue('Path', '', 'DoNotExpandEnvironmentNames'))"
            $key.SetValue('Path', "$original;$env:LOCALAPPDATA\mise\shims", 'ExpandString')
            foreach ($run in 1, 2) {
                & pwsh -NoProfile -File $environmentScript
                Assert ($LASTEXITCODE -eq 0) 'Environment script failed.'
            }
            Assert ($null -eq $key.GetValue('DOTFILES_RELOAD')) 'The environment script left a variable behind.'
            Assert ($key.GetValueKind('Path') -eq 'ExpandString' -and
                $key.GetValue('Path', '', 'DoNotExpandEnvironmentNames') -ceq ((@('%LOCALAPPDATA%\mise\shims') + ($original -split ';' -ne '')) -join ';')) 'User PATH is wrong.'
        } finally {
            $key.Dispose()
        }
    } else {
        Write-Output 'Skipped running the environment script outside CI.'
    }

    # The Documents guard runs only when applying to the real home; another home stands in for a redirected Documents.
    $guard = Join-Path $temporary.FullName 'check-documents.ps1'
    & $chezmoi @options execute-template --override-data '{"chezmoi":{"destDir":"/","homeDir":"/"}}' `
        --file (Join-Path $source '.chezmoiscripts/run_before_check-documents.ps1.tmpl') > $guard
    & pwsh -NoProfile -File $guard
    Assert ($LASTEXITCODE -eq 0) 'Documents guard rejected an unredirected Documents folder.'
    [IO.File]::WriteAllText($guard, [IO.File]::ReadAllText($guard).Replace('$HOME', "'$destination'"))
    $null = & pwsh -NoProfile -File $guard 2>&1
    Assert ($LASTEXITCODE -ne 0) 'Documents guard accepted a redirected Documents folder.'

    # Agents act on the docs literally, so their links and settings must match the repository.
    foreach ($document in (Get-ChildItem -LiteralPath $repository, (Join-Path $repository 'docs') -Filter *.md).FullName) {
        foreach ($link in [regex]::Matches([IO.File]::ReadAllText($document), '\]\((?!https?://)([^)#]*)(?:#([^)]*))?\)')) {
            $target = if ($link.Groups[1].Value) { Join-Path (Split-Path $document) $link.Groups[1].Value } else { $document }
            Assert (Test-Path -LiteralPath $target) "$document has a broken link: $($link.Value)."
            if ($link.Groups[2].Success) {
                $anchors = [regex]::Matches([IO.File]::ReadAllText($target), '(?m)^#+ (.+)$') |
                    ForEach-Object { $_.Groups[1].Value.ToLowerInvariant() -replace '[^a-z0-9 -]' -replace ' ', '-' }
                Assert ($anchors -ccontains $link.Groups[2].Value) "$document has a broken anchor: $($link.Value)."
            }
        }
    }
    $readme = [IO.File]::ReadAllText((Join-Path $repository 'README.md'))
    $documented = [regex]::Matches([regex]::Match($readme, '(?ms)^## Tool settings$.*?^## ').Value, '(?m)^\| `([a-z_]+)` \|') |
        ForEach-Object { $_.Groups[1].Value }
    Assert (($documented -join ',') -ceq ($settingNames -join ',')) "README's tool settings differ from the test: $($documented -join ',')."

    & $chezmoi @options verify
    Assert ($LASTEXITCODE -eq 0) 'Target verification failed.'
    Write-Output 'Windows: identity, tool files, installs, reruns, mise, profile, environment, Documents guard, docs and Git configuration passed.'
} finally {
    $temporary.Delete($true)
}
