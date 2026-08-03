USE SCHEMA BRONZE;


-------------------------------------------------------------------------------------------
    -- 1. BRONZE TABLE: Match-level summary with load metadata
-------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS BRONZE.MATCHES (
    -- Source
    MATCH_ID VARCHAR,
    GAME_DURATION VARCHAR,
    PATCH_VERSION VARCHAR,
    WINNING_TEAM VARCHAR,
    GAME_DATE VARCHAR,
    GAME_VERSION VARCHAR,
    GAME_MODE VARCHAR,
    QUEUE_ID VARCHAR,
    REGION VARCHAR,
    AVERAGE_RANK VARCHAR,
    BLUE_BANS VARCHAR,
    RED_BANS VARCHAR,
    -- Metadata
    LDTS TIMESTAMP_NTZ(9) NOT NULL,
    FILE_NAME VARCHAR(255) NOT NULL,
    FILE_ROW_NUMBER NUMBER(38,0) NOT NULL,
    RSRC VARCHAR(255) NOT NULL,

    CONSTRAINT BRONZE_MATCHES_PKEY PRIMARY KEY (MATCH_ID)
)
COMMENT = '[BRONZE] Raw match summary. Loaded via MATCHES_PP from @MATCHES_STG.';


-------------------------------------------------------------------------------------------
    -- 2. STREAM: CDC for silver consumption
-------------------------------------------------------------------------------------------
CREATE STREAM IF NOT EXISTS BRONZE.MATCHES_STM
    ON TABLE BRONZE.MATCHES
    COMMENT = 'BRONZE.MATCHES delta --> BRONZE_TO_SILVER_MATCHES_TASK --> SILVER.MATCHES';


-------------------------------------------------------------------------------------------
    -- 3. STAGE: Internal stage for match summary CSVs
-------------------------------------------------------------------------------------------
CREATE STAGE IF NOT EXISTS BRONZE.MATCHES_STG
    FILE_FORMAT = BRONZE.LEAGUE_CSV_FMT
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Stage for match-level summary CSVs. Expected file: matches_YYYYMMDD.csv';
    
-------------------------------------------------------------------------------------------
    -- 4. PIPE: Ingest from stage into bronze table
-------------------------------------------------------------------------------------------
CREATE PIPE IF NOT EXISTS BRONZE.MATCHES_PP
COMMENT = 'Match summary ingestion. Ingest frequency --> Daily.'
AS
COPY INTO BRONZE.MATCHES
FROM (
    SELECT
        $1,  -- match_id
        $2,  -- game_duration
        $3,  -- patch_version
        $4,  -- winning_team
        $5,  -- game_date (timestamp string)
        $6,  -- game_version
        $7,  -- game_mode
        $8,  -- queue_id
        $9,  -- region
        $10, -- average_rank
        $11, -- blue_bans
        $12, -- red_bans
        CURRENT_TIMESTAMP(),
        METADATA$FILENAME,
        METADATA$FILE_ROW_NUMBER,
        'Kaggle simulated daily ingestion'
    FROM @BRONZE.MATCHES_STG
)
ON_ERROR = 'SKIP_FILE_10%';


-------------------------------------------------------------------------------------------
    -- 5. _MATCHES_LOAD_ERRORS: audit view over this pipe's COPY_HISTORY.
-------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW BRONZE._MATCHES_LOAD_ERRORS AS
SELECT
    FILE_NAME,
    LAST_LOAD_TIME,
    ROW_COUNT,
    (ROW_PARSED - ROW_COUNT) AS ROWS_REJECTED,
    ERROR_COUNT,
    FIRST_ERROR_MESSAGE
FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
    TABLE_NAME => 'BRONZE.MATCHES',
    START_TIME => DATEADD(DAY, -30, CURRENT_TIMESTAMP())
))
WHERE ERROR_COUNT > 0;
