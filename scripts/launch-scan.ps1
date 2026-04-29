# --- configuration ---
$url = "https://127.0.0.1:8834"
$user = "admin"
$pass = "admin"
$scan_id = "5"

# force tls 1.2 for ssh/remote sessions
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# robust ssl bypass (fixes 'could not establish trust relationship' in ssh)
$trust_all_code = @'
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAll : ICertificatePolicy {
        public bool CheckValidationResult(ServicePoint s, X509Certificate c, WebRequest r, int p) { return true; }
    }
'@
try {
    Add-Type -TypeDefinition $trust_all_code -ErrorAction SilentlyContinue
} catch {}
[Net.ServicePointManager]::CertificatePolicy = New-Object TrustAll

try {
    # 1. get dynamic api token from nessus js file
    # we use -UseBasicParsing because ssh sessions don't have access to internet explorer engine
    $js_data = Invoke-WebRequest -Uri "$url/nessus6.js" -UseBasicParsing -ErrorAction Stop
    $api_token = ([regex]::Match($js_data.Content, '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}')).Value

    if (-not $api_token) { throw "api token not found in nessus6.js" }

    # 2. login to obtain session token
    $auth_body = @{ username = $user; password = $pass } | ConvertTo-Json
    $session = Invoke-RestMethod -Method Post -Uri "$url/session" -ContentType "application/json" -Body $auth_body
    $token = $session.token

    # 3. launch scan with required security headers
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
    Write-Host "error: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.InnerException) {
        Write-Host "inner error: $($_.Exception.InnerException.Message)"
    }
    exit 1
}
