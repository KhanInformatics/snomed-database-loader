-- Import SNOMED CT UK Query Table and History Substitution Table
-- Generated: 2026-01-30 23:06:47
-- Release: uk_sctqths_41.4.0_20260114000001

USE [snomedct];
GO

SET NOCOUNT ON;
GO

PRINT 'Starting import...';
PRINT '';

-- Import Query Table (Enhanced Transitive Closure)
PRINT 'Importing UK Query Table...';
PRINT 'Source: C:\QueryTable\CurrentReleases\uk_sctqths_41.4.0_20260114000001\SnomedCT_UKClinicalRF2_PRODUCTION_20260114T000001Z\Resources\QueryTable\xres2_SNOMEDQueryTable_CORE-UK_20260114.txt';
TRUNCATE TABLE uk_query_table;

BULK INSERT uk_query_table 
FROM 'C:\\\\QueryTable\\\\CurrentReleases\\\\uk_sctqths_41.4.0_20260114000001\\\\SnomedCT_UKClinicalRF2_PRODUCTION_20260114T000001Z\\\\Resources\\\\QueryTable\\\\xres2_SNOMEDQueryTable_CORE-UK_20260114.txt' 
WITH (
    FIRSTROW = 2, 
    FIELDTERMINATOR = '\t', 
    ROWTERMINATOR = '\n', 
    TABLOCK,
    BATCHSIZE = 500000
);

DECLARE @qt_rows INT = (SELECT COUNT(*) FROM uk_query_table);
PRINT 'Loaded ' + CAST(@qt_rows AS VARCHAR) + ' rows into uk_query_table';
PRINT '';

-- Import History Substitution Table
PRINT 'Importing UK History Substitution Table...';
PRINT 'Source: C:\QueryTable\CurrentReleases\uk_sctqths_41.4.0_20260114000001\SnomedCT_UKClinicalRF2_PRODUCTION_20260114T000001Z\Resources\HistorySubstitutionTable\xres2_HistorySubstitutionTable_Concepts_GB1000000_20260114.txt';
TRUNCATE TABLE uk_history_substitution;

BULK INSERT uk_history_substitution 
FROM 'C:\\\\QueryTable\\\\CurrentReleases\\\\uk_sctqths_41.4.0_20260114000001\\\\SnomedCT_UKClinicalRF2_PRODUCTION_20260114T000001Z\\\\Resources\\\\HistorySubstitutionTable\\\\xres2_HistorySubstitutionTable_Concepts_GB1000000_20260114.txt' 
WITH (
    FIRSTROW = 2, 
    FIELDTERMINATOR = '\t', 
    ROWTERMINATOR = '\n', 
    TABLOCK
);

DECLARE @hs_rows INT = (SELECT COUNT(*) FROM uk_history_substitution);
PRINT 'Loaded ' + CAST(@hs_rows AS VARCHAR) + ' rows into uk_history_substitution';
PRINT '';

PRINT '=== Import Complete ===';
GO
