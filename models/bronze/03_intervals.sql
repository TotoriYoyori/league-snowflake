USE SCHEMA BRONZE;


-------------------------------------------------------------------------------------------
    -- 1. BRONZE TABLE: Raw match interval data with load metadata
-------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS BRONZE.INTERVALS (
    -- Source
    ID VARCHAR,
    MATCH_ID VARCHAR,
    PLAYER_ID VARCHAR,
    MINUTE VARCHAR,
    CURRENT_GOLD VARCHAR,
    TOTAL_GOLD VARCHAR,
    CS VARCHAR,
    JUNGLE_CS VARCHAR,
    XP VARCHAR,
    LEVEL VARCHAR,
    KILLS VARCHAR,
    DEATHS VARCHAR,
    ASSISTS VARCHAR,
    ITEM_0 VARCHAR,
    ITEM_1 VARCHAR,
    ITEM_2 VARCHAR,
    ITEM_3 VARCHAR,
    ITEM_4 VARCHAR,
    ITEM_5 VARCHAR,
    ITEM_6 VARCHAR,
    TEAM_KILLS VARCHAR,
    TEAM_INHIBITORS VARCHAR,
    TEAM_TOWERS VARCHAR,
    TEAM_DRAGONS_FIRE VARCHAR,
    TEAM_DRAGONS_WATER VARCHAR,
    TEAM_DRAGONS_EARTH VARCHAR,
    TEAM_DRAGONS_AIR VARCHAR,
    TEAM_DRAGONS_CHEMTECH VARCHAR,
    TEAM_DRAGONS_HEXTECH VARCHAR,
    TEAM_DRAGONS VARCHAR,
    TEAM_BARONS VARCHAR,
    TEAM_VOID_GRUBS VARCHAR,
    TEAM_HERALDS VARCHAR,
    GOLD_DIFF VARCHAR,
    XP_DIFF VARCHAR,
    TEAM_GOLD_DIFF VARCHAR,
    -- Metadata
    LDTS TIMESTAMP_NTZ(9) NOT NULL,
    FILE_NAME VARCHAR(255) NOT NULL,
    FILE_ROW_NUMBER NUMBER(38,0) NOT NULL,
    RSRC VARCHAR(255) NOT NULL,

    CONSTRAINT BRONZE_INTERVALS_PKEY PRIMARY KEY (ID)
)
COMMENT = '[BRONZE] Raw match interval snapshots. Loaded via INTERVALS_PP from @INTERVALS_STG.';


-------------------------------------------------------------------------------------------
    -- 2. STREAM: CDC for silver consumption
-------------------------------------------------------------------------------------------
CREATE STREAM IF NOT EXISTS BRONZE.INTERVALS_STM
    ON TABLE BRONZE.INTERVALS
    COMMENT = 'INTERVALS delta --> BRONZE_TO_SILVER_INTERVALS_TASK';


-------------------------------------------------------------------------------------------
    -- 3. STAGE: Internal stage for interval snapshot CSVs
-------------------------------------------------------------------------------------------
CREATE STAGE IF NOT EXISTS BRONZE.INTERVALS_STG
    FILE_FORMAT = BRONZE.LEAGUE_CSV_FMT
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Stage for per-minute interval snapshot CSVs. Expected file: intervals_YYYYMMDD.csv';


-------------------------------------------------------------------------------------------
    -- 4. PIPE: Ingest from stage into bronze table
-------------------------------------------------------------------------------------------
CREATE PIPE IF NOT EXISTS BRONZE.INTERVALS_PP
COMMENT = 'Match interval snapshot ingestion. Ingest frequency --> Daily.'
AS
COPY INTO BRONZE.INTERVALS
FROM (
    SELECT
        $1,  -- id
        $2,  -- match_id
        $3,  -- player_id
        $4,  -- minute
        $5,  -- current_gold
        $6,  -- total_gold
        $7,  -- cs
        $8,  -- jungle_cs
        $9,  -- xp
        $10, -- level
        $11, -- kills
        $12, -- deaths
        $13, -- assists
        $14, -- item_0
        $15, -- item_1
        $16, -- item_2
        $17, -- item_3
        $18, -- item_4
        $19, -- item_5
        $20, -- item_6
        $21, -- team_kills
        $22, -- team_inhibitors
        $23, -- team_towers
        $24, -- team_dragons_fire
        $25, -- team_dragons_water
        $26, -- team_dragons_earth
        $27, -- team_dragons_air
        $28, -- team_dragons_chemtech
        $29, -- team_dragons_hextech
        $30, -- team_dragons
        $31, -- team_barons
        $32, -- team_void_grubs
        $33, -- team_heralds
        $34, -- gold_diff
        $35, -- xp_diff
        $36, -- team_gold_diff
        CURRENT_TIMESTAMP(),
        METADATA$FILENAME,
        METADATA$FILE_ROW_NUMBER,
        'Kaggle simulated daily ingestion'
    FROM @BRONZE.INTERVALS_STG
)
ON_ERROR = 'SKIP_FILE_10%';


-------------------------------------------------------------------------------------------
    -- 5. _INTERVALS_LOAD_ERRORS: audit view over this pipe's COPY_HISTORY.
-------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW BRONZE._INTERVALS_LOAD_ERRORS AS
SELECT
    FILE_NAME,
    LAST_LOAD_TIME,
    ROW_COUNT,
    (ROW_PARSED - ROW_COUNT) AS ROWS_REJECTED,
    ERROR_COUNT,
    FIRST_ERROR_MESSAGE
FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
    TABLE_NAME => 'BRONZE.INTERVALS',
    START_TIME => DATEADD(DAY, -30, CURRENT_TIMESTAMP())
))
WHERE ERROR_COUNT > 0;
