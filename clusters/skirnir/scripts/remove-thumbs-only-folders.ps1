[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false)]
    [string]$RootPath = "."
)

$ErrorActionPreference = "Stop"

$resolvedRoot = (Resolve-Path -Path $RootPath).Path

$folders = Get-ChildItem -Path $resolvedRoot -Directory -Recurse |
    Sort-Object { $_.FullName.Length } -Descending

foreach ($folder in $folders) {
    $subFolders = Get-ChildItem -LiteralPath $folder.FullName -Directory -Force
    if ($subFolders.Count -gt 0) {
        continue
    }

    $files = Get-ChildItem -LiteralPath $folder.FullName -File -Force
    if ($files.Count -eq 0) {
        continue
    }

    $nonThumbs = $files | Where-Object { $_.Name -ine "Thumbs.db" }
    if ($nonThumbs.Count -gt 0) {
        continue
    }

    foreach ($file in $files) {
        if ($PSCmdlet.ShouldProcess($file.FullName, "Force delete file")) {
            Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
            Write-Host "Deleted file: '$($file.FullName)'"
        }
    }

    if ($PSCmdlet.ShouldProcess($folder.FullName, "Delete folder")) {
        Remove-Item -LiteralPath $folder.FullName -Force -ErrorAction Stop
        Write-Host "Deleted folder: '$($folder.FullName)'"
    }
}
