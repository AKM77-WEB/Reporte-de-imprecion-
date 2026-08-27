# Cómo actualizar el reporte cada mes (sin ayuda de nadie)

El reporte publicado en **https://akm77-web.github.io/Reporte-de-imprecion-/** se actualiza solo
cuando subes los CSV nuevos a la carpeta `incoming/` de este repositorio. Funciona desde cualquier
computadora o celular con tu cuenta de GitHub.

## Pasos

1. Exporta los 4 CSV desde Kyocera Net Viewer (uno por área), con estos nombres:
   - `ALMACEN.csv`
   - `ADMINISTRACION.csv`
   - `POSTVENTA.csv`
   - `OPERACIONES.csv`

   (Mayúsculas o minúsculas dan igual, pero el nombre debe **empezar** con la palabra del área.)

2. Entra a la carpeta [`incoming/`](https://github.com/AKM77-WEB/Reporte-de-imprecion-/tree/main/incoming)
   de este repositorio.

3. Clic en **Add file → Upload files**, arrastra los 4 CSV y clic en **Commit changes**.
   (Si ya existían archivos con el mismo nombre, se reemplazan — así debe ser.)

4. Espera 1 o 2 minutos. Un robot (pestaña **Actions**) procesa los CSV, regenera el reporte,
   lo agrega al historial y lo publica. El link es siempre el mismo.

## Ya NO hace falta reiniciar los contadores de las impresoras

El robot guarda una copia de los CSV de cada corte en la carpeta `baseline/` (no la toques).
Cuando subes los CSV del corte nuevo, el consumo del periodo se calcula solo:

> **consumo del mes = contador actual − contador del corte anterior**, persona por persona.

Es decir: exporta los CSV el día del corte y súbelos, aunque los contadores vengan acumulados
desde hace meses. Detalles:

- Si una impresora **sí** se reinició a la mitad del periodo, el robot lo detecta
  (el contador actual sale menor que el del corte anterior) y usa el contador tal cual.
- Volver a correr el robot con los **mismos** CSV (por ejemplo para corregir el texto del
  periodo) no descompone nada: usa la línea base del corte anterior y salen los mismos números.
- La línea base actual es la foto de los contadores del **12 de agosto de 2026** (el corte
  pasado), así que el siguiente reporte cubrirá del 12 de agosto a la fecha en que exportes.

## El periodo (nombre del mes en el reporte)

- Si no haces nada, el robot usa el mes y año actuales, por ejemplo: **"Agosto 2026"**.
- Si quieres otro texto (por ejemplo "Corte 15 jul – 15 ago 2026"), edita el archivo
  [`incoming/periodo.txt`](https://github.com/AKM77-WEB/Reporte-de-imprecion-/blob/main/incoming/periodo.txt)
  (lápiz ✏️ → escribe el texto → Commit changes) **antes** de subir los CSV,
  o vuelve a correr el robot después (pestaña Actions → "Generar reporte" → Run workflow).

## Impresoras Epson (opcional)

Si quieres incluir las Epson a color, crea o edita el archivo `incoming/epson.json` con este formato:

```json
[
  { "name": "Recepción", "pages": 350, "fecha": "15/08/2026", "costPerPage": 0.25, "costPeriod": 87.50 }
]
```

Si no existe ese archivo, el reporte sale solo con las Kyocera (normal).

## Si algo sale mal

- Pestaña **Actions** del repositorio → el último "Generar reporte" en rojo te dice qué faltó
  (casi siempre: falta uno de los 4 CSV o el nombre no empieza con la palabra del área).
- Corriges y vuelves a subir; el robot se corre de nuevo solo.
