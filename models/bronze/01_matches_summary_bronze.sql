-- Bronze matches summary: table, stream, stage, and pipe (self-contained)
-- Co-authored with CoCo
-------------------------------------------------------------------------------------------
    -- 0. DECLARE WORKING CONTEXT (set by calling deploy script)
-------------------------------------------------------------------------------------------
USE SCHEMA BRONZE;


-------------------------------------------------------------------------------------------
    -- 1. BRONZE TABLE: Match-level summary with load metadata
-------------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE MATCHES_SUMMARY_BRONZE (
    -- Source columns
    MATCH_ID        VARCHAR(255) NOT NULL,
    GAME_DURATION   NUMBER(38,0),
    PATCH_VERSION   NUMBER(38,0),
    WINNING_TEAM    NUMBER(38,0),
    GAME_DATE       VARCHAR(255),
    GAME_VERSION    VARCHAR(255),
    GAME_MODE       VARCHAR(255),
    QUEUE_ID        NUMBER(38,0),
    REGION          VARCHAR(255),
    AVERAGE_RANK    VARCHAR(255),
    BLUE_BANS       VARCHAR(255),
    RED_BANS        VARCHAR(255),
    -- Load Metadata
    LDTS            TIMESTAMP_NTZ(9) NOT NULL,
    FILE_NAME       VARCHAR(255) NOT NULL,
    FILE_ROW_NUMBER NUMBER(38,0) NOT NULL,
    RSRC            VARCHAR(255) NOT NULL,
    -- Constraints
    CONSTRAINT MATCHES_SUMMARY_BRONZE_PKEY PRIMARY KEY (MATCH_ID)
)
COMMENT = '[BRONZE] Raw match summary. Loaded via MATCHES_SUMMARY_PP from @MATCHES_SUMMARY_STG.';


-------------------------------------------------------------------------------------------
    -- 2. STREAM: CDC for silver consumption
-------------------------------------------------------------------------------------------
CREATE OR REPLACE STREAM MATCHES_SUMMARY_BRONZE_STM
    ON TABLE MATCHES_SUMMARY_BRONZE
    COMMENT = 'MATCHES_SUMMARY_BRONZE delta --> BRONZE_TO_SILVER_MATCHES_TASK --> MATCHES_SUMMARY_SILVER';


-------------------------------------------------------------------------------------------
    -- 3. STAGE: Internal stage for match summary CSVs
-------------------------------------------------------------------------------------------
CREATE OR REPLACE STAGE MATCHES_SUMMARY_STG
    FILE_FORMAT = LEAGUE_CSV_FMT
    COMMENT = 'Stage for match-level summary CSVs. Expected file: matches_YYYYMMDD.csv';


-------------------------------------------------------------------------------------------
    -- 4. PIPE: Ingest from stage into bronze table
-------------------------------------------------------------------------------------------
CREATE OR REPLACE PIPE MATCHES_SUMMARY_PP
COMMENT = 'Match summary ingestion. Ingest frequency --> Daily.'
AS
COPY INTO MATCHES_SUMMARY_BRONZE
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
        'League Client Daily Logger'
    FROM @MATCHES_SUMMARY_STG
);
