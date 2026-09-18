#Requires -Version 5.1

[CmdletBinding()]
param(
    [switch]$Staging,
    [switch]$Production,
    [string]$SshHost = "vps69933.dreamhostps.com",
    [string]$SshUser = "vcfinsider_web",
    [string]$PrivateKeyPath = "$env:USERPROFILE\.ssh\vcfinsider_dreamhost_ed25519"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Invoke-Native {
    param(
        [Parameter(Mandatory = $true)][string]$Command,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )

    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code ${LASTEXITCODE}: $Command $($Arguments -join ' ')"
    }
}

function Get-NativeText {
    param(
        [Parameter(Mandatory = $true)][string]$Command,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )

    $output = & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code ${LASTEXITCODE}: $Command $($Arguments -join ' ')"
    }

    return ($output | Out-String).Trim()
}

function Assert-Command {
    param([Parameter(Mandatory = $true)][string]$Name)

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command '$Name' was not found in PATH."
    }
}

function Invoke-SmokeTest {
    param([Parameter(Mandatory = $true)][string]$Uri)

    $separator = if ($Uri.Contains("?")) { "&" } else { "?" }
    $cacheBuster = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $response = Invoke-WebRequest -Uri "${Uri}${separator}deployment_check=${cacheBuster}" -UseBasicParsing -MaximumRedirection 5
    if ($response.StatusCode -ne 200) {
        throw "Smoke test failed for $Uri with HTTP status $($response.StatusCode)."
    }

    Write-Host "HTTP $($response.StatusCode): $Uri"
}

if ($Staging -and $Production) {
    throw "Choose either -Staging or -Production, not both."
}

$mode = if ($Production) { "production" } elseif ($Staging) { "staging" } else { "validate" }
$isDeployment = $Staging -or $Production

$productionPath = "/home/vcfinsider_web/vcfinsider.com"
$productionDeploymentPath = "/home/vcfinsider_web/deployments/vcfinsider"
$productionUrl = "https://www.vcfinsider.com"

$stagingPath = "/home/vcfinsider_web/staging.vcfinsider.com"
$stagingDeploymentPath = "/home/vcfinsider_web/deployments/vcfinsider-staging"
$stagingUrl = "https://staging.vcfinsider.com"

$repositoryRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repositoryRoot

foreach ($command in @("git", "bundle", "tar", "ssh")) {
    Assert-Command $command
}

if ($isDeployment) {
    Assert-Command "scp"
}

if (-not (Test-Path -LiteralPath $PrivateKeyPath -PathType Leaf)) {
    throw "SSH private key was not found: $PrivateKeyPath"
}

$remote = "${SshUser}@${SshHost}"
$sshOptions = @(
    "-i", $PrivateKeyPath,
    "-o", "IdentitiesOnly=yes",
    "-o", "BatchMode=yes"
)

Write-Step "Verifying repository identity and current remote state"
$originUrl = Get-NativeText "git" @("remote", "get-url", "origin")
if ($originUrl -notmatch '^((https://github\.com/)|(git@github\.com:))krieg121/VCFInsider(\.git)?$') {
    throw "Unexpected origin URL: $originUrl"
}

$branch = Get-NativeText "git" @("branch", "--show-current")
if (-not $branch) {
    throw "A named local branch is required. Detached HEAD is not supported."
}

Invoke-Native "git" @("fetch", "--no-tags", "origin", "main:refs/remotes/origin/main")

$headSha = Get-NativeText "git" @("rev-parse", "HEAD")
$originMainSha = Get-NativeText "git" @("rev-parse", "origin/main")
$status = Get-NativeText "git" @("status", "--porcelain")

Write-Host "Mode:        $mode"
Write-Host "Branch:      $branch"
Write-Host "HEAD:        $headSha"
Write-Host "origin/main: $originMainSha"

if ($Production) {
    if ($branch -ne "main") {
        throw "Production deployment requires the local branch to be 'main'. Current branch: $branch"
    }
    if ($status) {
        throw "Production deployment requires a clean working tree. Commit, stash, or remove local changes first."
    }
    if ($headSha -ne $originMainSha) {
        throw "Local main does not exactly match origin/main. Deployment stopped."
    }
}
elseif ($Staging) {
    if ($branch -eq "main") {
        throw "Staging deployment requires a focused non-main branch."
    }
    if ($status) {
        throw "Staging deployment requires a clean working tree. Commit, stash, or remove local changes first."
    }

    Invoke-Native "git" @("fetch", "--no-tags", "origin", "${branch}:refs/remotes/origin/${branch}")
    $originBranchSha = Get-NativeText "git" @("rev-parse", "refs/remotes/origin/$branch")
    Write-Host "origin/${branch}: $originBranchSha"

    if ($headSha -ne $originBranchSha) {
        throw "Local $branch does not exactly match origin/$branch. Staging deployment stopped."
    }
}
elseif ($status) {
    Write-Warning "The working tree has local changes. This is allowed for validation, but not for staging or production deployment."
}

Write-Step "Checking non-interactive DreamHost key authentication"
$preflightPaths = if ($Staging) {
    @($stagingPath)
}
elseif ($Production) {
    @($productionPath)
}
else {
    @($productionPath, $stagingPath)
}

foreach ($path in $preflightPaths) {
    $remotePreflight = "test -d '$path' && test -x /usr/bin/bash && test -x /usr/bin/tar && test -x /usr/bin/rsync && test `"`$(/usr/bin/realpath '$path')`" = '$path' && echo 'DreamHost preflight passed: $path'"
    Invoke-Native "ssh" ($sshOptions + @($remote, $remotePreflight))
}

