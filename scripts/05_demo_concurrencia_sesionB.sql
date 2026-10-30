-- EJECUTAR casi a la vez que sesion A (preferentemente durante WAITFOR de A).
-- Alinear viaje/asiento/version de ambas ventanas. Debe ser asiento libre al empezar.
USE BusRD;
GO
DECLARE @ViajeID INT=16000, @Asiento INT=1, @Version VARCHAR(10)='NUEVA', @ID INT;
IF @Version='V0'
 EXEC dbo.sp_VenderBoleto_v0 @ViajeID=@ViajeID,@NumeroAsiento=@Asiento,@ClienteID=2000,@Canal='Taquilla',@Metodo='Efectivo';
ELSE
 EXEC dbo.sp_VenderBoleto @ViajeID=@ViajeID,@NumeroAsiento=@Asiento,@ClienteID=2000,@Canal='Taquilla',@Metodo='Efectivo',@BoletoID=@ID OUTPUT,@SimularDemora=0;
SELECT @ID AS BoletoCreado;
GO
-- En tercera ventana, o después de terminar ambas:
-- SELECT ViajeID,NumeroAsiento,COUNT(*) Activos FROM dbo.Boletos
-- WHERE ViajeID=<ID_REAL> AND NumeroAsiento=<ASIENTO_REAL> AND Estado='Activo'
-- GROUP BY ViajeID,NumeroAsiento;
