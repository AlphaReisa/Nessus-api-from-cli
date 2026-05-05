# --- configuration ---
$url = "https://127.0.0.1:8834"
$user = "admin"
$pass = "admin"
$scan_id = "6"  # El ID del escaneo

$agent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"

try {
    # 1. Obtener API Token dinámico
    $js_data = curl.exe -s -k -H "User-Agent: $agent" "$url/nessus6.js"
    $api_token = ([regex]::Match($js_data, '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}')).Value
    if (-not $api_token) { throw "could not retrieve api token" }

    # 2. Login (Arquitectura de tubería)
    $raw_json = @{ username = $user; password = $pass } | ConvertTo-Json -Compress
    
    $session_data = $raw_json | curl.exe -s -k -X POST "$url/session" `
        -H "Content-Type: application/json" `
        -H "User-Agent: $agent" `
        -H "Connection: close" `
        -d "@-"
    
    $token = ($session_data | ConvertFrom-Json -ErrorAction SilentlyContinue).token
    if (-not $token) { throw "login failed" }

    # 3. Enviar comando RESUME al endpoint /scans/{id}/resume
    $response = curl.exe -s -k -X POST "$url/scans/$scan_id/resume" `
        -H "X-Cookie: token=$token" `
        -H "X-API-Token: $api_token" `
        -H "Accept: application/json" `
        -H "User-Agent: $agent"

    Write-Host "status: resumed"
    Write-Host "$response"

} catch {
    Write-Host "error: $($_.Exception.Message)"
    exit 1
}