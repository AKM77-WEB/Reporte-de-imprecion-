@echo off
rem Doble clic para actualizar las lecturas Epson (y subir los CSV de corte\ si los hay)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Actualizar-Epson.ps1"
pause
