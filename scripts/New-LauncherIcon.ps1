[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$ApplicationExe,
  [Parameter(Mandatory = $true)][string]$OutputIco,
  [string]$BadgeText = 'P',
  [string]$BadgeColor = '#3A5CFF',
  [switch]$NoBadge
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
if (-not ('DshIconTool' -as [type])) {
  Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class DshIconTool {
  [DllImport("user32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
  public static extern uint PrivateExtractIcons(string file, int index, int cx, int cy, IntPtr[] icons, uint[] ids, uint count, uint flags);
  [DllImport("user32.dll", SetLastError=true)]
  public static extern bool DestroyIcon(IntPtr hIcon);
}
'@
}
$source = [System.IO.Path]::GetFullPath($ApplicationExe)
$target = [System.IO.Path]::GetFullPath($OutputIco)
if (-not (Test-Path -LiteralPath $source)) { throw "Application executable missing: $source" }
if (Test-Path -LiteralPath $target) { throw "Output ICO already exists: $target" }
$targetDirectory = Split-Path -Parent $target
if (-not (Test-Path -LiteralPath $targetDirectory)) { New-Item -ItemType Directory -Path $targetDirectory -Force | Out-Null }

$sizes = @(16, 24, 32, 48, 64, 128, 256)
$images = @{}
$bitmaps = @()
$pngs = @()
foreach ($size in $sizes) {
  $icons = New-Object IntPtr[] 1
  $ids = New-Object uint32[] 1
  $count = [DshIconTool]::PrivateExtractIcons($source, 0, $size, $size, $icons, $ids, 1, 0)
  if ($count -lt 1 -or $icons[0] -eq [IntPtr]::Zero) { throw "Could not extract icon size $size from $source" }
  $icon = [System.Drawing.Icon]::FromHandle($icons[0])
  $images[$size] = $icon.ToBitmap()
  $icon.Dispose()
  [void][DshIconTool]::DestroyIcon($icons[0])
}

try {
  foreach ($size in $sizes) {
    $canvas = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $bitmaps += $canvas
    $graphics = [System.Drawing.Graphics]::FromImage($canvas)
    try {
      $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
      $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
      $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
      $graphics.DrawImage($images[$size], 0, 0, $size, $size)
      if (-not $NoBadge -and $size -ge 32) {
        $diameter = [float]($size * 0.30)
        $left = [float]($size * 0.80 - $diameter / 2)
        $top = [float]($size * 0.80 - $diameter / 2)
        $color = [System.Drawing.ColorTranslator]::FromHtml($BadgeColor)
        $brush = New-Object System.Drawing.SolidBrush($color)
        $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::White, [float][Math]::Max(1.0, $size * 0.025))
        try {
          $graphics.FillEllipse($brush, $left, $top, $diameter, $diameter)
          $graphics.DrawEllipse($pen, $left, $top, $diameter, $diameter)
        } finally { $brush.Dispose(); $pen.Dispose() }
        $font = New-Object System.Drawing.Font('Segoe UI', [float]($size * 0.18), [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
        $textBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
        $format = New-Object System.Drawing.StringFormat
        try {
          $format.Alignment = [System.Drawing.StringAlignment]::Center
          $format.LineAlignment = [System.Drawing.StringAlignment]::Center
          $rectangle = New-Object System.Drawing.RectangleF($left, $top, $diameter, $diameter)
          $graphics.DrawString($BadgeText, $font, $textBrush, $rectangle, $format)
        } finally { $format.Dispose(); $font.Dispose(); $textBrush.Dispose() }
      }
    } finally {
      $graphics.Dispose()
    }
    $stream = New-Object System.IO.MemoryStream
    try {
      $canvas.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
      $pngs += ,$stream.ToArray()
    } finally { $stream.Dispose() }
  }

  $offset = 6 + 16 * $pngs.Count
  $file = [System.IO.File]::Create($target)
  $writer = New-Object System.IO.BinaryWriter($file)
  try {
    $writer.Write([uint16]0)
    $writer.Write([uint16]1)
    $writer.Write([uint16]$sizes.Count)
    for ($i = 0; $i -lt $sizes.Count; $i++) {
      $size = $sizes[$i]
      $writer.Write([byte]$(if ($size -eq 256) { 0 } else { $size }))
      $writer.Write([byte]$(if ($size -eq 256) { 0 } else { $size }))
      $writer.Write([byte]0)
      $writer.Write([byte]0)
      $writer.Write([uint16]1)
      $writer.Write([uint16]32)
      $writer.Write([uint32]$pngs[$i].Length)
      $writer.Write([uint32]$offset)
      $offset += $pngs[$i].Length
    }
    foreach ($png in $pngs) { $writer.Write($png) }
  } finally {
    $writer.Dispose()
    $file.Dispose()
  }
  Write-Output "Wrote multi-size ICO: $target"
} finally {
  foreach ($bitmap in $bitmaps) { $bitmap.Dispose() }
  foreach ($image in $images.Values) { $image.Dispose() }
}
