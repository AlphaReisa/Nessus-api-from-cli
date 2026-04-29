# --- configuration ---
$url = "https://127.0.0.1:8834"
$user = "admin"
$pass = "admin"
$scan_id = "5"

# --- robust ssl bypass for ssh/n8n sessions ---
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$trust_all_code = @'
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAll : ICertificatePolicy {
        public bool CheckValidationResult(ServicePoint s, X509Certificate c, WebRequest r, int p) { return true; }
    }
'@

# we use try/catch to add the type only if it doesn't exist
try {
    Add-Type -TypeDefinition $trust_all_code -ErrorAction SilentlyContinue
} catch {}

[Net.ServicePointManager]::CertificatePolicy = New-Object TrustAll

try {
    # 1. get dynamic api token
    # -UseBasicParsing is mandatory for SSH sessions
    $js_data = Invoke-WebRequest -Uri "$url/nessus6.js" -UseBasicParsing -ErrorAction Stop
    $api_token = ([regex]::Match($js_data.Content, '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}')).Value

    if (-not $api_token) { throw "api token not found" }

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
        "Accept" = "application/json"
    }

    $response = Invoke-RestMethod -Method Post -Uri "$url/scans/$scan_id/launch" -Headers $headers
    Write-Host "$($response.scan_uuid)" -ForegroundColor Green

} catch {
    # output full error details for debugging in n8n
    Write-Host "error: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.InnerException) {
        Write-Host "inner error: $($_.Exception.InnerException.Message)"
    }
    exit 1
}
