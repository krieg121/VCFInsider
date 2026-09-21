#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ManifestPath,

    [switch]$CreateThread,

    [string]$ApiBase = "https://community.vcfinsider.com/index.php/api",
    [int]$PostingUserId = 4,
    [string]$OutputDirectory
)

Set-StrictMode -Version Latest
$oldErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Stop"
$secureKey = $null
$bstr = [IntPtr]::Zero
$key = $null

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
}

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content
    )

    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $encoding)
}

function Invoke-XenForoGet {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][hashtable]$Headers
    )
    Invoke-RestMethod -Method Get -Uri "$ApiBase$Path" -Headers $Headers
}

function Write-ReleaseReport {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]$Result
    )

    Write-Utf8NoBom -Path $Path -Content ($Result | ConvertTo-Json -Depth 8)
}

$repositoryRoot = Split-Path -Parent $PSScriptRoot
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

$articleTitle = Get-RequiredText -InputObject $manifest -Name "article_title"
$expectedText = Get-RequiredText -InputObject $manifest -Name "expected_text"
$stagingUrl = Get-RequiredText -InputObject $manifest -Name "staging_url"
$productionUrl = Get-RequiredText -InputObject $manifest -Name "production_url"
Assert-HttpsUrl -Value $stagingUrl -ExpectedHost "staging.vcfinsider.com" -Name "staging_url"
Assert-HttpsUrl -Value $productionUrl -ExpectedHost "www.vcfinsider.com" -Name "production_url"

$xenForo = Get-RequiredProperty -InputObject $manifest -Name "xenforo"
$nodeId = [int](Get-RequiredProperty -InputObject $xenForo -Name "node_id")
if ($nodeId -le 0) { throw "xenforo.node_id must be greater than zero." }
$forumName = Get-RequiredText -InputObject $xenForo -Name "forum_name"
$title = Get-RequiredText -InputObject $xenForo -Name "thread_title"
$messageTemplate = Get-RequiredText -InputObject $xenForo -Name "message"
$message = $messageTemplate.Replace("{{ARTICLE_URL}}", $productionUrl)

$expectedThreadUrl = $null
$threadUrlProperty = $xenForo.PSObject.Properties["thread_url"]
if ($null -ne $threadUrlProperty -and -not [string]::IsNullOrWhiteSpace([string]$threadUrlProperty.Value)) {
    $expectedThreadUrl = [string]$threadUrlProperty.Value
    Assert-HttpsUrl -Value $expectedThreadUrl -ExpectedHost "community.vcfinsider.com" -Name "xenforo.thread_url"
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
    throw "Report output must be outside the Git repository: $outputFullPath"
}
New-Item -ItemType Directory -Path $outputFullPath -Force | Out-Null
$reportPath = Join-Path $outputFullPath "xenforo-release-report.json"

