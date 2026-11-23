# Holt die FotMob-Ratings des letzten Barça-Spiels (oder eines bestimmten Spiels)
# und schreibt sie nach match-ratings.js für den Ratings-Generator.
#   .\ratings-holen.ps1                         -> letztes beendetes Barça-Spiel
#   .\ratings-holen.ps1 -Match "<FotMob-Link>"  -> genau dieses Spiel
param([string]$Match = '')

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$TeamId = 8634   # FC Barcelona auf FotMob
$UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36'
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path

function Get-NextData([string]$url) {
  $r = Invoke-WebRequest -UseBasicParsing -UserAgent $UA $url
  $html = [Text.Encoding]::UTF8.GetString($r.RawContentStream.ToArray())
  $m = [regex]::Match($html, '<script id="__NEXT_DATA__"[^>]*>(.*?)</script>', 'Singleline')
  if (-not $m.Success) { throw "Keine Daten auf $url gefunden (FotMob hat evtl. die Seite geändert)." }
  return ($m.Groups[1].Value | ConvertFrom-Json).props.pageProps
}

# 1) Spiel bestimmen
$Match = $Match.Trim().Trim('"')
if ($Match -match '^https?://') {
  $matchUrl = $Match
} else {
  Write-Host 'Suche das letzte Barça-Spiel auf FotMob ...'
  $team = (Get-NextData "https://www.fotmob.com/teams/$TeamId/fixtures/barcelona").fallback."team-$TeamId"
  $fx = @($team.fixtures.allFixtures.fixtures) | Where-Object { $_.status.finished -and -not $_.status.cancelled }
  if ($Match -match '^\d+$') { $fx = $fx | Where-Object { "$($_.id)" -eq $Match } }
  $last = $fx | Sort-Object { [datetime]$_.status.utcTime } | Select-Object -Last 1
  if (-not $last) { throw 'Kein beendetes Spiel gefunden.' }
  $matchUrl = 'https://www.fotmob.com' + $last.pageUrl
}
Write-Host "Lade $matchUrl"

# 2) Spieldaten laden
$pp = Get-NextData $matchUrl
$g = $pp.general
if (-not $g.finished) { Write-Host 'Achtung: Spiel ist noch nicht beendet - Ratings sind vorläufig.' -ForegroundColor Yellow }
$teams = @($pp.header.teams)
$lu = $pp.content.lineup
$barcaIsHome = ($lu.homeTeam.id -eq $TeamId)
$side = if ($barcaIsHome) { $lu.homeTeam } else { $lu.awayTeam }
if (-not $side -or -not $side.starters) { throw 'Für dieses Spiel gibt es (noch) keine Aufstellung/Ratings auf FotMob.' }
$potmId = $pp.content.matchFacts.playerOfTheMatch.id

function Convert-Player($p, [bool]$starter) {
  $perf = $p.performance
  $ev = @($perf.events) | Where-Object { $_ }
  $subs = @($perf.substitutionEvents) | Where-Object { $_ }
  $in  = ($subs | Where-Object { $_.type -eq 'subIn' }  | Select-Object -First 1).time
  $out = ($subs | Where-Object { $_.type -eq 'subOut' } | Select-Object -First 1).time
  [ordered]@{
    fotmobId  = $p.id
    name      = $p.name
    firstName = $p.firstName
    lastName  = $p.lastName
    shirt     = $p.shirtNumber
    x         = $p.verticalLayout.x
    y         = $p.verticalLayout.y
    rating    = $perf.rating
    potm      = ($p.id -eq $potmId)
    goals     = @($ev | Where-Object { $_.type -eq 'goal' }).Count
    ownGoals  = @($ev | Where-Object { $_.type -eq 'ownGoal' }).Count
    assists   = @($ev | Where-Object { $_.type -eq 'assist' }).Count
    yellow    = @($ev | Where-Object { $_.type -eq 'yellowCard' }).Count
    red       = @($ev | Where-Object { $_.type -in 'redCard','yellowRedCard' }).Count
    subIn     = $in
    subOut    = $out
  }
}

$data = [ordered]@{
  matchId     = "$($g.matchId)"
  url         = $matchUrl
  fetchedAt   = (Get-Date).ToString('s')
  utcDate     = $g.matchTimeUTCDate
  finished    = [bool]$g.finished
  league      = $g.leagueName
  round       = "$($g.leagueRoundName)"
  home        = [ordered]@{ name = $teams[0].name; score = $teams[0].score }
  away        = [ordered]@{ name = $teams[1].name; score = $teams[1].score }
  barcaIsHome = $barcaIsHome
  formation   = $side.formation
  teamRating  = $side.rating
  starters    = @($side.starters | ForEach-Object { Convert-Player $_ $true })
  subs        = @($side.subs | Where-Object { @($_.performance.substitutionEvents | Where-Object { $_.type -eq 'subIn' }).Count -gt 0 } | ForEach-Object { Convert-Player $_ $false })
}

$json = $data | ConvertTo-Json -Depth 6
$out = Join-Path $Here 'match-ratings.js'
[IO.File]::WriteAllText($out, "// Automatisch erzeugt von ratings-holen.ps1`nwindow.MATCH_RATINGS = $json;`n", (New-Object Text.UTF8Encoding $false))
Write-Host ("Fertig: {0} {1}-{2} {3}  ({4} Startelf, {5} Einwechslungen)" -f $data.home.name, $data.home.score, $data.away.score, $data.away.name, $data.starters.Count, $data.subs.Count) -ForegroundColor Green
