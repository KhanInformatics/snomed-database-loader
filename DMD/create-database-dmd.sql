/* Create the DM+D (Dictionary of Medicines and Devices) database tables */
-- SQL Server script to create table structure for DM+D terminology
-- Based on NHS DM+D Data Model R2 v4.0 October 2024
-- Copyright 2025, licensed under GPL any version

-- Cannot drop database if you're already in it
USE master;
GO

IF EXISTS (SELECT name FROM sys.databases WHERE name = N'dmd')
BEGIN
    ALTER DATABASE dmd SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE dmd;
END
GO

CREATE DATABASE dmd;
GO

USE dmd;
GO

-- =====================================================
-- CORE DM+D ENTITY TABLES
-- =====================================================

-- Virtual Therapeutic Moiety (VTM)
-- The VTM represents the therapeutic moiety - the active ingredient(s) responsible for the therapeutic effect
-- Note: IDs stored as VARCHAR since they are identifiers, not numeric values
IF EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'vtm') DROP TABLE vtm;
CREATE TABLE vtm (
    vtmid VARCHAR(18) NOT NULL PRIMARY KEY,
    invalid BIT NOT NULL DEFAULT 0,
    nm NVARCHAR(255) NOT NULL,
    abbrevnm NVARCHAR(60),
    vtmidprev VARCHAR(18),
    vtmiddt DATE
);

-- Virtual Medical Product (VMP)
-- The VMP is a generic level of the medication hierarchy 
IF EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'vmp') DROP TABLE vmp;
CREATE TABLE vmp (
    vpid VARCHAR(18) NOT NULL PRIMARY KEY,
    vpiddt DATE,
    vpidprev VARCHAR(18),
    vtmid VARCHAR(18),
    invalid BIT NOT NULL DEFAULT 0,
    nm NVARCHAR(255) NOT NULL,
    abbrevnm NVARCHAR(60),
    basiscd VARCHAR(10),
    nmdt DATE,
    nmprev NVARCHAR(255),
    basis_prevcd VARCHAR(10),
    nmchangecd VARCHAR(10),
    comprodcd VARCHAR(10),
    pres_statcd VARCHAR(10),
    sug_f BIT NOT NULL DEFAULT 0,
    glu_f BIT NOT NULL DEFAULT 0,
    pres_f BIT NOT NULL DEFAULT 0,
    cfc_f BIT NOT NULL DEFAULT 0,
    non_availcd VARCHAR(10),
    non_availdt DATE,
    df_indcd VARCHAR(10),
    udfs DECIMAL(10,3),
    udfs_uomcd VARCHAR(18),
    unit_dose_uomcd VARCHAR(18),
    FOREIGN KEY (vtmid) REFERENCES vtm(vtmid)
);

-- Actual Medical Product (AMP)  
-- The AMP is a product level that is dispensable
IF EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'amp') DROP TABLE amp;
CREATE TABLE amp (
    apid VARCHAR(18) NOT NULL PRIMARY KEY,
    invalid BIT NOT NULL DEFAULT 0,
    vpid VARCHAR(18),
    nm NVARCHAR(255) NOT NULL,
    abbrevnm NVARCHAR(60),
    desc_f BIT NOT NULL DEFAULT 0,
    nmdt DATE,
    nm_prev NVARCHAR(255),
    suppcd VARCHAR(18),
    lic_authcd VARCHAR(10),
    lic_auth_prevcd VARCHAR(10),
    lic_authchangecd VARCHAR(10),
    lic_authchangedt DATE,
    combprodcd VARCHAR(10),
    flavourcd VARCHAR(10),
    ema_f BIT NOT NULL DEFAULT 0,
    parallel_import_f BIT NOT NULL DEFAULT 0,
    avail_restrictcd VARCHAR(10),
    FOREIGN KEY (vpid) REFERENCES vmp(vpid)
);

-- Virtual Medical Product Pack (VMPP)
-- The VMPP defines a pack size of a VMP
IF EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'vmpp') DROP TABLE vmpp;
CREATE TABLE vmpp (
    vppid VARCHAR(18) NOT NULL PRIMARY KEY,
    invalid BIT NOT NULL DEFAULT 0,
    nm NVARCHAR(500) NOT NULL,
    abbrevnm NVARCHAR(60),
    vpid VARCHAR(18),
    qtyval DECIMAL(10,3),
    qty_uomcd VARCHAR(18),
    combpackcd VARCHAR(10),
    FOREIGN KEY (vpid) REFERENCES vmp(vpid)
);

