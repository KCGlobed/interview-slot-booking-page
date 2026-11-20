# Generates one keyword-themed landing page per entry in heroes.json.
# Each page is a copy of ../index.html where ONLY these change:
#   <title>, meta description, hero kicker, hero <h1>, hero offer line, hero CTA label.
# Everything else stays byte-identical. Re-run after editing index.html:
#   powershell -ExecutionPolicy Bypass -File landing-pages\build.ps1
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $here
$utf8 = New-Object System.Text.UTF8Encoding($false)   # no BOM, same as index.html

$src = [IO.File]::ReadAllText((Join-Path $root 'index.html'), $utf8)
$heroes = [IO.File]::ReadAllText((Join-Path $here 'heroes.json'), $utf8) | ConvertFrom-Json

function Replace-Once([string]$text, [string]$pattern, [string]$value, [string]$what) {
  $rx = New-Object System.Text.RegularExpressions.Regex($pattern, 'Singleline')
  $n = $rx.Matches($text).Count
  if ($n -ne 1) { throw "Pattern for $what matched $n times (expected 1)" }
  $eval = [System.Text.RegularExpressions.MatchEvaluator] { param($m) $m.Groups[1].Value + $value + $m.Groups[2].Value }
  return $rx.Replace($text, $eval, 1)
}
function Attr([string]$s) { return $s.Replace('&', '&amp;').Replace('"', '&quot;') }

# Regions that are allowed to differ (used for both generating and verifying)
$P_TITLE  = '(<title>).*?(</title>)'
$P_DESC   = '(<meta name="description"\s+content=")[^"]*(")'
$P_KICKER = '(<div class="kicker">GCC School <span aria-hidden="true">\|</span> ).*?(</div>)'
$P_H1     = '(<h1 class="h1" id="hero-h1">).*?(</h1>)'
$P_OFFER  = '(<div class="offer-amt">.10 LPA <span>Pre-Placement Offer</span></div>\s*<p>).*?(</p>)'
$P_CTA    = '(<a href="#apply" class="btn btn-amber hero-cta go-apply check-eligibility">).*?(</a>)'

function Mask([string]$t) {
  foreach ($p in $P_TITLE, $P_DESC, $P_KICKER, $P_H1, $P_OFFER, $P_CTA) { $t = Replace-Once $t $p '@@' $p }
  return $t
}
$maskedSrc = Mask $src

$csv = New-Object System.Collections.Generic.List[string]
$csv.Add('Campaign,Ad Group,Keyword Theme,Page path,Headline')
function Q([string]$s) { return '"' + $s.Replace('"', '""') + '"' }

foreach ($h in $heroes) {
  $out = $src
  $out = Replace-Once $out $P_TITLE  (Attr $h.title) 'title'
  $out = Replace-Once $out $P_DESC   (Attr $h.description) 'description'
  $out = Replace-Once $out $P_KICKER $h.kicker 'kicker'
  $out = Replace-Once $out $P_H1     ($h.h1 + ' <span class="gold">' + $h.h1gold + '</span>') 'h1'
  $out = Replace-Once $out $P_OFFER  $h.offer 'offer'
  $out = Replace-Once $out $P_CTA    $h.cta 'cta'

  if ((Mask $out) -ne $maskedSrc) { throw "Verification failed for $($h.slug): non-hero content differs" }

  $file = Join-Path $root ($h.slug + '.html')
  [IO.File]::WriteAllText($file, $out, $utf8)

  $headline = ($h.h1 + ' ' + $h.h1gold).Replace('&amp;', '&')
  $campaign = 'Search | ' + $h.campaign + ' | Non-Brand | India'
  $csv.Add((Q $campaign) + ',' + (Q $h.theme) + ',' + (Q $h.theme) + ',' + (Q ('/' + $h.slug + '.html')) + ',' + (Q $headline))
  Write-Host "OK  /$($h.slug).html  ->  $headline"
}
[IO.File]::WriteAllLines((Join-Path $root 'landing-pages-map.csv'), $csv, $utf8)
Write-Host "Built $($heroes.Count) pages; non-hero content verified identical to index.html."
