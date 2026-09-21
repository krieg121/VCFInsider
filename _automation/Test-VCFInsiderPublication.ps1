#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ManifestPath,

    [switch]$DeployStaging,
    [switch]$VerifyStaging,
    [switch]$CheckXenForo,
    [switch]$PlanCommunityCta,
    [switch]$ApplyCommunityCta,

    [string]$OutputDirectory
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($ApplyCommunityCta -and ($DeployStaging -or $VerifyStaging)) {
    throw "ApplyCommunityCta cannot run with DeployStaging or VerifyStaging. Apply the CTA, review and commit it, then deploy staging in a separate run."
}

function Write-Step {
    param([Parameter(Mandatory = $true)][string]$Message)
    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Get-RequiredProperty {
    param(
        [Parameter(Mandatory = $true)]$InputObject,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $property) {
        throw "Manifest property '$Name' is required."
    }

    return $property.Value
}

function Get-RequiredText {
    param(
        [Parameter(Mandatory = $true)]$InputObject,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $value = [string](Get-RequiredProperty -InputObject $InputObject -Name $Name)
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw "Manifest property '$Name' cannot be empty."
    }

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

function Resolve-RepositoryFile {
    param(
        [Parameter(Mandatory = $true)][string]$RepositoryRoot,
        [Parameter(Mandatory = $true)][string]$RelativePath
    )

    if ([System.IO.Path]::IsPathRooted($RelativePath)) {
        throw "Repository file paths must be relative: $RelativePath"
    }

    $trimCharacters = [char[]]@(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    )
    $root = [System.IO.Path]::GetFullPath($RepositoryRoot).TrimEnd($trimCharacters)
    $candidate = [System.IO.Path]::GetFullPath((Join-Path $root $RelativePath))
    $rootPrefix = $root + [System.IO.Path]::DirectorySeparatorChar

    if (-not $candidate.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Repository path escapes the repository root: $RelativePath"
    }

    return $candidate
}

function Assert-HttpsUrl {
    param(
        [Parameter(Mandatory = $true)][string]$Value,
        [Parameter(Mandatory = $true)][string]$ExpectedHost,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $uri = $null
    if (-not [System.Uri]::TryCreate($Value, [System.UriKind]::Absolute, [ref]$uri)) {
        throw "Manifest property '$Name' is not an absolute URL: $Value"
    }
    if ($uri.Scheme -ne "https" -or $uri.Host -ne $ExpectedHost) {
        throw "Manifest property '$Name' must use https://$ExpectedHost/: $Value"
    }

    return $uri
}

function Expand-ArticleUrlToken {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$ArticleUrl
    )

    return $Text.Replace("{{ARTICLE_URL}}", $ArticleUrl)
}

function Get-FrontMatterProperty {
    param(
        [Parameter(Mandatory = $true)][string]$FrontMatter,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $pattern = '(?m)^' + [regex]::Escape($Name) + ':\s*(?:"(?<double>[^"]*)"|''(?<single>[^'']*)''|(?<plain>[^\r\n]+))\s*$'
    $matches = [regex]::Matches($FrontMatter, $pattern)
    if ($matches.Count -gt 1) {
        throw "Article front matter contains more than one '$Name' property."
    }

    if ($matches.Count -eq 0) {
        return [pscustomobject]@{ exists = $false; value = $null }
    }

    $match = $matches[0]
    $value = if ($match.Groups['double'].Success) {
        $match.Groups['double'].Value
    }
    elseif ($match.Groups['single'].Success) {
        $match.Groups['single'].Value
    }
    else {
        $match.Groups['plain'].Value.Trim()
    }

    return [pscustomobject]@{ exists = $true; value = $value }
}

function Invoke-CommunityCtaUpdate {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$ThreadUrl,
        [Parameter(Mandatory = $true)][string]$ThreadTitle,
        [Parameter(Mandatory = $true)][bool]$Apply,
        [Parameter(Mandatory = $true)][string]$RepositoryRoot
    )

    $stepMessage = if ($Apply) {
        "Applying the community CTA front matter"
    }
    else {
        "Planning the community CTA front matter"
    }
    Write-Step -Message $stepMessage

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $hasUtf8Bom = (
        $bytes.Length -ge 3 -and
        $bytes[0] -eq 0xEF -and
        $bytes[1] -eq 0xBB -and
        $bytes[2] -eq 0xBF
    )
    $text = [System.IO.File]::ReadAllText($Path)
    $newline = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }

    $separatorMatches = [regex]::Matches($text, '(?m)^---\r?$')
    if ($separatorMatches.Count -lt 2 -or $separatorMatches[0].Index -gt 1) {
        throw "The article does not contain valid YAML front matter: $Path"
    }

    $closingMarker = $separatorMatches[1]
    $openingEnd = $separatorMatches[0].Index + $separatorMatches[0].Length
    $frontMatter = $text.Substring($openingEnd, $closingMarker.Index - $openingEnd)
    $urlProperty = Get-FrontMatterProperty -FrontMatter $frontMatter -Name "community_thread_url"
    $titleProperty = Get-FrontMatterProperty -FrontMatter $frontMatter -Name "community_thread_title"

    if ($urlProperty.exists -and $urlProperty.value -ne $ThreadUrl) {
        throw "Existing community_thread_url conflicts with the manifest. No change made."
    }
    if ($titleProperty.exists -and $titleProperty.value -ne $ThreadTitle) {
        throw "Existing community_thread_title conflicts with the manifest. No change made."
    }

    $missingLines = @()
    if (-not $urlProperty.exists) {
        $missingLines += 'community_thread_url: "' + $ThreadUrl + '"'
    }
    if (-not $titleProperty.exists) {
        $missingLines += 'community_thread_title: "' + $ThreadTitle.Replace('"', '\"') + '"'
    }

    if ($missingLines.Count -eq 0) {
        Write-Host "Community CTA front matter is already correct; no change needed." -ForegroundColor Green
        return [pscustomobject]@{
            requested = $true
            applied = $false
            changed = $false
            status = "already-configured"
            thread_url = $ThreadUrl
            thread_title = $ThreadTitle
        }
    }

    if (-not $Apply) {
        Write-Host "Community CTA would add $($missingLines.Count) front-matter field(s)." -ForegroundColor Yellow
        return [pscustomobject]@{
            requested = $true
            applied = $false
            changed = $false
            status = "would-update"
            thread_url = $ThreadUrl
            thread_title = $ThreadTitle
        }
    }

    $branch = (& git -C $RepositoryRoot branch --show-current).Trim()
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($branch)) {
        throw "Unable to determine the current Git branch. No change made."
    }
    if ($branch -eq "main") {
        throw "Community CTA changes are not allowed directly on main. No change made."
    }

    $insertion = ($missingLines -join $newline) + $newline
    $updated = $text.Insert($closingMarker.Index, $insertion)
    $encoding = New-Object System.Text.UTF8Encoding($hasUtf8Bom)
    [System.IO.File]::WriteAllText($Path, $updated, $encoding)

    Write-Host "Community CTA front matter updated on branch '$branch'." -ForegroundColor Green
    return [pscustomobject]@{
        requested = $true
        applied = $true
        changed = $true
        status = "updated"
        thread_url = $ThreadUrl
        thread_title = $ThreadTitle
    }
}