-- Actual Medical Product Pack (AMPP)
-- The AMPP defines a pack size of an AMP  
IF EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'ampp') DROP TABLE ampp;
CREATE TABLE ampp (
    appid VARCHAR(18) NOT NULL PRIMARY KEY,
    invalid BIT NOT NULL DEFAULT 0,
    vppid VARCHAR(18),
    apid VARCHAR(18),
    nm NVARCHAR(500) NOT NULL,
    abbrevnm NVARCHAR(60),
    legal_catcd VARCHAR(10),
    subp NVARCHAR(100),
    disccd VARCHAR(10),
    hosp_f BIT NOT NULL DEFAULT 0,
    broken_bulk_f BIT NOT NULL DEFAULT 0,
    nurse_f BIT NOT NULL DEFAULT 0,
    enurse_f BIT NOT NULL DEFAULT 0,
    dent_f BIT NOT NULL DEFAULT 0,
    prod_order_no NVARCHAR(20),
    FOREIGN KEY (vppid) REFERENCES vmpp(vppid),
    FOREIGN KEY (apid) REFERENCES amp(apid)
);

-- =====================================================
-- LOOKUP AND REFERENCE TABLES
-- =====================================================

-- Lookup tables for various coded fields
IF EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'lookup') DROP TABLE lookup;
CREATE TABLE lookup (
    type NVARCHAR(50) NOT NULL,
    cd NVARCHAR(20) NOT NULL,
    descr NVARCHAR(255) NOT NULL,
    PRIMARY KEY (type, cd)
);

-- Ingredient Substance Reference - Master list of ingredient substances
IF EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'ingredient') DROP TABLE ingredient;
CREATE TABLE ingredient (
    isid VARCHAR(18) NOT NULL PRIMARY KEY,
    isiddt DATE,
    isidprev VARCHAR(18),
    nm NVARCHAR(500) NOT NULL,
    invalid BIT NOT NULL DEFAULT 0
);

-- =====================================================
-- INGREDIENT AND COMPONENT TABLES
-- =====================================================

-- VMP Ingredients - What ingredients are in each VMP
IF EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'vmp_ingredient') DROP TABLE vmp_ingredient;
CREATE TABLE vmp_ingredient (
    vpid VARCHAR(18) NOT NULL,
    isid VARCHAR(18) NOT NULL,
    basis_strntcd VARCHAR(10),
    bs_subid VARCHAR(18),
    strnt_nmrtr_val DECIMAL(15,5),
    strnt_nmrtr_uomcd VARCHAR(18),
    strnt_dnmtr_val DECIMAL(15,5),  
    strnt_dnmtr_uomcd VARCHAR(18),
    PRIMARY KEY (vpid, isid),
    FOREIGN KEY (vpid) REFERENCES vmp(vpid),
    FOREIGN KEY (isid) REFERENCES ingredient(isid)
);

-- VMP Drug Route - Administration routes for VMPs
IF EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'vmp_drugroute') DROP TABLE vmp_drugroute;
CREATE TABLE vmp_drugroute (
    vpid VARCHAR(18) NOT NULL,
    routecd NVARCHAR(20) NOT NULL,
    PRIMARY KEY (vpid, routecd),
    FOREIGN KEY (vpid) REFERENCES vmp(vpid)
);

-- VMP Drug Form - Pharmaceutical forms for VMPs
IF EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'vmp_drugform') DROP TABLE vmp_drugform;
CREATE TABLE vmp_drugform (
    vpid VARCHAR(18) NOT NULL,
    formcd NVARCHAR(20) NOT NULL,
    PRIMARY KEY (vpid, formcd),
    FOREIGN KEY (vpid) REFERENCES vmp(vpid)
);

-- =====================================================
-- PRICING AND COMMERCIAL TABLES
-- =====================================================

-- Drug Tariff information
IF EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'dt_payment_category') DROP TABLE dt_payment_category;
CREATE TABLE dt_payment_category (
    vpid VARCHAR(18),
    paycat_prevcd NVARCHAR(10),
    paycat_dt DATE,
    paycatcd NVARCHAR(10),
    dt_payment_category_prev NVARCHAR(10),
    PRIMARY KEY (vpid, paycat_dt),
    FOREIGN KEY (vpid) REFERENCES vmp(vpid)
);

