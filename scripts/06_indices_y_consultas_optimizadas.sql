USE BusRD;
GO
-- PREVIO a ejecutar: guardar plan real (Ctrl+M) y STATISTICS IO/TIME
-- de las consultas ORIGINALES del archivo 03 docente sobre el mismo estado de datos.
-- C1: ya existe UX_Boletos_Viaje_Asiento_Activo de la fase E1.
-- C2: sustituir cedula por la correspondiente al numero de grupo.
CREATE INDEX IX_Boletos_Cliente_Viaje
 ON dbo.Boletos(ClienteID,ViajeID) INCLUDE(NumeroAsiento,Precio,Estado);
GO
-- C3: índice para el año 2025 con columna fecha sin funciones en el predicado.
CREATE INDEX IX_Boletos_Fecha_Activo
 ON dbo.Boletos(FechaVenta,ViajeID,BoletoID) WHERE Estado='Activo';
CREATE INDEX IX_Pagos_Boleto ON dbo.Pagos(BoletoID) INCLUDE(Monto);
GO
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
GO
-- C1: reemplazar por viaje asignado, NO 16000 de muestra.
DECLARE @ViajeID INT=16000;
SELECT s.NumeroAsiento,s.Ubicacion
FROM dbo.Viajes v JOIN dbo.Asientos s ON s.AutobusID=v.AutobusID
WHERE v.ViajeID=@ViajeID
AND NOT EXISTS (SELECT 1 FROM dbo.Boletos b WHERE b.ViajeID=@ViajeID
 AND b.NumeroAsiento=s.NumeroAsiento AND b.Estado='Activo')
ORDER BY s.NumeroAsiento;
GO
-- C2: ClienteID del grupo = numero de grupo * 1000; en base la cedula
-- fue generada como '402' + 8 digitos con cero a la izquierda.
DECLARE @NumeroGrupo INT=1;
DECLARE @Cedula CHAR(11)='402'+RIGHT('00000000'+CONVERT(VARCHAR(8),@NumeroGrupo*1000),8);
SELECT c.Nombre,c.Apellido,r.Origen,r.Destino,v.FechaSalida,b.NumeroAsiento,b.Precio,b.Estado
FROM dbo.Clientes c
JOIN dbo.Boletos b ON b.ClienteID=c.ClienteID
JOIN dbo.Viajes v ON v.ViajeID=b.ViajeID
JOIN dbo.Rutas r ON r.RutaID=v.RutaID
WHERE c.Cedula=@Cedula
ORDER BY v.FechaSalida DESC;
GO
-- C3: evita YEAR(FechaVenta), hace el filtro sargable.
SELECT r.Origen,r.Destino,MONTH(b.FechaVenta) Mes,
 COUNT(*) Boletos,SUM(p.Monto) Ingresos
FROM dbo.Boletos b
JOIN dbo.Pagos p ON p.BoletoID=b.BoletoID
JOIN dbo.Viajes v ON v.ViajeID=b.ViajeID
JOIN dbo.Rutas r ON r.RutaID=v.RutaID
WHERE b.FechaVenta>='20250101' AND b.FechaVenta<'20260101'
AND b.Estado='Activo'
GROUP BY r.Origen,r.Destino,MONTH(b.FechaVenta)
ORDER BY r.Origen,r.Destino,Mes;
GO
SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO
-- Validar igualdad original vs optimizada para C1, C2 y C3 con EXCEPT EN AMBOS SENTIDOS.
-- La salida de C3 preserva SUM de pagos incluida cualquier reversión registrada.
