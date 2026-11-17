-- =============================================================================
-- AnalyseRCGPvsAlbasoft.sql
-- Compare [READv2].[dbo].[RCGPSNOMEDtoREADv2] against
--         [READv2].[dbo].[AlbasoftSensitiveCodeList]
-- =============================================================================
USE [READv2];
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Summary counts for each table
-- ─────────────────────────────────────────────────────────────────────────────
SELECT 'RCGPSNOMEDtoREADv2'         AS Source,
       COUNT(*)                      AS TotalRows,
       COUNT(DISTINCT ReadV2Code)    AS UniqueReadV2Codes
  FROM dbo.RCGPSNOMEDtoREADv2

UNION ALL

SELECT 'AlbasoftSensitiveCodeList',
       COUNT(*),
       COUNT(DISTINCT AlbasoftCode)
  FROM dbo.AlbasoftSensitiveCodeList;
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Overlap — ReadV2 codes present in BOTH lists
--    Normalise by trimming trailing dots for comparison
-- ─────────────────────────────────────────────────────────────────────────────
SELECT r.ReadV2Code,
       r.ReadV2Term,
       r.Exclusion_Category,
       r.SNOMED_ConceptID,
       r.Preferred_Term      AS SNOMED_PreferredTerm,
       r.MappingSource,
       r.MatchLevel,
       r.MatchScore
  FROM dbo.RCGPSNOMEDtoREADv2 r
 INNER JOIN dbo.AlbasoftSensitiveCodeList a
    ON RTRIM(REPLACE(r.ReadV2Code, '.', ''))
     = RTRIM(REPLACE(a.AlbasoftCode, '.', ''))
 ORDER BY r.ReadV2Code;
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Codes ONLY in RCGP (not in Albasoft)
-- ─────────────────────────────────────────────────────────────────────────────
SELECT r.ReadV2Code,
       r.ReadV2Term,
       r.Exclusion_Category,
       r.SNOMED_ConceptID,
       r.Preferred_Term      AS SNOMED_PreferredTerm,
       r.MappingSource,
       r.MatchLevel,
       r.MatchScore
  FROM dbo.RCGPSNOMEDtoREADv2 r
 WHERE NOT EXISTS (
       SELECT 1 FROM dbo.AlbasoftSensitiveCodeList a
        WHERE RTRIM(REPLACE(a.AlbasoftCode, '.', ''))
            = RTRIM(REPLACE(r.ReadV2Code, '.', ''))
       )
 ORDER BY r.ReadV2Code;
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. Codes ONLY in Albasoft (not in RCGP)
-- ─────────────────────────────────────────────────────────────────────────────
SELECT a.AlbasoftCode,
       a.ReadCode,
       a.Term60           AS ReadV2Term,
       a.MatchedInREADv2
  FROM dbo.AlbasoftSensitiveCodeList a
 WHERE NOT EXISTS (
       SELECT 1 FROM dbo.RCGPSNOMEDtoREADv2 r
        WHERE RTRIM(REPLACE(r.ReadV2Code, '.', ''))
            = RTRIM(REPLACE(a.AlbasoftCode, '.', ''))
       )
 ORDER BY a.AlbasoftCode;
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. Venn diagram summary counts
-- ─────────────────────────────────────────────────────────────────────────────
;WITH
  rcgp AS (
    SELECT DISTINCT RTRIM(REPLACE(ReadV2Code, '.', '')) AS Code
      FROM dbo.RCGPSNOMEDtoREADv2
  ),
  alb AS (
    SELECT DISTINCT RTRIM(REPLACE(AlbasoftCode, '.', '')) AS Code
      FROM dbo.AlbasoftSensitiveCodeList
  )
