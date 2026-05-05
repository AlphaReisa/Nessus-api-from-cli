[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, HelpMessage="Acción a ejecutar: launch, check-scan, resume, request-export, check-export, download")]
    [ValidateSet("launch", "check-scan", "resume", "request-export", "check-export", "download")]
    [string]$Action,

    [Parameter(Mandatory=$false)]
    [string]$TargetUuid,

    [Parameter(Mandatory=$false)]
    [string]$ExportToken,

    [Parameter(Mandatory=$false)]
    [string]$ScanId = "6",

    [Parameter(Mandatory=$false)]
    [string]$OutputDir = "C:\Users\nessus\Documents\reportes"
)

# --- configuration ---
$url = "https://127.0.0.1:8834"
$user = "admin"
$pass = "admin"
$agent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"

# Función para realizar login y obtener tokens
function Get-NessusSession {
    # 1. Obtener API Token dinámico
    $js_data = curl.exe -s -k -H "User-Agent: $agent" "$url/nessus6.js"
    $api_token = ([regex]::Match($js_data, '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}')).Value
    if (-not$api_token) { throw "could not retrieve api token" }

    # 2. Login
    $raw_json = @{ username = $user; password = $pass } | ConvertTo-Json -Compress
    $session_data = $raw_json | curl.exe -s -k -X POST "$url/session" `
        -H "Content-Type: application/json" `
        -H "User-Agent: $agent" `
        -H "Connection: close" `
        -d "@-"
    
    $token = ($session_data | ConvertFrom-Json -ErrorAction SilentlyContinue).token
    if (-not$token) { throw "login failed" }

    return @{
        Token    = $token
        ApiToken = $api_token
    }
}

try {
    # Iniciar sesión al principio de cada ejecución
    $session = Get-NessusSession
    $token = $session.Token
    $api_token = $session.ApiToken

    switch ($Action) {
        "launch" {
            $response = curl.exe -s -k -X POST "$url/scans/$ScanId/launch" `
                -H "X-Cookie: token=$token" `
                -H "X-API-Token: $api_token" `
                -H "Origin: $url" `
                -H "Referer: $url/" `
                -H "User-Agent: $agent" `
                -H "Accept: application/json"
            
            $uuid = ($response | ConvertFrom-Json -ErrorAction SilentlyContinue).scan_uuid
            if ($uuid) { Write-Host "$uuid" } 
            else { throw "scan launch failed" }
        }

        "check-scan" {
            if (-not $TargetUuid) { throw "TargetUuid es obligatorio para check-scan" }
            
            $details_json = curl.exe -s -k -X GET "$url/scans/$ScanId" `
                -H "X-Cookie: token=$token" `
                -H "X-API-Token: $api_token" `
                -H "User-Agent: $agent"

            $details = $details_json | ConvertFrom-Json
            $item = $details.history | Where-Object { $_.uuid -eq $TargetUuid }

            if ($null -eq $item) { 
                Write-Host "status: uuid_not_found" 
            } else { 
                Write-Host "status: $($item.status)" 
            }
        }

        "resume" {
            $response = curl.exe -s -k -X POST "$url/scans/$ScanId/resume" `
                -H "X-Cookie: token=$token" `
                -H "X-API-Token: $api_token" `
                -H "Accept: application/json" `
                -H "User-Agent: $agent"

            Write-Host "status: resumed"
            Write-Host "$response"
        }

        "request-export" {
            $export_body = @{ 
                format               = "pdf";
                template_id          = 771;
                formattingOptions    = @{};
                csvColumns           = @{};
                extraFilters         = @{
                    host_ids   = @();
                    plugin_ids = @();
                };
                plugin_detail_locale = "en";
            } | ConvertTo-Json -Compress

            $export_response = $export_body | curl.exe -s -k -X POST "$url/scans/$ScanId/export" `
                -H "X-Cookie: token=$token" `
                -H "X-API-Token: $api_token" `
                -H "Content-Type: application/json" `
                -H "User-Agent: $agent" `
                -d "@-"

            $export_token = ($export_response | ConvertFrom-Json -ErrorAction SilentlyContinue).token
            if ($export_token) { 
                Write-Host "$export_token" 
            } else { 
                throw "failed to request export token" 
            }
        }

        "check-export" {
            if (-not $ExportToken) { throw "ExportToken es obligatorio para check-export" }
            
            $status_response = curl.exe -s -k -X GET "$url/tokens/$ExportToken/status" `
                -H "X-Cookie: token=$token" `
                -H "X-API-Token: $api_token" `
                -H "User-Agent: $agent"

            $status = ($status_response | ConvertFrom-Json -ErrorAction SilentlyContinue).status
            if ($status) {
                Write-Host "$status"
            } else {
                Write-Host "unknown"
            }
        }

        "download" {
            if (-not $ExportToken) { throw "ExportToken es obligatorio para descargar" }

            if (-not (Test-Path -Path $OutputDir)) {
                New-Item -ItemType Directory -Path $OutputDir | Out-Null
            }

            $output_path = Join-Path $OutputDir "scan_report_$ExportToken.pdf"

            curl.exe -k -X GET "$url/tokens/$ExportToken/download" `
                -H "X-Cookie: token=$token" `
                -H "X-API-Token: $api_token" `
                -H "User-Agent: $agent" `
                -o $output_path

            Write-Host "$output_path"
        }
    }
} catch {
    Write-Host "error: $($_.Exception.Message)"
    exit 1
}