-- ABRIR DOS ventanas de SSMS, ejecutar A y B con diferencia menor de 10 segundos.
-- PRIMERA PRUEBA v0: SOLO sobre base nueva ANTES de 01_integridad.sql.
-- SEGUNDA PRUEBA: ejecutar 01,02,03 y entonces cambiar @Version a 'NUEVA'.
USE BusRD;
GO
DECLARE @ViajeID INT=16000, @Asiento INT=1, @Version VARCHAR(10)='NUEVA', @ID INT;
-- Importante: 16000 es un valor ilustrativo, reemplazar por viaje Programado del grupo.
IF @Version='V0'
 EXEC dbo.sp_VenderBoleto_v0 @ViajeID=@ViajeID,@NumeroAsiento=@Asiento,@ClienteID=1000,@Canal='Web',@Metodo='Tarjeta';
ELSE
 EXEC dbo.sp_VenderBoleto @ViajeID=@ViajeID,@NumeroAsiento=@Asiento,@ClienteID=1000,@Canal='Web',@Metodo='Tarjeta',@BoletoID=@ID OUTPUT,@SimularDemora=1;
SELECT @ID AS BoletoCreado;
GO
