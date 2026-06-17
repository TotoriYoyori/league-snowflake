-------------------------------------------------------------------------------------------
    -- 0. DECLARE WORKING CONTEXT
-------------------------------------------------------------------------------------------
USE DATABASE LEAGUE_RECORDS;

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


-------------------------------------------------------------------------------------------
    -- 2. INTERNAL STAGES (one per source table)
-------------------------------------------------------------------------------------------
CREATE OR REPLACE STAGE MATCHES_SUMMARY_STG
    FILE_FORMAT = LEAGUE_CSV_FMT
    COMMENT = 'Stage for match-level summary CSVs. Expected file: matches_YYYYMMDD.csv';

CREATE OR REPLACE STAGE PLAYERS_SUMMARY_STG
    FILE_FORMAT = LEAGUE_CSV_FMT
    COMMENT = 'Stage for player-level summary CSVs. Expected file: players_YYYYMMDD.csv';

CREATE OR REPLACE STAGE MATCH_INTERVALS_STG
    FILE_FORMAT = LEAGUE_CSV_FMT
    COMMENT = 'Stage for per-minute interval snapshot CSVs. Expected file: intervals_YYYYMMDD.csv';

CREATE OR REPLACE STAGE REFERENCE_STG
    FILE_FORMAT = LEAGUE_CSV_FMT
    COMMENT = 'Stage for reference/lookup CSVs. Expected files: items_ref.csv, champions_ref.csv';

-- Seed upload stage (lives in SEED schema, but created here since LEAGUE_CSV_FMT is defined above)
CREATE STAGE IF NOT EXISTS SEED.SEED_UPLOAD_STG
    FILE_FORMAT = LEAGUE_CSV_FMT
    COMMENT = 'Upload all seed CSVs here via Snowsight UI before running 02_seed_source.sql.';


-------------------------------------------------------------------------------------------
    -- 3. PIPES (manual-refresh via ALTER PIPE <pipe> REFRESH, one per source)
-------------------------------------------------------------------------------------------
-- 3a. MATCHES_SUMMARY
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

-- 3b. PLAYERS_SUMMARY
CREATE OR REPLACE PIPE PLAYERS_SUMMARY_PP
COMMENT = 'Player summary ingestion. Ingest frequency --> Daily.'
AS
COPY INTO PLAYERS_SUMMARY_BRONZE
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
    FROM @PLAYERS_SUMMARY_STG
);

-- 3c. MATCH_INTERVALS
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

-- 3d. ITEMS_REF
CREATE OR REPLACE PIPE ITEMS_REF_PP
COMMENT = 'Item reference lookup. Ingest frequency --> Every patch updates.'
AS
COPY INTO ITEMS_REF_BRONZE
FROM (
    SELECT
        $1,  -- item_id
        $2,  -- item_name
        CURRENT_TIMESTAMP(),
        METADATA$FILENAME,
        METADATA$FILE_ROW_NUMBER,
        'League Static Data'
    FROM @REFERENCE_STG/items_ref
);

-- 3e. CHAMPIONS_REF
CREATE OR REPLACE PIPE CHAMPIONS_REF_PP
COMMENT = 'Champion reference lookup. Ingest frequency --> Every patch updates.'
AS
COPY INTO CHAMPIONS_REF_BRONZE
FROM (
    SELECT
        $1,  -- champion_id
        $2,  -- champion_name
        CURRENT_TIMESTAMP(),
        METADATA$FILENAME,
        METADATA$FILE_ROW_NUMBER,
        'League Static Data'
    FROM @REFERENCE_STG/champions_ref
);
