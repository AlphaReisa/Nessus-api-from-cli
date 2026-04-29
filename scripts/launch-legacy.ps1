# --- configuration ---
$url = "https://localhost:8834"
$user = "admin"
$pass = "admin"
$scan_id = "5"

# --- legacy ssl bypass (required for ps 5.1) ---
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$policy_code = @'
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAll : ICertificatePolicy {
    public bool CheckValidationResult(ServicePoint s, X509Certificate c, WebRequest r, int p) { return true; }
}
'@
if (-not ([System.Net.ServicePointManager]::CertificatePolicy -is [TrustAll])) {
    Add-Type -TypeDefinition $policy_code
    [Net.ServicePointManager]::CertificatePolicy = New-Object TrustAll
}

# 1. get dynamic api token
try {
    $js_data = Invoke-WebRequest -Uri "$url/nessus6.js" -ErrorAction Stop
    $api_token = ([regex]::Match($js_data.Content, '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}')).Value
} catch {
    Write-Host "error: could not connect to nessus." -ForegroundColor Red
    return
}

# 2. login
$auth_body = @{ username = $user; password = $pass } | ConvertTo-Json
$session = Invoke-RestMethod -Method Post -Uri "$url/session" -ContentType "application/json" -Body $auth_body
$token = $session.token

# 3. launch scan
$headers = @{
    "X-Cookie" = "token=$token"
    "X-API-Token" = "$api_token"
    "Origin" = "$url"
    "Referer" = "$url/"
}

try {
    $response = Invoke-RestMethod -Method Post -Uri "$url/scans/$scan_id/launch" -Headers $headers
    Write-Host "success: scan $scan_id launched. uuid: $($response.scan_uuid)" -ForegroundColor Green
} catch {
    Write-Host "error: failed to launch scan." -ForegroundColor Red
}
