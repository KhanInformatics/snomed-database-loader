-- SQL Server Table Creation Script for SNOMED CT UK Query Table and History Substitution Table
-- TRUD Item 276 - Contains enhanced transitive closure with inactive concept handling
-- Recommended by JGPIT for primary care systems
-- 
-- Run this script once to create the tables, then use the import script to load data

USE snomedct;
GO

-- =============================================================================
-- UK Query Table (Enhanced Transitive Closure)
-- Contains ~23 million rows representing all ancestor-descendant relationships
-- including paths through inactive concepts via history substitutions
-- =============================================================================

IF EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'uk_query_table') 
    DROP TABLE uk_query_table;
GO

CREATE TABLE uk_query_table (
    supertypeId VARCHAR(18) NOT NULL,    -- Ancestor concept ID
    subtypeId VARCHAR(18) NOT NULL,      -- Descendant concept ID  
    provenance TINYINT NOT NULL          -- 0 = direct relationship, >0 = via substitution
);
GO

-- Create indexes for fast lookups
CREATE NONCLUSTERED INDEX IX_uk_query_table_supertype 
    ON uk_query_table (supertypeId) 
    INCLUDE (subtypeId, provenance);
GO

CREATE NONCLUSTERED INDEX IX_uk_query_table_subtype 
    ON uk_query_table (subtypeId) 
    INCLUDE (supertypeId, provenance);
GO

-- Composite index for existence checks
CREATE NONCLUSTERED INDEX IX_uk_query_table_pair
    ON uk_query_table (supertypeId, subtypeId);
GO

PRINT 'Created uk_query_table with indexes';
GO

-- =============================================================================
-- UK History Substitution Table
-- Maps inactive concepts to their recommended active replacements
-- Contains ~350K substitution mappings
-- =============================================================================

IF EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'uk_history_substitution') 
    DROP TABLE uk_history_substitution;
GO

CREATE TABLE uk_history_substitution (
    oldConceptId VARCHAR(18) NOT NULL,           -- Inactive concept ID
    oldConceptStatus TINYINT NOT NULL,           -- Status of old concept
    newConceptId VARCHAR(18) NOT NULL,           -- Recommended replacement concept ID
    newConceptStatus TINYINT NOT NULL,           -- Status of new concept (usually 0=active)
    [path] VARCHAR(255) NULL,                    -- Substitution path (if multi-hop)
    isAmbiguous TINYINT NOT NULL,                -- 0=unambiguous, 1+=number of alternatives
    iterations INT NOT NULL,                     -- Number of hops in substitution chain
    oldConceptFSN NVARCHAR(512) NULL,           -- Old concept's Fully Specified Name
    oldConceptFSN_TagCount TINYINT NULL,        -- Number of semantic tags in old FSN
    newConceptFSN NVARCHAR(512) NULL,           -- New concept's Fully Specified Name
    newConceptFSN_Status TINYINT NULL,          -- Status of new concept FSN
    TLH_IdenticalFlag TINYINT NULL,             -- Top-level hierarchy identical flag
    FSN_TaglessIdenticalFlag TINYINT NULL,      -- FSN (without tag) identical flag
    FSN_TagIdenticalFlag TINYINT NULL           -- FSN semantic tag identical flag
);
GO

-- Create indexes for fast lookups
CREATE NONCLUSTERED INDEX IX_uk_history_substitution_oldconcept 
    ON uk_history_substitution (oldConceptId) 
    INCLUDE (newConceptId, isAmbiguous);
GO

CREATE NONCLUSTERED INDEX IX_uk_history_substitution_newconcept 
    ON uk_history_substitution (newConceptId);
GO

PRINT 'Created uk_history_substitution with indexes';
GO

-- =============================================================================
-- Utility View: Combine Query Table with concept descriptions
-- =============================================================================

-- Note: This view assumes you have the standard SNOMED CT tables loaded
-- Uncomment after loading main SNOMED CT data

/*
CREATE OR ALTER VIEW vw_uk_query_table_with_terms AS
SELECT 
    qt.supertypeId,
    st.term AS supertypeTerm,
    qt.subtypeId,
    dt.term AS subtypeTerm,
    qt.provenance
FROM uk_query_table qt
LEFT JOIN curr_description_f st ON qt.supertypeId = st.conceptid 
    AND st.active = '1' 
    AND st.typeid = '900000000000003001' -- FSN
LEFT JOIN curr_description_f dt ON qt.subtypeId = dt.conceptid 
    AND dt.active = '1' 
    AND dt.typeid = '900000000000003001' -- FSN
GO
*/

PRINT '';
PRINT '=== Table Creation Complete ===';
PRINT 'Tables created:';
PRINT '  - uk_query_table (enhanced transitive closure)';
PRINT '  - uk_history_substitution (inactive concept mappings)';
PRINT '';
PRINT 'Next: Run the import script to load data from the downloaded files.';
GO
