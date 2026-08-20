<#
.SYNOPSIS
    Installs the Ptah spec-driven workflow into a target project's .claude/ folder.

.DESCRIPTION
    Run this from a checkout of ptah-workflow-claude (or point -SourcePath at one).
    The repo ships with a flat layout (commands/, hooks/, README.md, RULES.md, ...)
    but Ptah expects a reshaped layout inside the target project:

        .claude/commands/ptah/*.md                   <- commands/*.md
        .claude/ptah/README.md                        <- README.md
        .claude/ptah/RULES.md                         <- RULES.md
        .claude/ptah/guides/logs-format.md            <- logs-format.md
        .claude/ptah/ptah.example.yml                 <- ptah_example.yml
        .claude/ptah/hooks/ptah-continue-resolve.sh   <- hooks/ptah-continue-resolve.sh
        CLAUDE.md                                     <- Ptah section merged in from CLAUDE-snippet.md

    This script does that reshaping. It is safe to re-run: existing files are left
    alone unless -Force is passed.

.PARAMETER ProjectPath
    Root of the project to install Ptah into. Defaults to the current directory.

.PARAMETER SourcePath
    Root of the ptah-workflow-claude checkout. Defaults to the folder this script
    lives in (i.e. just run it from inside the cloned repo).

.PARAMETER CreateConfig
    Also copy ptah.example.yml to ptah.yml (the file the commands actually read
    for JIRA/Linear/GitHub wiring and /fix defaults). Skipped by default since
    it's optional and project-specific.

.PARAMETER RegisterContinueHook
    Also wire the /continue UserPromptExpansion hook into .claude/settings.local.json.
    Merges into the existing "hooks" key if the file already exists, and never
    touches settings.local.json.

.PARAMETER Force
    Overwrite files that already exist at the destination.

.EXAMPLE
    .\install-ptah.ps1 -ProjectPath C:\code\my-app

.EXAMPLE
    .\install-ptah.ps1 -ProjectPath C:\code\my-app -CreateConfig -RegisterContinueHook -Force
#>

[CmdletBinding()]
param(
    [string]$ProjectPath = (Get-Location).Path,
    [string]$SourcePath  = $PSScriptRoot,
    [switch]$CreateConfig,
    [switch]$RegisterContinueHook,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

function Write-Step  ($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Write-Ok    ($msg) { Write-Host "    OK    $msg" -ForegroundColor Green }
function Write-Skip  ($msg) { Write-Host "    SKIP  $msg" -ForegroundColor Yellow }
function Write-Warn2 ($msg) { Write-Host "    WARN  $msg" -ForegroundColor DarkYellow }

function Copy-PtahFile {
    param([Parameter(Mandatory=$true)][string]$From, [Parameter(Mandatory=$true)][string]$To)
    $dir = Split-Path $To -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    if ((Test-Path $To) -and -not $Force) {
        Write-Skip "$To (already exists, use -Force to overwrite)"
        return
    }
    Copy-Item -Path $From -Destination $To -Force
    Write-Ok $To
}

# ---------------------------------------------------------------------------
# 0. Validate source + target
# ---------------------------------------------------------------------------
Write-Step "Validating source checkout at $SourcePath"

$requiredSourceItems = @(
    'commands',
    'hooks\ptah-continue-resolve.sh',
    'README.md',
    'RULES.md',
    'logs-format.md',
    'ptah_example.yml',
    'CLAUDE-snippet.md'
)
foreach ($item in $requiredSourceItems) {
    $p = Join-Path $SourcePath $item
    if (-not (Test-Path $p)) {
        throw "Expected '$item' under -SourcePath ($SourcePath) but did not find it. Pass -SourcePath pointing at a ptah-workflow-claude checkout."
    }
}

if (-not (Test-Path $ProjectPath)) {
    throw "ProjectPath '$ProjectPath' does not exist."
}
$ProjectPath = (Resolve-Path $ProjectPath).Path.TrimEnd('\', '/')
$ClaudeDir   = Join-Path $ProjectPath '.claude'

Write-Ok "Source: $SourcePath"
Write-Ok "Target: $ProjectPath"

# ---------------------------------------------------------------------------
# 1. Slash commands -> .claude/commands/ptah/
# ---------------------------------------------------------------------------
Write-Step "Installing slash commands to .claude\commands\ptah\"

$commandsDest = Join-Path $ClaudeDir 'commands\ptah'
Get-ChildItem -Path (Join-Path $SourcePath 'commands') -Filter '*.md' | ForEach-Object {
    Copy-PtahFile -From $_.FullName -To (Join-Path $commandsDest $_.Name)
}

# ---------------------------------------------------------------------------
# 2. Ptah's own docs + config -> .claude/ptah/
# ---------------------------------------------------------------------------
Write-Step "Installing Ptah docs and config to .claude\ptah\"

$ptahDir = Join-Path $ClaudeDir 'ptah'
Copy-PtahFile -From (Join-Path $SourcePath 'README.md')        -To (Join-Path $ptahDir 'README.md')
Copy-PtahFile -From (Join-Path $SourcePath 'RULES.md')         -To (Join-Path $ptahDir 'RULES.md')
Copy-PtahFile -From (Join-Path $SourcePath 'logs-format.md')   -To (Join-Path $ptahDir 'guides\logs-format.md')
Copy-PtahFile -From (Join-Path $SourcePath 'ptah_example.yml') -To (Join-Path $ptahDir 'ptah.example.yml')

if ($CreateConfig) {
    $ptahYml = Join-Path $ptahDir 'ptah.yml'
    if ((Test-Path $ptahYml) -and -not $Force) {
        Write-Skip "$ptahYml (already exists, use -Force to overwrite)"
    } else {
        Copy-Item -Path (Join-Path $SourcePath 'ptah_example.yml') -Destination $ptahYml -Force
        Write-Ok "$ptahYml (edit this to wire up JIRA/Linear/GitHub, or set /fix defaults)"
    }
} else {
    Write-Skip "ptah.yml not created (pass -CreateConfig to generate it from the template)"
}

# ---------------------------------------------------------------------------
# 3. /continue hook script -> .claude/ptah/hooks/
# ---------------------------------------------------------------------------
Write-Step "Installing the /continue hook script"

$hookDest = Join-Path $ptahDir 'hooks\ptah-continue-resolve.sh'
Copy-PtahFile -From (Join-Path $SourcePath 'hooks\ptah-continue-resolve.sh') -To $hookDest

# Windows filesystems have no real +x bit. If this is a git repo, set the
# executable bit in git's index so it survives for teammates on Unix.
$relHook = $hookDest.Replace($ProjectPath, '').TrimStart('\', '/').Replace('\', '/')
try {
    Push-Location $ProjectPath
    git rev-parse --is-inside-work-tree *> $null
    if ($LASTEXITCODE -eq 0) {
        git update-index --add --chmod=+x -- "$relHook" *> $null
        if ($LASTEXITCODE -eq 0) {
            Write-Ok "Marked $relHook executable in the git index"
        } else {
            Write-Warn2 "git update-index failed for $relHook - set it manually with: git update-index --chmod=+x $relHook"
        }
    } else {
        Write-Warn2 "Not a git repo - run 'chmod +x $relHook' on a Unix machine before teammates rely on /continue."
    }
} catch {
    Write-Warn2 "git is not on PATH - run 'chmod +x $relHook' on a Unix machine before teammates rely on /continue."
} finally {
    Pop-Location
}

# ---------------------------------------------------------------------------
# 4. (Optional) Register the /continue hook in .claude/settings.local.json
# ---------------------------------------------------------------------------
if ($RegisterContinueHook) {
    Write-Step "Registering the /continue hook in .claude\settings.local.json"

    $settingsPath = Join-Path $ClaudeDir 'settings.local.json'
    $hookEntry = [PSCustomObject]@{
        matcher = 'continue'
        hooks   = @(
            [PSCustomObject]@{
                type    = 'command'
                command = '${CLAUDE_PROJECT_DIR}/.claude/ptah/hooks/ptah-continue-resolve.sh'
                args    = @()
            }
        )
    }

    if (Test-Path $settingsPath) {
        $json = Get-Content $settingsPath -Raw | ConvertFrom-Json

        if (-not (Get-Member -InputObject $json -Name 'hooks' -MemberType NoteProperty)) {
            $json | Add-Member -NotePropertyName 'hooks' -NotePropertyValue ([PSCustomObject]@{}) -Force
        }
        if (-not (Get-Member -InputObject $json.hooks -Name 'UserPromptExpansion' -MemberType NoteProperty)) {
            $json.hooks | Add-Member -NotePropertyName 'UserPromptExpansion' -NotePropertyValue @() -Force
        }

        $existingEntries = @($json.hooks.UserPromptExpansion)
        $alreadyThere     = $existingEntries | Where-Object { $_.matcher -eq 'continue' }

        if ($alreadyThere -and -not $Force) {
            Write-Skip "settings.local.json already has a 'continue' matcher (use -Force to replace it)"
        } else {
            $kept = @($existingEntries | Where-Object { $_.matcher -ne 'continue' })
            $json.hooks.UserPromptExpansion = @($kept + $hookEntry)
            ($json | ConvertTo-Json -Depth 20) | Set-Content -Path $settingsPath -Encoding utf8
            Write-Ok "$settingsPath (merged)"
        }
    } else {
        $new = [PSCustomObject]@{
            hooks = [PSCustomObject]@{
                UserPromptExpansion = @($hookEntry)
            }
        }
        New-Item -ItemType Directory -Path $ClaudeDir -Force | Out-Null
        ($new | ConvertTo-Json -Depth 20) | Set-Content -Path $settingsPath -Encoding utf8
        Write-Ok "$settingsPath (created)"
    }

    Write-Warn2 "Verify the matcher: open the /hooks menu in Claude Code after installing and confirm it fires on /continue. Adjust 'matcher' in settings.local.json if the menu shows a different name."
} else {
    Write-Skip "/continue hook not registered in settings.local.json (pass -RegisterContinueHook to wire it up; /continue has no fallback without it)"
}

# ---------------------------------------------------------------------------
# 5. Merge the CLAUDE.md snippet
# ---------------------------------------------------------------------------
Write-Step "Merging the Ptah snippet into CLAUDE.md"

$snippetRaw = Get-Content (Join-Path $SourcePath 'CLAUDE-snippet.md') -Raw
$match = [regex]::Match($snippetRaw, '```markdown\r?\n(.*?)\r?\n```', 'Singleline')
if (-not $match.Success) {
    throw "Could not find the fenced markdown block inside CLAUDE-snippet.md."
}
$block = $match.Groups[1].Value.TrimEnd()

$claudeMdPath = Join-Path $ProjectPath 'CLAUDE.md'

if (Test-Path $claudeMdPath) {
    $existing = Get-Content $claudeMdPath -Raw
    if ($existing -match '## Ptah workflow') {
        Write-Skip "CLAUDE.md already has a '## Ptah workflow' section - left untouched"
    } else {
        $sep = if ($existing.TrimEnd().Length -gt 0) { "`r`n`r`n" } else { "" }
        Add-Content -Path $claudeMdPath -Value ($sep + $block) -Encoding utf8
        Write-Ok "$claudeMdPath (appended Ptah section)"
    }
} else {
    Set-Content -Path $claudeMdPath -Value $block -Encoding utf8
    Write-Ok "$claudeMdPath (created)"
}

# ---------------------------------------------------------------------------
# 6. Summary
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "Ptah installed." -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Restart your Claude Code session so the new commands and CLAUDE.md rules load."
Write-Host "  2. Run /status   -> should say 'No specs found.'"
Write-Host "  3. Run /spec <your-first-feature> to start."
if (-not $CreateConfig) {
    Write-Host "  4. (optional) Copy .claude\ptah\ptah.example.yml to ptah.yml to wire up JIRA/Linear/GitHub or set /fix defaults."
}
if ($RegisterContinueHook) {
    Write-Host "  5. Open the /hooks menu in Claude Code and confirm the 'continue' matcher actually fires."
} else {
    Write-Host "  5. (optional) Re-run with -RegisterContinueHook if you want /continue to work without typing a spec number."
}
