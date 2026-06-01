# Suray Planilla

Aplicación Flutter para generar e imprimir planillas de boletos de bus de la empresa Suray.

## Funcionalidades

- **Planilla de boletos** — genera una grilla de 45 asientos (5 columnas × 9 filas) con numeración real del bus. Cada boleto muestra número de asiento, destino, horario de presentación, hora y fecha de salida.
- **Vista previa interactiva** — visor con zoom y paneo (InteractiveViewer) sobre la planilla, con controles de zoom desde la barra de estado.
- **Tamaño de papel** — soporte para A4 (210 × 297 mm) y Carta (215.9 × 279.4 mm).
- **Destino configurable** — permite seleccionar Coyhaique o Aysén.
- **Hora y fecha configurables** — selector de hora y calendario integrado para fijar la fecha del servicio.
- **Exportación e impresión** — genera un PDF listo para imprimir usando `package:printing`.
- **Tanda semanal** — vista de tanda por semana con colores diferenciados para lunes–viernes, sábado y domingo/feriado.
- **Gestión de horarios** — CRUD de horarios por tipo de día (lunes–viernes, sábado, domingo/feriado).
- **Feriados** — integración con servicio de feriados para marcar días especiales en la tanda.

## Tecnologías

- Flutter (Web / Desktop)
- `package:pdf` + `package:printing` para generación e impresión de PDF
- `CustomPainter` para el renderizado de la planilla
- **API de feriados del Gobierno de Chile** (`https://apis.digital.gob.cl/fl/feriados`) — fuente secundaria para obtener los feriados nacionales; se usa Nager Date como fuente primaria de respaldo
