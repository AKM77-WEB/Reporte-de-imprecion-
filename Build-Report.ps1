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
  [string]$TemplatePath = "$PSScriptRoot\template.html",
  [string]$OutputPath = "$PSScriptRoot\index.html"
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

function Get-AreaData {
  param([string]$CsvPath, [string]$AreaName)

  $rows = Import-Csv -Path $CsvPath -Header $Headers -Encoding UTF8 | Select-Object -Skip 1

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

# Mismo orden que AREAS en el HTML: Almacén, Administración, Postventa, Operaciones
$areas = @(
  (Get-AreaData -CsvPath $AlmacenCsv -AreaName 'Almacén'),
  (Get-AreaData -CsvPath $AdminCsv -AreaName 'Administración'),
  (Get-AreaData -CsvPath $PostventaCsv -AreaName 'Postventa'),
  (Get-AreaData -CsvPath $OperacionesCsv -AreaName 'Operaciones')
)

$epson = @()
if ($EpsonJson -and (Test-Path $EpsonJson)) {
  $epson = @(Get-Content $EpsonJson -Raw | ConvertFrom-Json)
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
Set-Content -Path $OutputPath -Value $final -Encoding UTF8 -NoNewline

Write-Host "OK -> $OutputPath"
Write-Host ("Total paginas: {0}" -f ($areas | ForEach-Object { $_.totals.total } | Measure-Object -Sum).Sum)
foreach ($a in $areas) { Write-Host ("  {0}: {1} pag, {2} activos, equipo {3}" -f $a.area, $a.totals.total, $a.activos, $a.model) }
