-- Bronze file format: shared CSV format used by all bronze stages and pipes
-- Co-authored with CoCo
-------------------------------------------------------------------------------------------
    -- 0. DECLARE WORKING CONTEXT (set by calling deploy script)
-------------------------------------------------------------------------------------------
USE SCHEMA BRONZE;


-------------------------------------------------------------------------------------------
    -- 1. SHARED FILE FORMAT FOR ALL CSV INGESTION
-------------------------------------------------------------------------------------------
CREATE OR REPLACE FILE FORMAT LEAGUE_CSV_FMT
    TYPE = 'CSV'
    FIELD_DELIMITER = ','
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    TRIM_SPACE = TRUE
    NULL_IF = ('', 'NULL')
    EMPTY_FIELD_AS_NULL = TRUE
    COMPRESSION = 'AUTO';
