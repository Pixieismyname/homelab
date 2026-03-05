param(
    [string]$Domain = "aegirshus",
    [ValidateSet("http", "https")]
    [string]$Scheme = "http",
    [int]$TimeoutSec = 8,
    [switch]$IgnoreTlsErrors,
    [switch]$ShowBodyPreview
)

$ErrorActionPreference = "Stop"

if ($IgnoreTlsErrors -and $Scheme -eq "https") {
    try {
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
    } catch {
    }
}

$checks = @(
    @{ Name = "Proxy"; Host = "proxy"; Path = "/"; Method = "GET"; Expected = @(200); ApiHint = "Caddy landing page" },
    @{ Name = "Homepage"; Host = "home"; Path = "/"; Method = "GET"; Expected = @(200); ApiHint = "Homepage UI root" },
    @{ Name = "DNS (AdGuard API)"; Host = "dns"; Path = "/control/status"; Method = "GET"; Expected = @(200, 401, 403); ApiHint = "AdGuard API endpoint" },
    @{ Name = "Portainer API"; Host = "portainer"; Path = "/api/status"; Method = "GET"; Expected = @(200); ApiHint = "Portainer status API" },
    @{ Name = "Jellyfin API"; Host = "jellyfin"; Path = "/System/Info/Public"; Method = "GET"; Expected = @(200); ApiHint = "Jellyfin public info API" },
    @{ Name = "Paperless API"; Host = "paperless"; Path = "/api/"; Method = "GET"; Expected = @(200, 301, 302, 401, 403); ApiHint = "Paperless API root" },
    @{ Name = "Home Assistant API"; Host = "ha"; Path = "/api/"; Method = "GET"; Expected = @(200, 401); ApiHint = "HA API root" },
    @{ Name = "Prowlarr API"; Host = "prowlarr"; Path = "/ping"; Method = "GET"; Expected = @(200); ApiHint = "Arr ping endpoint" },
    @{ Name = "Sonarr API"; Host = "sonarr"; Path = "/ping"; Method = "GET"; Expected = @(200); ApiHint = "Arr ping endpoint" },
    @{ Name = "Radarr API"; Host = "radarr"; Path = "/ping"; Method = "GET"; Expected = @(200); ApiHint = "Arr ping endpoint" },
    @{ Name = "Bazarr API"; Host = "bazarr"; Path = "/"; Method = "GET"; Expected = @(200); ApiHint = "Bazarr web/API root" },
    @{ Name = "qBittorrent API"; Host = "qbittorrent"; Path = "/api/v2/app/version"; Method = "GET"; Expected = @(200, 401, 403); ApiHint = "qBittorrent API version" },
    @{ Name = "FlareSolverr API"; Host = "flaresolverr"; Path = "/"; Method = "GET"; Expected = @(200, 405); ApiHint = "FlareSolverr entrypoint" }
)

function Write-Banner {
    param([string]$Text)
    $line = "=" * 78
    Write-Host $line -ForegroundColor DarkCyan
    Write-Host ("  " + $Text) -ForegroundColor Cyan
    Write-Host $line -ForegroundColor DarkCyan
}

function Test-ClientEndpoint {
    param(
        [hashtable]$Check,
        [string]$Domain,
        [string]$Scheme,
        [int]$TimeoutSec,
        [bool]$ShowBodyPreview
    )

    $fqdn = "{0}.{1}" -f $Check.Host, $Domain
    $uri = "{0}://{1}{2}" -f $Scheme, $fqdn, $Check.Path

    $dnsOk = $false
    $resolved = ""
    try {
        $dns = Resolve-DnsName -Name $fqdn -Type A -ErrorAction Stop | Select-Object -First 1
        $dnsOk = $true
        $resolved = $dns.IPAddress
    } catch {
        $dnsOk = $false
    }

    $httpOk = $false
    $statusCode = $null
    $latencyMs = $null
    $preview = ""
    $errorText = ""

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $resp = Invoke-WebRequest -Uri $uri -Method $Check.Method -TimeoutSec $TimeoutSec -MaximumRedirection 0 -ErrorAction Stop
        $statusCode = [int]$resp.StatusCode
        $sw.Stop()
        $latencyMs = [int]$sw.ElapsedMilliseconds

        if ($Check.Expected -contains $statusCode) {
            $httpOk = $true
        }

        if ($ShowBodyPreview -and $resp.Content) {
            $preview = ($resp.Content -replace "\s+", " ")
            if ($preview.Length -gt 100) {
                $preview = $preview.Substring(0, 100) + "..."
            }
        }
    } catch {
        $sw.Stop()
        $latencyMs = [int]$sw.ElapsedMilliseconds

        if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
            $statusCode = [int]$_.Exception.Response.StatusCode
            if ($Check.Expected -contains $statusCode) {
                $httpOk = $true
            } else {
                $errorText = $_.Exception.Message
            }
        } else {
            $errorText = $_.Exception.Message
        }
    }

    $ok = $dnsOk -and $httpOk

    [PSCustomObject]@{
        Name       = $Check.Name
        Endpoint   = $uri
        ApiHint    = $Check.ApiHint
        Dns        = if ($dnsOk) { "OK ($resolved)" } else { "FAIL" }
        HttpStatus = if ($statusCode) { $statusCode } else { "N/A" }
        LatencyMs  = $latencyMs
        Result     = if ($ok) { "PASS" } else { "FAIL" }
        Error      = $errorText
        Preview    = $preview
    }
}

Write-Banner "Skirnir Client Healthcheck"
Write-Host ("Target domain: {0}" -f $Domain) -ForegroundColor Gray
Write-Host ("Scheme: {0}" -f $Scheme) -ForegroundColor Gray
Write-Host ("Timeout: {0}s" -f $TimeoutSec) -ForegroundColor Gray
Write-Host ""

$results = @()
foreach ($check in $checks) {
    Write-Host ("[PENDING] {0}" -f $check.Name) -ForegroundColor DarkYellow
    $result = Test-ClientEndpoint -Check $check -Domain $Domain -Scheme $Scheme -TimeoutSec $TimeoutSec -ShowBodyPreview:$ShowBodyPreview
    $results += $result

    if ($result.Result -eq "PASS") {
        Write-Host ("[SUCCESS] {0}  HTTP {1}  {2}ms" -f $result.Name, $result.HttpStatus, $result.LatencyMs) -ForegroundColor Green
    } else {
        Write-Host ("[FAILURE] {0}  DNS={1}  HTTP={2}" -f $result.Name, $result.Dns, $result.HttpStatus) -ForegroundColor Red
        if ($result.Error) {
            Write-Host ("          {0}" -f $result.Error) -ForegroundColor DarkRed
        }
    }
}

Write-Host ""
Write-Banner "Summary"

$pass = ($results | Where-Object { $_.Result -eq "PASS" }).Count
$fail = ($results | Where-Object { $_.Result -eq "FAIL" }).Count

$summary = $results | Select-Object Name, Result, Dns, HttpStatus, LatencyMs, ApiHint
$summary | Format-Table -AutoSize

Write-Host ""
if ($fail -eq 0) {
    Write-Host ("✔ All checks passed ({0}/{0})" -f $pass) -ForegroundColor Green
    exit 0
}

Write-Host ("✖ Checks failed: {0} failed, {1} passed" -f $fail, $pass) -ForegroundColor Red
Write-Host "Failed endpoints:" -ForegroundColor Red
$results | Where-Object { $_.Result -eq "FAIL" } | ForEach-Object {
    Write-Host ("- {0} -> {1}" -f $_.Name, $_.Endpoint) -ForegroundColor DarkRed
}

exit 1
