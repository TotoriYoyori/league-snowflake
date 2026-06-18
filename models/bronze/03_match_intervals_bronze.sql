-- Bronze match intervals: table, stream, stage, and pipe (self-contained)
-- Co-authored with CoCo
-------------------------------------------------------------------------------------------
    -- 0. DECLARE WORKING CONTEXT (set by calling deploy script)
-------------------------------------------------------------------------------------------
USE SCHEMA BRONZE;


-------------------------------------------------------------------------------------------
    -- 1. BRONZE TABLE: Raw match interval data with load metadata
    -- Direct landing table from pipe ingestion. No transformations applied.
-------------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE MATCH_INTERVALS_BRONZE (
    -- Identifier
  ID NUMBER(38,0) NOT NULL,
  MATCH_ID VARCHAR(255) NOT NULL,
  PLAYER_ID NUMBER(38,0) NOT NULL,
    -- Economy
  MINUTE NUMBER(2,0) NOT NULL,
  CURRENT_GOLD NUMBER(38,0),
  TOTAL_GOLD NUMBER(38,0),
  CS NUMBER(38,0),
  JUNGLE_CS NUMBER(38,0),
  XP NUMBER(38,0),
  LEVEL NUMBER(38,0),
    -- KDA
  KILLS NUMBER(38,0),
  DEATHS NUMBER(38,0),
  ASSISTS NUMBER(38,0),
    -- Itemization
  ITEM_0 NUMBER(38,0),
  ITEM_1 NUMBER(38,0),
  ITEM_2 NUMBER(38,0),
  ITEM_3 NUMBER(38,0),
  ITEM_4 NUMBER(38,0),
  ITEM_5 NUMBER(38,0),
  ITEM_6 NUMBER(38,0),
    -- Team's Objective
  TEAM_KILLS NUMBER(38,0),
  TEAM_INHIBITORS NUMBER(38,0),
  TEAM_TOWERS NUMBER(38,0),
  TEAM_DRAGONS_FIRE NUMBER(38,0),
  TEAM_DRAGONS_WATER NUMBER(38,0),
  TEAM_DRAGONS_EARTH NUMBER(38,0),
  TEAM_DRAGONS_AIR NUMBER(38,0),
  TEAM_DRAGONS_CHEMTECH NUMBER(38,0),
  TEAM_DRAGONS_HEXTECH NUMBER(38,0),
  TEAM_DRAGONS NUMBER(38,0),
  TEAM_BARONS NUMBER(38,0),
  TEAM_VOID_GRUBS NUMBER(38,0),
  TEAM_HERALDS NUMBER(38,0),
    -- Stats Diff
  GOLD_DIFF NUMBER(38,0),
  XP_DIFF NUMBER(38,0),
  TEAM_GOLD_DIFF NUMBER(38,0),
    -- Load Metadata
  LDTS TIMESTAMP_NTZ(9) NOT NULL,
  FILE_NAME VARCHAR(255) NOT NULL,
  FILE_ROW_NUMBER NUMBER(38,0) NOT NULL,
  RSRC VARCHAR(255) NOT NULL,
    -- Constraints
  CONSTRAINT MATCH_INTERVALS_BRONZE_PKEY PRIMARY KEY (ID)
)
COMMENT = '[BRONZE] Raw match interval snapshots. Loaded via MATCH_INTERVALS_PP from @MATCH_INTERVALS_STG.';


-------------------------------------------------------------------------------------------
    -- 2. STREAM: CDC for silver consumption
-------------------------------------------------------------------------------------------
CREATE OR REPLACE STREAM MATCH_INTERVALS_BRONZE_STM
    ON TABLE MATCH_INTERVALS_BRONZE
    COMMENT = 'MATCH_INTERVALS_BRONZE delta --> BRONZE_TO_SILVER_INTERVALS_TASK --> MATCH_INTERVALS_SILVER';


-------------------------------------------------------------------------------------------
    -- 3. STAGE: Internal stage for interval snapshot CSVs
-------------------------------------------------------------------------------------------
CREATE OR REPLACE STAGE MATCH_INTERVALS_STG
    FILE_FORMAT = LEAGUE_CSV_FMT
    COMMENT = 'Stage for per-minute interval snapshot CSVs. Expected file: intervals_YYYYMMDD.csv';


-------------------------------------------------------------------------------------------
    -- 4. PIPE: Ingest from stage into bronze table
-------------------------------------------------------------------------------------------
CREATE OR REPLACE PIPE MATCH_INTERVALS_PP
COMMENT = 'Match interval snapshot ingestion. Ingest frequency --> Daily.'
AS
COPY INTO MATCH_INTERVALS_BRONZE
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
        'League Client Daily Logger'
    FROM @MATCH_INTERVALS_STG
);
