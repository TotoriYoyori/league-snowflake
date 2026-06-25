USE SCHEMA BRONZE;


-------------------------------------------------------------------------------------------
    -- 1. BRONZE TABLE: Player-level summary with load metadata
-------------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE BRONZE.PLAYERS_SUMMARY_BRONZE (
    -- Source columns
    ID                   NUMBER(38,0) NOT NULL,
    MATCH_ID             VARCHAR(255) NOT NULL,
    PARTICIPANT_ID       NUMBER(38,0),
    TEAM_ID              NUMBER(38,0),
    CHAMPION             VARCHAR(255),
    ROLE                 VARCHAR(255),
    INDIVIDUAL_POSITION  VARCHAR(255),
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
CREATE OR REPLACE STREAM BRONZE.PLAYERS_SUMMARY_BRONZE_STM
    ON TABLE BRONZE.PLAYERS_SUMMARY_BRONZE
    COMMENT = 'PLAYERS_SUMMARY_BRONZE delta --> BRONZE_TO_SILVER_PLAYERS_TASK --> PLAYERS_SUMMARY_SILVER';


-------------------------------------------------------------------------------------------
    -- 3. STAGE: Internal stage for player summary CSVs
-------------------------------------------------------------------------------------------
CREATE OR REPLACE STAGE BRONZE.PLAYERS_SUMMARY_STG
    FILE_FORMAT = BRONZE.LEAGUE_CSV_FMT
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Stage for player-level summary CSVs. Expected file: players_YYYYMMDD.csv';

-------------------------------------------------------------------------------------------
    -- 4. PIPE: Ingest from stage into bronze table
-------------------------------------------------------------------------------------------
CREATE OR REPLACE PIPE BRONZE.PLAYERS_SUMMARY_PP
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
);
