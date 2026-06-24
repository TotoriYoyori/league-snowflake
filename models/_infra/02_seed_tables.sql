USE SCHEMA SEED;


-------------------------------------------------------------------------------------------
    -- 1. SEED_MATCHES_SUMMARY: Source match-level dataset
-------------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE SEED.SEED_MATCHES_SUMMARY (
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
    RED_BANS        VARCHAR(255)
)
COMMENT = 'Source matches summary dataset. One record --> One match.';


-------------------------------------------------------------------------------------------
    -- 2. SEED_PLAYERS_SUMMARY: Source player-level dataset
-------------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE SEED.SEED_PLAYERS_SUMMARY (
    ID                   NUMBER(38,0) NOT NULL,
    MATCH_ID             VARCHAR(255) NOT NULL,
    PARTICIPANT_ID       NUMBER(38,0),
    TEAM_ID              NUMBER(38,0),
    CHAMPION             VARCHAR(255),
    ROLE                 VARCHAR(255),
    INDIVIDUAL_POSITION  VARCHAR(255)
)
COMMENT = 'Source players summary dataset. One record --> One player per match.';


-------------------------------------------------------------------------------------------
    -- 3. SEED_MATCH_INTERVALS: Full interval-level dataset (existing data, renamed)
-------------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE SEED.SEED_MATCH_INTERVALS (
    ID              NUMBER(38,0) NOT NULL,
    MATCH_ID        VARCHAR(255) NOT NULL,
    PLAYER_ID       NUMBER(38,0) NOT NULL,
    MINUTE          NUMBER(2,0) NOT NULL,
    CURRENT_GOLD    NUMBER(38,0),
    TOTAL_GOLD      NUMBER(38,0),
    CS              NUMBER(38,0),
    JUNGLE_CS       NUMBER(38,0),
    XP              NUMBER(38,0),
    LEVEL           NUMBER(38,0),
    KILLS           NUMBER(38,0),
    DEATHS          NUMBER(38,0),
    ASSISTS         NUMBER(38,0),
    ITEM_0          NUMBER(38,0),
    ITEM_1          NUMBER(38,0),
    ITEM_2          NUMBER(38,0),
    ITEM_3          NUMBER(38,0),
    ITEM_4          NUMBER(38,0),
    ITEM_5          NUMBER(38,0),
    ITEM_6          NUMBER(38,0),
    TEAM_KILLS      NUMBER(38,0),
    TEAM_INHIBITORS NUMBER(38,0),
    TEAM_TOWERS     NUMBER(38,0),
    TEAM_DRAGONS_FIRE    NUMBER(38,0),
    TEAM_DRAGONS_WATER   NUMBER(38,0),
    TEAM_DRAGONS_EARTH   NUMBER(38,0),
    TEAM_DRAGONS_AIR     NUMBER(38,0),
    TEAM_DRAGONS_CHEMTECH NUMBER(38,0),
    TEAM_DRAGONS_HEXTECH NUMBER(38,0),
    TEAM_DRAGONS    NUMBER(38,0),
    TEAM_BARONS     NUMBER(38,0),
    TEAM_VOID_GRUBS NUMBER(38,0),
    TEAM_HERALDS    NUMBER(38,0),
    GOLD_DIFF       NUMBER(38,0),
    XP_DIFF         NUMBER(38,0),
    TEAM_GOLD_DIFF  NUMBER(38,0)
)
COMMENT = 'Source match intervals dataset. One record --> One row per player per minute per match.';


-------------------------------------------------------------------------------------------
    -- 4. SEED_ITEMS_REF_CLASSIFIED: Item ID to name lookup, ALONG WITH CLASSIFICATIONS
    -- SEED_ITEMS_REF IS OUTDATED. 
-------------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE SEED.SEED_ITEMS_REF (
    ITEM_ID       NUMBER(38,0) NOT NULL,
    ITEM_NAME     VARCHAR(255),
    ITEM_CATEGORY VARCHAR(255)
)
COMMENT = 'Source item reference lookup. One record --> One item and its categorization.';

-------------------------------------------------------------------------------------------
    -- 5. SEED_CHAMPIONS_REF: Champion ID to name lookup
-------------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE SEED.SEED_CHAMPIONS_REF (
    CHAMPION_ID    NUMBER(38,0) NOT NULL,
    CHAMPION_NAME  VARCHAR(255)
)
COMMENT = 'Source champion reference lookup: One record --> One champion.';


-------------------------------------------------------------------------------------------
    -- 6. SEED_MATCH_DATE_INDEX: Sorted latest date first, for use by SIMULATE_DAILY_LOAD.
-------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW SEED.SEED_MATCH_DATE_INDEX AS
SELECT
    MATCH_ID,
    DATE(TRY_TO_TIMESTAMP(GAME_DATE)) AS GAME_DATE_DAY
FROM SEED.SEED_MATCHES_SUMMARY
WHERE GAME_DATE IS NOT NULL
ORDER BY GAME_DATE_DAY DESC;


-------------------------------------------------------------------------------------------
    -- 7. SEED_LOAD_STATE: Tracks date-based chunking for SIMULATE_DAILY_LOAD
-------------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE SEED.SEED_LOAD_STATE (
    CURRENT_LOAD_DATE  DATE,
    MIN_DATE           DATE,
    MAX_DATE           DATE,
    LAST_LOADED_AT     TIMESTAMP_NTZ
)
COMMENT = 'Tracks the current date pointer for simulated daily ingestion.';

INSERT INTO SEED.SEED_LOAD_STATE (
    CURRENT_LOAD_DATE, 
    MIN_DATE, 
    MAX_DATE,
    LAST_LOADED_AT
)
VALUES (NULL, NULL, NULL, NULL);


-------------------------------------------------------------------------------------------
    -- 8. SEED_UPLOAD_STG: Upload all seed CSVs here via Snowsight UI
-------------------------------------------------------------------------------------------
CREATE STAGE IF NOT EXISTS SEED.SEED_UPLOAD_STG
    FILE_FORMAT = (
        TYPE = CSV 
        FIELD_DELIMITER = ',' 
        SKIP_HEADER = 1
        FIELD_OPTIONALLY_ENCLOSED_BY = '"' 
        COMPRESSION = 'AUTO'
    )
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Raw file container for seed CSV uploads via Snowsight UI.';