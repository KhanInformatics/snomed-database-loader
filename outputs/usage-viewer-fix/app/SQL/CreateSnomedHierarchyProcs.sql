-- ============================================================================
-- SNOMED CT Hierarchy Stored Procedures (Using Transitive Closure)
-- ============================================================================
-- These stored procedures provide hierarchy queries for SNOMED CT
-- Uses the pre-computed transitive closure table for fast ancestor/descendant queries
--
-- Transitive Closure Table: DMWB_Export.dbo.DMWB_NHS_SNOMED_Transitive_Closure_SCTTC
-- Description Tables: snomedct.dbo.curr_description_f
-- 
-- Author: Generated for SNOMED Hierarchy Visualization
-- Date: 2026-01-29
-- ============================================================================

USE DMWB_Export;
GO

-- ============================================================================
-- Stored Procedure: GetSnomedAncestors
-- Gets all ancestors (parents, grandparents, etc.) of a concept using transitive closure
-- ============================================================================
IF OBJECT_ID('dbo.GetSnomedAncestors', 'P') IS NOT NULL
    DROP PROCEDURE dbo.GetSnomedAncestors;
GO

CREATE PROCEDURE dbo.GetSnomedAncestors
    @ConceptId NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT DISTINCT
        tc.SupertypeID AS ConceptId,
        d.term AS Term,
        fsn.term AS FullySpecifiedName,
        c.active AS IsActive,
        1 AS Depth,  -- Transitive closure doesn't track depth
        NULL AS ParentId,
        CASE WHEN EXISTS (
            SELECT 1 FROM DMWB_NHS_SNOMED_Transitive_Closure_SCTTC tc2 
            WHERE tc2.SupertypeID = tc.SupertypeID 
              AND tc2.SubtypeID != tc2.SupertypeID
        ) THEN 1 ELSE 0 END AS HasChildren,
        (SELECT COUNT(DISTINCT tc3.SubtypeID) 
         FROM DMWB_NHS_SNOMED_Transitive_Closure_SCTTC tc3 
         WHERE tc3.SupertypeID = tc.SupertypeID 
           AND tc3.SubtypeID != tc3.SupertypeID) AS ChildCount
    FROM DMWB_NHS_SNOMED_Transitive_Closure_SCTTC tc
    JOIN snomedct.dbo.curr_description_f d ON tc.SupertypeID = d.conceptid
    JOIN snomedct.dbo.curr_description_f fsn ON tc.SupertypeID = fsn.conceptid
    JOIN snomedct.dbo.curr_concept_f c ON tc.SupertypeID = c.id
    WHERE tc.SubtypeID = @ConceptId
      AND tc.SupertypeID != @ConceptId  -- Exclude self
      AND d.typeid = '900000000000013009'  -- Preferred term/Synonym
      AND d.active = 1
      AND fsn.typeid = '900000000000003001'  -- Fully Specified Name
      AND fsn.active = 1
    ORDER BY d.term;
END
GO

PRINT 'Created stored procedure: GetSnomedAncestors';

-- ============================================================================
-- Stored Procedure: GetSnomedDescendants
-- Gets descendants (children, grandchildren, etc.) of a concept
-- ============================================================================
IF OBJECT_ID('dbo.GetSnomedDescendants', 'P') IS NOT NULL
    DROP PROCEDURE dbo.GetSnomedDescendants;
GO

CREATE PROCEDURE dbo.GetSnomedDescendants
    @ConceptId NVARCHAR(20),
    @MaxResults INT = 500
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT TOP (@MaxResults)
        tc.SubtypeID AS ConceptId,
        d.term AS Term,
        fsn.term AS FullySpecifiedName,
        c.active AS IsActive,
        1 AS Depth,
        @ConceptId AS ParentId,
        CASE WHEN EXISTS (
            SELECT 1 FROM DMWB_NHS_SNOMED_Transitive_Closure_SCTTC tc2 
            WHERE tc2.SupertypeID = tc.SubtypeID 
              AND tc2.SubtypeID != tc2.SupertypeID
        ) THEN 1 ELSE 0 END AS HasChildren,
        (SELECT COUNT(DISTINCT tc3.SubtypeID) 
         FROM DMWB_NHS_SNOMED_Transitive_Closure_SCTTC tc3 
         WHERE tc3.SupertypeID = tc.SubtypeID 
           AND tc3.SubtypeID != tc3.SupertypeID) AS ChildCount
    FROM DMWB_NHS_SNOMED_Transitive_Closure_SCTTC tc
    JOIN snomedct.dbo.curr_description_f d ON tc.SubtypeID = d.conceptid
    JOIN snomedct.dbo.curr_description_f fsn ON tc.SubtypeID = fsn.conceptid
    JOIN snomedct.dbo.curr_concept_f c ON tc.SubtypeID = c.id
    WHERE tc.SupertypeID = @ConceptId
      AND tc.SubtypeID != @ConceptId  -- Exclude self
      AND d.typeid = '900000000000013009'  -- Preferred term/Synonym
      AND d.active = 1
      AND fsn.typeid = '900000000000003001'  -- Fully Specified Name
      AND fsn.active = 1
    ORDER BY d.term;
