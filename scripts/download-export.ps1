param (
    [Parameter(Mandatory=$true)]
    [string]$export_token,
    [Parameter(Mandatory=$false)]
    [string]$output_dir = "C:\Users\nessus\Documents\reportes"
)

# --- configuration ---
$url = "https://127.0.0.1:8834"
$user = "admin"
$pass = "admin"

$agent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"

# Crear la carpeta de reportes si no existe
if (-not (Test-Path -Path $output_dir)) {
    New-Item -ItemType Directory -Path $output_dir | Out-Null
}

$output_path = Join-Path $output_dir "scan_report_$export_token.pdf"

try {
    # 1. Obtener API Token dinámico
    $js_data = curl.exe -s -k -H "User-Agent: $agent" "$url/nessus6.js"
    $api_token = ([regex]::Match($js_data, '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}')).Value
    if (-not $api_token) { throw "could not retrieve api token" }

    # 2. Login
    $raw_json = @{ username = $user; password = $pass } | ConvertTo-Json -Compress
    $session_data = $raw_json | curl.exe -s -k -X POST "$url/session" `
        -H "Content-Type: application/json" `
        -H "User-Agent: $agent" `
        -H "Connection: close" `
        -d "@-"
    
    $token = ($session_data | ConvertFrom-Json -ErrorAction SilentlyContinue).token
    if (-not $token) { throw "login failed" }

    # 3. Descargar el archivo binario
    curl.exe -k -X GET "$url/tokens/$export_token/download" `
        -H "X-Cookie: token=$token" `
        -H "X-API-Token: $api_token" `
        -H "User-Agent: $agent" `
        -o $output_path

    Write-Host "$output_path"

} catch {
    Write-Host "error: $($_.Exception.Message)"
    exit 1
}