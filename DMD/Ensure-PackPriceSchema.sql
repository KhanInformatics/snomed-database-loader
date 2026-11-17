-- Additive migration: safe to run against an existing dm+d database.
-- Amounts are stored exactly as supplied by dm+d; NULL and zero are distinct.
IF OBJECT_ID('dbo.ampp_price', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ampp_price (
        appid VARCHAR(18) NOT NULL PRIMARY KEY,
        price BIGINT NULL,
        pricedt DATE NULL,
        price_prev BIGINT NULL,
        price_basiscd VARCHAR(10) NOT NULL,
        CONSTRAINT FK_ampp_price_ampp FOREIGN KEY (appid) REFERENCES dbo.ampp(appid)
    );
END;

IF OBJECT_ID('dbo.vmpp_drugtariffinfo', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.vmpp_drugtariffinfo (
        vppid VARCHAR(18) NOT NULL PRIMARY KEY,
        pay_catcd VARCHAR(10) NOT NULL,
        price BIGINT NULL,
        dt DATE NULL,
        prevprice BIGINT NULL,
        CONSTRAINT FK_vmpp_drugtariffinfo_vmpp FOREIGN KEY (vppid) REFERENCES dbo.vmpp(vppid)
    );
END;
