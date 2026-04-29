# Nessus-api-from-cli

![nessus](https://img.shields.io/badge/nessus-api-blue) ![powershell](https://img.shields.io/badge/powershell-5.1%20%7C%207+-blue) ![license](https://img.shields.io/badge/license-mit-green)

This repository contains a standalone powershell script to launch **tenable nessus** scans directly from the command line (cmd or powershell). 

Unlike other scripts, this tool automatically handles dynamic `x-api-token` extraction and is fully compatible with restricted environments running **powershell 5.1**.

## Features

* **No installation required:** no need for `cargo`, `python`, or external dependencies.
* **Dynamic extraction:** automatically retrieves the `x-api-token` from nessus internal files (`nessus6.js`).
* **Full compatibility:** works on both legacy powershell 5.1 (standard windows) and powershell 7+.
* **SSL bypass:** ignores self-signed certificate errors on `localhost`.
* **Automation ready:** ideal for windows task scheduler or CI/CD pipelines.

---

## Prerequisites

1.  **Running nessus instance:** the service must be active at `https://localhost:8834`.
2.  **Credentials:** username and password with valid permissions to launch scans.
3.  **Scan id:** you must identify the specific id of the scan you wish to launch.

---

## Usage from PowerShell

```powershell
# --- configuration ---
$url = "https://localhost:8834"
$user = "admin"
$pass = "admin"
$scan_id = "5"

# 1. get dynamic api token from nessus js file
$js_data = Invoke-WebRequest -Uri "$url/nessus6.js" -SkipCertificateCheck
$api_token = ([regex]::Match($js_data.Content, '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}')).Value

# 2. login to obtain session token
$auth_body = @{ username = $user; password = $pass } | ConvertTo-Json
$session = Invoke-RestMethod -Method Post -Uri "$url/session" -ContentType "application/json" -Body $auth_body -SkipCertificateCheck
$token = $session.token

# 3. launch scan with required security headers
$headers = @{
    "X-Cookie" = "token=$token"
    "X-API-Token" = "$api_token"
    "Origin" = "$url"
    "Referer" = "$url/"
    "Accept" = "application/json"
}

$response = Invoke-RestMethod -Method Post -Uri "$url/scans/$scan_id/launch" -Headers $headers -SkipCertificateCheck
Write-Host "scan launched successfully. uuid: $($response.scan_uuid)" -ForegroundColor Green
```
---

## Usage from CMD (Command prompt / powershell 5.1 legacy)

This "one-liner" is designed to work on older systems where `-skipcertificatecheck` is not available. run this from **CMD**:

```cmd
powershell -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $policy = Add-Type -TypeDefinition 'using System.Net; using System.Security.Cryptography.X509Certificates; public class TrustAll : ICertificatePolicy { public bool CheckValidationResult(ServicePoint s, X509Certificate c, WebRequest r, int p) { return true; } }' -PassThru; [Net.ServicePointManager]::CertificatePolicy = New-Object TrustAll; $u='https://localhost:8834'; $js=(Invoke-WebRequest -Uri \"$u/nessus6.js\").Content; $api=[regex]::Match($js,'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}').Value; $sess=Invoke-RestMethod -Method Post -Uri \"$u/session\" -ContentType 'application/json' -Body '{\"username\":\"admin\",\"password\":\"admin\"}'; $tk=$sess.token; $h=@{'X-Cookie'=\"token=$tk\";'X-API-Token'=\"$api\";'Origin'=\"$u\";'Referer'=\"$u/\"}; $r=Invoke-RestMethod -Method Post -Uri \"$u/scans/5/launch\" -Headers $h; Write-Host 'success - launched uuid: ' $r.scan_uuid -ForegroundColor Green"
```

## Installation
To download the script directly to your user folder without using a browser, run:

```powershell
iwr -useb "[https://raw.githubusercontent.com/AlphaReisa/nessus-api-from-cli/main/scripts/launch-scan.ps1](https://raw.githubusercontent.com/AlphaReisa/nessus-api-from-cli/main/scripts/launch-scan.ps1)" -OutFile "$HOME\launch-scan.ps1"
```

## Troubleshooting

### Error: "Api is not available"
Nessus returns this error if security headers are missing. this script resolves it by providing:
* **x-api-token**: dynamically extracted from the web client.
* **x-cookie**: session token obtained during authentication.
* **origin/referer**: headers used to validate the request source.

### Error in powershell 5.1
If you use the simplified command in ps 5.1, you will encounter an ssl certificate error. please use the compatible version provided in the cmd section, which implements the `icertificatepolicy` interface.

---

## License
This project is licensed under the mit license.

---
**Developed to simplify nessus automation without external dependencies.** 
