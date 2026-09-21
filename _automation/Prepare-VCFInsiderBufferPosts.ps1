#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ManifestPath,

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

function Get-OptionalText {
    param(
        [Parameter(Mandatory = $true)]$InputObject,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value) {
        return ""
    }
    return [string]$property.Value
}

function Get-OptionalBoolean {
    param(
        [Parameter(Mandatory = $true)]$InputObject,
        [Parameter(Mandatory = $true)][string]$Name,
        [bool]$Default = $false
    )

    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $property) { return $Default }
    if ($property.Value -isnot [bool]) {
        throw "Manifest property '$Name' must be true or false."
    }
    return [bool]$property.Value
}

function Assert-BufferId {
    param(
        [Parameter(Mandatory = $true)][string]$Value,
        [Parameter(Mandatory = $true)][string]$Name
    )

    if ($Value.Length -gt 128 -or $Value -match '\s') {
        throw "Manifest property '$Name' must be a non-whitespace Buffer ID no longer than 128 characters."
    }
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

function ConvertTo-BufferDate {
    param(
        [Parameter(Mandatory = $true)][string]$Value,
        [Parameter(Mandatory = $true)][string]$Name
    )

    if ($Value -notmatch '[+-][0-9]{2}:[0-9]{2}$') {
        throw "Manifest property '$Name' must end with an explicit UTC offset such as -04:00 or -05:00."
    }

    $parsed = [DateTimeOffset]::MinValue
    if (-not [DateTimeOffset]::TryParseExact(
        $Value,
        "yyyy-MM-dd'T'HH:mm:sszzz",
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::None,
        [ref]$parsed
    )) {
        throw "Manifest property '$Name' must use yyyy-MM-ddTHH:mm:ss-04:00 format."
    }

    if ($parsed -le [DateTimeOffset]::Now) {
        throw "Manifest property '$Name' must be a future time."
    }

    return $parsed.ToString("yyyy-MM-dd'T'HH:mm:sszzz")
}

function Get-XWeightedLength {
    param([Parameter(Mandatory = $true)][string]$Text)

    $length = $Text.Length
    $urlMatches = [regex]::Matches($Text, '(?i)https?://[^\s]+')
    foreach ($match in $urlMatches) {
        $length = $length - $match.Length + 23
    }
    return $length
}

function New-LinkAttachment {
    param(
        [Parameter(Mandatory = $true)][string]$Url,
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)][string]$Description,
        [Parameter(Mandatory = $true)][string]$ThumbnailUrl
    )

    return [pscustomobject][ordered]@{
        url = $Url
        title = $Title
        description = $Description
        thumbnail = [pscustomobject][ordered]@{
            url = $ThumbnailUrl
        }
    }
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

Write-Step "Loading and validating the Buffer publication plan"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$manifest = [System.IO.File]::ReadAllText($manifestFullPath, $utf8) | ConvertFrom-Json
$schemaVersion = [int](Get-RequiredProperty -InputObject $manifest -Name "schema_version")
if ($schemaVersion -ne 1) {
    throw "Unsupported publication manifest schema: $schemaVersion"
}

$releaseName = Get-RequiredText -InputObject $manifest -Name "release_name"
if ($releaseName -notmatch '^[a-z0-9][a-z0-9-]{2,79}$') {
    throw "release_name must contain only lowercase letters, numbers, and hyphens."
}

$articleTitle = Get-RequiredText -InputObject $manifest -Name "article_title"
$productionUrl = Get-RequiredText -InputObject $manifest -Name "production_url"
Assert-HttpsUrl -Value $productionUrl -ExpectedHost "www.vcfinsider.com" -Name "production_url"

$social = Get-RequiredProperty -InputObject $manifest -Name "social"
$buffer = Get-RequiredProperty -InputObject $manifest -Name "buffer"
$organizationId = Get-RequiredText -InputObject $buffer -Name "organization_id"
Assert-BufferId -Value $organizationId -Name "buffer.organization_id"
$timezone = Get-RequiredText -InputObject $buffer -Name "timezone"
$mode = Get-RequiredText -InputObject $buffer -Name "mode"
$schedulingType = Get-RequiredText -InputObject $buffer -Name "scheduling_type"
$channels = Get-RequiredProperty -InputObject $buffer -Name "channels"
$linkPreview = Get-RequiredProperty -InputObject $buffer -Name "link_preview"
$previewTitle = Get-RequiredText -InputObject $linkPreview -Name "title"
$previewDescription = Get-RequiredText -InputObject $linkPreview -Name "description"
$previewThumbnailUrl = Get-RequiredText -InputObject $linkPreview -Name "thumbnail_url"

