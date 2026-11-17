-- =============================================================================
-- CreateSensitiveCodeListCombined.sql
-- Creates and populates dbo.SensitiveCodeListCombined in the READv2 database
-- combining RCGPSNOMEDtoREADv2 and AlbasoftSensitiveCodeList with CodeSource
-- indicating BOTH, RCGP_ONLY, or ALBASOFT_ONLY.
-- =============================================================================
USE [READv2];
GO

IF OBJECT_ID(N'dbo.SensitiveCodeListCombined', N'U') IS NOT NULL
    DROP TABLE dbo.SensitiveCodeListCombined;
GO

CREATE TABLE dbo.SensitiveCodeListCombined (
    ReadV2Code           VARCHAR(10)    NOT NULL,
    ReadV2Term           NVARCHAR(200)  NULL,
    Exclusion_Category   NVARCHAR(60)   NULL,
    SNOMED_ConceptID     VARCHAR(20)    NULL,
    SNOMED_PreferredTerm NVARCHAR(500)  NULL,
    CodeSource           VARCHAR(20)    NOT NULL,  -- BOTH, RCGP_ONLY, ALBASOFT_ONLY
    MappingSource        VARCHAR(20)    NULL,
    MatchLevel           VARCHAR(20)    NULL,
    MatchScore           DECIMAL(4,3)   NULL,
    ReviewStatus         VARCHAR(20)    NOT NULL DEFAULT 'PENDING',
    ReviewNotes          NVARCHAR(500)  NULL,
    PRIMARY KEY (ReadV2Code)
);
GO

-- Insert RCGP codes (tagged BOTH or RCGP_ONLY depending on Albasoft match)
INSERT INTO dbo.SensitiveCodeListCombined
      (ReadV2Code, ReadV2Term, Exclusion_Category, SNOMED_ConceptID,
       SNOMED_PreferredTerm, CodeSource, MappingSource, MatchLevel, MatchScore)
SELECT r.ReadV2Code,
       r.ReadV2Term,
       r.Exclusion_Category,
       r.SNOMED_ConceptID,
       r.Preferred_Term,
       CASE WHEN a.AlbasoftCode IS NOT NULL
            THEN 'BOTH' ELSE 'RCGP_ONLY' END,
       r.MappingSource,
       r.MatchLevel,
       r.MatchScore
  FROM dbo.RCGPSNOMEDtoREADv2 r
  LEFT JOIN dbo.AlbasoftSensitiveCodeList a
    ON RTRIM(REPLACE(r.ReadV2Code, '.', ''))
     = RTRIM(REPLACE(a.AlbasoftCode, '.', ''));

-- Insert Albasoft-only codes (not already in RCGP)
INSERT INTO dbo.SensitiveCodeListCombined
      (ReadV2Code, ReadV2Term, CodeSource)
SELECT a.AlbasoftCode,
       a.Term60,
       'ALBASOFT_ONLY'
  FROM dbo.AlbasoftSensitiveCodeList a
 WHERE NOT EXISTS (
       SELECT 1 FROM dbo.RCGPSNOMEDtoREADv2 r
        WHERE RTRIM(REPLACE(r.ReadV2Code, '.', ''))
            = RTRIM(REPLACE(a.AlbasoftCode, '.', ''))
       );
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- Verify
-- ─────────────────────────────────────────────────────────────────────────────
SELECT CodeSource, COUNT(*) AS Cnt
  FROM dbo.SensitiveCodeListCombined
 GROUP BY CodeSource
 ORDER BY CodeSource;

SELECT COUNT(*) AS TotalCodes FROM dbo.SensitiveCodeListCombined;

SELECT ReviewStatus, COUNT(*) AS Cnt
  FROM dbo.SensitiveCodeListCombined
 GROUP BY ReviewStatus;
GO
