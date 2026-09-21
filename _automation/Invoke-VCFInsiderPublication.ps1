#Requires -Version 5.1

[CmdletBinding(DefaultParameterSetName = "Prepare")]
param(
    [Parameter(Mandatory = $true)]
    [string]$ManifestPath,

    [Parameter(Mandatory = $true, ParameterSetName = "Prepare")]
    [switch]$Prepare,

    [Parameter(ParameterSetName = "Prepare")]
    [switch]$DeployStaging,

    [Parameter(ParameterSetName = "Prepare")]
    [switch]$CheckXenForo,

    [Parameter(Mandatory = $true, ParameterSetName = "Release")]
    [switch]$Release,

    [Parameter(Mandatory = $true, ParameterSetName = "Release")]
    [ValidatePattern('^[0-9a-f]{40}$')]
    [string]$ExpectedCommit,

    [Parameter(ParameterSetName = "Release")]
    [switch]$PublishBuffer,

    [string]$OutputDirectory
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step {
    param([Parameter(Mandatory = $true)][string]$Text)
    Write-Host "`n==> $Text" -ForegroundColor Cyan
}

function Get-RequiredProperty {
    param(
        [Parameter(Mandatory = $true)]$InputObject,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $property) { throw "Manifest property '$Name' is required." }
    return $property.Value
}

function Get-RequiredText {
    param(
        [Parameter(Mandatory = $true)]$InputObject,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $value = [string](Get-RequiredProperty -InputObject $InputObject -Name $Name)
    if ([string]::IsNullOrWhiteSpace($value)) { throw "Manifest property '$Name' cannot be empty." }
    return $value
}

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content
    )

    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $encoding)
}

function Get-GitText {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)

    $output = & git -C $repositoryRoot @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Git command failed: git $($Arguments -join ' ')"
    }
    return ($output | Out-String).Trim()
}

function Invoke-ChildScript {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][hashtable]$Arguments
    )

    $global:LASTEXITCODE = 0
    & $Path @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Child script failed with exit code ${LASTEXITCODE}: $Path"
    }
}