END
GO

PRINT 'Created stored procedure: GetSnomedDescendants';

-- ============================================================================
-- Stored Procedure: GetSnomedDirectParents
-- Gets only the direct (immediate) parents using relationship table
-- ============================================================================
IF OBJECT_ID('dbo.GetSnomedDirectParents', 'P') IS NOT NULL
    DROP PROCEDURE dbo.GetSnomedDirectParents;
GO

CREATE PROCEDURE dbo.GetSnomedDirectParents
    @ConceptId NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT DISTINCT
        r.destinationid AS ConceptId,
        d.term AS Term,
        fsn.term AS FullySpecifiedName,
        c.active AS IsActive,
        1 AS Depth,
        @ConceptId AS ChildId,
        CASE WHEN EXISTS (
            SELECT 1 FROM snomedct.dbo.curr_relationship_f r2 
            WHERE r2.destinationid = r.destinationid 
              AND r2.typeid = '116680003' 
              AND r2.active = 1
        ) THEN 1 ELSE 0 END AS HasChildren,
        (SELECT COUNT(DISTINCT r3.sourceid) 
         FROM snomedct.dbo.curr_relationship_f r3 
         WHERE r3.destinationid = r.destinationid 
           AND r3.typeid = '116680003' 
           AND r3.active = 1) AS ChildCount
    FROM snomedct.dbo.curr_relationship_f r
    JOIN snomedct.dbo.curr_description_f d ON r.destinationid = d.conceptid
    JOIN snomedct.dbo.curr_description_f fsn ON r.destinationid = fsn.conceptid
    JOIN snomedct.dbo.curr_concept_f c ON r.destinationid = c.id
    WHERE r.sourceid = @ConceptId
      AND r.typeid = '116680003'  -- IS-A relationship
      AND r.active = 1
      AND d.typeid = '900000000000013009'  -- Preferred term/Synonym
      AND d.active = 1
      AND fsn.typeid = '900000000000003001'  -- Fully Specified Name
      AND fsn.active = 1
    ORDER BY d.term;
END
GO

PRINT 'Created stored procedure: GetSnomedDirectParents';

-- ============================================================================
-- Stored Procedure: GetSnomedDirectChildren
-- Gets only the direct (immediate) children using relationship table
-- ============================================================================
IF OBJECT_ID('dbo.GetSnomedDirectChildren', 'P') IS NOT NULL
    DROP PROCEDURE dbo.GetSnomedDirectChildren;
GO

CREATE PROCEDURE dbo.GetSnomedDirectChildren
    @ConceptId NVARCHAR(20),
    @MaxResults INT = 500
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT TOP (@MaxResults)
        r.sourceid AS ConceptId,
        d.term AS Term,
        fsn.term AS FullySpecifiedName,
        c.active AS IsActive,
        1 AS Depth,
        @ConceptId AS ParentId,
        CASE WHEN EXISTS (
            SELECT 1 FROM snomedct.dbo.curr_relationship_f r2 
            WHERE r2.destinationid = r.sourceid 
              AND r2.typeid = '116680003' 
              AND r2.active = 1
        ) THEN 1 ELSE 0 END AS HasChildren,
        (SELECT COUNT(DISTINCT r3.sourceid) 
         FROM snomedct.dbo.curr_relationship_f r3 
         WHERE r3.destinationid = r.sourceid 
           AND r3.typeid = '116680003' 
           AND r3.active = 1) AS ChildCount
    FROM snomedct.dbo.curr_relationship_f r
    JOIN snomedct.dbo.curr_description_f d ON r.sourceid = d.conceptid
    JOIN snomedct.dbo.curr_description_f fsn ON r.sourceid = fsn.conceptid
    JOIN snomedct.dbo.curr_concept_f c ON r.sourceid = c.id
    WHERE r.destinationid = @ConceptId
      AND r.typeid = '116680003'  -- IS-A relationship
      AND r.active = 1
      AND d.typeid = '900000000000013009'  -- Preferred term/Synonym
      AND d.active = 1
      AND fsn.typeid = '900000000000003001'  -- Fully Specified Name
      AND fsn.active = 1
    ORDER BY d.term;
END
GO

PRINT 'Created stored procedure: GetSnomedDirectChildren';

