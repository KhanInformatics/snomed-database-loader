-- =============================================================================
-- RCGPSNOMEDtoREADv2 — Final deduplicated codelist
-- Creates and populates a permanent table in the READv2 database from the
-- RCGPDataexclusionListtoReadV2Mapping source, keeping only the best match
-- per ReadV2Code (DMWB preferred over SEMANTIC, then highest MatchScore).
-- =============================================================================

USE [READv2];
GO

IF OBJECT_ID(N'dbo.RCGPSNOMEDtoREADv2', N'U') IS NOT NULL
    DROP TABLE dbo.RCGPSNOMEDtoREADv2;
GO

CREATE TABLE dbo.RCGPSNOMEDtoREADv2 (
    Exclusion_Category   NVARCHAR(60)   NOT NULL,
    RefsetID             VARCHAR(20)    NOT NULL,
    Refset_Name          NVARCHAR(255)  NULL,
    SNOMED_ConceptID     VARCHAR(20)    NOT NULL,
    FSN_Term             NVARCHAR(500)  NULL,
    Preferred_Term       NVARCHAR(500)  NULL,
    ConceptIsActive      VARCHAR(1)     NULL,
    ReadV2Code           VARCHAR(10)    NOT NULL,
    ReadV2Term           NVARCHAR(200)  NULL,
    CTV3Code             VARCHAR(10)    NULL,
    CTV3Term             NVARCHAR(200)  NULL,
    MappingSource        VARCHAR(20)    NULL,
    MatchLevel           VARCHAR(20)    NULL,
    MatchScore           DECIMAL(4,3)   NULL
);
GO

;WITH Ranked AS (
  SELECT [Exclusion_Category]
        ,[RefsetID]
        ,[Refset_Name]
        ,[SNOMED_ConceptID]
        ,[FSN_Term]
        ,[Preferred_Term]
        ,[ConceptIsActive]
        ,[ReadV2Code]
        ,[ReadV2Term]
        ,[CTV3Code]
        ,[CTV3Term]
        ,[MappingSource]
        ,[MatchLevel]
        ,[MatchScore]
        ,ROW_NUMBER() OVER (
            PARTITION BY [ReadV2Code]
            ORDER BY CASE [MappingSource] WHEN 'DMWB' THEN 1 ELSE 2 END,
                     [MatchScore] DESC
        ) AS rn
    FROM [READv2].[dbo].[RCGPDataexclusionListtoReadV2Mapping]
    WHERE [ReadV2Code] IS NOT NULL AND [ReadV2Code] <> ''
)
INSERT INTO dbo.RCGPSNOMEDtoREADv2
      ([Exclusion_Category]
      ,[RefsetID]
      ,[Refset_Name]
      ,[SNOMED_ConceptID]
      ,[FSN_Term]
      ,[Preferred_Term]
      ,[ConceptIsActive]
      ,[ReadV2Code]
      ,[ReadV2Term]
      ,[CTV3Code]
      ,[CTV3Term]
      ,[MappingSource]
      ,[MatchLevel]
      ,[MatchScore])
SELECT [Exclusion_Category]
      ,[RefsetID]
      ,[Refset_Name]
      ,[SNOMED_ConceptID]
      ,[FSN_Term]
      ,[Preferred_Term]
      ,[ConceptIsActive]
      ,[ReadV2Code]
      ,[ReadV2Term]
      ,[CTV3Code]
      ,[CTV3Term]
      ,[MappingSource]
      ,[MatchLevel]
      ,[MatchScore]
  FROM Ranked
  WHERE rn = 1
  ORDER BY [ReadV2Code];
GO

-- Verify
SELECT COUNT(*) AS TotalRows FROM dbo.RCGPSNOMEDtoREADv2;

SELECT [MappingSource], COUNT(*) AS Cnt
  FROM dbo.RCGPSNOMEDtoREADv2
 GROUP BY [MappingSource];

SELECT [Exclusion_Category], COUNT(*) AS Cnt
  FROM dbo.RCGPSNOMEDtoREADv2
 GROUP BY [Exclusion_Category]
 ORDER BY [Exclusion_Category];