[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$OutputDirectory,
  [string]$IconFile = '',
  [string]$CscPath = '',
  [switch]$Force
)
$ErrorActionPreference = 'Stop'
$source = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\assets\Launcher.cs'))
$outputDirectoryPath = [System.IO.Path]::GetFullPath($OutputDirectory)
$output = Join-Path $outputDirectoryPath 'DeepSeekHarnessLauncher.exe'
if (-not (Test-Path -LiteralPath $source)) { throw "Launcher source missing: $source" }
if (-not (Test-Path -LiteralPath $outputDirectoryPath)) { New-Item -ItemType Directory -Path $outputDirectoryPath -Force | Out-Null }
if ((Test-Path -LiteralPath $output) -and -not $Force) { throw "Output exists; pass -Force to replace: $output" }

if (-not $CscPath) {
  $csc64 = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
  $csc32 = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe'
  if (Test-Path -LiteralPath $csc64) { $CscPath = $csc64 }
  elseif (Test-Path -LiteralPath $csc32) { $CscPath = $csc32 }
  else { throw 'System C# compiler (csc.exe) not found. This launcher targets Windows built-in .NET Framework 4.8.' }
}
if (-not (Test-Path -LiteralPath $CscPath)) { throw "C# compiler missing: $CscPath" }

$arguments = @(
  '/nologo', '/codepage:65001', '/target:winexe', '/platform:anycpu',
  '/optimize+', '/debug-', ('/out:' + $output), $source,
  '/reference:System.dll', '/reference:System.Core.dll',
  '/reference:System.Windows.Forms.dll', '/reference:System.Drawing.dll'
)
if ($IconFile) {
  $icon = [System.IO.Path]::GetFullPath($IconFile)
  if (-not (Test-Path -LiteralPath $icon)) { throw "Icon file missing: $icon" }
  $arguments = @(('/win32icon:' + $icon)) + $arguments
}

& $CscPath @arguments
if ($LASTEXITCODE -ne 0) { throw "C# compilation failed with exit code $LASTEXITCODE" }
if (-not (Test-Path -LiteralPath $output)) { throw "Compiler did not create $output" }
Write-Output "Built launcher: $output"
exit 0
