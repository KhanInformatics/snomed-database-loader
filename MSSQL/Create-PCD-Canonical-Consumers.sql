/*
    Current Primary Care Domain supporting-product views and compatibility
    procedures.

    Prerequisites:
      Create-PCD-Database.sql has created the dedicated PCD database.
      Import-PCD-GPData.ps1 has successfully loaded both
      PCD.dbo.PCD_GPData_Cluster_Refset and
      PCD.dbo.PCD_GDPPR_Cluster_Refset.

    The legacy Output_ID/ruleset/service tables are intentionally untouched.
    GPData Cluster_Category and Type_of_Inclusion are not replacements for
    those historical concepts.
*/

USE PCD;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.PCD_GPData_Cluster_Refset', N'U') IS NULL
    THROW 51000, 'dbo.PCD_GPData_Cluster_Refset has not been loaded.', 1;

IF OBJECT_ID(N'dbo.PCD_GDPPR_Cluster_Refset', N'U') IS NULL
    THROW 51000, 'dbo.PCD_GDPPR_Cluster_Refset has not been loaded.', 1;
GO

CREATE OR ALTER VIEW dbo.PCD_GPData_Cluster_Refset_Active
AS
    SELECT
        Cluster_Category,
        Cluster_ID,
        Cluster_Desc,
        Active_in_Refset,
        Refset_Status_Date,
        RefsetId,
        Refset_Description,
        ConceptId,
        ConceptId_Description,
        Active_Code_Status,
        Code_Status_Date,
        Type_of_Inclusion,
        Sensitive_Status,
        Sensitive_Status_Date,
        Load_Id
    FROM dbo.PCD_GPData_Cluster_Refset
    WHERE Active_in_Refset = 1
      AND Active_Code_Status = 1;
GO

CREATE OR ALTER VIEW dbo.PCD_GDPPR_Cluster_Refset_Active
AS
    SELECT
        Cluster_Category,
        Cluster_ID,
        Cluster_Desc,
        Active_in_Refset,
        Refset_Status_Date,
        RefsetId,
        Refset_Description,
        ConceptId,
        ConceptId_Description,
        Active_Code_Status,
        Code_Status_Date,
        Type_of_Inclusion,
        Sensitive_Status,
        Sensitive_Status_Date,
        Load_Id
    FROM dbo.PCD_GDPPR_Cluster_Refset
    WHERE Active_in_Refset = 1
      AND Active_Code_Status = 1;
GO

CREATE OR ALTER VIEW dbo.PCD_SupportingProduct_Cluster_Refset_Current
AS
    SELECT
        CAST(N'GPData' AS NVARCHAR(16)) AS Product_Code,
        Cluster_Category,
        Cluster_ID,
        Cluster_Desc,
        Active_in_Refset,
        Refset_Status_Date,
        RefsetId,
        Refset_Description,
        ConceptId,
        ConceptId_Description,
        Active_Code_Status,
        Code_Status_Date,
        Type_of_Inclusion,
        Sensitive_Status,
        Sensitive_Status_Date,
        Load_Id
    FROM dbo.PCD_GPData_Cluster_Refset

    UNION ALL

    SELECT
        CAST(N'GDPPR' AS NVARCHAR(16)) AS Product_Code,
        Cluster_Category,
        Cluster_ID,
        Cluster_Desc,
        Active_in_Refset,
        Refset_Status_Date,
        RefsetId,
        Refset_Description,
        ConceptId,
        ConceptId_Description,
        Active_Code_Status,
        Code_Status_Date,
        Type_of_Inclusion,
        Sensitive_Status,
        Sensitive_Status_Date,
        Load_Id
    FROM dbo.PCD_GDPPR_Cluster_Refset;
GO

IF USER_ID(N'snomedreader') IS NOT NULL
BEGIN
    GRANT SELECT ON OBJECT::dbo.PCD_GPData_Cluster_Refset_Active TO snomedreader;
