param([string]$Pptx, [string]$Pdf)
# Applies entrance animations from shape names "anim|<step>|<fx>|<uid>",
# adds a smooth fade transition, saves, and exports a PDF.
$ErrorActionPreference = 'Stop'
$fx = @{
  fade  = @{ id = 10; dur = 0.6; dir = $null }   # Fade
  rise  = @{ id = 34; dur = 0.6; dir = $null }   # Rise Up
  zoom  = @{ id = 48; dur = 0.5; dir = $null }   # Faded Zoom
  flyup = @{ id = 2;  dur = 0.8; dir = 11 }      # Fly In from Bottom
  wipe  = @{ id = 22; dur = 0.8; dir = 2 }       # Wipe from Right (RTL)
}
$gap = 0.28; $lead = 0.15

$app = New-Object -ComObject PowerPoint.Application
try {
  $pres = $app.Presentations.Open($Pptx, 0, 0, 0)
  $total = 0
  foreach ($slide in $pres.Slides) {
    $t = $slide.SlideShowTransition
    $t.EntryEffect = 3849   # ppEffectFadeSmoothly
    $t.Duration = 0.6
    $t.AdvanceOnClick = -1

    $seq = $slide.TimeLine.MainSequence
    for ($k = $seq.Count; $k -ge 1; $k--) { $seq.Item($k).Delete() }

    $items = @()
    foreach ($sh in $slide.Shapes) {
      if ($sh.Name -like 'anim|*') {
        $p = $sh.Name.Split('|')
        $items += [pscustomobject]@{ Shape = $sh; Step = [int]$p[1]; Fx = $p[2]; Uid = [int]$p[3] }
      }
    }
    if ($items.Count -eq 0) { continue }
    $items = $items | Sort-Object Step, Uid
    $steps = @($items | Select-Object -ExpandProperty Step -Unique | Sort-Object)
    $g = if ($steps.Count -gt 1) { [math]::Min($gap, 2.2 / ($steps.Count - 1)) } else { $gap }
    $first = $true
    foreach ($it in $items) {
      $def = $fx[$it.Fx]; if (-not $def) { $def = $fx['fade'] }
      $rank = [array]::IndexOf($steps, $it.Step)
      $trigger = if ($first) { 3 } else { 2 }   # AfterPrevious for the first, then WithPrevious
      $e = $seq.AddEffect($it.Shape, $def.id, 0, $trigger)
      if ($def.dir) { $e.EffectParameters.Direction = $def.dir }
      $e.Timing.Duration = $def.dur
      $e.Timing.TriggerDelayTime = if ($first) { $lead } else { $rank * $g }
      $first = $false
      $total++
    }
  }
  $pres.Save()
  $pres.SaveAs($Pdf, 32)   # PDF (static)
  "animated elements: $total on $($pres.Slides.Count) slides"
  $pres.Close()
} finally {
  $app.Quit()
  [System.Runtime.InteropServices.Marshal]::ReleaseComObject($app) | Out-Null
}
