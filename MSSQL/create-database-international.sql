/* Create the International Edition SNOMED CT database tables */
-- Transact-SQL script to create table structure for SNOMED CT International Edition
-- This creates a separate database to hold the International Edition only
-- Useful for querying International descriptions separately from UK Extension

-- Cannot drop database if you're already in it
USE master;
GO

-- Check if database exists before attempting to drop
IF EXISTS (SELECT name FROM sys.databases WHERE name = 'snomedct_int')
BEGIN
    ALTER DATABASE snomedct_int SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE snomedct_int;
END
GO

CREATE DATABASE snomedct_int;
GO

USE snomedct_int;
GO

-- Core Terminology Tables
IF EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'curr_concept_f') DROP TABLE curr_concept_f;
CREATE TABLE curr_concept_f(
  id varchar(18) not null,
  effectivetime char(8) not null,
  active char(1) not null,
  moduleid varchar(18) not null,
  definitionstatusid varchar(18) not null,
  PRIMARY KEY(id, effectivetime)
);

IF EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'curr_description_f') DROP TABLE curr_description_f;
CREATE TABLE curr_description_f(
  id varchar(18) not null,
  effectivetime char(8) not null,
  active char(1) not null,
  moduleid varchar(18) not null,
  conceptid varchar(18) not null,
  languagecode varchar(2) not null,
  typeid varchar(18) not null,
  term text not null,
  casesignificanceid varchar(18) not null,
  PRIMARY KEY(id, effectivetime)
);

IF EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'curr_textdefinition_f') DROP TABLE curr_textdefinition_f;
CREATE TABLE curr_textdefinition_f(
  id varchar(18) not null,
  effectivetime char(8) not null,
  active char(1) not null,
  moduleid varchar(18) not null,
  conceptid varchar(18) not null,
  languagecode varchar(2) not null,
  typeid varchar(18) not null,
  term text not null,
  casesignificanceid varchar(18) not null,
  PRIMARY KEY(id, effectivetime)
);

IF EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'curr_relationship_f') DROP TABLE curr_relationship_f;
CREATE TABLE curr_relationship_f(
  id varchar(18) not null,
  effectivetime char(8) not null,
  active char(1) not null,
  moduleid varchar(18) not null,
  sourceid varchar(18) not null,
  destinationid varchar(18) not null,
  relationshipgroup varchar(18) not null,
  typeid varchar(18) not null,
  characteristictypeid varchar(18) not null,
  modifierid varchar(18) not null,
  PRIMARY KEY(id, effectivetime)
);

IF EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'curr_stated_relationship_f') DROP TABLE curr_stated_relationship_f;
CREATE TABLE curr_stated_relationship_f(
  id varchar(18) not null,
  effectivetime char(8) not null,
  active char(1) not null,
  moduleid varchar(18) not null,
  sourceid varchar(18) not null,
  destinationid varchar(18) not null,
  relationshipgroup varchar(18) not null,
  typeid varchar(18) not null,
  characteristictypeid varchar(18) not null,
  modifierid varchar(18) not null,
  PRIMARY KEY(id, effectivetime)
);

-- Reference Set Tables
IF EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'curr_langrefset_f') DROP TABLE curr_langrefset_f;
CREATE TABLE curr_langrefset_f(
  id uniqueidentifier not null,
  effectivetime char(8) not null,
  active char(1) not null,
  moduleid varchar(18) not null,
  refsetid varchar(18) not null,
  referencedcomponentid varchar(18) not null,
  acceptabilityid varchar(18) not null,
  PRIMARY KEY(id, effectivetime)
);

IF EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'curr_associationrefset_f') DROP TABLE curr_associationrefset_f;
CREATE TABLE curr_associationrefset_f(
  id uniqueidentifier not null,
  effectivetime char(8) not null,
  active char(1) not null,
  moduleid varchar(18) not null,
  refsetid varchar(18) not null,
  referencedcomponentid varchar(18) not null,
  targetcomponentid varchar(18) not null,
  PRIMARY KEY(id, effectivetime)
);

IF EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'curr_attributevaluerefset_f') DROP TABLE curr_attributevaluerefset_f;
CREATE TABLE curr_attributevaluerefset_f(
  id uniqueidentifier not null,
  effectivetime char(8) not null,
  active char(1) not null,
  moduleid varchar(18) not null,
  refsetid varchar(18) not null,
  referencedcomponentid varchar(18) not null,
  valueid varchar(18) not null,
  PRIMARY KEY(id, effectivetime)
);

IF EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'curr_simplerefset_f') DROP TABLE curr_simplerefset_f;
CREATE TABLE curr_simplerefset_f(
  id uniqueidentifier not null,
  effectivetime char(8) not null,
  active char(1) not null,
  moduleid varchar(18) not null,
  refsetid varchar(18) not null,
  referencedcomponentid varchar(18) not null,
  PRIMARY KEY(id, effectivetime)
);

IF EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'curr_simplemaprefset_f') DROP TABLE curr_simplemaprefset_f;
CREATE TABLE curr_simplemaprefset_f(
  id uniqueidentifier not null,
  effectivetime char(8) not null,
  active char(1) not null,
  moduleid varchar(18) not null,
  refsetid varchar(18) not null,
  referencedcomponentid varchar(18) not null,
  maptarget text not null,
  PRIMARY KEY(id, effectivetime)
);

IF EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'curr_extendedmaprefset_f') DROP TABLE curr_extendedmaprefset_f;
CREATE TABLE curr_extendedmaprefset_f(
  id uniqueidentifier not null,
  effectivetime char(8) not null,
  active char(1) not null,
  moduleid varchar(18) not null,
  refsetid varchar(18) not null,
  referencedcomponentid varchar(18) not null,
  mapGroup smallint not null,
  mapPriority smallint not null,
  mapRule text,
  mapAdvice text,
  mapTarget text,
  correlationId varchar(18),
  mapCategoryId varchar(18),
  PRIMARY KEY(id, effectivetime)
);

PRINT 'SNOMED CT International Edition database (snomedct_int) created successfully.';
PRINT 'Tables created: curr_concept_f, curr_description_f, curr_textdefinition_f,';
PRINT '                curr_relationship_f, curr_stated_relationship_f, curr_langrefset_f,';
PRINT '                curr_associationrefset_f, curr_attributevaluerefset_f, curr_simplerefset_f,';
PRINT '                curr_simplemaprefset_f, curr_extendedmaprefset_f';
GO
