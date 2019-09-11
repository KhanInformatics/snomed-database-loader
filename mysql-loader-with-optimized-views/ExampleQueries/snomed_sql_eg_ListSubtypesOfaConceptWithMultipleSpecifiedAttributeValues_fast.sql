-- SNOMED SQL QUERY EXAMPLE : LIST PREFERRED TERM OF ALL SUBTYPES OF A CONCEPT

-- Find the Preferred Term of subtypes of the concept with id `v_focus_id (set here to 404684003)
-- With an attribute with id`v_attr1_id` (here set to 363698007)
-- With a `value equal to or a subtype of @valueid1 (here set to 39057004)
-- AND
-- With an attribute with id @attributeid2 (here set to 116676008)
-- With a `value equal to or a subtype of @valueid2 (here set to 415582006)

-- Find the clinical findings with a finding site of pulmonary `valve (or subtype) and an 
-- associated morphology of stenosis (or subtype)
-- Expression Constraint: < 404684003 |clinical finding|:
--                              363698007 |finding site| = << 39057004 |pulmonary `valve|,
--                              116676008 |associated morphology| = << 415582006 |stenosis|

-- THIS IS AN OPTIMIZED VERSION OF:
--    snomed_sql_eg_ListSubtypesOfaConceptWithMultipleSpecifiedAttributeValues_slow.sql
-- Unlike the slower `version it run the individual tests separately and then logically combines them.
-- While the slow `version takes between 1 and 2 minutes to run, this `version returns exactly the same result 2 or 3 seconds.

DROP PROCEDURE IF EXISTS `eclSimple`;
DELIMITER ;;
CREATE PROCEDURE eclSimple(`p_ecl` text)
BEGIN
DECLARE `v_text` text;
DECLARE `v_ecl` text;
DECLARE `v_focus_id` bigint;
DECLARE `v_focus_symbol` text;
DECLARE `v_refine1` text;
DECLARE `v_refine2` text;
DECLARE `v_ref2` text;
DECLARE `v_value1_id` bigint(18);
DECLARE `v_value2_id` bigint(18);
DECLARE `v_attr1_id` bigint(18);
DECLARE `v_attr2_id` bigint(18);
DECLARE `v_value1_symbol` text;
DECLARE `v_value2_symbol` text;
DECLARE `v_pos` int;
DECLARE `v_count` int DEFAULT 0;

SET `v_ecl`='';
SET `v_text`=CONCAT(`p_ecl`,'|');

pipe:WHILE `v_text` regexp '\|' DO
	SET `v_count`=`v_count`+1;
	SET `v_ecl`=CONCAT(`v_ecl`,SUBSTRING_INDEX(`v_text`,'|',1));
    SET `v_pos`=LENGTH(SUBSTRING_INDEX(`v_text`,'|',2))+2;
    IF `v_pos`<3 OR `v_pos`>LENGTH(`v_text`) THEN
        LEAVE pipe;
	ELSE
		SET `v_text`=MID(`v_text`,`v_pos`);
	END IF;
    IF `v_count`>10 THEN LEAVE pipe; END IF;
END WHILE pipe;

SET `v_ecl`=REPLACE(`v_ecl`,' ','');

SET `v_focus_symbol`=SUBSTRING_INDEX(`v_ecl`,':',1);
IF `v_focus_symbol` != `v_ecl` THEN
	SET `v_refine1`=SUBSTRING_INDEX(`v_ecl`,':',-1);
	SET `v_refine2`=SUBSTRING_INDEX(`v_refine1`,',',-1);
ELSE
	SET `v_refine1`='';
END IF;

IF LEFT(`v_focus_symbol`,2)='<<' THEN
	SET `v_focus_id`=MID(v_focus_symbol,3);
    SET `v_focus_symbol`='<<';
ELSEIF LEFT(`v_focus_symbol`,1)='<' THEN
	SET `v_focus_id`=MID(`v_focus_symbol`,2);
    SET `v_focus_symbol`='<';
ELSE
	SET `v_focus_id`=`v_focus_symbol`;
    SET `v_focus_symbol`='';
END IF;

IF `v_refine2` != `v_refine1` THEN
	SET `v_refine1`=SUBSTRING_INDEX(`v_refine1`,',',1);
    SET `v_attr2_id`=SUBSTRING_INDEX(`v_refine2`,'=',1);
    SET `v_value2_symbol`=SUBSTRING_INDEX(`v_refine2`,'=',-1);
	IF LEFT(`v_value2_symbol`,2)='<<' THEN
		SET `v_value2_id`=MID(`v_value2_symbol`,3);
		SET `v_value2_symbol`='<<';
	ELSEIF LEFT(`v_value2_symbol`,1)='<' THEN
		SET `v_value1_id`=MID(`v_value2_symbol`,2);
		SET `v_value2_symbol`='<';
	ELSE
		SET `v_value2_id`=`v_value2_symbol`;
		SET `v_value2_symbol`='';
	END IF;    
ELSE
    SET `v_refine2`='';
END IF;
IF `v_refine1` != '' THEN
    SET `v_attr1_id`=SUBSTRING_INDEX(`v_refine1`,'=',1);
    SET `v_value1_symbol`=SUBSTRING_INDEX(`v_refine1`,'=',-1);
	IF LEFT(`v_value1_symbol`,2)='<<' THEN
		SET `v_value1_id`=MID(`v_value1_symbol`,3);
		SET `v_value1_symbol`='<<';
	ELSEIF LEFT(`v_value1_symbol`,1)='<' THEN
		SET `v_value1_id`=MID(`v_value1_symbol`,2);
		SET `v_value1_symbol`='<';
	ELSE
		SET `v_value1_id`=`v_value1_symbol`;
		SET `v_value1_symbol`='';
	END IF;
