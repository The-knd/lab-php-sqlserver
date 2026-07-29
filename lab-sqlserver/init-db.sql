IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'laboratorio')
BEGIN
    CREATE DATABASE laboratorio;
END
GO

USE laboratorio;
GO

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'test_connectivity')
BEGIN
    CREATE TABLE test_connectivity (
        id INT IDENTITY(1,1) PRIMARY KEY,
        php_version NVARCHAR(20),
        driver_version NVARCHAR(50),
        connected_at DATETIME DEFAULT GETDATE()
    );
END
GO
