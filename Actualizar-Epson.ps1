<#
Consulta cada impresora Epson por su IP, actualiza la lectura del contador en
incoming/epson.json y sube el cambio a GitHub para que el robot haga el resto.

Uso (doble clic en Corte-Epson.bat, o desde PowerShell):
  .\Actualizar-Epson.ps1

Si ademas dejas los 4 CSV de Kyocera Net Viewer en la carpeta corte\ de este
repositorio, el script los sube en el MISMO commit (corte completo de un jalon).

IMPORTANTE: corre este script JUNTO con la subida de los CSV del corte (o justo
despues), nunca dias antes — la lectura Epson que sube queda amarrada al corte.
#>
param(
  [string]$RepoDir = $PSScriptRoot,
  [string]$CsvDir = (Join-Path $PSScriptRoot 'corte')
)

$ErrorActionPreference = 'Stop'
Set-Location $RepoDir
$env:GIT_TERMINAL_PROMPT = '1'

Write-Host "Trayendo lo mas reciente del repositorio..."
git pull --rebase origin main

# ---------- leer lecturas actuales de cada Epson ----------
$epsonPath = Join-Path $RepoDir 'incoming\epson.json'
$entries = @((Get-Content $epsonPath -Raw -Encoding UTF8 | ConvertFrom-Json) | ForEach-Object { $_ })
$hoy = Get-Date -Format 'dd/MM/yyyy'

foreach ($e in $entries) {
  $ip = ('' + $e.ip).Trim()
  if (-not $ip) { Write-Host "$($e.name): sin IP registrada, se deja tal cual."; continue }

  Write-Host "Consultando $($e.name) en $ip ..."
  $html = curl.exe -k -s --max-time 20 "https://$ip/PRESENTATION/ADVANCED/INFO_MENTINFO/TOP" 2>$null
  if (-not $html) { $html = curl.exe -s --max-time 20 "http://$ip/PRESENTATION/ADVANCED/INFO_MENTINFO/TOP" 2>$null }
  $texto = (($html -join ' ') -replace '<[^>]+>', ' ' -replace '&nbsp;', ' ' -replace '\s+', ' ')

  # ".{1,3}" en lugar de la a acentuada: segun la consola, el acento puede llegar
  # como uno o varios bytes y no debe romper la deteccion
  if ($texto -match 'total de p.{1,3}ginas\s*:\s*([\d,]+)') {
    $lectura = [int]($Matches[1] -replace ',', '')
    Write-Host ("  contador total: {0} (lectura anterior: {1})" -f $lectura, $e.lectura)
    $e | Add-Member -NotePropertyName lectura -NotePropertyValue $lectura -Force
    $e | Add-Member -NotePropertyName fecha -NotePropertyValue $hoy -Force
  } else {
    throw "No se pudo leer el contador de $($e.name) ($ip). Revisa que este encendida y conectada a la red."
  }
}

$json = if ($entries.Count -eq 1) { '[' + (ConvertTo-Json $entries[0] -Depth 5) + ']' }
        else { ConvertTo-Json @($entries) -Depth 5 }
[System.IO.File]::WriteAllText($epsonPath, $json, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "incoming/epson.json actualizado."

# ---------- CSVs del corte, si estan en corte\ ----------
$conCsvs = $false
if (Test-Path $CsvDir) {
  $areas = 'ALMACEN', 'ADMINISTRACION', 'POSTVENTA', 'OPERACIONES'
  foreach ($a in $areas) {
    $f = Get-ChildItem $CsvDir -Filter *.csv -File |
         Where-Object { $_.Name -match ('(?i)^' + $a) } | Select-Object -First 1
    if ($f) {
      # quita versiones viejas del area (p.ej. con espacios en el nombre) para
      # que el robot no tome un archivo equivocado
      Get-ChildItem (Join-Path $RepoDir 'incoming') -Filter *.csv -File |
        Where-Object { $_.Name -match ('(?i)^' + $a) } | Remove-Item -Force
      Copy-Item $f.FullName (Join-Path $RepoDir ('incoming\' + $a + '.csv')) -Force
      Write-Host "CSV del corte: $($f.Name) -> incoming/$a.csv"
      $conCsvs = $true
    }
  }
  if (-not $conCsvs) { Write-Host "(carpeta corte\ sin CSVs: se suben solo las lecturas Epson)" }
}

# ---------- etiqueta del periodo (solo en corte con CSVs) ----------
# Del corte anterior (fecha grabada dentro de los CSV de la linea base) a hoy.
if ($conCsvs) {
  $meses = 'ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'
  $baseCsv = Join-Path $RepoDir 'baseline\current\ALMACEN.csv'
  if (Test-Path $baseCsv) {
    $ult = Get-Content $baseCsv -Encoding UTF8 | Select-Object -Skip 1 -First 1
    $ts = (($ult -split '","')[-1] -replace '"', '').Trim()
    if ($ts -match '(\d{2})/(\d{2})/(\d{4})') {
      $dIni = [int]$Matches[1]; $mIni = [int]$Matches[2]; $aIni = [int]$Matches[3]
      $hoyD = Get-Date
      $per = "Corte $dIni $($meses[$mIni - 1])"
      if ($aIni -ne $hoyD.Year) { $per += " $aIni" }
      $per += " - $($hoyD.Day) $($meses[$hoyD.Month - 1]) $($hoyD.Year)"
      [System.IO.File]::WriteAllText((Join-Path $RepoDir 'incoming\periodo.txt'), $per, (New-Object System.Text.UTF8Encoding($false)))
      Write-Host "Periodo del reporte: $per"
    }
  }
}

# ---------- subir ----------
git add incoming/
$pendiente = git status --porcelain incoming
if (-not $pendiente) {
  Write-Host "Sin cambios que subir (lecturas iguales a las ya registradas)."
  exit 0
}
git -c core.safecrlf=false commit -m "Corte: lecturas Epson actualizadas automaticamente ($hoy)"
git push origin main

Write-Host ""
Write-Host "Listo. El robot de GitHub procesa el corte en 1-2 minutos y publica el reporte."
Write-Host "https://akm77-web.github.io/Reporte-de-imprecion-/"
