USE BusRD;
GO
CREATE OR ALTER VIEW dbo.vw_AsientosDisponibles AS
SELECT v.ViajeID,v.FechaSalida,r.Origen,r.Destino,s.NumeroAsiento,s.Ubicacion
FROM dbo.Viajes v JOIN dbo.Rutas r ON r.RutaID=v.RutaID
JOIN dbo.Asientos s ON s.AutobusID=v.AutobusID
WHERE v.Estado='Programado' AND NOT EXISTS
(SELECT 1 FROM dbo.Boletos b WHERE b.ViajeID=v.ViajeID AND b.NumeroAsiento=s.NumeroAsiento AND b.Estado='Activo');
GO
CREATE OR ALTER VIEW dbo.vw_VentasMensuales AS
SELECT r.Origen,r.Destino,YEAR(b.FechaVenta) Anio,MONTH(b.FechaVenta) Mes,
 COUNT_BIG(*) Boletos, SUM(p.Monto) Ingresos
FROM dbo.Boletos b JOIN dbo.Pagos p ON p.BoletoID=b.BoletoID
JOIN dbo.Viajes v ON v.ViajeID=b.ViajeID JOIN dbo.Rutas r ON r.RutaID=v.RutaID
WHERE b.Estado='Activo'
GROUP BY r.Origen,r.Destino,YEAR(b.FechaVenta),MONTH(b.FechaVenta);
GO
IF DATABASE_PRINCIPAL_ID('rol_taquilla') IS NULL CREATE ROLE rol_taquilla;
IF DATABASE_PRINCIPAL_ID('rol_reportes') IS NULL CREATE ROLE rol_reportes;
IF DATABASE_PRINCIPAL_ID('rol_admin') IS NULL CREATE ROLE rol_admin;
IF DATABASE_PRINCIPAL_ID('usr_taquilla') IS NULL CREATE USER usr_taquilla WITHOUT LOGIN;
IF DATABASE_PRINCIPAL_ID('usr_reportes') IS NULL CREATE USER usr_reportes WITHOUT LOGIN;
IF DATABASE_PRINCIPAL_ID('usr_admin') IS NULL CREATE USER usr_admin WITHOUT LOGIN;
ALTER ROLE rol_taquilla ADD MEMBER usr_taquilla;
ALTER ROLE rol_reportes ADD MEMBER usr_reportes;
ALTER ROLE rol_admin ADD MEMBER usr_admin;
GRANT EXECUTE ON dbo.sp_VenderBoleto TO rol_taquilla;
GRANT EXECUTE ON dbo.sp_AnularBoleto TO rol_taquilla;
GRANT SELECT ON dbo.vw_AsientosDisponibles TO rol_taquilla;
GRANT SELECT ON dbo.vw_VentasMensuales TO rol_reportes;
ALTER ROLE db_owner ADD MEMBER rol_admin;
GO
-- Pruebas: al menos 2 permitidas y 2 denegadas POR rol, capturar mensajes.
-- Ejecutar cada bloque independientemente, porque errores de permisos son esperados.
EXECUTE AS USER='usr_taquilla';
SELECT TOP(3) * FROM dbo.vw_AsientosDisponibles; -- permitido 1
SELECT HAS_PERMS_BY_NAME('dbo.sp_VenderBoleto','OBJECT','EXECUTE') VenderPermitido; -- permitido 2 (derecho efectivo)
SELECT HAS_PERMS_BY_NAME('dbo.Boletos','OBJECT','SELECT') LeerBoletosDenegado; -- denegado 1
SELECT HAS_PERMS_BY_NAME('dbo.Clientes','OBJECT','UPDATE') ActualizarClientesDenegado; -- denegado 2
REVERT;
GO
EXECUTE AS USER='usr_reportes';
SELECT TOP(3) * FROM dbo.vw_VentasMensuales; -- permitido 1
SELECT HAS_PERMS_BY_NAME('dbo.vw_VentasMensuales','OBJECT','SELECT') VerReportePermitido; -- permitido 2
SELECT HAS_PERMS_BY_NAME('dbo.Clientes','OBJECT','SELECT') VerClientesDenegado; -- denegado 1
SELECT HAS_PERMS_BY_NAME('dbo.sp_AnularBoleto','OBJECT','EXECUTE') AnularDenegado; -- denegado 2
REVERT;
GO
EXECUTE AS USER='usr_admin';
SELECT TOP(3) * FROM dbo.Clientes; -- permitido 1
SELECT TOP(3) * FROM dbo.Boletos; -- permitido 2
SELECT HAS_PERMS_BY_NAME('dbo.Clientes','OBJECT','DELETE') AdminBorrado; -- permitido
SELECT IS_ROLEMEMBER('db_owner') EsDbOwner; -- permitido
REVERT;
GO
-- rol_admin NO tiene dos accesos denegados a objetos de BusRD: es db_owner.
-- Documentarlo como incompatibilidad entre 'administración completa' y '2 denegados por rol'.
-- El principio de mínimo privilegio no recomienda DENY arbitrarios sobre db_owner.
