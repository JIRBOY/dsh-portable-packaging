[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$Root,
  [string]$BuildPath = '',
  [switch]$AllowUserData
)
$ErrorActionPreference = 'Stop'
$rootPath = [System.IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
if (-not (Test-Path -LiteralPath $rootPath)) { throw "Portable root missing: $rootPath" }

$passed = 0
$failed = 0
function Check([string]$Name, [bool]$Condition, [string]$Detail) {
  if ($Condition) {
    $script:passed++
    Write-Output ("PASS  {0}  ({1})" -f $Name, $Detail)
  } else {
    $script:failed++
    Write-Output ("FAIL  {0}  ({1})" -f $Name, $Detail)
  }
}
function Read-Bytes([string]$Path) { return [System.IO.File]::ReadAllBytes($Path) }
function Test-AsciiCrlf([string]$Path) {
  $bytes = Read-Bytes $Path
  $nonAscii = @($bytes | Where-Object { $_ -gt 127 }).Count
  $bareLf = 0
  for ($i = 0; $i -lt $bytes.Length; $i++) {
    if ($bytes[$i] -eq 10 -and ($i -eq 0 -or $bytes[$i - 1] -ne 13)) { $bareLf++ }
  }
  return ($nonAscii -eq 0 -and $bareLf -eq 0)
}

$required = @(
  'runtime\node\bin\node.exe',
  'runtime\pnpm\dist\pnpm.mjs',
  'app\node_modules\@deepseek-ai\dsh\lib\bin.js',
  'desktop\resources\app.asar',
  'runtime\powershell\pwsh.exe',
  'runtime\git\usr\bin\bash.exe',
  'runtime\python-venv\Scripts\python.exe',
  'runtime\dotnet\dotnet.exe',
  'home\cordis.patch.yml',
  'portable-tools\validate-runtime.cmd'
)
$missing = @()
foreach ($relative in $required) {
  if (-not (Test-Path -LiteralPath (Join-Path $rootPath $relative))) { $missing += $relative }
}
Check 'Required payload files' ($missing.Count -eq 0) ($(if ($missing.Count) { $missing -join ', ' } else { "$($required.Count) files present" }))

$reparse = @(Get-ChildItem -Force -LiteralPath $rootPath -Recurse -ErrorAction SilentlyContinue | Where-Object {
  ($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
})
Check 'No reparse points' ($reparse.Count -eq 0) ($(if ($reparse.Count) { "$($reparse.Count) found; first: $($reparse[0].FullName)" } else { '0 found' }))

$credentialFiles = @(Get-ChildItem -Force -LiteralPath (Join-Path $rootPath 'home') -Recurse -File -Filter '.credentials*' -ErrorAction SilentlyContinue)
Check 'No credential file' ($credentialFiles.Count -eq 0) ($(if ($credentialFiles.Count) { $credentialFiles[0].FullName } else { 'none' }))

if ($AllowUserData) {
  Write-Output 'SKIP  User session/storage/profile checks  (AllowUserData)'
} else {
  $forbidden = @('home\sessions', 'home\storages', 'shell-profile')
  $present = @($forbidden | Where-Object { Test-Path -LiteralPath (Join-Path $rootPath $_) })
  Check 'No user session/profile state' ($present.Count -eq 0) ($(if ($present.Count) { $present -join ', ' } else { 'none' }))
}

$baks = @(Get-ChildItem -Force -LiteralPath $rootPath -Recurse -File -Filter '*.bak' -ErrorAction SilentlyContinue)
Check 'No .bak files' ($baks.Count -eq 0) ($(if ($baks.Count) { $baks[0].FullName } else { 'none' }))

$cmdFiles = @(Get-ChildItem -Force -LiteralPath $rootPath -File -Filter '*.cmd' -ErrorAction SilentlyContinue)
$badCmd = @($cmdFiles | Where-Object { -not (Test-AsciiCrlf $_.FullName) })
Check 'Root CMD files are ASCII/CRLF' ($badCmd.Count -eq 0) ($(if ($badCmd.Count) { $badCmd[0].FullName } else { "$($cmdFiles.Count) files" }))

$envFile = Join-Path $rootPath 'env.cmd'
if (Test-Path -LiteralPath $envFile) {
  $envText = Get-Content -LiteralPath $envFile -Raw
  Check 'DSH_HOME is redirected' ($envText -match 'set\s+"DSH_HOME=') 'env.cmd'
  Check 'Agent home is redirected' ($envText -match 'set\s+"DSH_AGENTS_HOME=') 'env.cmd'
  Check 'Portable workspace root is configured' ($envText -match 'DSH_PORTABLE_WORKSPACE_ROOT') 'env.cmd'
  Check 'USERPROFILE is not overridden' (-not ($envText -match 'set\s+"USERPROFILE=')) 'env.cmd'
} else {
  Check 'env.cmd present' $false 'missing'
}

$binDirs = @(Get-ChildItem -LiteralPath (Join-Path $rootPath 'home\profiles') -Recurse -Directory -Filter '.bin' -ErrorAction SilentlyContinue)
$absoluteShims = @()
foreach ($dir in $binDirs) {
  foreach ($file in @(Get-ChildItem -Force -LiteralPath $dir.FullName -File -ErrorAction SilentlyContinue)) {
    if ($file.Extension -notin @('.cmd', '.ps1') -and $file.Extension -ne '') { continue }
    $text = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction SilentlyContinue
    if ($text -match '[A-Za-z]:\\\\') { $absoluteShims += $file.FullName }
  }
}
Check 'pnpm shims contain no absolute drive paths' ($absoluteShims.Count -eq 0) ($(if ($absoluteShims.Count) { $absoluteShims[0] } else { 'none' }))

if ($BuildPath) {
  $buildFull = [System.IO.Path]::GetFullPath($BuildPath).TrimEnd('\', '/')
  $candidates = @()
  foreach ($relative in @('env.cmd', 'preflight.cmd', 'dsh-portable.ps1', 'version.json', 'shell-version.json', 'portable-config', 'portable-tools')) {
    $path = Join-Path $rootPath $relative
    if (Test-Path -LiteralPath $path) {
      $item = Get-Item -LiteralPath $path
      if ($item.PSIsContainer) { $candidates += @(Get-ChildItem -LiteralPath $path -Recurse -File -ErrorAction SilentlyContinue) }
      else { $candidates += $item }
    }
  }
  $stateFiles = @('home\profiles\pnpm-workspace.yaml', 'home\profiles\web\pnpm-workspace.yaml', 'home\profiles\desktop\pnpm-workspace.yaml', 'home\profiles\node_modules\.modules.yaml', 'home\profiles\node_modules\.pnpm-workspace-state-v1.json')
  foreach ($relative in $stateFiles) {
    $path = Join-Path $rootPath $relative
    if (Test-Path -LiteralPath $path) { $candidates += Get-Item -LiteralPath $path }
  }
  $hits = @()
  foreach ($file in $candidates) {
    if ($file.Length -gt 20MB) { continue }
    $text = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction SilentlyContinue
    if ($text -and $text.Contains($buildFull)) { $hits += $file.FullName }
  }
  Check 'No build absolute paths in config/state' ($hits.Count -eq 0) ($(if ($hits.Count) { $hits[0] } else { 'none' }))
} else {
  Write-Output 'SKIP  Build-path scan  (provide -BuildPath for this check)'
}

$secretHits = @()
$secretCandidates = @()
foreach ($relative in @('portable-config', 'portable-tools', 'home')) {
  $path = Join-Path $rootPath $relative
  if (-not (Test-Path -LiteralPath $path)) { continue }
  $secretCandidates += @(Get-ChildItem -LiteralPath $path -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
    $_.Extension -in @('.cmd', '.ps1', '.json', '.yaml', '.yml', '.txt') -and $_.FullName -notmatch '\\(node_modules|\.bin)\\' -and $_.Length -lt 2MB
  })
}
$secretPattern = '-----BEGIN (RSA|OPENSSH|EC|DSA|PGP) PRIVATE KEY-----|\?token=[A-Za-z0-9_-]{16,}|(?i)(api[_-]?key|secret|password)\s*[:=]\s*["'']?[A-Za-z0-9_\-]{24,}'
foreach ($file in $secretCandidates) {
  $text = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction SilentlyContinue
  if ($text -and ($text -match $secretPattern)) { $secretHits += $file.FullName }
}
Check 'No obvious secrets in config/tools/data' ($secretHits.Count -eq 0) ($(if ($secretHits.Count) { $secretHits[0] } else { 'none' }))

Write-Output ''
Write-Output ("RESULT  passed={0} failed={1}" -f $passed, $failed)
if ($failed -gt 0) { exit 1 }
Write-Output 'Portable bundle passed the generic checks. Manual clean-machine, exFAT and account tests are still required where applicable.'
exit 0
