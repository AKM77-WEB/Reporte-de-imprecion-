<#
Genera index.html (reporte con datos incrustados) a partir de los 4 CSV de Kyocera Net Viewer.
Replica exactamente las reglas de parseAreaCsv() del HTML original:
  - se ignoran filas sin "Nombre de cuenta"
  - se ignoran cuentas con Imprimir+Copia+Escanear = 0
  - Total de cada persona = Imprimir (total) + Copia (total)
  - orden descendente por Total

Uso:
  .\Build-Report.ps1 `
    -AlmacenCsv "C:\ruta\ALMACEN.csv" -AdminCsv "C:\ruta\ADMINISTRACION.csv" `
    -PostventaCsv "C:\ruta\POSTVENTA.csv" -OperacionesCsv "C:\ruta\OPERACIONES.csv" `
    -Periodo "Agosto 2026" -Generado "15/08/2026"
#>
param(
  [Parameter(Mandatory=$true)][string]$AlmacenCsv,
  [Parameter(Mandatory=$true)][string]$AdminCsv,
  [Parameter(Mandatory=$true)][string]$PostventaCsv,
  [Parameter(Mandatory=$true)][string]$OperacionesCsv,
  [Parameter(Mandatory=$true)][string]$Periodo,
  [Parameter(Mandatory=$true)][string]$Generado,
  [double]$Renta = 8167.95,
  [int]$Incluidas = 6000,  # limite por impresora, no total (son 4 impresoras)
  [double]$Tarifa = 0.20,
  [string]$EpsonJson = $null,
  # epson.json del corte anterior: permite anotar la LECTURA TOTAL de vida de cada
  # Epson (la que muestra su pagina web por IP) y que el consumo del periodo se
  # calcule solo, restando la lectura del corte pasado.
  [string]$EpsonBaselineJson = $null,
  # Carpeta con los CSV del corte anterior (linea base). Si existe el CSV del area,
  # el consumo del periodo = contador actual - contador de la linea base, cuenta por cuenta.
  # Asi no hace falta reiniciar los contadores fisicos en cada corte.
  [string]$BaselineDir = $null,
  # Join-Path normaliza el separador: en el runner de Linux "\" no separa carpetas
  # y el archivo terminaria escrito fuera del repositorio.
  [string]$TemplatePath = (Join-Path $PSScriptRoot 'template.html'),
  [string]$OutputPath = (Join-Path $PSScriptRoot 'index.html'),
  [string]$ReportsDir = (Join-Path $PSScriptRoot 'reports')
)

$ErrorActionPreference = 'Stop'

# Columnas del export de Kyocera Net Viewer, por posición (evita problemas de acentos/encoding
# al leer nombres de columna como "Dúplex").
#  1 Nombre del modelo | 5 Nombre de cuenta | 6 Imprimir (total) | 7 Copia (total)
#  8 Escanear (total) | 33 Simple | 34 Dúplex
$Headers = 1..38 | ForEach-Object { "c$_" }

function Get-Num($v) {
  if ($null -eq $v -or $v -eq '') { return 0 }
  $s = ($v -replace ',', '').Trim()
  $n = 0.0
  if ([double]::TryParse($s, [ref]$n)) { return $n }
  return 0
}

function Get-AccountKey($row) {
  $id = ('' + $row.c4).Trim()
  $name = ('' + $row.c5).Trim()
  return $id + '|' + $name.ToLowerInvariant()
}

# Lee un CSV de linea base y regresa un mapa cuenta -> contadores acumulados
function Get-BaselineMap {
  param([string]$CsvPath)
  $map = @{}
  if (-not $CsvPath) { return $map }
  $rows = Import-Csv -Path $CsvPath -Header $Headers -Encoding UTF8 | Select-Object -Skip 1
  foreach ($row in $rows) {
    $name = $row.c5
    if (-not $name -or $name.Trim() -eq '') { continue }
    $map[(Get-AccountKey $row)] = @{
      imprimir = Get-Num $row.c6; copia = Get-Num $row.c7; escanear = Get-Num $row.c8
      simple   = Get-Num $row.c33; duplex = Get-Num $row.c34
    }
  }
  return $map
}

function Get-AreaData {
  param([string]$CsvPath, [string]$AreaName, [string]$BaselineCsvPath)

  $rows = Import-Csv -Path $CsvPath -Header $Headers -Encoding UTF8 | Select-Object -Skip 1
  $base = Get-BaselineMap -CsvPath $BaselineCsvPath

  $model = ''
  $people = New-Object System.Collections.Generic.List[object]

  foreach ($row in $rows) {
    $m = $row.c1
    if ($m -and $m.Trim() -ne '') { $model = $m.Trim() }

    $name = $row.c5
    if (-not $name) { continue }
    $name = $name.Trim()
    if ($name -eq '') { continue }

    $imprimir = Get-Num $row.c6
    $copia    = Get-Num $row.c7
    $escanear = Get-Num $row.c8
    $simple   = Get-Num $row.c33
    $duplex   = Get-Num $row.c34

    # Con linea base: el consumo del periodo es la diferencia contra el corte anterior.
    # Si algun contador actual es menor que el de la linea base, el equipo se reinicio
    # despues de ese corte y el contador actual ya es el consumo del periodo.
    $key = Get-AccountKey $row
    if ($base.ContainsKey($key)) {
      $b = $base[$key]
      $dImp = $imprimir - $b.imprimir
      $dCop = $copia    - $b.copia
      $dEsc = $escanear - $b.escanear
      if ($dImp -ge 0 -and $dCop -ge 0 -and $dEsc -ge 0) {
        $imprimir = $dImp; $copia = $dCop; $escanear = $dEsc
        $simple = [Math]::Max(0, $simple - $b.simple)
        $duplex = [Math]::Max(0, $duplex - $b.duplex)
      }
    }

    if (($imprimir + $copia + $escanear) -eq 0) { continue }

    $people.Add([PSCustomObject][ordered]@{
      name=$name; imprimir=$imprimir; copia=$copia; escanear=$escanear;
      duplex=$duplex; simple=$simple; total=($imprimir + $copia)
    })
  }

  $sorted = @($people | Sort-Object -Property { $_.total } -Descending)

  $totals = [ordered]@{
    imprimir = ($sorted | Measure-Object -Property imprimir -Sum).Sum
    copia    = ($sorted | Measure-Object -Property copia -Sum).Sum
    escanear = ($sorted | Measure-Object -Property escanear -Sum).Sum
    duplex   = ($sorted | Measure-Object -Property duplex -Sum).Sum
    simple   = ($sorted | Measure-Object -Property simple -Sum).Sum
    total    = ($sorted | Measure-Object -Property total -Sum).Sum
  }
  if ($sorted.Count -eq 0) { $totals = [ordered]@{ imprimir=0;copia=0;escanear=0;duplex=0;simple=0;total=0 } }

  return [ordered]@{ area=$AreaName; model=$model; people=$sorted; totals=$totals; activos=$sorted.Count }
}

# Busca el CSV de linea base del area dentro de $BaselineDir (mismo criterio de prefijo)
function Find-BaselineCsv([string]$prefix) {
  if (-not $BaselineDir -or -not (Test-Path $BaselineDir)) { return $null }
  $f = Get-ChildItem -Path $BaselineDir -Filter *.csv -File |
       Where-Object { $_.Name -match ('(?i)^' + $prefix) } |
       Select-Object -First 1
  if ($f) { return $f.FullName }
  return $null
}

# Mismo orden que AREAS en el HTML: Almacén, Administración, Postventa, Operaciones
$areas = @(
  (Get-AreaData -CsvPath $AlmacenCsv -AreaName 'Almacén' -BaselineCsvPath (Find-BaselineCsv 'ALMACEN')),
  (Get-AreaData -CsvPath $AdminCsv -AreaName 'Administración' -BaselineCsvPath (Find-BaselineCsv 'ADMINISTRACION')),
  (Get-AreaData -CsvPath $PostventaCsv -AreaName 'Postventa' -BaselineCsvPath (Find-BaselineCsv 'POSTVENTA')),
  (Get-AreaData -CsvPath $OperacionesCsv -AreaName 'Operaciones' -BaselineCsvPath (Find-BaselineCsv 'OPERACIONES'))
)
if ($BaselineDir -and (Test-Path $BaselineDir)) {
  Write-Host "Linea base aplicada desde: $BaselineDir (consumo = contador actual - corte anterior)"
}

# ---------- Epson: lectura total de vida -> consumo del periodo ----------
# Formato nuevo de incoming/epson.json (se admite el viejo con "pages" directo):
#   [{ "name":"Recepcion", "ip":"192.168.1.50", "lectura":15230,
#      "fecha":"15/09/2026", "costoKit":450.00, "rendimientoKit":1800 }]
# lectura = contador total que muestra la impresora al entrar a su IP.
# paginas del periodo = lectura - lectura del corte anterior (por ip o por nombre);
# sin corte anterior = 0 (primer registro, solo establece la base);
# lectura menor que la base = impresora reiniciada/repuesta, se usa tal cual.
function Get-EpsonProp($obj, [string]$prop) {
  $p = $obj.PSObject.Properties[$prop]
  if ($p -and $null -ne $p.Value -and ('' + $p.Value).Trim() -ne '') { return $p.Value }
  return $null
}

$epson = @()
if ($EpsonJson -and (Test-Path $EpsonJson)) {
  # El "| ForEach-Object { $_ }" aplana el arreglo: PowerShell 5.1 entrega el JSON
  # como un solo objeto anidado y sin esto saldria una unica entrada vacia.
  $epsonIn = @((Get-Content $EpsonJson -Raw -Encoding UTF8 | ConvertFrom-Json) | ForEach-Object { $_ })
  $epsonBase = @()
  if ($EpsonBaselineJson -and (Test-Path $EpsonBaselineJson)) {
    $epsonBase = @((Get-Content $EpsonBaselineJson -Raw -Encoding UTF8 | ConvertFrom-Json) | ForEach-Object { $_ })
  }

  function Find-EpsonBase($entry) {
    $ip = ('' + (Get-EpsonProp $entry 'ip')).Trim()
    if ($ip) {
      foreach ($b in $epsonBase) { if ((('' + (Get-EpsonProp $b 'ip')).Trim()) -eq $ip) { return $b } }
    }
    $nm = ('' + (Get-EpsonProp $entry 'name')).Trim().ToLowerInvariant()
    foreach ($b in $epsonBase) {
      if ((('' + (Get-EpsonProp $b 'name')).Trim().ToLowerInvariant()) -eq $nm) { return $b }
    }
    return $null
  }

  $epson = @(foreach ($e in $epsonIn) {
    $costPerPage = $null
    $cpp = Get-EpsonProp $e 'costPerPage'
    $kit = Get-EpsonProp $e 'costoKit'
    $rend = Get-EpsonProp $e 'rendimientoKit'
    if ($null -ne $cpp) { $costPerPage = [math]::Round((Get-Num $cpp), 4) }
    elseif ($null -ne $kit -and $null -ne $rend -and (Get-Num $rend) -gt 0) {
      $costPerPage = [math]::Round((Get-Num $kit) / (Get-Num $rend), 4)
    }

    $lectura = Get-EpsonProp $e 'lectura'
    $pagesIn = Get-EpsonProp $e 'pages'
    $pages = 0
    if ($null -ne $lectura) {
      $lectura = Get-Num $lectura
      $b = Find-EpsonBase $e
      $lecturaBase = if ($b) { Get-EpsonProp $b 'lectura' } else { $null }
      if ($null -ne $lecturaBase -and (Get-Num $lecturaBase) -le $lectura) {
        $pages = $lectura - (Get-Num $lecturaBase)
      } elseif ($null -ne $lecturaBase) {
        $pages = $lectura   # contador reiniciado o impresora repuesta
      } else {
        $pages = 0          # primer registro: establece la base
      }
    } elseif ($null -ne $pagesIn) {
      $pages = Get-Num $pagesIn   # formato viejo: paginas del periodo a mano
    }

    $costPeriod = $null
    if ($null -ne $costPerPage) { $costPeriod = [math]::Round($pages * $costPerPage, 2) }
    $gastoVida = $null
    if ($null -ne $costPerPage -and $null -ne $lectura) { $gastoVida = [math]::Round($lectura * $costPerPage, 2) }

    $fecha = Get-EpsonProp $e 'fecha'
    if ($null -eq $fecha) { $fecha = $Generado }

    [ordered]@{
      name = ('' + (Get-EpsonProp $e 'name')); ip = (Get-EpsonProp $e 'ip')
      pages = $pages; fecha = ('' + $fecha)
      costPerPage = $costPerPage; costPeriod = $costPeriod
      lectura = $lectura; gastoVida = $gastoVida
    }
  })
}

$report = [ordered]@{
  periodo=$Periodo; generado=$Generado; renta=$Renta; incluidas=$Incluidas; tarifa=$Tarifa; areas=$areas; epson=$epson
}

$json = $report | ConvertTo-Json -Depth 12 -Compress
$json = $json -replace '</', '<\/'   # evita cerrar el <script> al incrustarlo

$template = Get-Content -Path $TemplatePath -Raw -Encoding UTF8

$dataScript = '<script type="application/json" id="embedded-report-data">' + $json + '</script>'
$bootScript = '<script id="embedded-boot">(function(){var d=document.getElementById(''embedded-report-data'');if(!d)return;try{var data=JSON.parse(d.textContent);if(window.__loadEmbeddedReport)window.__loadEmbeddedReport(data);}catch(e){console.error(''No se pudo cargar el reporte incrustado'', e);}})();</script>'

$final = $template -replace '</body>', ($dataScript + "`n" + $bootScript + "`n</body>")
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($OutputPath, $final, $Utf8NoBom)

# ---------- guarda este corte en el historial (reports/<slug>.json + reports/index.json) ----------
if (-not (Test-Path $ReportsDir)) { New-Item -ItemType Directory -Path $ReportsDir | Out-Null }

$slug = ($Periodo.ToLowerInvariant() -replace '[^a-z0-9]+', '-').Trim('-')
if (-not $slug) { $slug = 'reporte-' + (Get-Date -Format 'yyyyMMddHHmmss') }

$reportFile = Join-Path $ReportsDir "$slug.json"
[System.IO.File]::WriteAllText($reportFile, $json, $Utf8NoBom)

$manifestPath = Join-Path $ReportsDir 'index.json'
$manifest = @()
if (Test-Path $manifestPath) {
  $manifest = @(Get-Content $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json)
}
$manifest = @($manifest | Where-Object { $_.slug -ne $slug })
$entry = [ordered]@{ slug=$slug; periodo=$Periodo; generado=$Generado; file="$slug.json" }
$manifest = @($entry) + $manifest   # el mas reciente generado queda primero

$manifestJson = $manifest | ConvertTo-Json -Depth 5
if ($manifest.Count -eq 1) { $manifestJson = '[' + ($manifest[0] | ConvertTo-Json -Depth 5 -Compress) + ']' }
[System.IO.File]::WriteAllText($manifestPath, $manifestJson, $Utf8NoBom)

Write-Host "Historial -> $reportFile (manifiesto: $($manifest.Count) periodos)"
Write-Host "OK -> $OutputPath"
Write-Host ("Total paginas: {0}" -f ($areas | ForEach-Object { $_.totals.total } | Measure-Object -Sum).Sum)
foreach ($a in $areas) { Write-Host ("  {0}: {1} pag, {2} activos, equipo {3}" -f $a.area, $a.totals.total, $a.activos, $a.model) }
