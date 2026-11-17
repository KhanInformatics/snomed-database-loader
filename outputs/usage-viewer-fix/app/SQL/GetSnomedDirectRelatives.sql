-- =============================================
-- Stored Procedure: GetSnomedDirectRelatives
-- Purpose: Returns direct parents and/or children for a single concept
-- Used for interactive level-by-level expansion in diagrams
-- =============================================

USE snomedct
GO

IF OBJECT_ID('dbo.GetSnomedDirectRelatives', 'P') IS NOT NULL
    DROP PROCEDURE dbo.GetSnomedDirectRelatives
GO

CREATE PROCEDURE dbo.GetSnomedDirectRelatives
    @ConceptId NVARCHAR(18),
    @Direction NVARCHAR(10) = 'Both'  -- 'Parents', 'Children', or 'Both'
AS
BEGIN
    SET NOCOUNT ON;

    -- =============================================
    -- 1. Get the focus concept details
    -- =============================================
    SELECT 
        c.id AS ConceptId,
        CASE 
            WHEN CHARINDEX('(', CAST(fsn.term AS NVARCHAR(500))) > 0 
            THEN RTRIM(LEFT(CAST(fsn.term AS NVARCHAR(500)), CHARINDEX('(', CAST(fsn.term AS NVARCHAR(500))) - 2))
            ELSE CAST(fsn.term AS NVARCHAR(500))
        END AS Term,
        CAST(fsn.term AS NVARCHAR(500)) AS FSN,
        c.active AS IsActive,
        'Focus' AS NodeType
    FROM curr_concept_f c
    INNER JOIN curr_description_f fsn ON c.id = fsn.conceptId 
        AND fsn.typeId = '900000000000003001' -- FSN
        AND fsn.active = 1
    WHERE c.id = @ConceptId
    
    -- =============================================
    -- 2. Get direct parents (if requested)
    -- =============================================
    IF @Direction IN ('Parents', 'Both')
    BEGIN
        SELECT DISTINCT
            r.destinationId AS ConceptId,
            CASE 
                WHEN CHARINDEX('(', CAST(fsn.term AS NVARCHAR(500))) > 0 
                THEN RTRIM(LEFT(CAST(fsn.term AS NVARCHAR(500)), CHARINDEX('(', CAST(fsn.term AS NVARCHAR(500))) - 2))
                ELSE CAST(fsn.term AS NVARCHAR(500))
            END AS Term,
            CAST(fsn.term AS NVARCHAR(500)) AS FSN,
            c.active AS IsActive,
            'Parent' AS NodeType,
            -- Check if this parent has more parents
            CASE WHEN EXISTS (
                SELECT 1 FROM curr_relationship_f r2 
                WHERE r2.sourceId = r.destinationId 
                  AND r2.typeId = '116680003' 
                  AND r2.active = 1
            ) THEN 1 ELSE 0 END AS HasMoreParents,
            -- Count of parents
            (SELECT COUNT(DISTINCT r2.destinationId) FROM curr_relationship_f r2 
             WHERE r2.sourceId = r.destinationId 
               AND r2.typeId = '116680003' 
               AND r2.active = 1) AS ParentCount
        FROM curr_relationship_f r
        INNER JOIN curr_concept_f c ON r.destinationId = c.id
        INNER JOIN curr_description_f fsn ON r.destinationId = fsn.conceptId 
            AND fsn.typeId = '900000000000003001' -- FSN
            AND fsn.active = 1
        WHERE r.sourceId = @ConceptId
          AND r.typeId = '116680003'  -- IS A relationship
          AND r.active = 1
        ORDER BY Term
    END

    -- =============================================
    -- 3. Get direct children (if requested)
    -- =============================================
    IF @Direction IN ('Children', 'Both')
    BEGIN
        SELECT DISTINCT
            r.sourceId AS ConceptId,
            CASE 
                WHEN CHARINDEX('(', CAST(fsn.term AS NVARCHAR(500))) > 0 
                THEN RTRIM(LEFT(CAST(fsn.term AS NVARCHAR(500)), CHARINDEX('(', CAST(fsn.term AS NVARCHAR(500))) - 2))
                ELSE CAST(fsn.term AS NVARCHAR(500))
            END AS Term,
            CAST(fsn.term AS NVARCHAR(500)) AS FSN,
            c.active AS IsActive,
            'Child' AS NodeType,
            -- Check if this child has more children
            CASE WHEN EXISTS (
                SELECT 1 FROM curr_relationship_f r2 
                WHERE r2.destinationId = r.sourceId 
                  AND r2.typeId = '116680003' 
                  AND r2.active = 1
            ) THEN 1 ELSE 0 END AS HasMoreChildren,
            -- Count of children
            (SELECT COUNT(DISTINCT r2.sourceId) FROM curr_relationship_f r2 
             WHERE r2.destinationId = r.sourceId 
               AND r2.typeId = '116680003' 
               AND r2.active = 1) AS ChildCount
        FROM curr_relationship_f r
        INNER JOIN curr_concept_f c ON r.sourceId = c.id
        INNER JOIN curr_description_f fsn ON r.sourceId = fsn.conceptId 
            AND fsn.typeId = '900000000000003001' -- FSN
            AND fsn.active = 1
        WHERE r.destinationId = @ConceptId
          AND r.typeId = '116680003'  -- IS A relationship
          AND r.active = 1
        ORDER BY Term
    END

END
GO

-- =============================================
-- Test examples
-- =============================================
-- Get both parents and children:
-- EXEC dbo.GetSnomedDirectRelatives @ConceptId = '233604007'

-- Get only parents:
-- EXEC dbo.GetSnomedDirectRelatives @ConceptId = '233604007', @Direction = 'Parents'

-- Get only children:
-- EXEC dbo.GetSnomedDirectRelatives @ConceptId = '233604007', @Direction = 'Children'
