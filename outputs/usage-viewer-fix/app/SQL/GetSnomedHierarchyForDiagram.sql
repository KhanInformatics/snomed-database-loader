-- =============================================
-- Stored Procedure: GetSnomedHierarchyForDiagram
-- Purpose: Returns complete hierarchy data for Syncfusion diagram visualization
-- Returns ancestors, descendants, and all parent-child relationships
-- =============================================

USE snomedct
GO

IF OBJECT_ID('dbo.GetSnomedHierarchyForDiagram', 'P') IS NOT NULL
    DROP PROCEDURE dbo.GetSnomedHierarchyForDiagram
GO

CREATE PROCEDURE dbo.GetSnomedHierarchyForDiagram
    @ConceptId NVARCHAR(18),
    @MaxAncestorDepth INT = 100,      -- Limit how far up to go (default: all)
    @MaxDescendantDepth INT = 2,       -- Limit how far down to go (default: 2 levels)
    @MaxDescendants INT = 50           -- Limit total descendants (default: 50)
AS
BEGIN
    SET NOCOUNT ON;

    -- =============================================
    -- 1. Get the focus concept details (single row)
    -- =============================================
    SELECT 
        c.id AS ConceptId,
        CAST(fsn.term AS NVARCHAR(500)) AS Term,
        CAST(fsn.term AS NVARCHAR(500)) AS FSN,
        c.active AS IsActive,
        0 AS Depth,
        'Focus' AS NodeType,
        '#ff6b6b' AS FillColor,
        '#c92a2a' AS BorderColor
    FROM curr_concept_f c
    INNER JOIN curr_description_f fsn ON c.id = fsn.conceptId 
        AND fsn.typeId = '900000000000003001' -- FSN
        AND fsn.active = 1
    WHERE c.id = @ConceptId
    
    -- =============================================
    -- 2. Get all ancestors with their details (one row per concept - FSN only)
    -- =============================================
    ;WITH AncestorCTE AS (
        SELECT DISTINCT tc.SupertypeID AS ConceptId
        FROM DMWB_Export.dbo.DMWB_NHS_SNOMED_Transitive_Closure_SCTTC tc
        WHERE tc.SubtypeID = @ConceptId
          AND tc.SupertypeID != @ConceptId  -- Exclude self
    )
    SELECT 
        a.ConceptId,
        -- Extract just the term without the semantic tag for cleaner display
        CASE 
            WHEN CHARINDEX('(', CAST(fsn.term AS NVARCHAR(500))) > 0 
            THEN RTRIM(LEFT(CAST(fsn.term AS NVARCHAR(500)), CHARINDEX('(', CAST(fsn.term AS NVARCHAR(500))) - 2))
            ELSE CAST(fsn.term AS NVARCHAR(500))
        END AS Term,
        CAST(fsn.term AS NVARCHAR(500)) AS FSN,
        c.active AS IsActive,
        'Ancestor' AS NodeType,
        -- Color based on distance from focus (calculated later in app)
        CASE 
            WHEN a.ConceptId = '404684003' THEN '#e7704c'  -- Clinical finding (root)
            ELSE '#efd46e'  -- Default ancestor color
        END AS FillColor,
        CASE 
            WHEN a.ConceptId = '404684003' THEN '#c15433'
            ELSE '#d6b123'
        END AS BorderColor
    FROM AncestorCTE a
    INNER JOIN curr_concept_f c ON a.ConceptId = c.id
    INNER JOIN curr_description_f fsn ON a.ConceptId = fsn.conceptId 
        AND fsn.typeId = '900000000000003001' -- FSN only
        AND fsn.active = 1
    ORDER BY a.ConceptId

    -- =============================================
    -- 3. Get descendants (children and grandchildren) - one row per concept
    -- =============================================
    ;WITH DescendantCTE AS (
        SELECT DISTINCT TOP (@MaxDescendants) tc.SubtypeID AS ConceptId
        FROM DMWB_Export.dbo.DMWB_NHS_SNOMED_Transitive_Closure_SCTTC tc
        WHERE tc.SupertypeID = @ConceptId
          AND tc.SubtypeID != @ConceptId  -- Exclude self
    )
    SELECT 
        d2.ConceptId,
        -- Extract just the term without the semantic tag for cleaner display
        CASE 
            WHEN CHARINDEX('(', CAST(fsn.term AS NVARCHAR(500))) > 0 
            THEN RTRIM(LEFT(CAST(fsn.term AS NVARCHAR(500)), CHARINDEX('(', CAST(fsn.term AS NVARCHAR(500))) - 2))
            ELSE CAST(fsn.term AS NVARCHAR(500))
        END AS Term,
        CAST(fsn.term AS NVARCHAR(500)) AS FSN,
        c.active AS IsActive,
        'Descendant' AS NodeType,
        '#659be5' AS FillColor,  -- Default descendant color
        '#3a6eb5' AS BorderColor
    FROM DescendantCTE d2
    INNER JOIN curr_concept_f c ON d2.ConceptId = c.id
    INNER JOIN curr_description_f fsn ON d2.ConceptId = fsn.conceptId 
        AND fsn.typeId = '900000000000003001' -- FSN only
        AND fsn.active = 1
    ORDER BY d2.ConceptId

    -- =============================================
    -- 4. Get ALL parent-child (ISA) relationships between concepts
    --    This includes relationships between ancestors AND descendants
    -- =============================================
    ;WITH AllConcepts AS (
        -- Focus concept
        SELECT @ConceptId AS ConceptId
        UNION
        -- All ancestors
        SELECT DISTINCT tc.SupertypeID
        FROM DMWB_Export.dbo.DMWB_NHS_SNOMED_Transitive_Closure_SCTTC tc
        WHERE tc.SubtypeID = @ConceptId
        UNION
        -- All descendants (limited)
        SELECT DISTINCT TOP (@MaxDescendants) tc.SubtypeID
        FROM DMWB_Export.dbo.DMWB_NHS_SNOMED_Transitive_Closure_SCTTC tc
        WHERE tc.SupertypeID = @ConceptId
    )
    SELECT DISTINCT
        r.sourceId AS ChildId,
        r.destinationId AS ParentId
    FROM curr_relationship_f r
    INNER JOIN AllConcepts child ON r.sourceId = child.ConceptId
    INNER JOIN AllConcepts parent ON r.destinationId = parent.ConceptId
    WHERE r.typeId = '116680003'  -- IS A relationship
      AND r.active = 1
    ORDER BY r.sourceId, r.destinationId

END
GO

-- =============================================
-- Test the stored procedure
-- =============================================
-- EXEC dbo.GetSnomedHierarchyForDiagram @ConceptId = '233604007'  -- Pneumonia

-- Example with limited descendants:
-- EXEC dbo.GetSnomedHierarchyForDiagram @ConceptId = '233604007', @MaxDescendants = 20
