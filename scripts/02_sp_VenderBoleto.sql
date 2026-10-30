USE BusRD;
GO
CREATE OR ALTER PROCEDURE dbo.sp_VenderBoleto
 @ViajeID INT, @NumeroAsiento INT, @ClienteID INT,
 @Canal VARCHAR(10), @Metodo VARCHAR(15),
 @BoletoID INT OUTPUT, @SimularDemora BIT = 0
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 SET @BoletoID = NULL;
 DECLARE @Precio DECIMAL(10,2), @AutobusID INT, @Estado VARCHAR(15);
 IF @Canal IS NULL OR @Canal NOT IN ('Taquilla','Web') THROW 51101,'Canal invalido.',1;
 IF @Metodo IS NULL OR @Metodo NOT IN ('Efectivo','Tarjeta','Transferencia') THROW 51102,'Metodo invalido.',1;
 BEGIN TRY
   BEGIN TRAN;
   SELECT @AutobusID=v.AutobusID,@Estado=v.Estado,@Precio=r.PrecioBase
   FROM dbo.Viajes v JOIN dbo.Rutas r ON r.RutaID=v.RutaID WHERE v.ViajeID=@ViajeID;
   IF @AutobusID IS NULL THROW 51103,'El viaje no existe.',1;
   IF @Estado<>'Programado' THROW 51104,'El viaje no esta Programado.',1;
   IF NOT EXISTS (SELECT 1 FROM dbo.Asientos WHERE AutobusID=@AutobusID AND NumeroAsiento=@NumeroAsiento)
     THROW 51105,'El asiento no pertenece al autobus del viaje.',1;
   IF NOT EXISTS (SELECT 1 FROM dbo.Clientes WHERE ClienteID=@ClienteID)
     THROW 51106,'El cliente no existe.',1;
   -- SERIALIZABLE + UPDLOCK mantiene el bloqueo de rango hasta COMMIT;
   -- UX_Boletos_Viaje_Asiento_Activo es barrera adicional de integridad.
   IF EXISTS(SELECT 1 FROM dbo.Boletos WITH(UPDLOCK,HOLDLOCK,INDEX(UX_Boletos_Viaje_Asiento_Activo))
     WHERE ViajeID=@ViajeID AND NumeroAsiento=@NumeroAsiento AND Estado='Activo')
       THROW 51107,'El asiento ya esta vendido.',1;
   IF @SimularDemora=1 WAITFOR DELAY '00:00:10';
   INSERT dbo.Boletos(ViajeID,NumeroAsiento,ClienteID,FechaVenta,Canal,Precio,Estado)
   VALUES(@ViajeID,@NumeroAsiento,@ClienteID,SYSDATETIME(),@Canal,@Precio,'Activo');
   SET @BoletoID=CONVERT(INT,SCOPE_IDENTITY());
   INSERT dbo.Pagos(BoletoID,Monto,Metodo,FechaPago)
   VALUES(@BoletoID,@Precio,@Metodo,SYSDATETIME());
   COMMIT TRAN;
 END TRY
 BEGIN CATCH
   IF @@TRANCOUNT>0 ROLLBACK TRAN;
   SET @BoletoID=NULL;
   THROW;
 END CATCH
END;
GO
