#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PlanPath,

    [switch]$Publish,

    [string]$ApiEndpoint = "https://api.buffer.com",
    [string]$ApiKeyEnvironmentVariable = "VCFINSIDER_BUFFER_API_KEY",
    [string]$OutputDirectory
)

Set-StrictMode -Version Latest
$oldErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Stop"
$apiKey = $null
$secureKey = $null
$bstr = [IntPtr]::Zero

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
        throw "Required property '$Name' is missing."
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
        throw "Required property '$Name' cannot be empty."
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

function Write-BufferReport {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]$Report
    )

    $Report["updated_utc"] = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
    Write-Utf8NoBom -Path $Path -Content ($Report | ConvertTo-Json -Depth 20)
}

function Invoke-BufferGraphQl {
    param(
        [Parameter(Mandatory = $true)][string]$Query,
        [Parameter(Mandatory = $true)][hashtable]$Variables,
        [Parameter(Mandatory = $true)][string]$OperationName
    )

    $body = [ordered]@{
        query = $Query
        variables = $Variables
        operationName = $OperationName
    } | ConvertTo-Json -Depth 30 -Compress

    $response = Invoke-RestMethod `
        -Method Post `
        -Uri $ApiEndpoint `
        -Headers @{ Authorization = "Bearer $apiKey" } `
        -ContentType "application/json; charset=utf-8" `
        -Body $body

    $errorsProperty = $response.PSObject.Properties["errors"]
    if ($null -ne $errorsProperty -and @($errorsProperty.Value).Count -gt 0) {
        $messages = @($errorsProperty.Value | ForEach-Object { [string]$_.message })
        throw "Buffer GraphQL $OperationName failed: $($messages -join '; ')"
    }
    if ($null -eq $response.data) {
        throw "Buffer GraphQL $OperationName returned no data."
    }
    return $response.data
}

function Get-CanonicalDate {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    $parsed = [DateTimeOffset]::MinValue
    if (-not [DateTimeOffset]::TryParse($Value, [ref]$parsed)) {
        throw "Buffer returned an invalid date: $Value"
    }
    return $parsed.ToUniversalTime().ToString("o")
}

function Test-DateMatch {
    param([string]$Expected, [string]$Actual)

    if ([string]::IsNullOrWhiteSpace($Expected) -and [string]::IsNullOrWhiteSpace($Actual)) {
        return $true
    }
    if ([string]::IsNullOrWhiteSpace($Expected) -or [string]::IsNullOrWhiteSpace($Actual)) {
        return $false
    }
    return (Get-CanonicalDate -Value $Expected) -ceq (Get-CanonicalDate -Value $Actual)
}

function Get-PlatformAttachment {
    param(
        [Parameter(Mandatory = $true)]$Post,
        [Parameter(Mandatory = $true)][string]$Platform
    )

    if ($null -eq $Post.metadata) { return $null }
    $expectedType = if ($Platform -ceq "linkedin") { "LinkedInPostMetadata" } else { "FacebookPostMetadata" }
    if ([string]$Post.metadata.__typename -cne $expectedType) { return $null }
    return $Post.metadata.linkAttachment
}

function Assert-PostMatchesPlan {
    param(
        [Parameter(Mandatory = $true)]$Post,
        [Parameter(Mandatory = $true)]$PlannedPost,
        [Parameter(Mandatory = $true)]$Plan
    )

    if ([string]$Post.channelId -cne [string]$PlannedPost.channel_id) {
        throw "Buffer post $($Post.id) channel mismatch."
    }
    if ([string]$Post.text -cne [string]$PlannedPost.text) {
        throw "Buffer post $($Post.id) text mismatch."
    }
    if ([string]$Post.channelService -cne [string]$PlannedPost.service) {
        throw "Buffer post $($Post.id) service mismatch."
    }
    if ([string]$Post.shareMode -cne [string]$Plan.mode) {
        throw "Buffer post $($Post.id) share mode mismatch."
    }
    if ([string]$Post.schedulingType -cne [string]$Plan.scheduling_type) {
        throw "Buffer post $($Post.id) scheduling type mismatch."
    }
    if ($Plan.mode -ceq "customScheduled" -and -not (Test-DateMatch -Expected $PlannedPost.due_at -Actual $Post.dueAt)) {
        throw "Buffer post $($Post.id) scheduled time mismatch."
    }

    $attachment = Get-PlatformAttachment -Post $Post -Platform $PlannedPost.platform
    if ($null -eq $attachment) {
        throw "Buffer post $($Post.id) has a null $($PlannedPost.platform) linkAttachment."
    }
    if ([string]$attachment.url -cne [string]$PlannedPost.article_url -or
        [string]$attachment.title -cne [string]$Plan.link_preview.title -or
        [string]$attachment.text -cne [string]$Plan.link_preview.description -or
        [string]$attachment.thumbnail -cne [string]$Plan.link_preview.thumbnail_url) {
        throw "Buffer post $($Post.id) linkAttachment does not match the validated plan."
    }

    return [ordered]@{
        post_id = [string]$Post.id
        platform = [string]$PlannedPost.platform
        channel_id = [string]$Post.channelId
        status = [string]$Post.status
        share_mode = [string]$Post.shareMode
        scheduling_type = [string]$Post.schedulingType
        due_at = [string]$Post.dueAt
        sent_at = [string]$Post.sentAt
        public_url = [string]$Post.externalLink
        preview_url = [string]$attachment.url
        preview_thumbnail_url = [string]$attachment.thumbnail
        preview_verified = $true
    }
}

$postFields = @"
id
channelId
channelService
text
status
shareMode
schedulingType
dueAt
isCustomScheduled
sharedNow
sentAt
externalLink
createdAt
updatedAt
metadata {
  __typename
  ... on LinkedInPostMetadata {
    linkAttachment { url title text thumbnail }
  }
  ... on FacebookPostMetadata {
    type
    linkAttachment { url title text thumbnail }
  }
}
"@

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$apiUri = [Uri]$ApiEndpoint
if ($apiUri.Scheme -cne "https" -or
    $apiUri.Host -cne "api.buffer.com" -or
    $apiUri.AbsolutePath -cne "/" -or
    -not [string]::IsNullOrEmpty($apiUri.Query) -or
    -not [string]::IsNullOrEmpty($apiUri.Fragment) -or
    -not [string]::IsNullOrEmpty($apiUri.UserInfo)) {
    throw "ApiEndpoint must be exactly https://api.buffer.com."
}
$planFullPath = if ([System.IO.Path]::IsPathRooted($PlanPath)) {
    [System.IO.Path]::GetFullPath($PlanPath)
}
else {
    [System.IO.Path]::GetFullPath((Join-Path $repositoryRoot $PlanPath))
}
if (-not (Test-Path -LiteralPath $planFullPath -PathType Leaf)) {
    throw "Buffer plan was not found: $planFullPath"
}

$utf8 = New-Object System.Text.UTF8Encoding($false)
$plan = [System.IO.File]::ReadAllText($planFullPath, $utf8) | ConvertFrom-Json
if ([int](Get-RequiredProperty -InputObject $plan -Name "schema_version") -ne 2) {
    throw "Unsupported Buffer plan schema. Regenerate it with Prepare-VCFInsiderBufferPosts.ps1."
}
$releaseName = Get-RequiredText -InputObject $plan -Name "release_name"
$releaseNamePattern = '^(?<date>[0-9]{4}-[0-9]{2}-[0-9]{2})-[a-z0-9][a-z0-9-]{2,69}$'
if ($releaseName -notmatch $releaseNamePattern) {
    throw "release_name must begin with yyyy-MM-dd and contain only lowercase letters, numbers, and hyphens."
}
$releaseDateText = [string]$Matches['date']
$organizationId = Get-RequiredText -InputObject $plan -Name "organization_id"
$mode = Get-RequiredText -InputObject $plan -Name "mode"
if ($mode -cnotin @("shareNow", "customScheduled")) {
    throw "Unsupported Buffer mode in plan: $mode"
}

$enabledPosts = @($plan.posts | Where-Object { [bool]$_.enabled })
if ($enabledPosts.Count -eq 0 -or -not [bool]$plan.ready_to_publish) {
    throw "The Buffer plan has no enabled posts. No API request was made."
}
foreach ($plannedPost in $enabledPosts) {
    if ([string]$plannedPost.platform -cnotin @("linkedin", "facebook")) {
        throw "Only LinkedIn and Facebook are supported by this verified publisher."
    }
    if ($null -eq $plannedPost.input) {
        throw "Enabled post '$($plannedPost.platform)' has no validated input."
    }
    if ([bool]$plannedPost.input.saveToDraft -or [bool]$plannedPost.input.needsApproval) {
        throw "Enabled post '$($plannedPost.platform)' must not be a draft or approval request."
    }
    if ([string]$plannedPost.input.source -cne "vcfinsider-publishing-automation") {
        throw "Enabled post '$($plannedPost.platform)' has an unexpected source marker."
    }
    if (@($plannedPost.input.assets).Count -ne 0) {
        throw "Enabled post '$($plannedPost.platform)' must use linkAttachment with an empty assets array."
    }
}

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Split-Path -Parent $planFullPath
}
$outputFullPath = [System.IO.Path]::GetFullPath($OutputDirectory)
$repositoryFullPath = [System.IO.Path]::GetFullPath($repositoryRoot).TrimEnd([char[]]@('\', '/'))
$repositoryPrefix = $repositoryFullPath + [System.IO.Path]::DirectorySeparatorChar
if ($outputFullPath.Equals($repositoryFullPath, [System.StringComparison]::OrdinalIgnoreCase) -or
    $outputFullPath.StartsWith($repositoryPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Buffer API output must be outside the Git repository: $outputFullPath"
}
New-Item -ItemType Directory -Path $outputFullPath -Force | Out-Null
$reportPath = Join-Path $outputFullPath "buffer-api-release-report.json"
$report = [ordered]@{
    schema_version = 1
    generated_utc = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
    updated_utc = $null
    release_name = $releaseName
    plan_path = $planFullPath
    api_endpoint = $ApiEndpoint
    publish_requested = [bool]$Publish
    confirmation_phrase = if ($mode -ceq "shareNow") { "PUBLISH $releaseName" } else { "SCHEDULE $releaseName" }
    organization_verified = $false
    channels_verified = $false
    duplicate_check_completed = $false
    write_performed = $false
    results = @()
    status = "starting"
}
Write-BufferReport -Path $reportPath -Report $report

try {
    $apiKey = [Environment]::GetEnvironmentVariable($ApiKeyEnvironmentVariable, "Process")
    if ([string]::IsNullOrWhiteSpace($apiKey)) {
        $secureKey = Read-Host "Enter the Buffer API key" -AsSecureString
        $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureKey)
        $apiKey = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    }
    if ([string]::IsNullOrWhiteSpace($apiKey)) {
        throw "The Buffer API key cannot be empty."
    }

    Write-Step "Verifying the Buffer organization and channels"
    $identityQuery = @"
query VerifyPublishingIdentity(`$organizationId: OrganizationId!) {
  account { organizations { id name } }
  channels(input: { organizationId: `$organizationId }) {
    id name displayName service isDisconnected isLocked
  }
}
"@
    $identity = Invoke-BufferGraphQl `
        -Query $identityQuery `
        -Variables @{ organizationId = $organizationId } `
        -OperationName "VerifyPublishingIdentity"

    $organization = @($identity.account.organizations) |
        Where-Object { [string]$_.id -ceq $organizationId } |
        Select-Object -First 1
    if ($null -eq $organization) {
        throw "The API key cannot access Buffer organization '$organizationId'."
    }
    $report["organization_verified"] = $true
    $report["organization_name"] = [string]$organization.name

    foreach ($plannedPost in $enabledPosts) {
        $channel = @($identity.channels) |
            Where-Object { [string]$_.id -ceq [string]$plannedPost.channel_id } |
            Select-Object -First 1
        if ($null -eq $channel) {
            throw "Buffer channel '$($plannedPost.channel_id)' was not found."
        }
        if ([string]$channel.service -cne [string]$plannedPost.service) {
            throw "Buffer channel '$($plannedPost.channel_id)' service mismatch."
        }
        if ([bool]$channel.isDisconnected -or [bool]$channel.isLocked) {
            throw "Buffer channel '$($plannedPost.channel_id)' is disconnected or locked."
        }
    }
    $report["channels_verified"] = $true

    Write-Step "Checking for exact duplicate Buffer posts"
    $today = [DateTimeOffset]::UtcNow
    $releaseDate = [DateTimeOffset]::MinValue
    if (-not [DateTimeOffset]::TryParseExact(
        $releaseDateText,
        "yyyy-MM-dd",
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::AssumeUniversal,
        [ref]$releaseDate
    )) {
        throw "release_name must begin with yyyy-MM-dd for duplicate detection."
    }
    $thirtyDaysAgo = $today.AddDays(-30)
    $windowStart = if ($releaseDate.AddDays(-1) -lt $thirtyDaysAgo) { $releaseDate.AddDays(-1) } else { $thirtyDaysAgo }
    $postQuery = @"
query FindReleasePosts(`$input: PostsInput!, `$first: Int!, `$after: String) {
  posts(input: `$input, first: `$first, after: `$after) {
    edges { node { id channelId text status dueAt createdAt } }
    pageInfo { endCursor hasNextPage }
  }
}
"@
    $allPosts = @()
    $after = $null
    $pageCount = 0
    do {
        $pageCount++
        if ($pageCount -gt 10) {
            throw "Duplicate detection exceeded 1,000 posts. No write was attempted."
        }
        $variables = @{
            input = @{
                organizationId = $organizationId
                filter = @{
                    channelIds = @($enabledPosts | ForEach-Object { [string]$_.channel_id })
                    createdAt = @{
                        start = $windowStart.ToString("o")
                        end = $today.AddDays(1).ToString("o")
                    }
                }
            }
            first = 100
            after = $after
        }
        $page = Invoke-BufferGraphQl -Query $postQuery -Variables $variables -OperationName "FindReleasePosts"
        $allPosts += @($page.posts.edges | ForEach-Object { $_.node })
        $after = [string]$page.posts.pageInfo.endCursor
    } while ([bool]$page.posts.pageInfo.hasNextPage)

    $postReadQuery = @"
query ReadBackPost(`$input: PostInput!) {
  post(input: `$input) {
$postFields
  }
}
"@
    $pendingPosts = @()
    foreach ($plannedPost in $enabledPosts) {
        $duplicates = @($allPosts | Where-Object {
            [string]$_.channelId -ceq [string]$plannedPost.channel_id -and
            [string]$_.text -ceq [string]$plannedPost.text
        })
        if ($mode -ceq "customScheduled") {
            $duplicates = @($duplicates | Where-Object {
                Test-DateMatch -Expected $plannedPost.due_at -Actual $_.dueAt
            })
        }
        if ($duplicates.Count -gt 1) {
            throw "Multiple exact Buffer duplicates exist for '$($plannedPost.platform)'. Reconcile them manually."
        }
        if ($duplicates.Count -eq 1) {
            $existingData = Invoke-BufferGraphQl `
                -Query $postReadQuery `
                -Variables @{ input = @{ id = [string]$duplicates[0].id } } `
                -OperationName "ReadBackPost"
            $verified = Assert-PostMatchesPlan -Post $existingData.post -PlannedPost $plannedPost -Plan $plan
            $verified["action"] = "existing-exact-duplicate"
            $report["results"] += [pscustomobject]$verified
            Write-Host "Existing verified $($plannedPost.platform) post: $($existingData.post.id)" -ForegroundColor Yellow
        }
        else {
            $pendingPosts += $plannedPost
        }
    }
    $report["duplicate_check_completed"] = $true

    Write-Step "Validated Buffer publication inputs"
    foreach ($plannedPost in $pendingPosts) {
        Write-Host "`n$($plannedPost.platform.ToUpperInvariant())"
        Write-Host ($plannedPost.input | ConvertTo-Json -Depth 15)
    }

    if (-not $Publish) {
        $report["status"] = "check-only"
        Write-BufferReport -Path $reportPath -Report $report
        Write-Host "`nBuffer API preflight completed. No post was created or scheduled." -ForegroundColor Green
        Write-Host "Report: $reportPath"
        return
    }
    if ($pendingPosts.Count -eq 0) {
        $report["status"] = "already-complete"
        Write-BufferReport -Path $reportPath -Report $report
        Write-Host "`nEvery enabled Buffer post already exists and passed verification. No write was performed." -ForegroundColor Green
        return
    }

    $confirmationPhrase = [string]$report["confirmation_phrase"]
    $confirmation = Read-Host "Type $confirmationPhrase to continue"
    if ($confirmation -cne $confirmationPhrase) {
        throw "Confirmation did not match. No Buffer post was created or scheduled."
    }

    $createMutation = @"
mutation CreatePublicationPost(`$input: CreatePostInput!) {
  createPost(input: `$input) {
    __typename
    ... on PostActionSuccess {
      post {
$postFields
      }
    }
    ... on MutationError { message }
  }
}
"@

    foreach ($plannedPost in $pendingPosts) {
        Write-Step "Creating the $($plannedPost.platform) Buffer post"
        $mutationAttempted = $false
        try {
            $mutationAttempted = $true
            $createdData = Invoke-BufferGraphQl `
                -Query $createMutation `
                -Variables @{ input = $plannedPost.input } `
                -OperationName "CreatePublicationPost"
            $payload = $createdData.createPost
            if ([string]$payload.__typename -cne "PostActionSuccess" -or $null -eq $payload.post) {
                $message = if ($payload.message) { [string]$payload.message } else { "Unknown mutation result" }
                throw "Buffer rejected the $($plannedPost.platform) post: $message"
            }

            $postId = [string]$payload.post.id
            if ([string]::IsNullOrWhiteSpace($postId)) {
                throw "Buffer returned success without a post ID."
            }
            $readbackData = Invoke-BufferGraphQl `
                -Query $postReadQuery `
                -Variables @{ input = @{ id = $postId } } `
                -OperationName "ReadBackPost"
            $verified = Assert-PostMatchesPlan -Post $readbackData.post -PlannedPost $plannedPost -Plan $plan
            $verified["action"] = "created-and-verified"
            $report["results"] += [pscustomobject]$verified
            $report["write_performed"] = $true
            Write-BufferReport -Path $reportPath -Report $report
            Write-Host "$($plannedPost.platform) post $postId created and preview-verified." -ForegroundColor Green
        }
        catch {
            $report["status"] = if ($mutationAttempted) { "mutation-attempted-reconciliation-required" } else { "failed-before-mutation" }
            $report["error"] = $_.Exception.Message
            Write-BufferReport -Path $reportPath -Report $report
            if ($mutationAttempted) {
                throw "A Buffer mutation was attempted for '$($plannedPost.platform)'. Do not retry automatically. Inspect Buffer and the report before continuing. $($_.Exception.Message)"
            }
            throw
        }
    }

    $report["status"] = "completed"
    Write-BufferReport -Path $reportPath -Report $report
    Write-Host "`nBuffer publication completed and verified." -ForegroundColor Green
    Write-Host "Report: $reportPath"
}
catch {
    if ($report["status"] -eq "starting") {
        $report["status"] = "failed-before-mutation"
        $report["error"] = $_.Exception.Message
        Write-BufferReport -Path $reportPath -Report $report
    }
    throw
}
finally {
    if ($bstr -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
    $apiKey = $null
    $secureKey = $null
    $ErrorActionPreference = $oldErrorActionPreference
}