END IF;

DROP TABLE IF EXISTS tmp_focus;
DROP TABLE IF EXISTS tmp_ref1;
DROP TABLE IF EXISTS tmp_ref2;

-- Create temporary tables
CREATE TEMPORARY TABLE IF NOT EXISTS tmp_focus (
  `id` bigint(20) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4;

CREATE TEMPORARY TABLE IF NOT EXISTS tmp_ref1 (
  `id` bigint(20) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4;

CREATE TEMPORARY TABLE IF NOT EXISTS tmp_ref2 (
  `id` bigint(20) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4;
-- END OF PREPARATION STEPS

-- IF SUBTYPES INCLUDED ADD ALL CONCEPTS PASSING THE SUBSUMPTION TEST TO A TEMPORARY TABLE tmp_focus
IF `v_focus_symbol` = '<' OR `v_focus_symbol` = '<<' THEN
	INSERT IGNORE INTO `tmp_focus` SELECT `subtypeId` FROM `ss_transclose` as `tc` WHERE `tc`.`supertypeId` = `v_focus_id`;
END IF;

-- IF SELF INCLUDED ADD FOCUS CONCEPT TO TEMPORARY TABLE tmp_focus
IF `v_focus_symbol` = '' OR `v_focus_symbol` = '<<' THEN
	INSERT IGNORE INTO `tmp_focus` VALUES (`v_focus_id`);
END IF;

# SELECT * FROM `tmp_focus`;

-- ADD ALL CONCEPTS PASSING THE FIRST ATTRIBUTE VALUE TEST TO TEMPORARY TABLE tmp_ref1
IF `v_refine1` != '' THEN
	IF `v_value1_symbol` = '<' OR `v_value1_symbol` = '<<' THEN
		INSERT IGNORE INTO `tmp_ref1` SELECT DISTINCT `sourceId` FROM `soa_relationship` as `r` WHERE `r`.`active` = 1 AND `r`.`typeId` = `v_attr1_id` 
		AND `r`.`destinationId` IN (SELECT `tc`.`subTypeId` FROM `ss_transclose` as `tc`
		WHERE `tc`.`supertypeId` = `v_value1_id` );
	END IF;
    IF `v_value1_symbol` = '' OR `v_value1_symbol` = '<<' THEN
		INSERT IGNORE INTO `tmp_ref1` SELECT DISTINCT `sourceId` FROM `soa_relationship` as `r` WHERE `r`.`active` = 1 AND `r`.`typeId` = `v_attr1_id` 
		AND `r`.`destinationId` = `v_value1_id`;
    END IF;
END IF;

-- ADD ALL CONCEPTS PASSING THE SECOND ATTRIBUTE VALUE TEST TO TEMPORARY TABLE tmp_ref2
IF `v_refine2` != '' THEN
	IF `v_value2_symbol` = '<' OR `v_value2_symbol` = '<<' THEN
		INSERT IGNORE INTO `tmp_ref2` SELECT DISTINCT `sourceId` FROM `soa_relationship` as `r` WHERE `r`.`active` = 1 AND `r`.`typeId` = `v_attr2_id` 
		AND `r`.`destinationId` IN (SELECT `tc`.`subTypeId` FROM `ss_transclose` as `tc`
		WHERE `tc`.`supertypeId` = `v_value2_id` );
	END IF;
    IF `v_value2_symbol` = '' OR `v_value2_symbol` = '<<' THEN
		INSERT IGNORE INTO `tmp_ref2` SELECT DISTINCT `sourceId` FROM `soa_relationship` as `r` WHERE `r`.`active` = 1 AND `r`.`typeId` = `v_attr2_id` 
		AND `r`.`destinationId` = `v_value2_id`;
    END IF;
END IF;

-- LIST ALL THE CONCEPT THAT ARE IN ALL THREE TEMPORARY TABLES

IF `v_refine1` = '' THEN
	SELECT `pt`.`conceptId`,`pt`.`term`
	FROM `tmp_focus`, `soa_pref` as `pt`
		WHERE  `pt`.`conceptId` = `tmp_focus`.`id` 
		ORDER BY `pt`.`term`;

ELSEIF `v_refine2` = '' THEN
	SELECT `pt`.`conceptId`,`pt`.`term`
	FROM `tmp_focus`, `soa_pref` as `pt`
		WHERE  `pt`.`conceptId` = `tmp_focus`.`id` 
		AND `tmp_focus`.`id` IN (SELECT `id` FROM `tmp_ref1`)
		ORDER BY `pt`.`term`;

ELSE
	SELECT `pt`.`conceptId`,`pt`.`term`
	FROM `tmp_focus`, `soa_pref` as `pt`
		WHERE  `pt`.`conceptId` = `tmp_focus`.`id` 
		AND `pt`.`conceptId` IN (SELECT `id` FROM `tmp_ref1`)
		AND `pt`.`conceptId` IN (SELECT `id` FROM `tmp_ref2`)
		ORDER BY `pt`.`term`;

END IF;

-- Remove the temporary tables
DROP TABLE IF EXISTS `tmp_focus`;
DROP TABLE IF EXISTS `tmp_ref1`;
DROP TABLE IF EXISTS `tmp_ref2`;

END;;
DELIMITER ;

CALL eclSimple('< 404684003 |clinical finding|:363698007 |finding site| = << 39057004 |pulmonary `valve|,116676008 |associated morphology| = << 415582006 |stenosis|')