Write-Step "Building the Jekyll site"
$buildArguments = @("exec", "jekyll", "build")
$stagingConfigPath = $null
if ($Staging) {
    $stagingConfigName = "vcfinsider-staging-{0}.yml" -f ([Guid]::NewGuid().ToString("N"))
    $stagingConfigPath = Join-Path ([System.IO.Path]::GetTempPath()) $stagingConfigName
    $stagingConfigText = "url: `"$stagingUrl`"`n"
    $utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($stagingConfigPath, $stagingConfigText, $utf8WithoutBom)
    $configFiles = "{0},{1}" -f (Join-Path $repositoryRoot "_config.yml"), $stagingConfigPath
    $buildArguments += @("--config", $configFiles, "--future")
}

$previousJekyllEnvironment = $env:JEKYLL_ENV
try {
    $env:JEKYLL_ENV = "production"
    Invoke-Native "bundle" $buildArguments
}
finally {
    $env:JEKYLL_ENV = $previousJekyllEnvironment
    if ($stagingConfigPath -and (Test-Path -LiteralPath $stagingConfigPath)) {
        Remove-Item -LiteralPath $stagingConfigPath -Force
    }
}

$siteRoot = Join-Path $repositoryRoot "_site"
$siteIndex = Join-Path $siteRoot "index.html"
if (-not (Test-Path -LiteralPath $siteIndex -PathType Leaf)) {
    throw "Jekyll completed without producing the expected file: $siteIndex"
}

if ($Staging) {
    $robotsPath = Join-Path $siteRoot "robots.txt"
    $robotsText = "User-agent: *`nDisallow: /`n"
    $utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($robotsPath, $robotsText, $utf8WithoutBom)
}

if (-not $isDeployment) {
    Write-Host "`nValidation completed. No remote files were changed." -ForegroundColor Green
    Write-Host "Use -Staging or -Production only after the exact deployment is separately approved."
    exit 0
}

if ($Staging) {
    $targetPath = $stagingPath
    $deploymentPath = $stagingDeploymentPath
    $siteUrl = $stagingUrl
    $confirmationVerb = "STAGE"
}
else {
    $targetPath = $productionPath
    $deploymentPath = $productionDeploymentPath
    $siteUrl = $productionUrl
    $confirmationVerb = "DEPLOY"
}

$shortSha = $headSha.Substring(0, 12)
$releaseId = "{0}-{1}" -f ([DateTime]::UtcNow.ToString("yyyyMMddTHHmmssZ")), $shortSha
$confirmation = Read-Host "Type $confirmationVerb $shortSha to deploy this exact commit to $mode"
if ($confirmation -cne "$confirmationVerb $shortSha") {
    throw "$mode confirmation did not match. Nothing was uploaded."
}

$temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) "vcfinsider-$mode-$releaseId"
$archivePath = Join-Path $temporaryRoot "$releaseId.tar.gz"
$remoteScript = Join-Path $PSScriptRoot "deploy-vcfinsider-remote.sh"
$remoteScriptUpload = Join-Path $temporaryRoot "deploy-vcfinsider-remote.sh"

if (-not (Test-Path -LiteralPath $remoteScript -PathType Leaf)) {
    throw "Remote deployment helper was not found: $remoteScript"
}

New-Item -ItemType Directory -Path $temporaryRoot | Out-Null
try {
    Write-Step "Packaging $mode release $releaseId"
    Invoke-Native "tar" @("-czf", $archivePath, "-C", $siteRoot, ".")

    # Windows Git settings may check shell scripts out with CRLF line endings.
    # Upload a temporary LF-only, UTF-8 copy for Bash on DreamHost.
    $remoteScriptText = [System.IO.File]::ReadAllText($remoteScript).Replace("`r`n", "`n")
    $utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($remoteScriptUpload, $remoteScriptText, $utf8WithoutBom)

    $remoteIncoming = "$deploymentPath/incoming"
    $remoteArchive = "$remoteIncoming/$releaseId.tar.gz"
    $remoteHelper = "$remoteIncoming/deploy-vcfinsider-remote.sh"

    Write-Step "Creating the private DreamHost incoming directory"
    Invoke-Native "ssh" ($sshOptions + @($remote, "umask 077 && mkdir -p '$remoteIncoming'"))

    Write-Step "Uploading the staged release"
    $scpOptions = @(
        "-i", $PrivateKeyPath,
        "-o", "IdentitiesOnly=yes",
        "-o", "BatchMode=yes"
    )
    Invoke-Native "scp" ($scpOptions + @($archivePath, "${remote}:$remoteArchive"))
    Invoke-Native "scp" ($scpOptions + @($remoteScriptUpload, "${remote}:$remoteHelper"))

    Write-Step "Backing up and promoting the $mode release"
    $deployCommand = "/usr/bin/bash '$remoteHelper' deploy '$mode' '$releaseId' '$headSha' '$remoteArchive'"
    Invoke-Native "ssh" ($sshOptions + @($remote, $deployCommand))

    Write-Step "Running $mode smoke tests"
    Invoke-SmokeTest "$siteUrl/"
    Invoke-SmokeTest "$siteUrl/blog/"

    Write-Host "`n$mode deployment completed." -ForegroundColor Green
    Write-Host "Target:   $targetPath"
    Write-Host "Release:  $releaseId"
    Write-Host "Commit:   $headSha"
    Write-Host "Backup:   $deploymentPath/backups/$releaseId"
}
finally {
    if (Test-Path -LiteralPath $temporaryRoot) {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
    }
}
