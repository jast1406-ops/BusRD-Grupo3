/* GUIA E5 - EJECUTAR POR BLOQUES, NO TODO DE UNA VEZ.
 Requisitos: carpeta C:\Backups\BusRD\ creada y accesible a la CUENTA DEL SERVICIO SQL SERVER;
 permisos BACKUP DATABASE/LOG y CREATE DATABASE; anotar hora, IDs y asiento.
 Tras pasar a FULL, el primer backup full inicia la cadena de log.
 No ejecutar DELETE si las fases previas no se verificaron correctamente.
 Los viajes futuros deben estar en Estado='Programado'.
*/
-- BLOQUE 1: backup FULL
USE master;
GO
ALTER DATABASE BusRD SET RECOVERY FULL;
GO
BACKUP DATABASE BusRD TO DISK='C:\Backups\BusRD\BusRD_full.bak'
WITH INIT, CHECKSUM, NAME='BusRD Full inicial';
GO
-- BLOQUE 2: ejecutar y documentar 5 ventas de asientos libres por sp_VenderBoleto
-- Ejemplo de UNA venta, repetir con distintos asientos (NO repetir el mismo asiento).
/*
USE BusRD;
DECLARE @Nuevo INT;
EXEC dbo.sp_VenderBoleto @ViajeID=REEMPLAZAR,@NumeroAsiento=REEMPLAZAR,
@ClienteID=1000,@Canal='Taquilla',@Metodo='Efectivo',@BoletoID=@Nuevo OUTPUT;
SELECT @Nuevo AS BoletoCreado;
*/
-- BLOQUE 3: backup DIFERENCIAL (después de las cinco ventas)
/*
BACKUP DATABASE BusRD TO DISK='C:\Backups\BusRD\BusRD_diff.bak'
WITH DIFFERENTIAL, INIT, CHECKSUM, NAME='BusRD Diferencial 5 ventas';
*/
-- BLOQUE 4: 3 ventas más, apuntar ocho BoletoID
-- BLOQUE 5: backup LOG y anotar instante EXACTO inmediatamente antes del DELETE
/*
BACKUP LOG BusRD TO DISK='C:\Backups\BusRD\BusRD_log1.trn'
WITH INIT, CHECKSUM, NAME='BusRD Log tras 8 ventas';
USE BusRD;
SELECT SYSDATETIME() AS HoraAnteriorDelete;
-- Guardar valor y garantizar que no se hace DELETE en ese mismo segundo.
WAITFOR DELAY '00:00:03';
BEGIN TRAN;
DELETE FROM dbo.Pagos WHERE BoletoID IN(SELECT BoletoID FROM dbo.Boletos WHERE ViajeID=REEMPLAZAR);
DELETE FROM dbo.Boletos WHERE ViajeID=REEMPLAZAR;
COMMIT;
*/
-- IMPORTANTE: FK exige borrar pagos del viaje primero. Esto simula pérdida accidental.
-- BLOQUE 6: backup de LOG final (cola) y dejar origen listo para restauración.
/*
USE master;
BACKUP LOG BusRD TO DISK='C:\Backups\BusRD\BusRD_log_cola.trn'
WITH INIT,CHECKSUM,NO_TRUNCATE,NAME='BusRD cola tras DELETE';
*/
-- BLOQUE 7: comprobar rutas físicas de datos y log con RESTORE FILELISTONLY;
-- reemplazar nombres lógicos y rutas MOVE de ejemplo por valores reales.
/*
RESTORE FILELISTONLY FROM DISK='C:\Backups\BusRD\BusRD_full.bak';
RESTORE DATABASE BusRD_Recuperada
 FROM DISK='C:\Backups\BusRD\BusRD_full.bak'
 WITH MOVE 'BusRD' TO 'C:\SQLData\BusRD_Recuperada.mdf',
      MOVE 'BusRD_log' TO 'C:\SQLData\BusRD_Recuperada_log.ldf',
      NORECOVERY,REPLACE;
RESTORE DATABASE BusRD_Recuperada
 FROM DISK='C:\Backups\BusRD\BusRD_diff.bak' WITH NORECOVERY;
RESTORE LOG BusRD_Recuperada
 FROM DISK='C:\Backups\BusRD\BusRD_log1.trn' WITH NORECOVERY;
RESTORE LOG BusRD_Recuperada
 FROM DISK='C:\Backups\BusRD\BusRD_log_cola.trn'
 WITH STOPAT='YYYY-MM-DDTHH:MM:SS',RECOVERY;
-- Validación: los 8 IDs deben existir y todos los boletos previos del viaje estar restaurados.
USE BusRD_Recuperada;
SELECT BoletoID,ViajeID,NumeroAsiento,Estado FROM dbo.Boletos WHERE BoletoID IN(1,2,3,4,5,6,7,8); -- sustituir IDs
*/
-- Nota técnica: para STOPAT en un backup, el tiempo debe ubicarse en la
-- cobertura de ese backup de log; si el instante cae dentro de log1,
-- aplicar STOPAT en log1 y NO restaurar cola.
