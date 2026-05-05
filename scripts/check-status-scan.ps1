param (
    [Parameter(Mandatory=$true)]
    [string]$target_uuid
)

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

    # 2. login (Misma arquitectura de tubería para evitar fallos de comillas)
    $raw_json = @{ username = $user; password = $pass } | ConvertTo-Json -Compress
    
    $session_data = $raw_json | curl.exe -s -k -X POST "$url/session" `
        -H "Content-Type: application/json" `
        -H "User-Agent: $agent" `
        -H "Connection: close" `
        -d "@-"
    
    $token = ($session_data | ConvertFrom-Json -ErrorAction SilentlyContinue).token
    if (-not $token) { throw "login failed during status check" }

    # 3. get scan history
    $details_json = curl.exe -s -k -X GET "$url/scans/$scan_id" `
        -H "X-Cookie: token=$token" `
        -H "X-API-Token: $api_token" `
        -H "User-Agent: $agent"

    $details = $details_json | ConvertFrom-Json
    
    # Buscar el objeto en el historial que coincida con el UUID
    $item = $details.history | Where-Object { $_.uuid -eq $target_uuid }

    if ($null -eq $item) { 
        Write-Host "status: uuid_not_found" 
    } else { 
        # Esto devolverá "completed", "running", "canceled", etc.
        Write-Host "status: $($item.status)" 
    }

} catch {
    Write-Host "error: $($_.Exception.Message)"
    exit 1
}