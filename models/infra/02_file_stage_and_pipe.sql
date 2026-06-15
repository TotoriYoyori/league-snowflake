-------------------------------------------------------------------------------------------
    -- 0. DECLARE WORKING CONTEXT
-------------------------------------------------------------------------------------------
USE DATABASE LEAGUE_RECORDS;

USE SCHEMA BRONZE;


-------------------------------------------------------------------------------------------
    -- 1. FILE FORMAT FOR CSV INGESTION
-------------------------------------------------------------------------------------------
CREATE OR REPLACE FILE FORMAT MATCH_INTERVAL_FMT
    TYPE = 'CSV'
    FIELD_DELIMITER = ','
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    TRIM_SPACE = TRUE
    NULL_IF = ('', 'NULL')
    EMPTY_FIELD_AS_NULL = TRUE
    COMPRESSION = 'AUTO';


-------------------------------------------------------------------------------------------
    -- 2. INTERNAL STAGE FOR DEMO INGESTION
-------------------------------------------------------------------------------------------
CREATE OR REPLACE STAGE MATCH_INTERVAL_STG
    FILE_FORMAT = MATCH_INTERVAL_FMT
    COMMENT = 'Internal stage for demo ingestion of match interval CSVs.';


-------------------------------------------------------------------------------------------
    -- 3. PIPE FOR MANUAL-REFRESH INGESTION
    -- Requires ALTER PIPE MATCH_INTERVAL_PP REFRESH to trigger loading.
-------------------------------------------------------------------------------------------
CREATE OR REPLACE PIPE MATCH_INTERVAL_PP
COMMENT = 'Manual-refresh pipe for demo ingestion from internal stage.'
AS
COPY INTO MATCH_INTERVALS_BRONZE
FROM (
    SELECT 
        $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, 
        $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, 
        $21, $22, $23, $24, $25, $26, $27, $28, $29, $30, 
        $31, $32, $33, $34, $35, $36,
        TO_TIMESTAMP(
            REGEXP_SUBSTR(METADATA$FILENAME, 'match_(\\d{8}_\\d{6})', 1, 1, 'e'),
            'YYYYMMDD_HH24MISS'
        ),
        METADATA$FILENAME,
        METADATA$FILE_ROW_NUMBER,
        'League Client Daily Logger'
    FROM @MATCH_INTERVAL_STG
);
