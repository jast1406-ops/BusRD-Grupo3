USE BusRD;
GO
CREATE OR ALTER PROCEDURE dbo.sp_AnularBoleto @BoletoID INT
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 DECLARE @Estado VARCHAR(10), @Saldo DECIMAL(12,2), @Metodo VARCHAR(15);
 BEGIN TRY
  BEGIN TRAN;
  SELECT @Estado=Estado FROM dbo.Boletos WITH(UPDLOCK,HOLDLOCK) WHERE BoletoID=@BoletoID;
  IF @Estado IS NULL THROW 51201,'El boleto no existe.',1;
  IF @Estado<>'Activo' THROW 51202,'El boleto ya esta anulado.',1;
  SELECT @Saldo=COALESCE(SUM(Monto),0) FROM dbo.Pagos WITH(UPDLOCK,HOLDLOCK) WHERE BoletoID=@BoletoID;
  IF @Saldo<=0 THROW 51203,'El boleto no tiene saldo positivo para reversar.',1;
  SELECT TOP(1) @Metodo=Metodo FROM dbo.Pagos WHERE BoletoID=@BoletoID AND Monto>0 ORDER BY FechaPago,PagoID;
  UPDATE dbo.Boletos SET Estado='Anulado' WHERE BoletoID=@BoletoID;
  INSERT dbo.Pagos(BoletoID,Monto,Metodo,FechaPago) VALUES(@BoletoID,-@Saldo,@Metodo,SYSDATETIME());
  COMMIT TRAN;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK TRAN; THROW; END CATCH
END;
GO
