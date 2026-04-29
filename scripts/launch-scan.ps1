# --- configuration ---
$url = "https://127.0.0.1:8834"
$user = "admin"
$pass = "admin"
$scan_id = "6"

$agent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"

try {
    # 1. get dynamic api token
    $js_data = curl.exe -s -k -H "User-Agent: $agent" "$url/nessus6.js"
    $api_token = ([regex]::Match($js_data, '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}')).Value
    if (-not $api_token) { throw "could not retrieve api token" }

    # 2. login (JSON por tubería, con "@-" entre comillas para evitar el ParserError)
    $raw_json = @{ username = $user; password = $pass } | ConvertTo-Json -Compress

    $token = $null
    $attempts = 0

    while (-not $token -and $attempts -lt 5) {
        $attempts++
        
        $session_data = $raw_json | curl.exe -s -k -X POST "$url/session" `
            -H "Content-Type: application/json" `
            -H "User-Agent: $agent" `
            -H "Connection: close" `
            -d "@-"
        
        $token = ($session_data | ConvertFrom-Json -ErrorAction SilentlyContinue).token
        if (-not $token) { Start-Sleep -Seconds 1 }
    }

    if (-not $token) { throw "login failed after $attempts attempts. check credentials." }

    # 3. launch scan
    $response = curl.exe -s -k -X POST "$url/scans/$scan_id/launch" `
        -H "X-Cookie: token=$token" `
        -H "X-API-Token: $api_token" `
        -H "Origin: $url" `
        -H "Referer: $url/" `
        -H "User-Agent: $agent" `
        -H "Accept: application/json"
    
    $uuid = ($response | ConvertFrom-Json -ErrorAction SilentlyContinue).scan_uuid
    if ($uuid) { Write-Host "$uuid" } 
    else { throw "scan launch failed" }

} catch {
    Write-Host "error: $($_.Exception.Message)"
    exit 1
}
