[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, HelpMessage="Acción a ejecutar: launch, check-scan, resume, request-export, check-export, download")]
    [ValidateSet("launch", "check-scan", "resume", "request-export", "check-export", "download")]
    [string]$Action,

    [Parameter(Mandatory=$false)]
    [string]$TargetUuid,

    [Parameter(Mandatory=$false)]
    [string]$ExportToken,

    # Parámetros configurables por instancia
    [Parameter(Mandatory=$false)]
    [string]$Url = "https://127.0.0.1:8834",

    [Parameter(Mandatory=$false)]
    [string]$User = "admin",

    [Parameter(Mandatory=$false)]
    [string]$Pass = "admin",

    [Parameter(Mandatory=$false)]
    [string]$ScanId = "6",

    [Parameter(Mandatory=$false)]
    [string]$OutputDir = "C:\Users\nessus\Documents\reportes"
)

# Configuración del agente
$agent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"

# Función para realizar login y obtener tokens
function Get-NessusSession {
    param($Url, $User, $Pass, $Agent)

    # 1. Obtener API Token dinámico
    $js_data = curl.exe -s -k -H "User-Agent: $Agent" "$Url/nessus6.js"
    $api_token = ([regex]::Match($js_data, '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}')).Value
    if (-not $api_token) { throw "could not retrieve api token" }

    # 2. Login
    $raw_json = @{ username = $User; password = $Pass } | ConvertTo-Json -Compress
    $session_data = $raw_json | curl.exe -s -k -X POST "$Url/session" `
        -H "Content-Type: application/json" `
        -H "User-Agent: $Agent" `
        -H "Connection: close" `
        -d "@-"
    
    $token = ($session_data | ConvertFrom-Json -ErrorAction SilentlyContinue).token
    if (-not $token) { throw "login failed" }

    return @{
        Token    = $token
        ApiToken = $api_token
    }
}

try {
    # Iniciar sesión con los parámetros recibidos
    $session = Get-NessusSession -Url $Url -User $User -Pass $Pass -Agent $agent
    $token = $session.Token
    $api_token = $session.ApiToken

    switch ($Action) {
        "launch" {
            $response = curl.exe -s -k -X POST "$Url/scans/$ScanId/launch" `
                -H "X-Cookie: token=$token" `
                -H "X-API-Token: $api_token" `
                -H "Origin: $Url" `
                -H "Referer: $Url/" `
                -H "User-Agent: $Agent" `
                -H "Accept: application/json"
            
            $uuid = ($response | ConvertFrom-Json -ErrorAction SilentlyContinue).scan_uuid
            if ($uuid) { Write-Host "$uuid" } 
            else { throw "scan launch failed" }
        }

        "check-scan" {
            if (-not $TargetUuid) { throw "TargetUuid es obligatorio para check-scan" }
            
            $details_json = curl.exe -s -k -X GET "$Url/scans/$ScanId" `
                -H "X-Cookie: token=$token" `
                -H "X-API-Token: $api_token" `
                -H "User-Agent: $Agent"

            $details = $details_json | ConvertFrom-Json
            $item = $details.history | Where-Object { $_.uuid -eq $TargetUuid }

            if ($null -eq $item) { 
                Write-Host "status: uuid_not_found" 
            } else { 
                Write-Host "status: $($item.status)" 
            }
        }

        "resume" {
            $response = curl.exe -s -k -X POST "$Url/scans/$ScanId/resume" `
                -H "X-Cookie: token=$token" `
                -H "X-API-Token: $api_token" `
                -H "Accept: application/json" `
                -H "User-Agent: $Agent"

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

            $export_response = $export_body | curl.exe -s -k -X POST "$Url/scans/$ScanId/export" `
                -H "X-Cookie: token=$token" `
                -H "X-API-Token: $api_token" `
                -H "Content-Type: application/json" `
                -H "User-Agent: $Agent" `
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
            
            $status_response = curl.exe -s -k -X GET "$Url/tokens/$ExportToken/status" `
                -H "X-Cookie: token=$token" `
                -H "X-API-Token: $api_token" `
                -H "User-Agent: $Agent"

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

            curl.exe -k -X GET "$Url/tokens/$ExportToken/download" `
                -H "X-Cookie: token=$token" `
                -H "X-API-Token: $api_token" `
                -H "User-Agent: $Agent" `
                -o $output_path

            Write-Host "$output_path"
        }
    }
} catch {
    Write-Host "error: $($_.Exception.Message)"
    exit 1
}
