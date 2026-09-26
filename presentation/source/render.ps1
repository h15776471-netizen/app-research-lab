param([string]$Pptx, [string]$OutDir, [int]$Width = 1600)
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force $OutDir | Out-Null
Get-ChildItem $OutDir -Filter 'slide-*.png' -ErrorAction SilentlyContinue | Remove-Item -Force
$app = New-Object -ComObject PowerPoint.Application
try {
  # ReadOnly, Untitled, WithWindow = false
  $pres = $app.Presentations.Open($Pptx, -1, 0, 0)
  $h = [int]($Width * $pres.PageSetup.SlideHeight / $pres.PageSetup.SlideWidth)
  $i = 0
  foreach ($s in $pres.Slides) {
    $i++
    $s.Export((Join-Path $OutDir ('slide-{0:D2}.png' -f $i)), 'PNG', $Width, $h)
  }
  "rendered $i slides"
  $pres.Close()
} finally {
  $app.Quit()
  [System.Runtime.InteropServices.Marshal]::ReleaseComObject($app) | Out-Null
}
