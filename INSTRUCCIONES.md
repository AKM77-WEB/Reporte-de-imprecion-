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

## Impresoras Epson (opcional) — con la lectura de su página web

Las Epson muestran su **contador total de vida** al entrar a su dirección IP desde el
navegador (el número acumulado desde que se compró). Solo apunta ese número: el robot
guarda la lectura de cada corte y calcula lo del mes restando la lectura anterior,
igual que con las Kyocera. **No hay que reiniciar nada.**

Crea o edita `incoming/epson.json` con este formato (una entrada por impresora):

```json
[
  {
    "name": "Recepción",
    "ip": "192.168.1.50",
    "lectura": 15230,
    "fecha": "15/09/2026",
    "costoKit": 450.00,
    "rendimientoKit": 1800
  }
]
```

- `lectura`: el contador total que muestra la impresora en su página (por IP).
- `costoKit` y `rendimientoKit`: lo que cuesta el kit de tinta y cuántas páginas rinde;
  con eso se calcula el costo por página (también se acepta `costPerPage` directo).
- La **primera vez** que registras una impresora, ese mes sale con 0 páginas: la lectura
  solo queda guardada como base, y a partir del siguiente corte ya se calcula solo.
  Puedes hacer ese primer registro cualquier día, no hace falta esperar al corte.
- Si una Epson se reinicia o se reemplaza (la lectura sale menor que la anterior),
  el robot lo detecta y usa la lectura tal cual.
- El reporte muestra además el contador de vida y el gasto estimado de tinta de toda
  la vida útil de cada impresora, y cada corte queda en el historial.

En cada corte solo actualizas `lectura` (y `fecha`) de cada impresora **junto con los CSV
del corte o justo después de subirlos** (nunca días antes: la lectura queda amarrada al
corte con el que se sube). Si no existe `incoming/epson.json`, el reporte sale solo con
las Kyocera (normal).

## Recordatorio automático cada día 15

En la computadora de la oficina hay una tarea programada de Windows
(**"Corte reporte impresion"**, día 15 a las 9:00) que ejecuta `Corte-Programado.ps1`:
avisa con una ventana que es día de corte, abre la carpeta `corte\` y queda esperando.
Solo exportas los 4 CSV desde Kyocera Net Viewer a esa carpeta y el resto es solo:
lee las Epson por IP, arma la etiqueta del periodo (del corte anterior a hoy) y sube
todo en un commit. Si ese día la compu estuvo apagada, corre el corte a mano con
`Corte-Epson.bat` cuando puedas.

## Corte automático desde la computadora (recomendado)

En la copia del repositorio en la computadora de la oficina está **`Corte-Epson.bat`**:
con doble clic, el script consulta cada Epson por su IP, lee el contador solo, actualiza
`incoming/epson.json` y lo sube a GitHub. Nada que teclear.

Y mejor todavía: si antes de dar doble clic dejas los 4 CSV de Kyocera Net Viewer en la
carpeta `corte\` del repositorio, el script sube **todo el corte en un solo paso**
(CSVs + lecturas Epson) y el robot publica el reporte completo.

La impresora debe estar encendida y en red. Registrada hasta ahora:

| Impresora | IP | Tinta | Rendimiento usado |
|---|---|---|---|
| Administración (L6270) | 120.200.124.1 | Kit T504 ($900) | 6,000 pág. por kit (≈ $0.15/pág.) |

*(El rendimiento oficial del kit T504 es 7,500 pág. el negro y 6,000 pág. los colores;
como esta impresora imprime ~85% a color, se usa 6,000.)*

## Si algo sale mal

- Pestaña **Actions** del repositorio → el último "Generar reporte" en rojo te dice qué faltó
  (casi siempre: falta uno de los 4 CSV o el nombre no empieza con la palabra del área).
- Corriges y vuelves a subir; el robot se corre de nuevo solo.