function Invoke-XenForoReadOnlyCheck {
    param(
        [Parameter(Mandatory = $true)][string]$ThreadTitle,
        [Parameter(Mandatory = $true)][int]$NodeId,
        [string]$ExpectedThreadUrl
    )

    $apiBase = "https://community.vcfinsider.com/index.php/api"
    $postingUserId = 4
    $secureKey = $null
    $bstr = [IntPtr]::Zero
    $key = $null

    try {
        Write-Step "Running read-only XenForo checks"
        $secureKey = Read-Host "Enter XenForo API key for read-only checks" -AsSecureString
        $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureKey)
        $key = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
        if ([string]::IsNullOrWhiteSpace($key)) {
            throw "The XenForo API key cannot be empty."
        }

        $headers = @{
            "XF-Api-Key"  = $key
            "XF-Api-User" = $postingUserId.ToString()
        }

        $meResponse = Invoke-RestMethod -Method Get -Uri "$apiBase/me/" -Headers $headers
        $me = if ($meResponse.me) { $meResponse.me } elseif ($meResponse.user) { $meResponse.user } else { $meResponse }
        if ([int]$me.user_id -ne $postingUserId -or [string]$me.username -ne "VCF Insider") {
            throw "Unexpected XenForo identity: user_id=$($me.user_id), username=$($me.username)."
        }

        $page = 1
        $lastPage = 1
        $duplicate = $null
        do {
            $threadsResponse = Invoke-RestMethod `
                -Method Get `
                -Uri "$apiBase/threads/?page=$page&last_days=0" `
                -Headers $headers

            $duplicate = @($threadsResponse.threads) |
                Where-Object { [string]$_.title -ceq $ThreadTitle } |
                Select-Object -First 1
            if ($duplicate) { break }

            if ($threadsResponse.pagination -and $threadsResponse.pagination.last_page) {
                $lastPage = [int]$threadsResponse.pagination.last_page
            }
            $page++
        } while ($page -le $lastPage)

        $existingUrl = $null
        $existingId = $null
        if ($duplicate) {
            $existingId = [int]$duplicate.thread_id
            $existingUrl = ([string]$duplicate.view_url) -replace '^http:', 'https:'
            Write-Host "Existing exact-title thread: $existingUrl" -ForegroundColor Yellow
        }
        else {
            Write-Host "No exact-title duplicate found for node $NodeId." -ForegroundColor Green
        }

        $urlVerified = $false
        if (-not [string]::IsNullOrWhiteSpace($ExpectedThreadUrl)) {
            if (-not $duplicate) {
                throw "The manifest specifies a XenForo thread URL, but no exact-title thread was found."
            }
            if ([string]::IsNullOrWhiteSpace($existingUrl)) {
                throw "The exact-title XenForo result did not include a view URL."
            }

            $expectedCanonical = $ExpectedThreadUrl.TrimEnd('/')
            $existingCanonical = $existingUrl.TrimEnd('/')
            if (-not $existingCanonical.Equals($expectedCanonical, [System.StringComparison]::OrdinalIgnoreCase)) {
                throw "XenForo thread URL mismatch. Expected '$ExpectedThreadUrl'; found '$existingUrl'."
            }
            $urlVerified = $true
            Write-Host "Existing XenForo thread URL matches the manifest." -ForegroundColor Green
        }

        return [pscustomobject]@{
            authenticated_user = [string]$me.username
            posting_user_id    = [int]$me.user_id
            target_node_id     = $NodeId
            duplicate_found    = [bool]$duplicate
            existing_thread_id = $existingId
            existing_thread_url = $existingUrl
            expected_thread_url = $ExpectedThreadUrl
            thread_url_verified = $urlVerified
            write_performed    = $false
        }
    }
    finally {
        if ($bstr -ne [IntPtr]::Zero) {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        }
        $key = $null
        $secureKey = $null
    }
}

function Test-StagingArticle {
    param(
        [Parameter(Mandatory = $true)][string]$Uri,
        [Parameter(Mandatory = $true)][string]$ExpectedText
    )

    Write-Step "Verifying the staged article"
    $separator = if ($Uri.Contains("?")) { "&" } else { "?" }
    $cacheBuster = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $response = Invoke-WebRequest `
        -Uri "${Uri}${separator}publication_check=${cacheBuster}" `
        -UseBasicParsing `
        -MaximumRedirection 5

    if ($response.StatusCode -ne 200) {
        throw "Staging article returned HTTP $($response.StatusCode): $Uri"
    }
    if (-not $response.Content.Contains($ExpectedText)) {
        throw "Staging article did not contain expected text: $ExpectedText"
    }

    Write-Host "HTTP 200 and expected article text found: $Uri" -ForegroundColor Green
    return [pscustomobject]@{
        url           = $Uri
        http_status   = [int]$response.StatusCode
        expected_text = $ExpectedText
        text_found    = $true
    }
}

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$deploymentScript = Join-Path $repositoryRoot "scripts\Deploy-VCFInsider.ps1"

if (-not (Test-Path -LiteralPath $deploymentScript -PathType Leaf)) {
    throw "Known-good deployment script was not found: $deploymentScript"
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

Write-Step "Loading and validating the publication manifest"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$manifestJson = [System.IO.File]::ReadAllText($manifestFullPath, $utf8)
$manifest = $manifestJson | ConvertFrom-Json
$schemaVersion = [int](Get-RequiredProperty -InputObject $manifest -Name "schema_version")
if ($schemaVersion -ne 1) {
    throw "Unsupported publication manifest schema: $schemaVersion"
}

$releaseName = Get-RequiredText -InputObject $manifest -Name "release_name"
if ($releaseName -notmatch '^[a-z0-9][a-z0-9-]{2,79}$') {
    throw "release_name must contain only lowercase letters, numbers, and hyphens."
}

$postRelativePath = Get-RequiredText -InputObject $manifest -Name "post_path"
$postFullPath = Resolve-RepositoryFile -RepositoryRoot $repositoryRoot -RelativePath $postRelativePath
if (-not (Test-Path -LiteralPath $postFullPath -PathType Leaf)) {
    throw "Article source was not found: $postFullPath"
}

$articleTitle = Get-RequiredText -InputObject $manifest -Name "article_title"
$expectedText = Get-RequiredText -InputObject $manifest -Name "expected_text"
$stagingUrl = Get-RequiredText -InputObject $manifest -Name "staging_url"
$productionUrl = Get-RequiredText -InputObject $manifest -Name "production_url"
$null = Assert-HttpsUrl -Value $stagingUrl -ExpectedHost "staging.vcfinsider.com" -Name "staging_url"
$null = Assert-HttpsUrl -Value $productionUrl -ExpectedHost "www.vcfinsider.com" -Name "production_url"

$xenForo = Get-RequiredProperty -InputObject $manifest -Name "xenforo"
$nodeId = [int](Get-RequiredProperty -InputObject $xenForo -Name "node_id")
if ($nodeId -le 0) { throw "xenforo.node_id must be greater than zero." }
$forumName = Get-RequiredText -InputObject $xenForo -Name "forum_name"
$threadTitle = Get-RequiredText -InputObject $xenForo -Name "thread_title"
$threadMessageTemplate = Get-RequiredText -InputObject $xenForo -Name "message"
$threadMessage = Expand-ArticleUrlToken -Text $threadMessageTemplate -ArticleUrl $productionUrl
$threadUrl = $null
$threadUrlProperty = $xenForo.PSObject.Properties["thread_url"]
if ($null -ne $threadUrlProperty -and -not [string]::IsNullOrWhiteSpace([string]$threadUrlProperty.Value)) {
    $threadUrl = [string]$threadUrlProperty.Value
    $null = Assert-HttpsUrl -Value $threadUrl -ExpectedHost "community.vcfinsider.com" -Name "xenforo.thread_url"
}

if (($PlanCommunityCta -or $ApplyCommunityCta) -and [string]::IsNullOrWhiteSpace($threadUrl)) {
    throw "xenforo.thread_url is required when planning or applying the community CTA."
}

$social = Get-RequiredProperty -InputObject $manifest -Name "social"
$linkedInText = Expand-ArticleUrlToken `
    -Text (Get-RequiredText -InputObject $social -Name "linkedin") `
    -ArticleUrl $productionUrl
$facebookText = Expand-ArticleUrlToken `
    -Text (Get-RequiredText -InputObject $social -Name "facebook") `
    -ArticleUrl $productionUrl
$xText = Expand-ArticleUrlToken `
    -Text (Get-RequiredText -InputObject $social -Name "x") `
    -ArticleUrl $productionUrl

$sourceText = [System.IO.File]::ReadAllText($postFullPath)
if (-not $sourceText.Contains("title: `"$articleTitle`"")) {
    throw "The article source does not contain the manifest article_title in front matter."
}

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path `
        (Join-Path $env:USERPROFILE "Documents\VCFInsider-publishing-previews") `
        $releaseName
}
$outputFullPath = [System.IO.Path]::GetFullPath($OutputDirectory)
$repositoryFullPath = [System.IO.Path]::GetFullPath($repositoryRoot).TrimEnd([char[]]@('\', '/'))
$repositoryPrefix = $repositoryFullPath + [System.IO.Path]::DirectorySeparatorChar
if ($outputFullPath.StartsWith($repositoryPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Preview output must be outside the Git repository: $outputFullPath"
}

New-Item -ItemType Directory -Path $outputFullPath -Force | Out-Null

Write-Step "Writing publication previews outside the repository"
Write-Utf8NoBom -Path (Join-Path $outputFullPath "xenforo.txt") -Content ("Title: $threadTitle`r`nForum: $forumName (node $nodeId)`r`n`r`n$threadMessage`r`n")
Write-Utf8NoBom -Path (Join-Path $outputFullPath "linkedin.txt") -Content ($linkedInText + "`r`n")
Write-Utf8NoBom -Path (Join-Path $outputFullPath "facebook.txt") -Content ($facebookText + "`r`n")
Write-Utf8NoBom -Path (Join-Path $outputFullPath "x.txt") -Content ($xText + "`r`n")

$communityCtaResult = [pscustomobject]@{
    requested = $false
    applied = $false
    changed = $false
    status = "not-requested"
    thread_url = $threadUrl
    thread_title = $threadTitle
}
if ($PlanCommunityCta -or $ApplyCommunityCta) {
    $communityCtaResult = Invoke-CommunityCtaUpdate `
        -Path $postFullPath `
        -ThreadUrl $threadUrl `
        -ThreadTitle $threadTitle `
        -Apply ([bool]$ApplyCommunityCta) `
        -RepositoryRoot $repositoryRoot
}

$xenForoResult = [pscustomobject]@{
    check_requested = $false
    write_performed = $false
}
if ($CheckXenForo) {
    $xenForoResult = Invoke-XenForoReadOnlyCheck `
        -ThreadTitle $threadTitle `
        -NodeId $nodeId `
        -ExpectedThreadUrl $threadUrl
}

$stagingResult = [pscustomobject]@{
    deployment_requested = [bool]$DeployStaging
    verification_requested = [bool]($DeployStaging -or $VerifyStaging)
    verified = $false
}

if ($DeployStaging) {
    Write-Step "Calling the existing staging deployment workflow"
    & $deploymentScript -Staging
}

if ($DeployStaging -or $VerifyStaging) {
    $stagingResult = Test-StagingArticle -Uri $stagingUrl -ExpectedText $expectedText
    $stagingResult | Add-Member -NotePropertyName deployment_requested -NotePropertyValue ([bool]$DeployStaging)
    $stagingResult | Add-Member -NotePropertyName verification_requested -NotePropertyValue $true
    $stagingResult | Add-Member -NotePropertyName verified -NotePropertyValue $true
}

$reportMode = if ($DeployStaging) {
    "staging-deploy-test"
}
elseif ($VerifyStaging) {
    "staging-verify"
}
else {
    "preview-only"
}

$report = [ordered]@{
    schema_version = 1
    generated_utc = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
    mode = $reportMode
    release_name = $releaseName
    repository_root = $repositoryRoot
    manifest_path = $manifestFullPath
    post_path = $postRelativePath
    article_title = $articleTitle
    staging_url = $stagingUrl
    production_url = $productionUrl
    staging = $stagingResult
    xenforo = $xenForoResult
    community_cta = $communityCtaResult
    social = [ordered]@{
        linkedin_characters = $linkedInText.Length
        facebook_characters = $facebookText.Length
        x_characters = $xText.Length
        write_performed = $false
    }
    safeguards = [ordered]@{
        production_deployment_available = $false
        xenforo_post_available = $false
        social_post_available = $false
        community_cta_write_available = $true
        community_cta_main_write_blocked = $true
        previews_outside_repository = $true
    }
    preview_directory = $outputFullPath
}

$reportPath = Join-Path $outputFullPath "release-report.json"
Write-Utf8NoBom -Path $reportPath -Content ($report | ConvertTo-Json -Depth 8)

Write-Host "`nStaging publication test completed." -ForegroundColor Green
Write-Host "Article:  $articleTitle"
Write-Host "Preview:  $outputFullPath"
Write-Host "Report:   $reportPath"
Write-Host "XenForo:  read-only; no thread was created"
Write-Host "CTA:      $($communityCtaResult.status)"
Write-Host "Social:   previews only; nothing was published"
Write-Host "Production deployment is not implemented in this script."
