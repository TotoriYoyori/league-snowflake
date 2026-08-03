USE SCHEMA BRONZE;


-------------------------------------------------------------------------------------------
    -- 1. BRONZE TABLE: Champions reference lookup
-------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS BRONZE.CHAMPIONS_REF (
    -- Source
    CHAMPION_ID VARCHAR,
    CHAMPION_NAME VARCHAR,
    -- Metadata
    LDTS TIMESTAMP_NTZ(9) NOT NULL,
    FILE_NAME VARCHAR(255) NOT NULL,
    FILE_ROW_NUMBER NUMBER(38,0) NOT NULL,
    RSRC VARCHAR(255) NOT NULL,

    CONSTRAINT BRONZE_CHAMPIONS_REF_PKEY PRIMARY KEY (CHAMPION_ID)
)
COMMENT = '[BRONZE] Champion reference lookup. Loaded via CHAMPIONS_REF_PP from @CHAMPIONS_REF_STG.';


-------------------------------------------------------------------------------------------
    -- 2. STREAM: CDC for silver consumption
-------------------------------------------------------------------------------------------
CREATE STREAM IF NOT EXISTS BRONZE.CHAMPIONS_REF_STM
    ON TABLE BRONZE.CHAMPIONS_REF
    COMMENT = 'CHAMPIONS_REF delta --> BRONZE_TO_SILVER_CHAMPIONS_TASK --> SILVER.CHAMPIONS_REF';


-------------------------------------------------------------------------------------------
    -- 3. STAGE: Internal stage for champions reference CSV
-------------------------------------------------------------------------------------------
CREATE STAGE IF NOT EXISTS BRONZE.CHAMPIONS_REF_STG
    FILE_FORMAT = BRONZE.LEAGUE_CSV_FMT
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Stage for champion reference CSV. Expected file: champions_ref.csv';

-------------------------------------------------------------------------------------------
    -- 4. PIPE: Ingest from stage into bronze table
-------------------------------------------------------------------------------------------
CREATE PIPE IF NOT EXISTS BRONZE.CHAMPIONS_REF_PP
COMMENT = 'Champion reference lookup. Ingest frequency --> Every patch updates.'
AS
COPY INTO BRONZE.CHAMPIONS_REF
FROM (
    SELECT
        $1,  -- champion_id
        $2,  -- champion_name
        CURRENT_TIMESTAMP(),
        METADATA$FILENAME,
        METADATA$FILE_ROW_NUMBER,
        'League Static Data'
    FROM @BRONZE.CHAMPIONS_REF_STG
)
ON_ERROR = 'SKIP_FILE_10%';


-------------------------------------------------------------------------------------------
    -- 5. _CHAMPIONS_REF_LOAD_ERRORS: audit view over this pipe's COPY_HISTORY.
-------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW BRONZE._CHAMPIONS_REF_LOAD_ERRORS AS
SELECT
    FILE_NAME,
    LAST_LOAD_TIME,
    ROW_COUNT,
    (ROW_PARSED - ROW_COUNT) AS ROWS_REJECTED,
    ERROR_COUNT,
    FIRST_ERROR_MESSAGE
FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
    TABLE_NAME => 'BRONZE.CHAMPIONS_REF',
    START_TIME => DATEADD(DAY, -30, CURRENT_TIMESTAMP())
))
WHERE ERROR_COUNT > 0;
