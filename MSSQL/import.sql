-- Generating BULK INSERTS for Monolith + UK Primary Care Snapshot
USE snomedct;
GO
TRUNCATE TABLE curr_concept_f;
TRUNCATE TABLE curr_description_f;
TRUNCATE TABLE curr_textdefinition_f;
TRUNCATE TABLE curr_relationship_f;
TRUNCATE TABLE curr_stated_relationship_f;
TRUNCATE TABLE curr_langrefset_f;
TRUNCATE TABLE curr_simplerefset_f;
TRUNCATE TABLE curr_attributevaluerefset_f;
TRUNCATE TABLE curr_associationrefset_f;
TRUNCATE TABLE curr_simplemaprefset_f;
TRUNCATE TABLE curr_extendedmaprefset_f;
-- Processing folder: C:\SNOMEDCT\CurrentReleases\uk_sct2mo_39.6.0_20250312000001Z\SnomedCT_MonolithRF2_PRODUCTION_20250312T120000Z\Snapshot
BULK INSERT curr_associationrefset_f FROM 'C:\\\\SNOMEDCT\\\\CurrentReleases\\\\uk_sct2mo_39.6.0_20250312000001Z\\\\SnomedCT_MonolithRF2_PRODUCTION_20250312T120000Z\\\\Snapshot\\\\Refset\\\\Content\\\\der2_cRefset_AssociationMONOSnapshot_GB_20250312.txt' WITH (FIRSTROW = 2, FIELDTERMINATOR = '\t', ROWTERMINATOR = '\n', TABLOCK);
BULK INSERT curr_attributevaluerefset_f FROM 'C:\\\\SNOMEDCT\\\\CurrentReleases\\\\uk_sct2mo_39.6.0_20250312000001Z\\\\SnomedCT_MonolithRF2_PRODUCTION_20250312T120000Z\\\\Snapshot\\\\Refset\\\\Content\\\\der2_cRefset_AttributeValueMONOSnapshot_GB_20250312.txt' WITH (FIRSTROW = 2, FIELDTERMINATOR = '\t', ROWTERMINATOR = '\n', TABLOCK);
BULK INSERT curr_simplerefset_f FROM 'C:\\\\SNOMEDCT\\\\CurrentReleases\\\\uk_sct2mo_39.6.0_20250312000001Z\\\\SnomedCT_MonolithRF2_PRODUCTION_20250312T120000Z\\\\Snapshot\\\\Refset\\\\Content\\\\der2_Refset_SimpleMONOSnapshot_GB_20250312.txt' WITH (FIRSTROW = 2, FIELDTERMINATOR = '\t', ROWTERMINATOR = '\n', TABLOCK);
BULK INSERT curr_langrefset_f FROM 'C:\\\\SNOMEDCT\\\\CurrentReleases\\\\uk_sct2mo_39.6.0_20250312000001Z\\\\SnomedCT_MonolithRF2_PRODUCTION_20250312T120000Z\\\\Snapshot\\\\Refset\\\\Language\\\\der2_cRefset_LanguageMONOSnapshot-en_GB_20250312.txt' WITH (FIRSTROW = 2, FIELDTERMINATOR = '\t', ROWTERMINATOR = '\n', TABLOCK);
BULK INSERT curr_extendedmaprefset_f FROM 'C:\\\\SNOMEDCT\\\\CurrentReleases\\\\uk_sct2mo_39.6.0_20250312000001Z\\\\SnomedCT_MonolithRF2_PRODUCTION_20250312T120000Z\\\\Snapshot\\\\Refset\\\\Map\\\\der2_iisssccRefset_ExtendedMapMONOSnapshot_GB_20250312.txt' WITH (FIRSTROW = 2, FIELDTERMINATOR = '\t', ROWTERMINATOR = '\n', TABLOCK);
BULK INSERT curr_simplemaprefset_f FROM 'C:\\\\SNOMEDCT\\\\CurrentReleases\\\\uk_sct2mo_39.6.0_20250312000001Z\\\\SnomedCT_MonolithRF2_PRODUCTION_20250312T120000Z\\\\Snapshot\\\\Refset\\\\Map\\\\der2_sRefset_SimpleMapMONOSnapshot_GB_20250312.txt' WITH (FIRSTROW = 2, FIELDTERMINATOR = '\t', ROWTERMINATOR = '\n', TABLOCK);
BULK INSERT curr_concept_f FROM 'C:\\\\SNOMEDCT\\\\CurrentReleases\\\\uk_sct2mo_39.6.0_20250312000001Z\\\\SnomedCT_MonolithRF2_PRODUCTION_20250312T120000Z\\\\Snapshot\\\\Terminology\\\\sct2_Concept_MONOSnapshot_GB_20250312.txt' WITH (FIRSTROW = 2, FIELDTERMINATOR = '\t', ROWTERMINATOR = '\n', TABLOCK);
BULK INSERT curr_description_f FROM 'C:\\\\SNOMEDCT\\\\CurrentReleases\\\\uk_sct2mo_39.6.0_20250312000001Z\\\\SnomedCT_MonolithRF2_PRODUCTION_20250312T120000Z\\\\Snapshot\\\\Terminology\\\\sct2_Description_MONOSnapshot-en_GB_20250312.txt' WITH (FIRSTROW = 2, FIELDTERMINATOR = '\t', ROWTERMINATOR = '\n', TABLOCK);
BULK INSERT curr_relationship_f FROM 'C:\\\\SNOMEDCT\\\\CurrentReleases\\\\uk_sct2mo_39.6.0_20250312000001Z\\\\SnomedCT_MonolithRF2_PRODUCTION_20250312T120000Z\\\\Snapshot\\\\Terminology\\\\sct2_RelationshipConcreteValues_MONOSnapshot_GB_20250312.txt' WITH (FIRSTROW = 2, FIELDTERMINATOR = '\t', ROWTERMINATOR = '\n', TABLOCK);
BULK INSERT curr_relationship_f FROM 'C:\\\\SNOMEDCT\\\\CurrentReleases\\\\uk_sct2mo_39.6.0_20250312000001Z\\\\SnomedCT_MonolithRF2_PRODUCTION_20250312T120000Z\\\\Snapshot\\\\Terminology\\\\sct2_Relationship_MONOSnapshot_GB_20250312.txt' WITH (FIRSTROW = 2, FIELDTERMINATOR = '\t', ROWTERMINATOR = '\n', TABLOCK);
BULK INSERT curr_stated_relationship_f FROM 'C:\\\\SNOMEDCT\\\\CurrentReleases\\\\uk_sct2mo_39.6.0_20250312000001Z\\\\SnomedCT_MonolithRF2_PRODUCTION_20250312T120000Z\\\\Snapshot\\\\Terminology\\\\sct2_StatedRelationship_MONOSnapshot_GB_20250312.txt' WITH (FIRSTROW = 2, FIELDTERMINATOR = '\t', ROWTERMINATOR = '\n', TABLOCK);
BULK INSERT curr_textdefinition_f FROM 'C:\\\\SNOMEDCT\\\\CurrentReleases\\\\uk_sct2mo_39.6.0_20250312000001Z\\\\SnomedCT_MonolithRF2_PRODUCTION_20250312T120000Z\\\\Snapshot\\\\Terminology\\\\sct2_TextDefinition_MONOSnapshot-en_GB_20250312.txt' WITH (FIRSTROW = 2, FIELDTERMINATOR = '\t', ROWTERMINATOR = '\n', TABLOCK);
-- Processing folder: C:\SNOMEDCT\CurrentReleases\uk_sct2pc_54.0.0_20241205000000Z\SnomedCT_UKPrimaryCareRF2_PRODUCTION_20241205T000000Z\Snapshot
BULK INSERT curr_associationrefset_f FROM 'C:\\\\SNOMEDCT\\\\CurrentReleases\\\\uk_sct2pc_54.0.0_20241205000000Z\\\\SnomedCT_UKPrimaryCareRF2_PRODUCTION_20241205T000000Z\\\\Snapshot\\\\Refset\\\\Content\\\\der2_cRefset_AssociationUKPCSnapshot_1000230_20241205.txt' WITH (FIRSTROW = 2, FIELDTERMINATOR = '\t', ROWTERMINATOR = '\n', TABLOCK);
BULK INSERT curr_attributevaluerefset_f FROM 'C:\\\\SNOMEDCT\\\\CurrentReleases\\\\uk_sct2pc_54.0.0_20241205000000Z\\\\SnomedCT_UKPrimaryCareRF2_PRODUCTION_20241205T000000Z\\\\Snapshot\\\\Refset\\\\Content\\\\der2_cRefset_AttributeValueUKPCSnapshot_1000230_20241205.txt' WITH (FIRSTROW = 2, FIELDTERMINATOR = '\t', ROWTERMINATOR = '\n', TABLOCK);
BULK INSERT curr_simplerefset_f FROM 'C:\\\\SNOMEDCT\\\\CurrentReleases\\\\uk_sct2pc_54.0.0_20241205000000Z\\\\SnomedCT_UKPrimaryCareRF2_PRODUCTION_20241205T000000Z\\\\Snapshot\\\\Refset\\\\Content\\\\der2_Refset_SimpleUKPCSnapshot_1000230_20241205.txt' WITH (FIRSTROW = 2, FIELDTERMINATOR = '\t', ROWTERMINATOR = '\n', TABLOCK);
BULK INSERT curr_langrefset_f FROM 'C:\\\\SNOMEDCT\\\\CurrentReleases\\\\uk_sct2pc_54.0.0_20241205000000Z\\\\SnomedCT_UKPrimaryCareRF2_PRODUCTION_20241205T000000Z\\\\Snapshot\\\\Refset\\\\Language\\\\der2_cRefset_LanguageUKPCSnapshot-en_1000230_20241205.txt' WITH (FIRSTROW = 2, FIELDTERMINATOR = '\t', ROWTERMINATOR = '\n', TABLOCK);
BULK INSERT curr_extendedmaprefset_f FROM 'C:\\\\SNOMEDCT\\\\CurrentReleases\\\\uk_sct2pc_54.0.0_20241205000000Z\\\\SnomedCT_UKPrimaryCareRF2_PRODUCTION_20241205T000000Z\\\\Snapshot\\\\Refset\\\\Map\\\\der2_iisssccRefset_ExtendedMapUKPCSnapshot_1000230_20241205.txt' WITH (FIRSTROW = 2, FIELDTERMINATOR = '\t', ROWTERMINATOR = '\n', TABLOCK);
BULK INSERT curr_simplemaprefset_f FROM 'C:\\\\SNOMEDCT\\\\CurrentReleases\\\\uk_sct2pc_54.0.0_20241205000000Z\\\\SnomedCT_UKPrimaryCareRF2_PRODUCTION_20241205T000000Z\\\\Snapshot\\\\Refset\\\\Map\\\\der2_sRefset_SimpleMapUKPCSnapshot_1000230_20241205.txt' WITH (FIRSTROW = 2, FIELDTERMINATOR = '\t', ROWTERMINATOR = '\n', TABLOCK);
BULK INSERT curr_concept_f FROM 'C:\\\\SNOMEDCT\\\\CurrentReleases\\\\uk_sct2pc_54.0.0_20241205000000Z\\\\SnomedCT_UKPrimaryCareRF2_PRODUCTION_20241205T000000Z\\\\Snapshot\\\\Terminology\\\\sct2_Concept_UKPCSnapshot_1000230_20241205.txt' WITH (FIRSTROW = 2, FIELDTERMINATOR = '\t', ROWTERMINATOR = '\n', TABLOCK);
BULK INSERT curr_description_f FROM 'C:\\\\SNOMEDCT\\\\CurrentReleases\\\\uk_sct2pc_54.0.0_20241205000000Z\\\\SnomedCT_UKPrimaryCareRF2_PRODUCTION_20241205T000000Z\\\\Snapshot\\\\Terminology\\\\sct2_Description_UKPCSnapshot-en_1000230_20241205.txt' WITH (FIRSTROW = 2, FIELDTERMINATOR = '\t', ROWTERMINATOR = '\n', TABLOCK);
BULK INSERT curr_relationship_f FROM 'C:\\\\SNOMEDCT\\\\CurrentReleases\\\\uk_sct2pc_54.0.0_20241205000000Z\\\\SnomedCT_UKPrimaryCareRF2_PRODUCTION_20241205T000000Z\\\\Snapshot\\\\Terminology\\\\sct2_Relationship_UKPCSnapshot_1000230_20241205.txt' WITH (FIRSTROW = 2, FIELDTERMINATOR = '\t', ROWTERMINATOR = '\n', TABLOCK);
BULK INSERT curr_stated_relationship_f FROM 'C:\\\\SNOMEDCT\\\\CurrentReleases\\\\uk_sct2pc_54.0.0_20241205000000Z\\\\SnomedCT_UKPrimaryCareRF2_PRODUCTION_20241205T000000Z\\\\Snapshot\\\\Terminology\\\\sct2_StatedRelationship_UKPCSnapshot_1000230_20241205.txt' WITH (FIRSTROW = 2, FIELDTERMINATOR = '\t', ROWTERMINATOR = '\n', TABLOCK);
BULK INSERT curr_textdefinition_f FROM 'C:\\\\SNOMEDCT\\\\CurrentReleases\\\\uk_sct2pc_54.0.0_20241205000000Z\\\\SnomedCT_UKPrimaryCareRF2_PRODUCTION_20241205T000000Z\\\\Snapshot\\\\Terminology\\\\sct2_TextDefinition_UKPCSnapshot-en_1000230_20241205.txt' WITH (FIRSTROW = 2, FIELDTERMINATOR = '\t', ROWTERMINATOR = '\n', TABLOCK);
