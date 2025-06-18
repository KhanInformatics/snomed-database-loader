-- =================================================================
-- Primary Care Domain (PCD) Table Creation Script
-- Extracted from Load-PCD-Refset-Content.ps1
-- 
-- This script creates all PCD tables with proper schemas, indexes,
-- and drop/recreate logic for clean imports.
-- =================================================================

USE SNOMEDCT;
GO

-- =================================================================
-- Table 1: PCD_Refset_Content_by_Output
-- Main PCD refset content organized by output indicators
-- =================================================================

IF OBJECT_ID('dbo.PCD_Refset_Content_by_Output', 'U') IS NOT NULL
BEGIN
    -- Truncate existing data
    TRUNCATE TABLE PCD_Refset_Content_by_Output;
    
    -- Drop existing table
    DROP TABLE PCD_Refset_Content_by_Output;
END

-- Create the table with updated data types
CREATE TABLE PCD_Refset_Content_by_Output (
    Output_ID VARCHAR(255) NOT NULL,
    Cluster_ID VARCHAR(255) NOT NULL,
    Cluster_Description VARCHAR(255) NOT NULL,
    SNOMED_code VARCHAR(255) NOT NULL, -- Increased length to accommodate larger values
    SNOMED_code_description VARCHAR(255) NOT NULL,
    PCD_Refset_ID VARCHAR(18) NOT NULL
);

-- Add indexes for better query performance
CREATE INDEX IX_PCD_Refset_Content_Cluster_ID ON PCD_Refset_Content_by_Output(Cluster_ID);
CREATE INDEX IX_PCD_Refset_Content_SNOMED_code ON PCD_Refset_Content_by_Output(SNOMED_code);
CREATE INDEX IX_PCD_Refset_Content_PCD_Refset_ID ON PCD_Refset_Content_by_Output(PCD_Refset_ID);

PRINT 'Created table: PCD_Refset_Content_by_Output';

-- =================================================================
-- Table 2: PCD_Refset_Content_V2
-- Alternative structure for PCD refset content
-- =================================================================

IF OBJECT_ID('dbo.PCD_Refset_Content_V2', 'U') IS NOT NULL
BEGIN
    -- Truncate existing data
    TRUNCATE TABLE PCD_Refset_Content_V2;
    
    -- Drop existing table
    DROP TABLE PCD_Refset_Content_V2;
END

-- Create the table with appropriate data types (6 columns to match actual data file)
CREATE TABLE PCD_Refset_Content_V2 (
    Cluster_ID VARCHAR(50) NOT NULL,
    Cluster_Description VARCHAR(500) NOT NULL,
    SNOMED_code VARCHAR(255) NOT NULL,
    SNOMED_code_description VARCHAR(500) NOT NULL,
    PCD_Refset_ID VARCHAR(18) NOT NULL,
    Service_and_Ruleset VARCHAR(500) NOT NULL
);

-- Add indexes for better query performance
CREATE INDEX IX_PCD_Refset_Content_V2_SNOMED_code ON PCD_Refset_Content_V2(SNOMED_code);
CREATE INDEX IX_PCD_Refset_Content_V2_PCD_Refset_ID ON PCD_Refset_Content_V2(PCD_Refset_ID);
CREATE INDEX IX_PCD_Refset_Content_V2_Cluster_ID ON PCD_Refset_Content_V2(Cluster_ID);

PRINT 'Created table: PCD_Refset_Content_V2';

-- =================================================================
-- Table 3: PCD_Ruleset_Full_Name_Mappings_V2
-- Maps ruleset IDs to their full descriptive names
-- Examples: '6IN1' -> '6-in-1 Vaccination Programme', 'Asthma' -> 'Asthma'
-- =================================================================

IF OBJECT_ID('dbo.PCD_Ruleset_Full_Name_Mappings_V2', 'U') IS NOT NULL
BEGIN
    TRUNCATE TABLE PCD_Ruleset_Full_Name_Mappings_V2;
    DROP TABLE PCD_Ruleset_Full_Name_Mappings_V2;
END

CREATE TABLE PCD_Ruleset_Full_Name_Mappings_V2 (
    Ruleset_ID VARCHAR(50) NOT NULL,
    Ruleset_Short_Name VARCHAR(255) NOT NULL,
    Ruleset_Full_Name VARCHAR(500) NOT NULL
);

