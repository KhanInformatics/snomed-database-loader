/*
    Creates the dedicated current Primary Care Domain supporting-products
    database. Keeping these snapshots outside SNOMEDCT avoids SQL Server
    Express's 10 GB per-database limit while leaving the legacy PCD tables
    untouched.

    Run with an account that can create databases. The loader itself needs
    db_owner (or equivalent DDL/DML rights) in PCD. Existing read-only callers
    use the explicit snomedreader grant below when that login is present.
*/

USE master;
GO

IF DB_ID(N'PCD') IS NULL
BEGIN
    CREATE DATABASE PCD;
END;
GO

ALTER DATABASE PCD SET RECOVERY SIMPLE;
ALTER DATABASE PCD SET AUTO_CLOSE OFF;
ALTER DATABASE PCD SET AUTO_SHRINK OFF;
ALTER DATABASE PCD SET PAGE_VERIFY CHECKSUM;
ALTER DATABASE PCD SET COMPATIBILITY_LEVEL = 160;
GO

USE PCD;
GO

IF SUSER_ID(N'snomedreader') IS NOT NULL
   AND USER_ID(N'snomedreader') IS NULL
BEGIN
    CREATE USER snomedreader FOR LOGIN snomedreader;
END;
GO

IF USER_ID(N'snomedreader') IS NOT NULL
BEGIN
    GRANT CONNECT TO snomedreader;
    -- Current-product views are granted individually by
    -- Create-PCD-Canonical-Consumers.sql after they exist. Do not expose the
    -- load-history or staging tables through a schema-wide grant.
    REVOKE SELECT ON SCHEMA::dbo FROM snomedreader;
END;
GO
