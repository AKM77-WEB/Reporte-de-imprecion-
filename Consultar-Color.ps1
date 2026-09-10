<#
Consulta EN VIVO el contador de cada impresora Epson (a color) por su IP y muestra
cuanto se ha impreso desde la ultima lectura registrada, con su costo de tinta.

SOLO LEE: no modifica la linea base, no sube nada, no altera el reporte publicado.
Se puede correr las veces que quieras, cualquier dia.

Uso: doble clic en Consultar-Color.bat
#>
param([string]$RepoDir = $PSScriptRoot)

$ErrorActionPreference = 'Stop'

$basePath = Join-Path $RepoDir 'baseline\current\epson.json'
if (-not (Test-Path $basePath)) {
  Write-Host "No hay lecturas registradas todavia (falta baseline/current/epson.json)." -ForegroundColor Yellow
  return
}
$base = @((Get-Content $basePath -Raw -Encoding UTF8 | ConvertFrom-Json) | ForEach-Object { $_ })

function Get-Lectura([string]$ip) {
  $html = curl.exe -k -s --max-time 20 "https://$ip/PRESENTATION/ADVANCED/INFO_MENTINFO/TOP" 2>$null
  if (-not $html) { $html = curl.exe -s --max-time 20 "http://$ip/PRESENTATION/ADVANCED/INFO_MENTINFO/TOP" 2>$null }
  if (-not $html) { return $null }
  $texto = (($html -join ' ') -replace '<[^>]+>', ' ' -replace '&nbsp;', ' ' -replace '\s+', ' ')
  if ($texto -match 'total de p.{1,3}ginas\s*:\s*([\d,]+)') { return [int]($Matches[1] -replace ',', '') }
  return $null
}

$fechaBase = ($base | Where-Object { $_.fecha } | Select-Object -First 1).fecha
Write-Host ""
Write-Host "  IMPRESION A COLOR - avance en vivo" -ForegroundColor Cyan
Write-Host "  Ultima lectura registrada: $fechaBase" -ForegroundColor DarkGray
Write-Host ""
Write-Host ("  {0,-16} {1,10} {2,10} {3,10} {4,12}" -f 'IMPRESORA', 'ANTES', 'AHORA', 'IMPRESO', 'TINTA')
Write-Host ("  " + ('-' * 62)) -ForegroundColor DarkGray

$totPag = 0; $totCost = 0; $fallas = @()
foreach ($e in $base) {
  $ip = ('' + $e.ip).Trim()
  $antes = [int]$e.lectura
  $ahora = if ($ip) { Get-Lectura $ip } else { $null }

  if ($null -eq $ahora) {
    $fallas += $e.name
    Write-Host ("  {0,-16} {1,10:N0} {2,10} {3,10} {4,12}" -f $e.name, $antes, 'sin resp.', '-', '-') -ForegroundColor DarkYellow
    continue
  }

  # contador reiniciado o impresora repuesta: la lectura actual ya es el consumo
  $dif = if ($ahora -ge $antes) { $ahora - $antes } else { $ahora }
  $cpp = 0.0
  if ($e.PSObject.Properties['costPerPage'] -and $e.costPerPage) { $cpp = [double]$e.costPerPage }
  elseif ($e.rendimientoKit -and [double]$e.rendimientoKit -gt 0) { $cpp = [double]$e.costoKit / [double]$e.rendimientoKit }
  $costo = [Math]::Round($dif * $cpp, 2)

  $totPag += $dif; $totCost += $costo
  $color = if ($dif -gt 0) { 'White' } else { 'DarkGray' }
  Write-Host ("  {0,-16} {1,10:N0} {2,10:N0} {3,10:N0} {4,12:C}" -f $e.name, $antes, $ahora, $dif, $costo) -ForegroundColor $color
}

Write-Host ("  " + ('-' * 62)) -ForegroundColor DarkGray
Write-Host ("  {0,-16} {1,10} {2,10} {3,10:N0} {4,12:C}" -f 'TOTAL', '', '', $totPag, $totCost) -ForegroundColor Cyan
Write-Host ""
Write-Host "  Esto es solo consulta: el reporte publicado se actualiza en el corte." -ForegroundColor DarkGray
if ($fallas.Count -gt 0) {
  Write-Host "  Sin respuesta: $($fallas -join ', ') (revisa que esten encendidas y en red)." -ForegroundColor Yellow
}
Write-Host ""
