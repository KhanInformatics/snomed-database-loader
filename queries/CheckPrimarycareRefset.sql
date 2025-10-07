DECLARE @ClusterID NVARCHAR(50) = 'AST_COD';

SELECT DISTINCT 
    SNOMED_code,SNOMED_code_description,
    PCD_Refset_ID,
    Cluster_Description
FROM PCD_Refset_Content_V2
WHERE Cluster_ID = @ClusterID
ORDER BY SNOMED_code;