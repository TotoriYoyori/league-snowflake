-------------------------------------------------------------------------------------------
    -- 0. DECLARE WORKING CONTEXT
-------------------------------------------------------------------------------------------
USE DATABASE LEAGUE_RECORDS;

USE SCHEMA L00_STG;


-------------------------------------------------------------------------------------------
    -- 1. FILE FORMAT FOR CSV INGESTION
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
    -- 2. INTERNAL STAGE FOR DEMO INGESTION
    -- In production this would be an external stage connected to Azure Blob (see 02a).
-------------------------------------------------------------------------------------------
CREATE OR REPLACE STAGE DAILY_MATCH_STG
    FILE_FORMAT = DAILY_MATCH_FMT
    COMMENT = 'Internal stage for demo ingestion. See 02a for the Azure equivalent.';


-------------------------------------------------------------------------------------------
    -- 3. PIPE FOR MANUAL-REFRESH INGESTION
    -- Unlike the Azure auto-ingest pipe (02a), this pipe requires a manual
    -- ALTER PIPE DAILY_MATCH_PP REFRESH to trigger loading.
-------------------------------------------------------------------------------------------
CREATE OR REPLACE PIPE DAILY_MATCH_PP
COMMENT = 'Manual-refresh pipe for demo ingestion from internal stage.'
AS
COPY INTO STG_INTERVALS
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
    FROM @DAILY_MATCH_STG
);