CREATE INDEX IX_PCD_Ruleset_Mappings_ID ON PCD_Ruleset_Full_Name_Mappings_V2(Ruleset_ID);

PRINT 'Created table: PCD_Ruleset_Full_Name_Mappings_V2';

-- =================================================================
-- Table 4: PCD_Service_Full_Name_Mappings_V2
-- Maps service type codes to their full descriptions
-- Examples: 'CC' -> 'Core Contract (CC)', 'ES' -> 'Enhanced Service (ES)'
-- =================================================================

IF OBJECT_ID('dbo.PCD_Service_Full_Name_Mappings_V2', 'U') IS NOT NULL
BEGIN
    TRUNCATE TABLE PCD_Service_Full_Name_Mappings_V2;
    DROP TABLE PCD_Service_Full_Name_Mappings_V2;
END

CREATE TABLE PCD_Service_Full_Name_Mappings_V2 (
    Service_ID VARCHAR(50) NOT NULL,
    Service_Short_Name VARCHAR(255) NOT NULL,
    Service_Full_Name VARCHAR(500) NOT NULL
);

CREATE INDEX IX_PCD_Service_Mappings_ID ON PCD_Service_Full_Name_Mappings_V2(Service_ID);

PRINT 'Created table: PCD_Service_Full_Name_Mappings_V2';

-- =================================================================
-- Table 5: PCD_Output_Descriptions_V2
-- Provides detailed descriptions and metadata for PCD outputs
-- Contains Service, Ruleset, Output mapping with descriptions
-- =================================================================

IF OBJECT_ID('dbo.PCD_Output_Descriptions_V2', 'U') IS NOT NULL
BEGIN
    TRUNCATE TABLE PCD_Output_Descriptions_V2;
    DROP TABLE PCD_Output_Descriptions_V2;
END

CREATE TABLE PCD_Output_Descriptions_V2 (
    Service_ID VARCHAR(50) NOT NULL,
    Ruleset_ID VARCHAR(255) NOT NULL,
    Output_ID VARCHAR(50) NOT NULL,
    Output_Description VARCHAR(2000) NOT NULL,
    Output_Type VARCHAR(10) NOT NULL
);

CREATE INDEX IX_PCD_Output_Descriptions_Service_ID ON PCD_Output_Descriptions_V2(Service_ID);
CREATE INDEX IX_PCD_Output_Descriptions_Ruleset_ID ON PCD_Output_Descriptions_V2(Ruleset_ID);
CREATE INDEX IX_PCD_Output_Descriptions_Output_ID ON PCD_Output_Descriptions_V2(Output_ID);

PRINT 'Created table: PCD_Output_Descriptions_V2';

-- =================================================================
-- Summary
-- =================================================================

PRINT '==================================================';
PRINT 'PCD Table Creation Complete';
PRINT '==================================================';
PRINT 'Created 5 PCD tables:';
PRINT '  1. PCD_Refset_Content_by_Output (Main content by output)';
PRINT '  2. PCD_Refset_Content_V2 (Alternative content structure)';
PRINT '  3. PCD_Ruleset_Full_Name_Mappings_V2 (Clinical area mappings)';
PRINT '  4. PCD_Service_Full_Name_Mappings_V2 (Service classifications)';
PRINT '  5. PCD_Output_Descriptions_V2 (Output descriptions)';
PRINT '==================================================';
PRINT 'Ready for data import using Load-PCD-Refset-Content.ps1';
PRINT '==================================================';

-- =================================================================
-- Optional: Check table existence and structure
-- =================================================================

SELECT 
    t.name AS TableName,
    c.name AS ColumnName,
    ty.name AS DataType,
    c.max_length AS MaxLength,
    c.is_nullable AS IsNullable
FROM sys.tables t
JOIN sys.columns c ON t.object_id = c.object_id
JOIN sys.types ty ON c.user_type_id = ty.user_type_id
WHERE t.name IN (
    'PCD_Refset_Content_by_Output',
    'PCD_Refset_Content_V2',
    'PCD_Ruleset_Full_Name_Mappings_V2',
    'PCD_Service_Full_Name_Mappings_V2',
    'PCD_Output_Descriptions_V2'
)
ORDER BY t.name, c.column_id;