-- ============================================================================
-- Stored Procedure: GetSnomedConceptDetails
-- Gets details for a single SNOMED CT concept
-- ============================================================================
IF OBJECT_ID('dbo.GetSnomedConceptDetails', 'P') IS NOT NULL
    DROP PROCEDURE dbo.GetSnomedConceptDetails;
GO

CREATE PROCEDURE dbo.GetSnomedConceptDetails
    @ConceptId NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        c.id AS ConceptId,
        d.term AS Term,
        fsn.term AS FullySpecifiedName,
        c.active AS IsActive,
        0 AS Depth,
        NULL AS ParentId,
        CASE WHEN EXISTS (
            SELECT 1 FROM snomedct.dbo.curr_relationship_f r 
            WHERE r.destinationid = c.id 
              AND r.typeid = '116680003' 
              AND r.active = 1
        ) THEN 1 ELSE 0 END AS HasChildren,
        (SELECT COUNT(DISTINCT r.sourceid) 
         FROM snomedct.dbo.curr_relationship_f r 
         WHERE r.destinationid = c.id 
           AND r.typeid = '116680003' 
           AND r.active = 1) AS ChildCount
    FROM snomedct.dbo.curr_concept_f c
    JOIN snomedct.dbo.curr_description_f d ON c.id = d.conceptid
    JOIN snomedct.dbo.curr_description_f fsn ON c.id = fsn.conceptid
    WHERE c.id = @ConceptId
      AND d.typeid = '900000000000013009'  -- Preferred term/Synonym
      AND d.active = 1
      AND fsn.typeid = '900000000000003001'  -- Fully Specified Name
      AND fsn.active = 1;
END
GO

PRINT 'Created stored procedure: GetSnomedConceptDetails';

-- ============================================================================
-- Stored Procedure: GetSnomedHierarchy
-- Gets full hierarchy (concept, direct parents/children, counts) in one call
-- ============================================================================
IF OBJECT_ID('dbo.GetSnomedHierarchy', 'P') IS NOT NULL
    DROP PROCEDURE dbo.GetSnomedHierarchy;
GO

CREATE PROCEDURE dbo.GetSnomedHierarchy
    @ConceptId NVARCHAR(20),
    @MaxDescendants INT = 100
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Return concept details
    EXEC dbo.GetSnomedConceptDetails @ConceptId;
    
    -- Return direct parents
    EXEC dbo.GetSnomedDirectParents @ConceptId;
    
    -- Return direct children
    EXEC dbo.GetSnomedDirectChildren @ConceptId, @MaxDescendants;
    
    -- Return ancestor count (using transitive closure)
    SELECT COUNT(DISTINCT tc.SupertypeID) AS AncestorCount
    FROM DMWB_NHS_SNOMED_Transitive_Closure_SCTTC tc
    WHERE tc.SubtypeID = @ConceptId
      AND tc.SupertypeID != @ConceptId;
    
    -- Return descendant count (using transitive closure)
    SELECT COUNT(DISTINCT tc.SubtypeID) AS DescendantCount
    FROM DMWB_NHS_SNOMED_Transitive_Closure_SCTTC tc
    WHERE tc.SupertypeID = @ConceptId
      AND tc.SubtypeID != @ConceptId;
END
GO

PRINT 'Created stored procedure: GetSnomedHierarchy';

-- ============================================================================
-- Test the stored procedures
-- ============================================================================
PRINT '';
PRINT '=== Testing GetSnomedConceptDetails for Pneumonia (233604007) ===';
EXEC dbo.GetSnomedConceptDetails '233604007';

PRINT '';
PRINT '=== Testing GetSnomedDirectParents for Pneumonia (233604007) ===';
EXEC dbo.GetSnomedDirectParents '233604007';

PRINT '';
PRINT '=== Testing GetSnomedDirectChildren for Pneumonia (233604007) - Top 10 ===';
EXEC dbo.GetSnomedDirectChildren '233604007', 10;

PRINT '';
PRINT '=== Testing GetSnomedAncestors (via transitive closure) for Pneumonia ===';
EXEC dbo.GetSnomedAncestors '233604007';

PRINT '';
PRINT '=== Ancestor/Descendant counts for Pneumonia (233604007) ===';
SELECT 
    (SELECT COUNT(DISTINCT SupertypeID) FROM DMWB_NHS_SNOMED_Transitive_Closure_SCTTC WHERE SubtypeID = '233604007' AND SupertypeID != '233604007') AS AncestorCount,
    (SELECT COUNT(DISTINCT SubtypeID) FROM DMWB_NHS_SNOMED_Transitive_Closure_SCTTC WHERE SupertypeID = '233604007' AND SubtypeID != '233604007') AS DescendantCount;

PRINT '';
PRINT '=== All stored procedures created successfully! ===';
GO
