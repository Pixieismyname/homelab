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
    $oldName = $folder.Name
    $newName = $oldName -replace '^\[[^\]]*\]', ''

    if ($newName -eq $oldName) {
        continue
    }

    if ([string]::IsNullOrWhiteSpace($newName)) {
        Write-Warning "Skipping '$($folder.FullName)': new name would be empty."
        continue
    }

    $targetPath = Join-Path -Path $folder.Parent.FullName -ChildPath $newName
    if (Test-Path -LiteralPath $targetPath) {
        Write-Warning "Skipping '$($folder.FullName)': target already exists '$targetPath'."
        continue
    }

    if ($PSCmdlet.ShouldProcess($folder.FullName, "Rename to '$newName'")) {
        Rename-Item -LiteralPath $folder.FullName -NewName $newName
        Write-Host "Renamed: '$oldName' -> '$newName'"
    }
}
