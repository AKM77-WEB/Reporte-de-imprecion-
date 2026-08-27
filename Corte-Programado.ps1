<#
Corre solo cada dia de corte (tarea programada de Windows "Corte reporte impresion").

1. Avisa con una ventana que hoy es dia de corte y abre la carpeta corte\.
2. Espera (hasta 6 horas) a que esten los 4 CSV de HOY exportados de Kyocera Net Viewer.
3. En cuanto estan, corre Actualizar-Epson.ps1: lee las Epson por IP, arma la etiqueta
   del periodo, y sube CSVs + lecturas en un solo commit. El robot publica el reporte.

Tambien se puede correr a mano cualquier dia (o usar Corte-Epson.bat directo si ya
tienes los CSV listos).
#>
param([string]$RepoDir = $PSScriptRoot)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms

$CsvDir = Join-Path $RepoDir 'corte'
if (-not (Test-Path $CsvDir)) { New-Item -ItemType Directory -Path $CsvDir | Out-Null }

$areas = 'ALMACEN', 'ADMINISTRACION', 'POSTVENTA', 'OPERACIONES'
function Test-EsArea([string]$nombre) {
  foreach ($a in $areas) { if ($nombre -match ('(?i)^' + $a)) { return $true } }
  return $false
}
function Get-Faltantes {
  # Un solo CSV combinado (todas las impresoras) exportado hoy tambien cuenta:
  # Actualizar-Epson.ps1 lo parte por impresora al subir.
  foreach ($f in (Get-ChildItem $CsvDir -Filter *.csv -File)) {
    if (-not (Test-EsArea $f.Name) -and $f.LastWriteTime.Date -eq (Get-Date).Date) { return @() }
  }
  $falta = @()
  foreach ($a in $areas) {
    $f = Get-ChildItem $CsvDir -Filter *.csv -File |
         Where-Object { $_.Name -match ('(?i)^' + $a) -and $_.LastWriteTime.Date -eq (Get-Date).Date } |
         Select-Object -First 1
    if (-not $f) { $falta += $a }
  }
  return $falta
}

if ((Get-Faltantes).Count -gt 0) {
  Start-Process explorer.exe $CsvDir
  [System.Windows.Forms.MessageBox]::Show(
    ("Hoy es dia de corte del reporte de impresion." + [Environment]::NewLine + [Environment]::NewLine +
     "Exporta desde Kyocera Net Viewer UN SOLO CSV de contadores con todas las impresoras (o los 4 por area, como prefieras) y guardalo en la carpeta que se acaba de abrir:" + [Environment]::NewLine +
     $CsvDir + [Environment]::NewLine + [Environment]::NewLine +
     "Este programa queda esperando: en cuanto esten los 4 archivos de hoy, lee las Epson por IP y sube todo solo."),
    'Corte del reporte de impresion',
    [System.Windows.Forms.MessageBoxButtons]::OK,
    [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
}

$limite = (Get-Date).AddHours(6)
while ($true) {
  $falta = Get-Faltantes
  if ($falta.Count -eq 0) { break }
  if ((Get-Date) -gt $limite) {
    [System.Windows.Forms.MessageBox]::Show(
      ("No aparecieron los CSV de hoy (faltan: " + ($falta -join ', ') + ")." + [Environment]::NewLine +
       "Cuando los tengas en la carpeta corte\, da doble clic a Corte-Epson.bat para subir el corte."),
      'Corte pendiente',
      [System.Windows.Forms.MessageBoxButtons]::OK,
      [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
    exit 1
  }
  Start-Sleep -Seconds 60
}

& (Join-Path $RepoDir 'Actualizar-Epson.ps1')

[System.Windows.Forms.MessageBox]::Show(
  ("Corte subido. El robot publica el reporte en 1 o 2 minutos:" + [Environment]::NewLine +
   "https://akm77-web.github.io/Reporte-de-imprecion-/"),
  'Corte completado',
  [System.Windows.Forms.MessageBoxButtons]::OK,
  [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
