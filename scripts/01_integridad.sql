USE BusRD;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
-- Guardar resultado de los diagnósticos como evidencia ANTES de limpiar.
SELECT ViajeID, NumeroAsiento, COUNT(*) Cantidad
FROM dbo.Boletos WHERE Estado='Activo'
GROUP BY ViajeID, NumeroAsiento HAVING COUNT(*)>1;
SELECT p.* FROM dbo.Pagos p LEFT JOIN dbo.Boletos b ON b.BoletoID=p.BoletoID
WHERE b.BoletoID IS NULL;
-- Diagnósticos adicionales: otras relaciones huérfanas, identificadores repetidos y dominios.
SELECT Cedula, COUNT(*) N FROM dbo.Clientes GROUP BY Cedula HAVING COUNT(*)>1;
SELECT Placa, COUNT(*) N FROM dbo.Autobuses GROUP BY Placa HAVING COUNT(*)>1;
SELECT b.BoletoID FROM dbo.Boletos b LEFT JOIN dbo.Viajes v ON v.ViajeID=b.ViajeID WHERE v.ViajeID IS NULL;
SELECT b.BoletoID FROM dbo.Boletos b LEFT JOIN dbo.Clientes c ON c.ClienteID=b.ClienteID WHERE c.ClienteID IS NULL;
SELECT b.BoletoID FROM dbo.Boletos b JOIN dbo.Viajes v ON v.ViajeID=b.ViajeID
LEFT JOIN dbo.Asientos a ON a.AutobusID=v.AutobusID AND a.NumeroAsiento=b.NumeroAsiento
WHERE a.NumeroAsiento IS NULL;
GO
BEGIN TRY
 BEGIN TRAN;
 -- Regla: conservar el boleto activo más antiguo (desempate: BoletoID menor).
 -- Los demás pasan a Anulado y se les registra reverso si hay saldo positivo.
 IF OBJECT_ID('tempdb..#DuplicadosAnulados') IS NOT NULL DROP TABLE #DuplicadosAnulados;
 SELECT BoletoID INTO #DuplicadosAnulados
 FROM (SELECT BoletoID, ROW_NUMBER() OVER(PARTITION BY ViajeID, NumeroAsiento
 ORDER BY FechaVenta ASC, BoletoID ASC) rn
 FROM dbo.Boletos WHERE Estado='Activo') q WHERE rn>1;
 UPDATE b SET Estado='Anulado' FROM dbo.Boletos b JOIN #DuplicadosAnulados d ON d.BoletoID=b.BoletoID;
 -- Reversar monto neto pagado por cada boleto anulado (si es positivo).
 INSERT dbo.Pagos(BoletoID,Monto,Metodo,FechaPago)
 SELECT p.BoletoID,-SUM(p.Monto),'Transferencia',SYSDATETIME()
 FROM dbo.Pagos p JOIN #DuplicadosAnulados d ON d.BoletoID=p.BoletoID
 GROUP BY p.BoletoID HAVING SUM(p.Monto)>0;
 -- Archivar los pagos huérfanos antes de borrarlos: no hay boleto al cual asociarlos.
 IF OBJECT_ID('dbo.PagosHuerfanosAuditoria','U') IS NULL
 CREATE TABLE dbo.PagosHuerfanosAuditoria(
   PagoID INT NOT NULL PRIMARY KEY, BoletoID INT NOT NULL,
   Monto DECIMAL(10,2) NOT NULL, Metodo VARCHAR(15) NOT NULL,
   FechaPago DATETIME2(0) NOT NULL, FechaDeteccion DATETIME2(0) NOT NULL DEFAULT SYSDATETIME());
 INSERT dbo.PagosHuerfanosAuditoria(PagoID,BoletoID,Monto,Metodo,FechaPago)
 SELECT p.PagoID,p.BoletoID,p.Monto,p.Metodo,p.FechaPago
 FROM dbo.Pagos p LEFT JOIN dbo.Boletos b ON b.BoletoID=p.BoletoID
 WHERE b.BoletoID IS NULL AND NOT EXISTS(SELECT 1 FROM dbo.PagosHuerfanosAuditoria a WHERE a.PagoID=p.PagoID);
 DELETE p FROM dbo.Pagos p LEFT JOIN dbo.Boletos b ON b.BoletoID=p.BoletoID WHERE b.BoletoID IS NULL;
 -- Rechazar inconsistencias no previstas para NO ocultarlas.
 IF EXISTS (SELECT 1 FROM dbo.Clientes GROUP BY Cedula HAVING COUNT(*)>1)
   THROW 51001,'Existen cedulas repetidas sin regla de consolidacion aprobada.',1;
 IF EXISTS (SELECT 1 FROM dbo.Autobuses GROUP BY Placa HAVING COUNT(*)>1)
   THROW 51002,'Existen placas repetidas sin regla de consolidacion aprobada.',1;
 IF EXISTS (SELECT 1 FROM dbo.Boletos b LEFT JOIN dbo.Viajes v ON v.ViajeID=b.ViajeID WHERE v.ViajeID IS NULL)
   THROW 51003,'Existen boletos con viaje inexistente.',1;
 IF EXISTS (SELECT 1 FROM dbo.Boletos b LEFT JOIN dbo.Clientes c ON c.ClienteID=b.ClienteID WHERE c.ClienteID IS NULL)
   THROW 51004,'Existen boletos con cliente inexistente.',1;
 IF EXISTS (SELECT 1 FROM dbo.Boletos b JOIN dbo.Viajes v ON v.ViajeID=b.ViajeID
 LEFT JOIN dbo.Asientos a ON a.AutobusID=v.AutobusID AND a.NumeroAsiento=b.NumeroAsiento
 WHERE a.NumeroAsiento IS NULL)
   THROW 51005,'Existen boletos con asiento fuera del autobus.',1;
 -- Claves foráneas; la FK compuesta de Asientos refuerza el vínculo autobús/asiento.
 ALTER TABLE dbo.Asientos WITH CHECK ADD CONSTRAINT FK_Asientos_Autobuses FOREIGN KEY(AutobusID) REFERENCES dbo.Autobuses(AutobusID);
 ALTER TABLE dbo.Viajes WITH CHECK ADD CONSTRAINT FK_Viajes_Rutas FOREIGN KEY(RutaID) REFERENCES dbo.Rutas(RutaID);
 ALTER TABLE dbo.Viajes WITH CHECK ADD CONSTRAINT FK_Viajes_Autobuses FOREIGN KEY(AutobusID) REFERENCES dbo.Autobuses(AutobusID);
 ALTER TABLE dbo.Boletos WITH CHECK ADD CONSTRAINT FK_Boletos_Viajes FOREIGN KEY(ViajeID) REFERENCES dbo.Viajes(ViajeID);
 ALTER TABLE dbo.Boletos WITH CHECK ADD CONSTRAINT FK_Boletos_Clientes FOREIGN KEY(ClienteID) REFERENCES dbo.Clientes(ClienteID);
 ALTER TABLE dbo.Pagos WITH CHECK ADD CONSTRAINT FK_Pagos_Boletos FOREIGN KEY(BoletoID) REFERENCES dbo.Boletos(BoletoID);
 ALTER TABLE dbo.Autobuses WITH CHECK ADD CONSTRAINT CK_Autobuses_Tipo CHECK(Tipo IN ('Estandar','Ejecutivo'));
 ALTER TABLE dbo.Autobuses WITH CHECK ADD CONSTRAINT CK_Autobuses_Capacidad CHECK((Tipo='Estandar' AND Capacidad=44) OR (Tipo='Ejecutivo' AND Capacidad=32));
 ALTER TABLE dbo.Rutas WITH CHECK ADD CONSTRAINT CK_Rutas_Precio CHECK(PrecioBase>0);
 ALTER TABLE dbo.Rutas WITH CHECK ADD CONSTRAINT CK_Rutas_Distancia CHECK(DistanciaKm>0);
 ALTER TABLE dbo.Viajes WITH CHECK ADD CONSTRAINT CK_Viajes_Estado CHECK(Estado IN ('Programado','Completado','Cancelado'));
 ALTER TABLE dbo.Boletos WITH CHECK ADD CONSTRAINT CK_Boletos_Estado CHECK(Estado IN ('Activo','Anulado'));
 ALTER TABLE dbo.Boletos WITH CHECK ADD CONSTRAINT CK_Boletos_Canal CHECK(Canal IN ('Taquilla','Web'));
 ALTER TABLE dbo.Boletos WITH CHECK ADD CONSTRAINT CK_Boletos_Precio CHECK(Precio>0);
 ALTER TABLE dbo.Pagos WITH CHECK ADD CONSTRAINT CK_Pagos_Metodo CHECK(Metodo IN ('Efectivo','Tarjeta','Transferencia'));
 ALTER TABLE dbo.Pagos WITH CHECK ADD CONSTRAINT CK_Pagos_Monto CHECK(Monto<>0);
 ALTER TABLE dbo.Asientos WITH CHECK ADD CONSTRAINT CK_Asientos_Ubicacion CHECK(Ubicacion IN ('Ventana','Pasillo'));
 ALTER TABLE dbo.Asientos WITH CHECK ADD CONSTRAINT CK_Asientos_Numero CHECK(NumeroAsiento BETWEEN 1 AND 44);
 ALTER TABLE dbo.Clientes ADD CONSTRAINT UQ_Clientes_Cedula UNIQUE(Cedula);
 ALTER TABLE dbo.Autobuses ADD CONSTRAINT UQ_Autobuses_Placa UNIQUE(Placa);
 CREATE UNIQUE INDEX UX_Boletos_Viaje_Asiento_Activo ON dbo.Boletos(ViajeID,NumeroAsiento) WHERE Estado='Activo';
 COMMIT TRAN;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK TRAN;
 THROW;
END CATCH;
GO
SELECT COUNT(*) DuplicadosPersistentes FROM (
 SELECT ViajeID,NumeroAsiento FROM dbo.Boletos WHERE Estado='Activo'
 GROUP BY ViajeID,NumeroAsiento HAVING COUNT(*)>1) x;
SELECT COUNT(*) PagosHuerfanosPersistentes FROM dbo.Pagos p LEFT JOIN dbo.Boletos b ON b.BoletoID=p.BoletoID WHERE b.BoletoID IS NULL;
SELECT COUNT(*) PagosArchivados FROM dbo.PagosHuerfanosAuditoria;
GO
