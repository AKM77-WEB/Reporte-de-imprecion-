@echo off
chcp 65001 >nul
rem Doble clic: consulta en vivo las Epson a color y muestra lo impreso
rem desde la ultima lectura registrada. Solo lee, no cambia nada.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Consultar-Color.ps1"
pause