SELECT
  (SELECT COUNT(*) FROM rcgp r INNER JOIN alb a ON r.Code = a.Code)  AS InBoth,
  (SELECT COUNT(*) FROM rcgp r WHERE NOT EXISTS (SELECT 1 FROM alb a WHERE a.Code = r.Code)) AS OnlyInRCGP,
  (SELECT COUNT(*) FROM alb  a WHERE NOT EXISTS (SELECT 1 FROM rcgp r WHERE r.Code = a.Code)) AS OnlyInAlbasoft;
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. RCGP breakdown by Exclusion Category — overlap vs unique
-- ─────────────────────────────────────────────────────────────────────────────
SELECT r.Exclusion_Category,
       COUNT(*)                                                        AS RCGP_Total,
       SUM(CASE WHEN a.AlbasoftCode IS NOT NULL THEN 1 ELSE 0 END)    AS AlsoInAlbasoft,
       SUM(CASE WHEN a.AlbasoftCode IS NULL     THEN 1 ELSE 0 END)    AS OnlyInRCGP
  FROM dbo.RCGPSNOMEDtoREADv2 r
  LEFT JOIN dbo.AlbasoftSensitiveCodeList a
    ON RTRIM(REPLACE(r.ReadV2Code, '.', ''))
     = RTRIM(REPLACE(a.AlbasoftCode, '.', ''))
 GROUP BY r.Exclusion_Category
 ORDER BY r.Exclusion_Category;
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- 7. RCGP breakdown by MappingSource — overlap vs unique
-- ─────────────────────────────────────────────────────────────────────────────
SELECT r.MappingSource,
       COUNT(*)                                                        AS RCGP_Total,
       SUM(CASE WHEN a.AlbasoftCode IS NOT NULL THEN 1 ELSE 0 END)    AS AlsoInAlbasoft,
       SUM(CASE WHEN a.AlbasoftCode IS NULL     THEN 1 ELSE 0 END)    AS OnlyInRCGP
  FROM dbo.RCGPSNOMEDtoREADv2 r
  LEFT JOIN dbo.AlbasoftSensitiveCodeList a
    ON RTRIM(REPLACE(r.ReadV2Code, '.', ''))
     = RTRIM(REPLACE(a.AlbasoftCode, '.', ''))
 GROUP BY r.MappingSource
 ORDER BY r.MappingSource;
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- 8. Full combined codelist — union of both sources with provenance
--    Both resolve terms from the same Read v2 dictionary.
-- ─────────────────────────────────────────────────────────────────────────────
SELECT ReadV2Code,
       ReadV2Term,
       Exclusion_Category,
       SNOMED_ConceptID,
       SNOMED_PreferredTerm,
       CodeSource
  FROM (
    -- Codes from RCGP (may or may not be in Albasoft)
    SELECT r.ReadV2Code,
           r.ReadV2Term,
           r.Exclusion_Category,
           r.SNOMED_ConceptID,
           r.Preferred_Term      AS SNOMED_PreferredTerm,
           CASE WHEN a.AlbasoftCode IS NOT NULL
                THEN 'BOTH' ELSE 'RCGP_ONLY' END AS CodeSource
      FROM dbo.RCGPSNOMEDtoREADv2 r
      LEFT JOIN dbo.AlbasoftSensitiveCodeList a
        ON RTRIM(REPLACE(r.ReadV2Code, '.', ''))
         = RTRIM(REPLACE(a.AlbasoftCode, '.', ''))

    UNION ALL

    -- Codes only in Albasoft (not in RCGP)
    SELECT a.AlbasoftCode        AS ReadV2Code,
           a.Term60              AS ReadV2Term,
           NULL                  AS Exclusion_Category,
           NULL                  AS SNOMED_ConceptID,
           NULL                  AS SNOMED_PreferredTerm,
           'ALBASOFT_ONLY'       AS CodeSource
      FROM dbo.AlbasoftSensitiveCodeList a
     WHERE NOT EXISTS (
           SELECT 1 FROM dbo.RCGPSNOMEDtoREADv2 r
            WHERE RTRIM(REPLACE(r.ReadV2Code, '.', ''))
                = RTRIM(REPLACE(a.AlbasoftCode, '.', ''))
           )
  ) combined
 ORDER BY ReadV2Code;
GO
