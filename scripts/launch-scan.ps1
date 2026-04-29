# --- configuration ---
$url = "https://localhost:8834"
$user = "admin"
$pass = "admin"
$scan_id = "5"

# 1. get dynamic api token from nessus js file
try {
    $js_data = Invoke-WebRequest -Uri "$url/nessus6.js" -SkipCertificateCheck -ErrorAction Stop
    $api_token = ([regex]::Match($js_data.Content, '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}')).Value
} catch {
    Write-Host "error: could not connect to nessus or retrieve js file." -ForegroundColor Red
    return
}

if (-not $api_token) {
    Write-Host "error: api token not found in nessus6.js" -ForegroundColor Yellow
    return
}

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

try {
    $response = Invoke-RestMethod -Method Post -Uri "$url/scans/$scan_id/launch" -Headers $headers -SkipCertificateCheck
    Write-Host "success: scan $scan_id launched. uuid: $($response.scan_uuid)" -ForegroundColor Green
} catch {
    Write-Host "error: failed to launch scan. check if id $scan_id exists." -ForegroundColor Red
}
