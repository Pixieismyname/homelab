# Transfer downloads from local Windows machine to Tyr USB
$sourcePath = "E:\MEDIA\Downloads"
$pw = (Get-Content -Raw .\secrets\tyr).Trim()
$plinkExe = "C:\Program Files\PuTTY\plink.exe"
$pscpExe = "C:\Program Files\PuTTY\pscp.exe"
$sshHost = "tyr@tyr.aegirshus"

Write-Host "Starting transfer of downloads to Tyr USB..." -ForegroundColor Cyan

# Get all files (exclude incomplete folder for now)
$movieFiles = @()
$tvFiles = @()

# Root level movies
Get-ChildItem -Path $sourcePath -MaxDepth 1 -File | ForEach-Object {
    $movieFiles += $_
}

# Root level folders (movies)
Get-ChildItem -Path $sourcePath -MaxDepth 1 -Directory | Where-Object { $_.Name -ne "incomplete" -and $_.Name -ne "tv" } | ForEach-Object {
    $movieFiles += $_
}

# TV shows in tv subfolder
Get-ChildItem -Path "$sourcePath\tv" -Recurse -File | ForEach-Object {
    $tvFiles += $_
}

Write-Host "Found $($movieFiles.Count) movie items and $($tvFiles.Count) TV files" -ForegroundColor Yellow

# Transfer movies
if ($movieFiles.Count -gt 0) {
    Write-Host "`nTransferring movies..." -ForegroundColor Cyan
    foreach ($item in $movieFiles) {
        $sourceFull = $item.FullName
        $fileName = $item.Name
        Write-Host "Transferring movie: $fileName"
        
        if ($item.PSIsContainer) {
            # Folder
            & $pscpExe -r -batch -pw $pw "$sourceFull\*" "${sshHost}:/mnt/torrentdownloads/movies/$fileName/"
        } else {
            # File
            & $pscpExe -batch -pw $pw "$sourceFull" "${sshHost}:/mnt/torrentdownloads/movies/"
        }
    }
}

# Transfer TV shows
if ($tvFiles.Count -gt 0) {
    Write-Host "`nTransferring TV shows..." -ForegroundColor Cyan
    foreach ($item in $tvFiles) {
        $sourceFull = $item.FullName
        Write-Host "Transferring: $($item.Name)"
        & $pscpExe -batch -pw $pw "$sourceFull" "${sshHost}:/mnt/torrentdownloads/tv/"
    }
}

Write-Host "`nTransfer complete!" -ForegroundColor Green
