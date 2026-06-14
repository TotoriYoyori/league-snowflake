-------------------------------------------------------------------------------------------
    -- 0. DECLARE WORKING CONTEXT
-------------------------------------------------------------------------------------------
USE DATABASE LEAGUE_RECORDS;

USE SCHEMA L00_STG;


-------------------------------------------------------------------------------------------
    -- 1. FILE FORMAT OF INGESTION TAGE
-------------------------------------------------------------------------------------------
CREATE OR REPLACE FILE FORMAT DAILY_MATCH_FMT
    TYPE = 'CSV'
    FIELD_DELIMITER = ','
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    TRIM_SPACE = TRUE
    NULL_IF = ('', 'NULL')
    EMPTY_FIELD_AS_NULL = TRUE
    COMPRESSION = 'AUTO';


-------------------------------------------------------------------------------------------
    -- 2. NON-AZURE STAGE, USED FOR DEMO PURPOSE, NAME IS KEPT SAME FOR COMPATIBILITY
-------------------------------------------------------------------------------------------
CREATE OR REPLACE STAGE DAILY_MATCH_AZSTG
    FILE_FORMAT = DAILY_MATCH_FMT
    COMMENT = 'Internal stage for demo seeding, mirrors the Azure stage in 02a.';
