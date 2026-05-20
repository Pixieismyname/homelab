# Move downloads from E:\MEDIA\Downloads to USB drive K:\

$sourceRoot = "E:\MEDIA\Downloads"
$usbRoot = "K:"

# Create directories on USB if they don't exist
$movieDir = "$usbRoot\movies"
$tvDir = "$usbRoot\tv"
$animeDir = "$usbRoot\anime"

Write-Host "Creating USB directories..."
@($movieDir, $tvDir, $animeDir) | ForEach-Object {
    if (!(Test-Path $_)) {
        New-Item -ItemType Directory -Path $_ -Force | Out-Null
        Write-Host "Created: $_"
    }
}

Write-Host ""
Write-Host "Moving files to USB..."

# Move complete folders from root (movies)
Write-Host ""
Write-Host "[MOVIES] Moving root-level movie folders..."
Get-ChildItem -Path $sourceRoot -Directory | Where-Object { $_.Name -ne "incomplete" -and $_.Name -ne "tv" -and $_.Parent.FullName -eq $sourceRoot } | ForEach-Object {
    Write-Host "  Moving: $($_.Name)"
    Move-Item -Path $_.FullName -Destination $movieDir -Force
}

# Move root-level files (movies)
Write-Host ""
Write-Host "[MOVIES] Moving root-level files..."
Get-ChildItem -Path $sourceRoot -File | Where-Object { $_.Directory.FullName -eq $sourceRoot } | ForEach-Object {
    Write-Host "  Moving: $($_.Name)"
    Move-Item -Path $_.FullName -Destination $movieDir -Force
}

# Move TV shows
Write-Host ""
Write-Host "[TV] Moving TV shows from tv folder..."
Get-ChildItem -Path "$sourceRoot\tv" -Directory | ForEach-Object {
    Write-Host "  Moving: $($_.Name)"
    Move-Item -Path $_.FullName -Destination $tvDir -Force
}

# Move individual TV files
Get-ChildItem -Path "$sourceRoot\tv" -File | ForEach-Object {
    Write-Host "  Moving: $($_.Name)"
    Move-Item -Path $_.FullName -Destination $tvDir -Force
}

# Move anime from incomplete if it exists
if (Test-Path "$sourceRoot\incomplete") {
    Write-Host ""
    Write-Host "[ANIME] Moving anime from incomplete folder..."
    
    if (Test-Path "$sourceRoot\incomplete\anime") {
        Get-ChildItem -Path "$sourceRoot\incomplete\anime" -Recurse -File | ForEach-Object {
            Write-Host "  Moving: $($_.Name)"
            Move-Item -Path $_.FullName -Destination $animeDir -Force
        }
    }
}

Write-Host ""
Write-Host "Transfer complete!"
Write-Host ""
Write-Host "Final structure on K:"
Get-ChildItem -Path $usbRoot -Recurse | Select-Object FullName
