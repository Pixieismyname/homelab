[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false)]
    [string]$RootPath = "."
)

$ErrorActionPreference = "Stop"

$resolvedRoot = (Resolve-Path -Path $RootPath).Path

$deletedFiles = 0
$deletedFolders = 0
$skippedFolders = 0

$folders = Get-ChildItem -Path $resolvedRoot -Directory -Recurse |
    Sort-Object { $_.FullName.Length } -Descending

foreach ($folder in $folders) {
    $subFolders = Get-ChildItem -LiteralPath $folder.FullName -Directory -Force
    if ($subFolders.Count -gt 0) {
        $skippedFolders++
        continue
    }

    $files = Get-ChildItem -LiteralPath $folder.FullName -File -Force
    if ($files.Count -eq 0) {
        if ($PSCmdlet.ShouldProcess($folder.FullName, "Delete empty folder")) {
            Remove-Item -LiteralPath $folder.FullName -Force -ErrorAction Stop
            Write-Host "Deleted empty folder: '$($folder.FullName)'"
            $deletedFolders++
        }
        continue
    }

    $nonThumbs = $files | Where-Object { $_.Name -ine "Thumbs.db" }
    if ($nonThumbs.Count -gt 0) {
        $skippedFolders++
        continue
    }

    foreach ($file in $files) {
        if ($PSCmdlet.ShouldProcess($file.FullName, "Force delete file")) {
            Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
            Write-Host "Deleted file: '$($file.FullName)'"
            $deletedFiles++
        }
    }

    if ($PSCmdlet.ShouldProcess($folder.FullName, "Delete folder")) {
        Remove-Item -LiteralPath $folder.FullName -Force -ErrorAction Stop
        Write-Host "Deleted folder: '$($folder.FullName)'"
        $deletedFolders++
    }
}

Write-Host ""
Write-Host "Cleanup summary" -ForegroundColor Cyan
Write-Host "Root path: $resolvedRoot"
Write-Host "Deleted files: $deletedFiles"
Write-Host "Deleted folders: $deletedFolders"
Write-Host "Skipped folders: $skippedFolders"