-- AMPP Drug Tariff Information
IF EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'ampp_drugtariffinfo') DROP TABLE ampp_drugtariffinfo;
CREATE TABLE ampp_drugtariffinfo (
    appid VARCHAR(18) NOT NULL,
    pay_catcd NVARCHAR(10),
    price DECIMAL(12,2),
    dt DATE,
    prevprice DECIMAL(12,2),
    PRIMARY KEY (appid, dt),
    FOREIGN KEY (appid) REFERENCES ampp(appid)
);

-- =====================================================
-- SUPPLEMENTARY DATA TABLES (BNF, ATC, etc.)
-- =====================================================

-- BNF (British National Formulary) codes
IF EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'dmd_bnf') DROP TABLE dmd_bnf;
CREATE TABLE dmd_bnf (
    vpid VARCHAR(18) NOT NULL,
    bnf_code NVARCHAR(15) NOT NULL,
    PRIMARY KEY (vpid, bnf_code),
    FOREIGN KEY (vpid) REFERENCES vmp(vpid)
);

-- ATC (Anatomical Therapeutic Chemical) codes  
IF EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'dmd_atc') DROP TABLE dmd_atc;
CREATE TABLE dmd_atc (
    vpid VARCHAR(18) NOT NULL,
    atc_code NVARCHAR(7) NOT NULL,
    PRIMARY KEY (vpid, atc_code),
    FOREIGN KEY (vpid) REFERENCES vmp(vpid)
);

-- =====================================================
-- SNOMED CT MAPPINGS
-- =====================================================

-- DM+D to SNOMED CT concept mappings
IF EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'dmd_snomed') DROP TABLE dmd_snomed;
CREATE TABLE dmd_snomed (
    dmd_id VARCHAR(18) NOT NULL,
    dmd_type NVARCHAR(10) NOT NULL, -- VTM, VMP, AMP, VMPP, AMPP
    snomed_conceptid VARCHAR(18) NOT NULL,
    PRIMARY KEY (dmd_id, dmd_type)
);

-- =====================================================
-- GTIN (Global Trade Item Number) MAPPINGS  
-- =====================================================

-- GTIN codes for AMPPs
IF EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'gtin') DROP TABLE gtin;
CREATE TABLE gtin (
    appid VARCHAR(18) NOT NULL,
    gtin NVARCHAR(14) NOT NULL,
    startdt DATE,
    enddt DATE,
    PRIMARY KEY (appid, gtin),
    FOREIGN KEY (appid) REFERENCES ampp(appid)
);

-- =====================================================
-- INDEXES FOR PERFORMANCE
-- =====================================================

-- Core entity indexes
CREATE INDEX IX_vmp_vtmid ON vmp(vtmid);
CREATE INDEX IX_vmp_nm ON vmp(nm);
CREATE INDEX IX_amp_vpid ON amp(vpid);  
CREATE INDEX IX_amp_nm ON amp(nm);
CREATE INDEX IX_vmpp_vpid ON vmpp(vpid);
CREATE INDEX IX_ampp_vppid ON ampp(vppid);
CREATE INDEX IX_ampp_apid ON ampp(apid);

-- Ingredient and component indexes
CREATE INDEX IX_vmp_ingredient_isid ON vmp_ingredient(isid);
CREATE INDEX IX_vmp_drugroute_routecd ON vmp_drugroute(routecd);
CREATE INDEX IX_vmp_drugform_formcd ON vmp_drugform(formcd);

-- Lookup table indexes  
CREATE INDEX IX_lookup_type ON lookup(type);
CREATE INDEX IX_lookup_descr ON lookup(descr);

-- Supplementary data indexes
CREATE INDEX IX_dmd_bnf_bnf_code ON dmd_bnf(bnf_code);
CREATE INDEX IX_dmd_atc_atc_code ON dmd_atc(atc_code);
CREATE INDEX IX_dmd_snomed_conceptid ON dmd_snomed(snomed_conceptid);
CREATE INDEX IX_gtin_gtin ON gtin(gtin);

PRINT 'DM+D database schema created successfully';