function Test-RenderedArticle {
    param(
        [Parameter(Mandatory = $true)][string]$Uri,
        [Parameter(Mandatory = $true)][string]$ExpectedText,
        [Parameter(Mandatory = $true)][string]$ExpectedThreadUrl
    )

    $separator = if ($Uri.Contains("?")) { "&" } else { "?" }
    $cacheBuster = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $response = Invoke-WebRequest `
        -Uri "${Uri}${separator}release_check=${cacheBuster}" `
        -UseBasicParsing `
        -MaximumRedirection 5
    if ($response.StatusCode -ne 200) {
        throw "Production article returned HTTP $($response.StatusCode): $Uri"
    }
    if (-not $response.Content.Contains($ExpectedText)) {
        throw "Production article does not contain the expected text: $ExpectedText"
    }
    if (-not $response.Content.Contains($ExpectedThreadUrl)) {
        throw "Production article does not contain the verified community thread URL."
    }
    return [ordered]@{
        url = $Uri
        http_status = [int]$response.StatusCode
        expected_text_found = $true
        community_cta_found = $true
    }
}

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$testScript = Join-Path $PSScriptRoot "Test-VCFInsiderPublication.ps1"
$plannerScript = Join-Path $PSScriptRoot "Prepare-VCFInsiderBufferPosts.ps1"
$publisherScript = Join-Path $PSScriptRoot "Publish-VCFInsiderBufferPosts.ps1"
$deploymentScript = Join-Path $repositoryRoot "scripts\Deploy-VCFInsider.ps1"
foreach ($requiredScript in @($testScript, $plannerScript, $publisherScript, $deploymentScript)) {
    if (-not (Test-Path -LiteralPath $requiredScript -PathType Leaf)) {
        throw "Required script was not found: $requiredScript"
    }
}

$manifestFullPath = if ([System.IO.Path]::IsPathRooted($ManifestPath)) {
    [System.IO.Path]::GetFullPath($ManifestPath)
}
else {
    [System.IO.Path]::GetFullPath((Join-Path $repositoryRoot $ManifestPath))
}
if (-not (Test-Path -LiteralPath $manifestFullPath -PathType Leaf)) {
    throw "Publication manifest was not found: $manifestFullPath"
}

$utf8 = New-Object System.Text.UTF8Encoding($false)
$manifest = [System.IO.File]::ReadAllText($manifestFullPath, $utf8) | ConvertFrom-Json
if ([int](Get-RequiredProperty -InputObject $manifest -Name "schema_version") -ne 1) {
    throw "Unsupported publication manifest schema."
}
$releaseName = Get-RequiredText -InputObject $manifest -Name "release_name"
$articleTitle = Get-RequiredText -InputObject $manifest -Name "article_title"
$expectedText = Get-RequiredText -InputObject $manifest -Name "expected_text"
$productionUrl = Get-RequiredText -InputObject $manifest -Name "production_url"
$postRelativePath = Get-RequiredText -InputObject $manifest -Name "post_path"
$postFullPath = [System.IO.Path]::GetFullPath((Join-Path $repositoryRoot $postRelativePath))
if (-not (Test-Path -LiteralPath $postFullPath -PathType Leaf)) {
    throw "Article source was not found: $postFullPath"
}

$xenForo = Get-RequiredProperty -InputObject $manifest -Name "xenforo"
$threadTitle = Get-RequiredText -InputObject $xenForo -Name "thread_title"
$threadUrl = [string]$xenForo.thread_url

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path `
        (Join-Path $env:USERPROFILE "Documents\VCFInsider-publishing-previews") `
        $releaseName
}
$outputFullPath = [System.IO.Path]::GetFullPath($OutputDirectory)
$repositoryFullPath = [System.IO.Path]::GetFullPath($repositoryRoot).TrimEnd([char[]]@('\', '/'))
$repositoryPrefix = $repositoryFullPath + [System.IO.Path]::DirectorySeparatorChar
if ($outputFullPath.Equals($repositoryFullPath, [System.StringComparison]::OrdinalIgnoreCase) -or
    $outputFullPath.StartsWith($repositoryPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Publication output must be outside the Git repository: $outputFullPath"
}
New-Item -ItemType Directory -Path $outputFullPath -Force | Out-Null
$orchestratorReportPath = Join-Path $outputFullPath "publication-orchestrator-report.json"
$orchestratorReport = [ordered]@{
    schema_version = 1
    generated_utc = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
    release_name = $releaseName
    article_title = $articleTitle
    mode = $PSCmdlet.ParameterSetName.ToLowerInvariant()
    expected_commit = if ($Release) { $ExpectedCommit } else { $null }
    staging_deployment_requested = [bool]$DeployStaging
    xenforo_check_requested = [bool]$CheckXenForo
    production_deployment_requested = [bool]$Release
    buffer_publish_requested = [bool]$PublishBuffer
    production_verified = $false
    completed = $false
}

try {
    if ($Prepare) {
        Write-Step "Preparing the publication"
        $testArguments = @{
            ManifestPath = $manifestFullPath
            OutputDirectory = $outputFullPath
        }
        if ($DeployStaging) { $testArguments["DeployStaging"] = $true }
        if ($CheckXenForo) { $testArguments["CheckXenForo"] = $true }
        if (-not [string]::IsNullOrWhiteSpace($threadUrl)) {
            $testArguments["PlanCommunityCta"] = $true
        }
        Invoke-ChildScript -Path $testScript -Arguments $testArguments
        Invoke-ChildScript -Path $plannerScript -Arguments @{
            ManifestPath = $manifestFullPath
            OutputDirectory = $outputFullPath
        }

        $orchestratorReport["completed"] = $true
        $orchestratorReport["status"] = "prepared"
        Write-Utf8NoBom -Path $orchestratorReportPath -Content ($orchestratorReport | ConvertTo-Json -Depth 8)
        Write-Host "`nPublication preparation completed. No production deployment or Buffer write was performed." -ForegroundColor Green
        Write-Host "Report: $orchestratorReportPath"
        return
    }

    Write-Step "Verifying the exact production release"
    if ([string]::IsNullOrWhiteSpace($threadUrl)) {
        throw "A final release requires a verified xenforo.thread_url and committed community CTA."
    }
    $sourceText = [System.IO.File]::ReadAllText($postFullPath)
    $expectedUrlLine = 'community_thread_url: "' + $threadUrl + '"'
    $expectedTitleLine = 'community_thread_title: "' + $threadTitle.Replace('"', '\"') + '"'
    if (-not $sourceText.Contains($expectedUrlLine) -or -not $sourceText.Contains($expectedTitleLine)) {
        throw "The article source does not contain the manifest's exact community CTA fields."
    }

    $originUrl = Get-GitText -Arguments @("remote", "get-url", "origin")
    $approvedOriginPatterns = @(
        '^((https://github\.com/)|(git@github\.com:))krieg121/VCFInsider(\.git)?$',
        '^((https://gitlab\.com/)|(git@gitlab\.com:))vcf-insider-group/vcfinsider(\.git)?$'
    )
    if (-not ($approvedOriginPatterns | Where-Object { $originUrl -match $_ })) {
        throw "Unexpected origin URL: $originUrl"
    }
    $branch = Get-GitText -Arguments @("branch", "--show-current")
    if ($branch -cne "main") { throw "Final release requires branch 'main'. Current branch: $branch" }
    $status = Get-GitText -Arguments @("status", "--porcelain")
    if ($status) { throw "Final release requires a clean working tree." }
    $head = Get-GitText -Arguments @("rev-parse", "HEAD")
    if ($head -cne $ExpectedCommit) {
        throw "HEAD does not match ExpectedCommit. Expected $ExpectedCommit; found $head."
    }
    $null = Get-GitText -Arguments @("fetch", "--no-tags", "origin", "main:refs/remotes/origin/main")
    $originMain = Get-GitText -Arguments @("rev-parse", "origin/main")
    if ($originMain -cne $ExpectedCommit) {
        throw "origin/main does not match ExpectedCommit. Expected $ExpectedCommit; found $originMain."
    }

    Invoke-ChildScript -Path $plannerScript -Arguments @{
        ManifestPath = $manifestFullPath
        OutputDirectory = $outputFullPath
    }
    $bufferPlanPath = Join-Path $outputFullPath "buffer-plan.json"
    $bufferPlan = [System.IO.File]::ReadAllText($bufferPlanPath, $utf8) | ConvertFrom-Json
    $bufferReady = [bool]$bufferPlan.ready_to_publish
    if ($PublishBuffer -and -not $bufferReady) {
        throw "PublishBuffer was requested, but the manifest has no enabled Buffer posts."
    }

    Write-Step "Deploying the exact commit to production"
    Invoke-ChildScript -Path $deploymentScript -Arguments @{ Production = $true }

    Write-Step "Verifying the production article and community CTA"
    $productionResult = Test-RenderedArticle `
        -Uri $productionUrl `
        -ExpectedText $expectedText `
        -ExpectedThreadUrl $threadUrl
    $orchestratorReport["production_verified"] = $true
    $orchestratorReport["production"] = $productionResult

    if ($bufferReady) {
        Write-Step "Running the Buffer API release gate"
        $publisherArguments = @{
            PlanPath = $bufferPlanPath
            OutputDirectory = $outputFullPath
        }
        if ($PublishBuffer) { $publisherArguments["Publish"] = $true }
        Invoke-ChildScript -Path $publisherScript -Arguments $publisherArguments
        $orchestratorReport["buffer_status"] = if ($PublishBuffer) { "processed" } else { "check-only" }
    }
    else {
        $orchestratorReport["buffer_status"] = "skipped-no-enabled-posts"
        Write-Host "`nBuffer: no enabled posts; no API request was made." -ForegroundColor Yellow
    }

    $orchestratorReport["completed"] = $true
    $orchestratorReport["status"] = if ($PublishBuffer) { "released-and-buffer-processed" } else { "released-buffer-check-only" }
    Write-Utf8NoBom -Path $orchestratorReportPath -Content ($orchestratorReport | ConvertTo-Json -Depth 10)
    Write-Host "`nFinal publication release completed." -ForegroundColor Green
    Write-Host "Production: verified"
    Write-Host "Buffer:     $($orchestratorReport['buffer_status'])"
    Write-Host "Report:     $orchestratorReportPath"
}
catch {
    $orchestratorReport["status"] = "failed"
    $orchestratorReport["error"] = $_.Exception.Message
    Write-Utf8NoBom -Path $orchestratorReportPath -Content ($orchestratorReport | ConvertTo-Json -Depth 10)
    throw
}
