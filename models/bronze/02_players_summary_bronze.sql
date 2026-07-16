USE SCHEMA BRONZE;


-------------------------------------------------------------------------------------------
    -- 1. BRONZE TABLE: Player-level summary with load metadata
-------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS BRONZE.PLAYERS_SUMMARY_BRONZE (
    -- Source columns
    ID                   VARCHAR NOT NULL,
    MATCH_ID             VARCHAR NOT NULL,
    PARTICIPANT_ID       VARCHAR,
    TEAM_ID              VARCHAR,
    CHAMPION             VARCHAR,
    ROLE                 VARCHAR,
    INDIVIDUAL_POSITION  VARCHAR,
    -- Load Metadata
    LDTS                 TIMESTAMP_NTZ(9) NOT NULL,
    FILE_NAME            VARCHAR(255) NOT NULL,
    FILE_ROW_NUMBER      NUMBER(38,0) NOT NULL,
    RSRC                 VARCHAR(255) NOT NULL,
    -- Constraints
    CONSTRAINT PLAYERS_SUMMARY_BRONZE_PKEY PRIMARY KEY (ID)
)
COMMENT = '[BRONZE] Raw player summary. Loaded via PLAYERS_SUMMARY_PP from @PLAYERS_SUMMARY_STG.';


-------------------------------------------------------------------------------------------
    -- 2. STREAM: CDC for silver consumption
-------------------------------------------------------------------------------------------
CREATE STREAM IF NOT EXISTS BRONZE.PLAYERS_SUMMARY_BRONZE_STM
    ON TABLE BRONZE.PLAYERS_SUMMARY_BRONZE
    COMMENT = 'PLAYERS_SUMMARY_BRONZE delta --> BRONZE_TO_SILVER_PLAYERS_TASK --> PLAYERS_SUMMARY_SILVER';


-------------------------------------------------------------------------------------------
    -- 3. STAGE: Internal stage for player summary CSVs
-------------------------------------------------------------------------------------------
CREATE STAGE IF NOT EXISTS BRONZE.PLAYERS_SUMMARY_STG
    FILE_FORMAT = BRONZE.LEAGUE_CSV_FMT
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Stage for player-level summary CSVs. Expected file: players_YYYYMMDD.csv';

-------------------------------------------------------------------------------------------
    -- 4. PIPE: Ingest from stage into bronze table
-------------------------------------------------------------------------------------------
CREATE PIPE IF NOT EXISTS BRONZE.PLAYERS_SUMMARY_PP
COMMENT = 'Player summary ingestion. Ingest frequency --> Daily.'
AS
COPY INTO BRONZE.PLAYERS_SUMMARY_BRONZE
FROM (
    SELECT
        $1,  -- id
        $2,  -- match_id
        $3,  -- participant_id
        $4,  -- team_id
        $5,  -- champion
        $6,  -- role
        $7,  -- individual_position
        CURRENT_TIMESTAMP(),
        METADATA$FILENAME,
        METADATA$FILE_ROW_NUMBER,
        'League Client Daily Logger'
    FROM @BRONZE.PLAYERS_SUMMARY_STG
)
ON_ERROR = 'SKIP_FILE_10%';


-------------------------------------------------------------------------------------------
    -- 5. _PLAYERS_SUMMARY_LOAD_ERRORS: audit view over this pipe's COPY_HISTORY.
-------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW BRONZE._PLAYERS_SUMMARY_LOAD_ERRORS AS
SELECT
    FILE_NAME,
    LAST_LOAD_TIME,
    ROW_COUNT,
    (ROW_PARSED - ROW_COUNT) AS ROWS_REJECTED,
    ERROR_COUNT,
    FIRST_ERROR_MESSAGE
FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
    TABLE_NAME => 'BRONZE.PLAYERS_SUMMARY_BRONZE',
    START_TIME => DATEADD(DAY, -30, CURRENT_TIMESTAMP())
))
WHERE ERROR_COUNT > 0;
