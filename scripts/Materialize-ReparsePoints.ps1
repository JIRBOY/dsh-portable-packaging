[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$Source,
  [Parameter(Mandatory = $true)][string]$Destination,
  [string[]]$RelativeRoots = @('home\profiles')
)
$ErrorActionPreference = 'Stop'
$sourceRoot = [System.IO.Path]::GetFullPath($Source).TrimEnd('\')
$destRoot = [System.IO.Path]::GetFullPath($Destination).TrimEnd('\')
if (-not (Test-Path -LiteralPath $sourceRoot)) { throw "Source missing: $sourceRoot" }
if (-not (Test-Path -LiteralPath $destRoot)) { throw "Destination missing: $destRoot" }

$links = @()
foreach ($relativeRoot in $RelativeRoots) {
  $scanRoot = Join-Path $sourceRoot $relativeRoot
  if (-not (Test-Path -LiteralPath $scanRoot)) { continue }
  $links += @(Get-ChildItem -Force -LiteralPath $scanRoot -Recurse -ErrorAction Stop | Where-Object {
    ($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
  })
}
Write-Output "ReparsePointsToMaterialize=$($links.Count)"
foreach ($link in $links) {
  $relative = $link.FullName.Substring($sourceRoot.Length).TrimStart('\')
  $target = Join-Path $destRoot $relative
  $targetParent = Split-Path -Parent $target
  if (-not (Test-Path -LiteralPath $targetParent)) { New-Item -ItemType Directory -Path $targetParent -Force | Out-Null }
  Write-Output "Materialize: $relative ($($link.LinkType))"
  & robocopy.exe $link.FullName $target /E /COPY:DAT /DCOPY:DAT /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
  $code = $LASTEXITCODE
  if ($code -ge 8) { throw "Robocopy failed for $relative with exit $code" }
}
$remaining = @()
foreach ($relativeRoot in $RelativeRoots) {
  $scanRoot = Join-Path $destRoot $relativeRoot
  if (-not (Test-Path -LiteralPath $scanRoot)) { continue }
  $remaining += @(Get-ChildItem -Force -LiteralPath $scanRoot -Recurse -ErrorAction Stop | Where-Object {
    ($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
  })
}
Write-Output "RemainingReparsePoints=$($remaining.Count)"
if ($remaining.Count -gt 0) {
  $remaining | ForEach-Object { Write-Output $_.FullName }
  exit 1
}
Write-Output 'All pnpm directory links were materialized as real directories.'
exit 0
