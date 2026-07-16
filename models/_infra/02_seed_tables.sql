USE SCHEMA SEED;


-------------------------------------------------------------------------------------------
    -- 1. SEED_MATCHES_SUMMARY: Source match-level dataset
-------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS SEED.SEED_MATCHES_SUMMARY (
    MATCH_ID        VARCHAR NOT NULL,
    GAME_DURATION   VARCHAR,
    PATCH_VERSION   VARCHAR,
    WINNING_TEAM    VARCHAR,
    GAME_DATE       VARCHAR,
    GAME_VERSION    VARCHAR,
    GAME_MODE       VARCHAR,
    QUEUE_ID        VARCHAR,
    REGION          VARCHAR,
    AVERAGE_RANK    VARCHAR,
    BLUE_BANS       VARCHAR,
    RED_BANS        VARCHAR
)
COMMENT = 'Source matches summary dataset. One record --> One match.';


-------------------------------------------------------------------------------------------
    -- 2. SEED_PLAYERS_SUMMARY: Source player-level dataset
-------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS SEED.SEED_PLAYERS_SUMMARY (
    ID                   VARCHAR NOT NULL,
    MATCH_ID             VARCHAR NOT NULL,
    PARTICIPANT_ID       VARCHAR,
    TEAM_ID              VARCHAR,
    CHAMPION             VARCHAR,
    ROLE                 VARCHAR,
    INDIVIDUAL_POSITION  VARCHAR
)
COMMENT = 'Source players summary dataset. One record --> One player per match.';


-------------------------------------------------------------------------------------------
    -- 3. SEED_MATCH_INTERVALS: Full interval-level dataset (existing data, renamed)
-------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS SEED.SEED_MATCH_INTERVALS (
    ID              VARCHAR NOT NULL,
    MATCH_ID        VARCHAR NOT NULL,
    PLAYER_ID       VARCHAR NOT NULL,
    MINUTE          VARCHAR NOT NULL,
    CURRENT_GOLD    VARCHAR,
    TOTAL_GOLD      VARCHAR,
    CS              VARCHAR,
    JUNGLE_CS       VARCHAR,
    XP              VARCHAR,
    LEVEL           VARCHAR,
    KILLS           VARCHAR,
    DEATHS          VARCHAR,
    ASSISTS         VARCHAR,
    ITEM_0          VARCHAR,
    ITEM_1          VARCHAR,
    ITEM_2          VARCHAR,
    ITEM_3          VARCHAR,
    ITEM_4          VARCHAR,
    ITEM_5          VARCHAR,
    ITEM_6          VARCHAR,
    TEAM_KILLS      VARCHAR,
    TEAM_INHIBITORS VARCHAR,
    TEAM_TOWERS     VARCHAR,
    TEAM_DRAGONS_FIRE    VARCHAR,
    TEAM_DRAGONS_WATER   VARCHAR,
    TEAM_DRAGONS_EARTH   VARCHAR,
    TEAM_DRAGONS_AIR     VARCHAR,
    TEAM_DRAGONS_CHEMTECH VARCHAR,
    TEAM_DRAGONS_HEXTECH VARCHAR,
    TEAM_DRAGONS    VARCHAR,
    TEAM_BARONS     VARCHAR,
    TEAM_VOID_GRUBS VARCHAR,
    TEAM_HERALDS    VARCHAR,
    GOLD_DIFF       VARCHAR,
    XP_DIFF         VARCHAR,
    TEAM_GOLD_DIFF  VARCHAR
)
COMMENT = 'Source match intervals dataset. One record --> One 5 minute snapshot per player per match.';


-------------------------------------------------------------------------------------------
    -- 4. SEED_ITEMS_REF: Item ID to name lookup and its categorization
-------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS SEED.SEED_ITEMS_REF (
    ITEM_ID       VARCHAR NOT NULL,
    ITEM_NAME     VARCHAR,
    ITEM_CATEGORY VARCHAR
)
COMMENT = 'Source item reference lookup. One record --> One item and its categorization.';

-------------------------------------------------------------------------------------------
    -- 5. SEED_CHAMPIONS_REF: Champion ID to name lookup
-------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS SEED.SEED_CHAMPIONS_REF (
    CHAMPION_ID    VARCHAR NOT NULL,
    CHAMPION_NAME  VARCHAR
)
COMMENT = 'Source champion reference lookup: One record --> One champion.';


-------------------------------------------------------------------------------------------
    -- 6. _SEED_MATCH_DATE_INDEX: Sorted latest date first, for use by SIMULATE_DAILY_LOAD.
    -- Internal-use view (underscore prefix), not a source table.
-------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW SEED._SEED_MATCH_DATE_INDEX AS
SELECT
    MATCH_ID,
    DATE(TRY_TO_TIMESTAMP(GAME_DATE)) AS GAME_DATE_DAY
FROM SEED.SEED_MATCHES_SUMMARY
WHERE TRY_TO_TIMESTAMP(GAME_DATE) IS NOT NULL
ORDER BY GAME_DATE_DAY DESC;


-------------------------------------------------------------------------------------------
    -- 6b. SEED._UNPARSEABLE_GAME_DATES: audit view for matches _SEED_MATCH_DATE_INDEX
-------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW SEED._UNPARSEABLE_GAME_DATES AS
SELECT
    MATCH_ID,
    GAME_DATE AS RAW_GAME_DATE
FROM SEED.SEED_MATCHES_SUMMARY
WHERE GAME_DATE IS NOT NULL
    AND TRY_TO_TIMESTAMP(GAME_DATE) IS NULL;


-------------------------------------------------------------------------------------------
    -- 7. SEED_LOAD_STATE: Tracks date-based chunking for SIMULATE_DAILY_LOAD
-------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS SEED.SEED_LOAD_STATE (
    CURRENT_LOAD_DATE  DATE,
    MIN_DATE           DATE,
    MAX_DATE           DATE,
    LAST_LOADED_AT     TIMESTAMP_NTZ
)
COMMENT = 'Tracks the current date pointer for simulated daily ingestion.';

-- Conditional insert: only seed the initial row if the table is empty.
INSERT INTO SEED.SEED_LOAD_STATE (CURRENT_LOAD_DATE, MIN_DATE, MAX_DATE, LAST_LOADED_AT)
SELECT
    NULL AS CURRENT_LOAD_DATE,
    NULL AS MIN_DATE,
    NULL AS MAX_DATE,
    NULL AS LAST_LOADED_AT
WHERE NOT EXISTS (
    SELECT 1
    FROM SEED.SEED_LOAD_STATE
);


-------------------------------------------------------------------------------------------
    -- 8. SEED_UPLOAD_STG: Upload all seed CSVs here via Snowsight UI
-------------------------------------------------------------------------------------------
CREATE STAGE IF NOT EXISTS SEED.SEED_UPLOAD_STG
    FILE_FORMAT = (
        TYPE = CSV
        FIELD_DELIMITER = ','
        SKIP_HEADER = 1
        FIELD_OPTIONALLY_ENCLOSED_BY = '"'
        TRIM_SPACE = TRUE
        NULL_IF = ('', 'NULL')
        EMPTY_FIELD_AS_NULL = TRUE
        COMPRESSION = 'AUTO'
    )
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Raw file container for seed CSV uploads via Snowsight UI.';