END;
GO

USE SNOMEDCT;
GO

/*
    Compatibility contract for existing cluster-search callers. The final
    column keeps its historical name, but now contains the current product's
    Type_of_Inclusion value ("Refset" or "PC refset"). New consumers should
    use dbo.PCD_GPData_Cluster_Refset_Active and its exact source column names.
*/
CREATE OR ALTER VIEW dbo.PCD_GPData_Membership_Current
AS
    SELECT
        ISNULL(CAST(Cluster_ID AS VARCHAR(50)), '') AS Cluster_ID,
        ISNULL(CAST(Cluster_Desc AS VARCHAR(500)), '') AS Cluster_Description,
        ISNULL(CAST(ConceptId AS VARCHAR(255)), '') AS SNOMED_code,
        ISNULL(CAST(ConceptId_Description AS VARCHAR(500)), '') AS SNOMED_code_description,
        ISNULL(CAST(RefsetId AS VARCHAR(18)), '') AS PCD_Refset_ID,
        ISNULL(CAST(Type_of_Inclusion AS VARCHAR(500)), '') AS Service_and_Ruleset
    FROM PCD.dbo.PCD_GPData_Cluster_Refset_Active;
GO

CREATE OR ALTER PROCEDURE dbo.GetSNOMEDCodesByClusterID
    @ClusterID NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        SNOMED_code,
        SNOMED_code_description,
        MIN(Cluster_ID) AS Cluster_ID,
        MIN(Cluster_Description) AS Cluster_Description,
        MIN(PCD_Refset_ID) AS PCD_Refset_ID,
        MIN(Service_and_Ruleset) AS Service_and_Ruleset
    FROM dbo.PCD_GPData_Membership_Current
    WHERE Cluster_ID IN (
        SELECT LTRIM(RTRIM(value))
        FROM STRING_SPLIT(@ClusterID, N',')
        WHERE LTRIM(RTRIM(value)) <> N''
    )
      AND SNOMED_code <> N''
    GROUP BY SNOMED_code, SNOMED_code_description
    ORDER BY SNOMED_code;
END;
GO

CREATE OR ALTER PROCEDURE dbo.GetSNOMEDCodesByClusterIDList
    @ClusterIDList NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ClusterIDs TABLE (
        Cluster_ID NVARCHAR(64) NOT NULL PRIMARY KEY
    );

    INSERT INTO @ClusterIDs (Cluster_ID)
    SELECT DISTINCT LTRIM(RTRIM(value))
    FROM STRING_SPLIT(@ClusterIDList, N',')
    WHERE LTRIM(RTRIM(value)) <> N'';

    SELECT DISTINCT
        p.SNOMED_code,
        p.SNOMED_code_description
    FROM dbo.PCD_GPData_Membership_Current AS p
    INNER JOIN @ClusterIDs AS c
        ON c.Cluster_ID = p.Cluster_ID
    ORDER BY p.SNOMED_code;
END;
GO

CREATE OR ALTER PROCEDURE dbo.GetSNOMEDCodesByPCDRefsetID
    @PCD_Refset_ID NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT DISTINCT
        Cluster_ID,
        Cluster_Description,
        SNOMED_code,
        SNOMED_code_description,
        PCD_Refset_ID,
        Service_and_Ruleset
    FROM dbo.PCD_GPData_Membership_Current
    WHERE PCD_Refset_ID = @PCD_Refset_ID
    ORDER BY SNOMED_code;
END;
GO

IF USER_ID(N'snomedreader') IS NOT NULL
BEGIN
    GRANT EXECUTE ON OBJECT::dbo.GetSNOMEDCodesByClusterID TO snomedreader;
    GRANT EXECUTE ON OBJECT::dbo.GetSNOMEDCodesByClusterIDList TO snomedreader;
    GRANT EXECUTE ON OBJECT::dbo.GetSNOMEDCodesByPCDRefsetID TO snomedreader;
END;
GO
