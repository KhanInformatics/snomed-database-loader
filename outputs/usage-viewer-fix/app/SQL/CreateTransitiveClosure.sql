-- ============================================================================
-- SNOMED CT Transitive Closure Table Creation Script
-- ============================================================================
-- This script creates a transitive closure table that pre-computes all 
-- ancestor/descendant relationships in the SNOMED CT IS-A hierarchy.
-- 
-- The transitive closure enables efficient queries like:
-- - Find ALL ancestors of a concept (not just direct parents)
-- - Find ALL descendants of a concept (not just direct children)
-- - Check if concept A is an ancestor/descendant of concept B
--
-- Database: snomedct (SILENTPRIORY\SQLEXPRESS)
-- Author: Generated for SNOMED Hierarchy Visualization
-- Date: 2026-01-29
-- ============================================================================

USE snomedct;
GO

-- ============================================================================
-- Step 1: Drop existing table if it exists
-- ============================================================================
IF OBJECT_ID('dbo.snomed_transitive_closure', 'U') IS NOT NULL
BEGIN
    DROP TABLE dbo.snomed_transitive_closure;
    PRINT 'Dropped existing snomed_transitive_closure table';
END
GO

-- ============================================================================
-- Step 2: Create the transitive closure table
-- ============================================================================
CREATE TABLE dbo.snomed_transitive_closure (
    subtypeId BIGINT NOT NULL,      -- The descendant/child concept
    supertypeId BIGINT NOT NULL,    -- The ancestor/parent concept
    depth INT NOT NULL DEFAULT 1,    -- Distance between concepts (1 = direct parent)
    CONSTRAINT PK_snomed_transitive_closure PRIMARY KEY CLUSTERED (subtypeId, supertypeId)
);
GO

PRINT 'Created snomed_transitive_closure table';

-- ============================================================================
-- Step 3: Create indexes for efficient querying
-- ============================================================================
CREATE NONCLUSTERED INDEX IX_transitive_supertypeId 
    ON dbo.snomed_transitive_closure (supertypeId) 
    INCLUDE (subtypeId, depth);
GO

CREATE NONCLUSTERED INDEX IX_transitive_depth 
    ON dbo.snomed_transitive_closure (depth);
GO

PRINT 'Created indexes on snomed_transitive_closure';

-- ============================================================================
-- Step 4: Populate with recursive CTE (builds transitive closure)
-- ============================================================================
-- This uses a recursive Common Table Expression to traverse the IS-A hierarchy
-- IS-A type ID = 116680003

PRINT 'Starting transitive closure computation...';
PRINT 'This may take 5-15 minutes depending on database size.';

;WITH RECURSIVE_HIERARCHY AS (
    -- Base case: Direct IS-A relationships (depth = 1)
    SELECT 
        CAST(sourceid AS BIGINT) AS subtypeId,
        CAST(destinationid AS BIGINT) AS supertypeId,
        1 AS depth
    FROM curr_relationship_f
    WHERE typeid = '116680003'  -- IS-A relationship type
      AND active = 1
    
    UNION ALL
    
    -- Recursive case: Follow the hierarchy up
    SELECT 
        rh.subtypeId,
        CAST(r.destinationid AS BIGINT) AS supertypeId,
        rh.depth + 1 AS depth
    FROM RECURSIVE_HIERARCHY rh
    INNER JOIN curr_relationship_f r 
        ON rh.supertypeId = CAST(r.sourceid AS BIGINT)
    WHERE r.typeid = '116680003'  -- IS-A relationship type
      AND r.active = 1
      AND rh.depth < 20  -- Safety limit to prevent infinite loops
)
INSERT INTO dbo.snomed_transitive_closure (subtypeId, supertypeId, depth)
SELECT DISTINCT 
    subtypeId, 
    supertypeId,
    MIN(depth) AS depth  -- Keep shortest path when concept appears via multiple routes
FROM RECURSIVE_HIERARCHY
GROUP BY subtypeId, supertypeId
OPTION (MAXRECURSION 20);

GO

-- ============================================================================
-- Step 5: Show statistics
-- ============================================================================
DECLARE @rowCount INT;
SELECT @rowCount = COUNT(*) FROM dbo.snomed_transitive_closure;
PRINT 'Transitive closure table populated with ' + CAST(@rowCount AS VARCHAR(20)) + ' rows';

-- Show sample data
PRINT '';
PRINT 'Sample data (ancestors of Pneumonia - 233604007):';
SELECT TOP 10 
    tc.subtypeId,
    tc.supertypeId,
    tc.depth,
    d.term AS ancestorTerm
FROM dbo.snomed_transitive_closure tc
JOIN curr_description_f d ON tc.supertypeId = CAST(d.conceptid AS BIGINT)
WHERE tc.subtypeId = 233604007
  AND d.typeid = '900000000000003001'  -- Fully Specified Name
  AND d.active = 1
ORDER BY tc.depth;

GO

-- ============================================================================
-- Step 6: Create helper views for easier querying
-- ============================================================================

-- View to get ancestors with their terms
IF OBJECT_ID('dbo.vw_snomed_ancestors', 'V') IS NOT NULL
    DROP VIEW dbo.vw_snomed_ancestors;
GO

CREATE VIEW dbo.vw_snomed_ancestors AS
SELECT 
    tc.subtypeId AS conceptId,
    tc.supertypeId AS ancestorId,
    tc.depth,
    d.term AS ancestorTerm,
    d.typeid AS descriptionTypeId
FROM dbo.snomed_transitive_closure tc
JOIN curr_description_f d ON tc.supertypeId = CAST(d.conceptid AS BIGINT)
WHERE d.active = 1;
GO

-- View to get descendants with their terms
IF OBJECT_ID('dbo.vw_snomed_descendants', 'V') IS NOT NULL
    DROP VIEW dbo.vw_snomed_descendants;
GO

CREATE VIEW dbo.vw_snomed_descendants AS
SELECT 
    tc.supertypeId AS conceptId,
    tc.subtypeId AS descendantId,
    tc.depth,
    d.term AS descendantTerm,
    d.typeid AS descriptionTypeId
FROM dbo.snomed_transitive_closure tc
JOIN curr_description_f d ON tc.subtypeId = CAST(d.conceptid AS BIGINT)
WHERE d.active = 1;
GO

PRINT 'Created helper views: vw_snomed_ancestors and vw_snomed_descendants';
PRINT '';
PRINT 'Transitive closure creation complete!';
PRINT '';
PRINT 'Example queries:';
PRINT '  -- Get all ancestors of a concept:';
PRINT '  SELECT * FROM vw_snomed_ancestors WHERE conceptId = 233604007 AND descriptionTypeId = ''900000000000003001'';';
PRINT '';
PRINT '  -- Get all descendants of a concept:';
PRINT '  SELECT * FROM vw_snomed_descendants WHERE conceptId = 233604007 AND descriptionTypeId = ''900000000000003001'';';
GO
