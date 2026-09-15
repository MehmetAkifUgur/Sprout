# Uygulama ikonu ve splash görselini üretir (Windows PowerShell, System.Drawing).
# Kullanım: powershell -ExecutionPolicy Bypass -File tool\generate_icon.ps1
# Ardından: dart run flutter_launcher_icons
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $root 'assets\icon'
New-Item -ItemType Directory -Force $outDir | Out-Null

function New-Color([string]$hex) {
  return [System.Drawing.ColorTranslator]::FromHtml($hex)
}

function Draw-Plant($g, [float]$size) {
  $s = $size / 1024.0
  $pot = New-Object System.Drawing.SolidBrush (New-Color '#C8693F')
  $rim = New-Object System.Drawing.SolidBrush (New-Color '#B05A33')
  $leaf = New-Object System.Drawing.SolidBrush (New-Color '#4CAF50')
  $leafDark = New-Object System.Drawing.SolidBrush (New-Color '#2E7D32')
  $stemPen = New-Object System.Drawing.Pen (New-Color '#558B2F'), (34 * $s)
  $stemPen.StartCap = 'Round'; $stemPen.EndCap = 'Round'

  # Gövde
  $g.DrawBezier($stemPen, 512 * $s, 700 * $s, 500 * $s, 600 * $s, 530 * $s, 480 * $s, 512 * $s, 380 * $s)

  # Yapraklar
  foreach ($l in @(@(512, 470, -50, $leaf), @(512, 420, 45, $leafDark), @(512, 560, -60, $leafDark), @(512, 540, 55, $leaf))) {
    $state = $g.Save()
    $g.TranslateTransform($l[0] * $s, $l[1] * $s)
    $g.RotateTransform($l[2])
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddBezier(0, 0, 80 * $s, -60 * $s, 60 * $s, -180 * $s, 0, -220 * $s)
    $path.AddBezier(0, -220 * $s, -60 * $s, -180 * $s, -80 * $s, -60 * $s, 0, 0)
    $g.FillPath($l[3], $path)
    $g.Restore($state)
  }

  # Saksı
  $body = New-Object System.Drawing.Drawing2D.GraphicsPath
  $body.AddPolygon(@(
      (New-Object System.Drawing.PointF (330 * $s), (700 * $s)),
      (New-Object System.Drawing.PointF (694 * $s), (700 * $s)),
      (New-Object System.Drawing.PointF (640 * $s), (880 * $s)),
      (New-Object System.Drawing.PointF (384 * $s), (880 * $s))
    ))
  $g.FillPath($pot, $body)
  $g.FillRectangle($rim, 300 * $s, 670 * $s, 424 * $s, 70 * $s)
}

function Save-Icon([string]$name, [int]$size, [bool]$background, [float]$scale) {
  $bmp = New-Object System.Drawing.Bitmap $size, $size
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = 'AntiAlias'
  $g.Clear([System.Drawing.Color]::Transparent)
  if ($background) {
    $bg = New-Object System.Drawing.SolidBrush (New-Color '#E3F2D9')
    $g.FillRectangle($bg, 0, 0, $size, $size)
  }
  # İçeriği ölçekleyip ortala (adaptive icon güvenli alanı için).
  $offset = $size * (1 - $scale) / 2
  $g.TranslateTransform($offset, $offset - $size * $scale * 0.08)
  Draw-Plant $g ($size * $scale)
  $g.Dispose()
  $bmp.Save((Join-Path $outDir $name), [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
}

Save-Icon 'icon.png' 1024 $true 1.0
Save-Icon 'icon_foreground.png' 1024 $false 0.62
Save-Icon 'splash.png' 384 $false 1.0
Write-Output "Icons written to $outDir"