try {
    $secureKey = Read-Host "Enter the XenForo API key" -AsSecureString
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureKey)
    $key = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    if ([string]::IsNullOrWhiteSpace($key)) {
        throw "The XenForo API key cannot be empty."
    }

    $headers = @{
        "XF-Api-Key"  = $key
        "XF-Api-User" = $PostingUserId.ToString()
    }

    Write-Step "Verifying the XenForo posting identity"
    $meResponse = Invoke-XenForoGet -Path "/me/" -Headers $headers
    $me = if ($meResponse.me) { $meResponse.me } elseif ($meResponse.user) { $meResponse.user } else { $meResponse }
    if ([int]$me.user_id -ne $PostingUserId -or [string]$me.username -ne "VCF Insider") {
        throw "Unexpected XenForo identity: user_id=$($me.user_id), username=$($me.username)."
    }
    Write-Host "Authenticated as VCF Insider (user ID $PostingUserId)." -ForegroundColor Green

    Write-Step "Checking for an existing thread with the same title"
    $page = 1
    $lastPage = 1
    $duplicate = $null
    do {
        $threadsResponse = Invoke-XenForoGet -Path "/threads/?page=$page&last_days=0" -Headers $headers
        $duplicate = @($threadsResponse.threads) |
            Where-Object { [string]$_.title -ceq $title } |
            Select-Object -First 1
        if ($duplicate) { break }

        if ($threadsResponse.pagination -and $threadsResponse.pagination.last_page) {
            $lastPage = [int]$threadsResponse.pagination.last_page
        }
        $page++
    } while ($page -le $lastPage)

    if ($duplicate) {
        $existingId = [int]$duplicate.thread_id
        $existingUrl = ([string]$duplicate.view_url) -replace '^http:', 'https:'
        if ([string]::IsNullOrWhiteSpace($existingUrl)) {
            throw "The exact-title XenForo result did not include a view URL."
        }

        $urlVerified = $false
        if (-not [string]::IsNullOrWhiteSpace($expectedThreadUrl)) {
            $expectedCanonical = $expectedThreadUrl.TrimEnd('/')
            $existingCanonical = $existingUrl.TrimEnd('/')
            if (-not $existingCanonical.Equals($expectedCanonical, [System.StringComparison]::OrdinalIgnoreCase)) {
                throw "XenForo thread URL mismatch. Expected '$expectedThreadUrl'; found '$existingUrl'."
            }
            $urlVerified = $true
        }

        $result = [ordered]@{
            schema_version = 1
            generated_utc = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
            release_name = $releaseName
            article_title = $articleTitle
            requested_create = [bool]$CreateThread
            action = "existing-thread"
            authenticated_user = [string]$me.username
            posting_user_id = [int]$me.user_id
            node_id = $nodeId
            thread_id = $existingId
            thread_title = $title
            thread_url = $existingUrl
            manifest_url_verified = $urlVerified
            write_performed = $false
        }
        Write-ReleaseReport -Path $reportPath -Result $result

        Write-Host "Existing exact-title thread verified; no POST was performed." -ForegroundColor Green
        Write-Host "Thread ID: $existingId"
        Write-Host "URL:       $existingUrl"
        Write-Host "Report:    $reportPath"
        return
    }

    if (-not [string]::IsNullOrWhiteSpace($expectedThreadUrl)) {
        throw "The manifest contains xenforo.thread_url, but no exact-title thread was found. No POST was attempted."
    }

    Write-Host "No exact-title duplicate found." -ForegroundColor Green
    Write-Step "Proposed XenForo write"
    Write-Host "Forum: $forumName (node $nodeId)"
    Write-Host "Title: $title"
    Write-Host "`n$message`n"

    if (-not $CreateThread) {
        $result = [ordered]@{
            schema_version = 1
            generated_utc = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
            release_name = $releaseName
            article_title = $articleTitle
            requested_create = $false
            action = "check-only-no-duplicate"
            authenticated_user = [string]$me.username
            posting_user_id = [int]$me.user_id
            node_id = $nodeId
            thread_id = $null
            thread_title = $title
            thread_url = $null
            manifest_url_verified = $false
            write_performed = $false
        }
        Write-ReleaseReport -Path $reportPath -Result $result
        Write-Host "Check-only mode completed. No POST was performed." -ForegroundColor Green
        Write-Host "Report: $reportPath"
        return
    }

    $branch = (& git -C $repositoryRoot branch --show-current).Trim()
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($branch)) {
        throw "Unable to determine the current Git branch. No POST was attempted."
    }
    if ($branch -eq "main") {
        throw "XenForo thread creation is not allowed directly from main. No POST was attempted."
    }
    $workingChanges = @(& git -C $repositoryRoot status --porcelain)
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to verify the Git working tree. No POST was attempted."
    }
    if ($workingChanges.Count -gt 0) {
        throw "The Git working tree must be clean before creating a XenForo thread. No POST was attempted."
    }

    Write-Step "Verifying the staged article before the live XenForo write"
    $separator = if ($stagingUrl.Contains("?")) { "&" } else { "?" }
    $cacheBuster = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $stagingResponse = Invoke-WebRequest `
        -Uri "${stagingUrl}${separator}xenforo_preflight=${cacheBuster}" `
        -UseBasicParsing `
        -MaximumRedirection 5
    if ($stagingResponse.StatusCode -ne 200 -or -not $stagingResponse.Content.Contains($expectedText)) {
        throw "The staged article preflight failed. No POST was attempted: $stagingUrl"
    }
    Write-Host "Staged article preflight passed." -ForegroundColor Green

    $confirmationPhrase = "POST $releaseName"
    $confirmation = Read-Host "Type $confirmationPhrase to create this live thread"
    if ($confirmation -cne $confirmationPhrase) {
        throw "Confirmation did not match. No XenForo content was created."
    }

    Write-Step "Creating the XenForo thread"
    $createResponse = Invoke-RestMethod `
        -Method Post `
        -Uri "$ApiBase/threads/" `
        -Headers $headers `
        -ContentType "application/x-www-form-urlencoded; charset=utf-8" `
        -Body @{
            node_id = $nodeId
            title   = $title
            message = $message
        }

    $thread = $createResponse.thread
    if (-not $thread -or -not $thread.thread_id) {
        throw "XenForo did not return the created thread object. Reconcile the community site before attempting another POST."
    }

    $threadId = [int]$thread.thread_id
    $viewUrl = ([string]$thread.view_url) -replace '^http:', 'https:'

    Write-Step "Verifying the newly created thread"
    $readbackResponse = Invoke-XenForoGet -Path "/threads/$threadId/?with_first_post=1" -Headers $headers
    $readbackThread = $readbackResponse.thread
    if (-not $readbackThread) { $readbackThread = $readbackResponse }

    if ([int]$readbackThread.thread_id -ne $threadId -or [string]$readbackThread.title -ne $title) {
        throw "Thread $threadId was created, but read-back verification did not match. Do not repost; inspect this thread: $viewUrl"
    }

    $result = [ordered]@{
        schema_version = 1
        generated_utc = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
        release_name = $releaseName
        article_title = $articleTitle
        requested_create = $true
        action = "created-and-verified"
        authenticated_user = [string]$me.username
        posting_user_id = [int]$me.user_id
        node_id = $nodeId
        thread_id = $threadId
        thread_title = $title
        thread_url = $viewUrl
        manifest_url_verified = $false
        write_performed = $true
    }
    Write-ReleaseReport -Path $reportPath -Result $result

    Write-Host "`nThread created and verified." -ForegroundColor Green
    Write-Host "Thread ID: $threadId"
    Write-Host "Forum ID:  $nodeId"
    Write-Host "Title:     $title"
    Write-Host "URL:       $viewUrl"
    Write-Host "Report:    $reportPath"
    Write-Host "Add this verified URL to xenforo.thread_url before applying the community CTA." -ForegroundColor Yellow
}
catch {
    Write-Error $_
    Write-Host "If a POST may have occurred, do not rerun the script until the XenForo forum has been checked for a partial success." -ForegroundColor Yellow
    exit 1
}
finally {
    if ($bstr -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
    $key = $null
    $secureKey = $null
    $ErrorActionPreference = $oldErrorActionPreference
}