if ($previewTitle -cne $articleTitle) {
    throw "buffer.link_preview.title must exactly match article_title."
}
Assert-HttpsUrl `
    -Value $previewThumbnailUrl `
    -ExpectedHost "www.vcfinsider.com" `
    -Name "buffer.link_preview.thumbnail_url"

if ($mode -cnotin @("customScheduled", "shareNow")) {
    throw "buffer.mode must be 'customScheduled' or 'shareNow'."
}
if ($schedulingType -cne "automatic") {
    throw "buffer.scheduling_type must be 'automatic'."
}
if ($timezone -cne "America/New_York") {
    throw "buffer.timezone must be 'America/New_York' for the current VCF Insider workflow."
}

$definitions = @(
    [pscustomobject]@{ Name = "linkedin"; Service = "linkedin"; SocialName = "linkedin"; Limit = 3000; PreviewType = "linkedin"; Supported = $true },
    [pscustomobject]@{ Name = "facebook"; Service = "facebook"; SocialName = "facebook"; Limit = 63206; PreviewType = "facebook"; Supported = $true },
    [pscustomobject]@{ Name = "x"; Service = "twitter"; SocialName = "x"; Limit = 280; PreviewType = ""; Supported = $false }
)

$posts = @()
$configuredChannelIds = @{}
foreach ($definition in $definitions) {
    $channel = Get-RequiredProperty -InputObject $channels -Name $definition.Name
    $enabled = Get-OptionalBoolean -InputObject $channel -Name "enabled"
    $channelId = Get-OptionalText -InputObject $channel -Name "channel_id"

    if ($enabled -and [string]::IsNullOrWhiteSpace($channelId)) {
        throw "buffer.channels.$($definition.Name).channel_id is required when enabled is true."
    }
    if (-not [string]::IsNullOrWhiteSpace($channelId)) {
        Assert-BufferId -Value $channelId -Name "buffer.channels.$($definition.Name).channel_id"
        if ($configuredChannelIds.ContainsKey($channelId)) {
            throw "Buffer channel ID '$channelId' is assigned to more than one service."
        }
        $configuredChannelIds[$channelId] = $definition.Name
    }

    $service = Get-RequiredText -InputObject $channel -Name "service"
    if ($service -cne $definition.Service) {
        throw "buffer.channels.$($definition.Name).service must be '$($definition.Service)'."
    }
    if ($enabled -and -not $definition.Supported) {
        throw "buffer.channels.$($definition.Name) cannot be enabled. Its connected-channel and link-preview workflow has not been verified."
    }

    $textTemplate = Get-RequiredText -InputObject $social -Name $definition.SocialName
    $text = $textTemplate.Replace("{{ARTICLE_URL}}", $productionUrl)
    if ($text -notmatch [regex]::Escape($productionUrl)) {
        throw "social.$($definition.SocialName) must include {{ARTICLE_URL}}."
    }
    $countedCharacters = if ($definition.Name -eq "x") {
        Get-XWeightedLength -Text $text
    }
    else {
        $text.Length
    }
    if ($countedCharacters -gt $definition.Limit) {
        throw "social.$($definition.SocialName) is $countedCharacters counted characters; limit is $($definition.Limit)."
    }

    $dueAt = $null
    $dueAtValue = Get-OptionalText -InputObject $channel -Name "due_at"
    if ($enabled -and $mode -ceq "customScheduled") {
        if ([string]::IsNullOrWhiteSpace($dueAtValue)) {
            throw "buffer.channels.$($definition.Name).due_at is required when enabled is true and buffer.mode is customScheduled."
        }
        $dueAt = ConvertTo-BufferDate `
            -Value $dueAtValue `
            -Name "buffer.channels.$($definition.Name).due_at"
    }
    elseif ($enabled -and $mode -ceq "shareNow" -and -not [string]::IsNullOrWhiteSpace($dueAtValue)) {
        throw "buffer.channels.$($definition.Name).due_at must be empty when buffer.mode is shareNow."
    }

    $metadata = $null
    $postInput = $null
    if ($enabled) {
        $attachment = New-LinkAttachment `
            -Url $productionUrl `
            -Title $previewTitle `
            -Description $previewDescription `
            -ThumbnailUrl $previewThumbnailUrl

        if ($definition.PreviewType -ceq "linkedin") {
            $metadata = [pscustomobject][ordered]@{
                linkedin = [pscustomobject][ordered]@{
                    linkAttachment = $attachment
                }
            }
        }
        elseif ($definition.PreviewType -ceq "facebook") {
            $metadata = [pscustomobject][ordered]@{
                facebook = [pscustomobject][ordered]@{
                    type = "post"
                    linkAttachment = $attachment
                }
            }
        }
        else {
            throw "No verified link-preview payload exists for enabled platform '$($definition.Name)'."
        }

        $inputFields = [ordered]@{
            channelId = $channelId
            text = $text
            assets = @()
            metadata = $metadata
            mode = $mode
            schedulingType = $schedulingType
            saveToDraft = $false
        }
        if ($mode -ceq "customScheduled") {
            $inputFields["dueAt"] = $dueAt
        }
        $postInput = [pscustomobject]$inputFields
    }

    $posts += [pscustomobject][ordered]@{
        platform = $definition.Name
        service = $definition.Service
        enabled = $enabled
        supported = $definition.Supported
        channel_id = $channelId
        due_at = $dueAt
        text = $text
        raw_characters = $text.Length
        counted_characters = $countedCharacters
        preview_required = $definition.Supported
        preview_metadata_path = if ($definition.PreviewType) { "metadata.$($definition.PreviewType).linkAttachment" } else { $null }
        input = $postInput
    }
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
    throw "Buffer output must be outside the Git repository: $outputFullPath"
}
New-Item -ItemType Directory -Path $outputFullPath -Force | Out-Null

$enabledPosts = @($posts | Where-Object { $_.enabled })
$planPath = Join-Path $outputFullPath "buffer-plan.json"
$requestPath = Join-Path $outputFullPath "buffer-codex-request.txt"
$reportPath = Join-Path $outputFullPath "buffer-release-report.json"

$plan = [ordered]@{
    schema_version = 2
    generated_utc = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
    release_name = $releaseName
    article_title = $articleTitle
    production_url = $productionUrl
    organization_id = $organizationId
    timezone = $timezone
    mode = $mode
    scheduling_type = $schedulingType
    link_preview = [ordered]@{
        title = $previewTitle
        description = $previewDescription
        thumbnail_url = $previewThumbnailUrl
    }
    ready_to_publish = ($enabledPosts.Count -gt 0)
    enabled_post_count = $enabledPosts.Count
    posts = $posts
    write_performed = $false
}
Write-Utf8NoBom -Path $planPath -Content ($plan | ConvertTo-Json -Depth 15)

$actionVerb = if ($mode -ceq "shareNow") { "PUBLISH" } else { "SCHEDULE" }
$confirmationPhrase = "$actionVerb $releaseName"
$request = @"
Use Buffer MCP to process the validated VCF Insider plan at:
$planPath

This is a two-turn guarded operation. Treat every link preview as mandatory.

FIRST TURN - READ ONLY:
1. Read buffer-plan.json.
2. Stop if ready_to_publish is false or enabled_post_count is zero.
3. Verify the Buffer organization ID and every enabled channel ID/service mapping with read-only operations.
4. Stop if any enabled post is not LinkedIn or Facebook, or if its input metadata linkAttachment is missing, null, or incomplete.
5. Verify each linkAttachment URL, title, description, and thumbnail URL exactly against plan.link_preview and production_url.
6. Check Buffer for an existing post with the same channelId and text. For a scheduled post, also match dueAt. If an exact duplicate exists, report it and do not create another. If duplicate checking cannot be completed, stop.
7. Display every exact enabled input, including channelId, text, mode, dueAt when present, and the complete platform linkAttachment.
8. Ask me to type this exact phrase: $confirmationPhrase
9. Do not call execute_mutation or any other write tool during the first turn.

SECOND TURN - ONLY AFTER THE EXACT PHRASE:
1. Re-read the unchanged plan and repeat the organization, channel, duplicate, timing, and linkAttachment checks.
2. Create enabled posts sequentially with mcp__buffer__execute_mutation using this mutation and each post.input as variables.input:

mutation CreatePost(`$input: CreatePostInput!) {
  createPost(input: `$input) {
    __typename
    ... on PostActionSuccess {
      post {
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
        createdAt
        updatedAt
      }
    }
  }
}

3. After each mutation, retrieve the new post with a read-only Buffer operation.
4. Verify channelId, text, status, shareMode, schedulingType, dueAt when scheduled, and the platform linkAttachment against the plan.
5. A non-null linkAttachment is mandatory. Verify its URL, title, description, and thumbnail URL exactly. If verification fails after creation, report the created post ID and stop. Do not delete, recreate, or automatically retry it.
6. Report each returned post ID, status, publication or schedule time, public URL when available, and verified preview thumbnail URL.
7. Do not modify or delete any other Buffer content.
"@
Write-Utf8NoBom -Path $requestPath -Content $request

$report = [ordered]@{
    schema_version = 2
    generated_utc = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
    release_name = $releaseName
    mode = "buffer-plan-only"
    buffer_mode = $mode
    ready_to_publish = ($enabledPosts.Count -gt 0)
    enabled_post_count = $enabledPosts.Count
    preview_required = $true
    preview_title = $previewTitle
    preview_thumbnail_url = $previewThumbnailUrl
    confirmation_phrase = $confirmationPhrase
    plan_path = $planPath
    codex_request_path = $requestPath
    write_performed = $false
}
Write-Utf8NoBom -Path $reportPath -Content ($report | ConvertTo-Json -Depth 8)

Write-Host "`nBuffer publication plan completed." -ForegroundColor Green
Write-Host "Article:  $articleTitle"
Write-Host "Enabled:  $($enabledPosts.Count)"
Write-Host "Mode:     $mode"
Write-Host "Preview:  required for every enabled post"
Write-Host "Plan:     $planPath"
Write-Host "Request:  $requestPath"
Write-Host "Report:   $reportPath"
if ($enabledPosts.Count -eq 0) {
    Write-Host "No channels are enabled. Enable LinkedIn or Facebook and configure due_at when using customScheduled." -ForegroundColor Yellow
}
Write-Host "Buffer:   plan only; nothing was created, scheduled, modified, or deleted"
