# BusRD — Proyecto final ISW-323

## Archivos y modo de ejecución

**Motor:** SQL Server 2022; **cliente:** SSMS (NO MySQL).

1. Ejecutar `originales/01_BusRD_base(1).sql` para crear base. **ADVERTENCIA:** este archivo destruye y vuelve a crear BusRD si ya existe; respaldar primero cualquier trabajo.
2. Ejecutar `originales/02_sp_VenderBoleto_v0(1).sql`.
3. Antes de añadir restricciones, hacer **demostración de doble venta v0** en dos sesiones con `scripts/04_demo_concurrencia_sesionA.sql` y `05_demo_concurrencia_sesionB.sql`, sustituyendo el viaje, asiento, clientes y `@Version='V0'`. Seleccionar viaje `Programado` y asiento realmente libre, capturar SELECT de duplicados.
4. Para evaluación de rendimiento, medir las consultas originales del script 03, con viaje y cédula del grupo, antes de agregar índices; guardar planes reales y STATISTICS IO/TIME. Capturar mediciones repetidas para reducir ruido.
5. Ejecutar `scripts/01_integridad.sql`, `02_sp_VenderBoleto.sql`, `03_sp_AnularBoleto.sql`. Estos scripts suponen base ORIGINAL sin restricciones previamente agregadas; para reejecutar 01, iniciar nuevamente sobre base limpia.
6. Repetir demo A/B con **un asiento libre distinto**, `@Version='NUEVA'`, `@SimularDemora=1` en A. Capturar bloqueo, error de B, SELECT de un solo boleto activo.
7. Ejecutar `06_indices_y_consultas_optimizadas.sql` tras capturar baseline. Comparar resultados con EXCEPT en ambas direcciones y registrar métricas.
8. Ejecutar `07_seguridad.sql` para crear roles, vistas y usuarios. Capturar los accesos efectivos y denegados. `rol_admin` es db_owner; los accesos denegados no son coherentes con ese alcance.
9. Seguir **por bloques** la plantilla `08_respaldo_y_restauracion.sql`; editar identificadores y rutas de archivos reales. No ejecutar borrado sin respaldos válidos.

## Datos asignados
- Grupo: **PENDIENTE**
- Viaje asignado: **PENDIENTE**, elegir `Programado` para la venta.
- Cliente C2: ClienteID = grupo × 1000; Cédula calculada como 402 + ocho dígitos.
- Integrantes y aportes: **PENDIENTE**.

## Evidencias que solo se obtienen ejecutando SSMS
Antes/después de cada consulta: capturas del plan real, lecturas lógicas y CPU. Dos ventanas para concurrencia v0/nueva. Seguridad: pruebas SELECT y permisos rechazados. Respaldo: mensajes de BACKUP/RESTORE y verificación de los 8 IDs.

## Precauciones y límites
Los scripts están preparados por análisis estático: **no se han ejecutado en SQL Server** desde este entorno. El material incluye las consultas de diagnóstico y acciones de prueba, pero no simula resultados ni capturas. Los nombres de archivos de backup y las rutas son ejemplos. La cobertura total de FK a asientos físicos del viaje requiere además una regla cruzada entre Viajes/Boletos/Asientos: el procedimiento verifica esta condición para las ventas; no existe una FK directa desde Boletos hasta Asientos porque no guarda AutobusID.

El PDF exige índice único filtrado, auditoría de huérfanos, rollback, comparativa de 3 consultas, pruebas de 3 roles y STOPAT. La clave de ejecución es probar **v0 antes de crear** el índice único filtrado.
