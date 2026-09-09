# VCF Insider XenForo API Runbook

This document records the working API access pattern for the VCF Insider
Community so it does not have to be rediscovered later.

Forum:

https://community.vcfinsider.com/

## Important security rules

- Never commit an API key to this repository.
- Never paste an API key into ChatGPT, tickets, logs, screenshots, or documentation.
- Enter the key interactively when testing from PowerShell.
- Prefer the normal permissions of the intended XenForo account.
- Do not use `api_bypass_permissions=1` unless there is a specific,
  reviewed reason to do so.
- Verify the effective XenForo user with a read-only request before
  performing any write operation.

## API route on this installation

Confirmed September 9, 2026.

The normal XenForo API form:

    https://community.vcfinsider.com/api/...

does not currently route through XenForo on this server. Apache returns
an HTML 404 before XenForo sees the request.

The working API route is:

    https://community.vcfinsider.com/index.php/api/...

Example:

    https://community.vcfinsider.com/index.php/api/me/

Do not change XenForo friendly-URL or Apache rewrite settings merely to
make `/api/...` work. The `index.php/api/...` route is currently known
to work.

## Confirming that the API route works

This test does not require an API key:

```powershell
curl.exe -i https://community.vcfinsider.com/index.php/api/auth
```

A request that reaches XenForo should return JSON similar to:

```json
{
  "errors": [
    {
      "code": "no_api_key_in_request",
      "message": "No API key was included in the request."
    }
  ]
}
```

An Apache HTML `404 Not Found` means the request did not reach XenForo.

## Safely loading the API key in PowerShell

Do not assign the API key directly in a script or command history.

```powershell
$secureKey = Read-Host "Enter XenForo API key" -AsSecureString
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureKey)
$key = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
```

Always clear it afterward:

```powershell
[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
$key = $null
$secureKey = $null
```

## Read-only API-key test

```powershell
$secureKey = Read-Host "Enter XenForo API key" -AsSecureString
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureKey)
$key = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)

try {
    $headers = @{
        "XF-Api-Key" = $key
    }

    Invoke-RestMethod `
        -Uri "https://community.vcfinsider.com/index.php/api/me/" `
        -Headers $headers `
        -Method Get |
        ConvertTo-Json -Depth 8
}
finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    $key = $null
    $secureKey = $null
}
```

## Current observed API-user behavior

The current API key was successfully accepted by XenForo.

Calling `/me/` without specifying an acting user returned:

```json
{
  "me": {
    "user_id": 0,
    "username": ""
  }
}
```

That is the XenForo guest context.

This behavior is consistent with a super-user-style API key where the
effective user must be supplied separately. Confirm the key type before
changing its scopes or using it for broader automation.

## Confirmed XenForo identities

Confirmed September 9, 2026:

- `megsadmin` - user ID `1`
- `VCF Insider` - user ID `4`

The browser/admin session is logged in as `megsadmin`, while the existing
public forum content is authored by the separate `VCF Insider` account.

The API should act as the public VCF Insider account by sending:

```powershell
"XF-Api-User" = "4"
```

A read-only `/me/` request with `XF-Api-User: 4` was verified successfully.
The response confirmed:

- `user_id`: `4`
- `username`: `VCF Insider`
- `is_staff`: `true`
- `user_title`: `Administrator`
- `message_count`: `13`

## Acting as the VCF Insider account

Use the confirmed VCF Insider user ID in the request headers:

```powershell
$headers = @{
    "XF-Api-Key"  = $key
    "XF-Api-User" = "4"
}
```

Then verify the identity before any write operation:

```powershell
Invoke-RestMethod `
    -Uri "https://community.vcfinsider.com/index.php/api/me/" `
    -Headers $headers `
    -Method Get |
    ConvertTo-Json -Depth 8
```

Do not continue to a write operation unless the response identifies:

```text
user_id: 4
username: VCF Insider
```

## Required workflow before creating forum content

1. Verify the API route.
2. Load the API key securely.
3. Verify the effective XenForo user.
4. Enumerate existing forums/nodes and threads.
5. Check for duplicate or overlapping discussions.
6. Review proposed thread title, body, and destination forum.
7. Obtain Chris's explicit approval for the forum write.
8. Create the thread.
9. Read the created thread back from XenForo and record its canonical URL.
10. Only then update any VCF Insider article link that should point to it.

Forum writes and repository writes are separate approval actions.

## Current status

Confirmed:

- XenForo API is enabled.
- The API key currently in use is accepted by XenForo.
- `index.php/api/...` is the working route on this installation.
- `/api/...` currently returns an Apache 404.
- An API call without an acting user currently resolves to guest user ID 0.
- `megsadmin` is XenForo user ID `1`.
- `VCF Insider` is XenForo user ID `4`.
- `XF-Api-User: 4` makes `/me/` resolve to the `VCF Insider` account.
- The `VCF Insider` account reports staff status, Administrator title, and 13 messages.

Still to verify:

- The exact API-key type and scopes.
- The effective forum/thread permissions of the `VCF Insider` account.
- The complete forum/node inventory.
- The complete thread inventory.
- Thread-creation behavior and returned canonical URLs.

Update this runbook as each item is verified.
