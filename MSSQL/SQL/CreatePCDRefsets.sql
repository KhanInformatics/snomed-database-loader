-- Check if table exists, truncate and recreate with proper structure
IF OBJECT_ID('dbo.PCD_Refset_Content_by_Output', 'U') IS NOT NULL
BEGIN
    -- Truncate existing data
    TRUNCATE TABLE PCD_Refset_Content_by_Output;
    
    -- Drop existing table
    DROP TABLE PCD_Refset_Content_by_Output;
END

-- Create the table with correct data types
CREATE TABLE PCD_Refset_Content_by_Output (
    Output_ID VARCHAR(50) NOT NULL,
    Cluster_ID VARCHAR(50) NOT NULL,
    Cluster_Description VARCHAR(255) NOT NULL,
    SNOMED_code VARCHAR(18) NOT NULL,
    SNOMED_code_description VARCHAR(255) NOT NULL,
    PCD_Refset_ID VARCHAR(18) NOT NULL,
    
    -- Optional: Add constraints
    CONSTRAINT PK_PCD_Refset_Content_by_Output PRIMARY KEY (Output_ID, SNOMED_code),
    CONSTRAINT CK_SNOMED_code_numeric CHECK (ISNUMERIC(SNOMED_code) = 1 AND LEN(SNOMED_code) > 0),
    CONSTRAINT CK_PCD_Refset_ID_numeric CHECK (ISNUMERIC(PCD_Refset_ID) = 1 AND LEN(PCD_Refset_ID) > 0)
);

-- Optional: Add indexes for better query performance
CREATE INDEX IX_PCD_Refset_Content_Cluster_ID ON PCD_Refset_Content_by_Output(Cluster_ID);
CREATE INDEX IX_PCD_Refset_Content_SNOMED_code ON PCD_Refset_Content_by_Output(SNOMED_code);
CREATE INDEX IX_PCD_Refset_Content_PCD_Refset_ID ON PCD_Refset_Content_by_Output(PCD_Refset_ID);