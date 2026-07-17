USE SCHEMA SILVER;

-- NUTS NULL UNTYPABLE TOOWEIRD SAFE
-------------------------------------------------------------------------------------------
    -- 1. CLEANING VIEW: drop GAME_MODE/QUEUE_ID/REGION/PATCH_VERSION + below edits
-------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW SILVER.MATCHES_SUMMARY_BRONZE_STM_TO_SILVER AS
WITH CLEANING AS (
    SELECT
        UPPER(MATCH_ID) AS MATCH_ID,
        -- Cap game durations to 0+
        VALID_NUM_RANGE(
            ROUND(TRY_TO_NUMBER(GAME_DURATION), 0),
            0,
            24 * 60 * 60
        ) AS GAME_DURATION,
        -- Standardize team's name to Blue or Red
        CASE WINNING_TEAM
            WHEN '100' THEN 'Blue'
            WHEN '200' THEN 'Red'
            ELSE NULL
        END AS WINNING_TEAM,
        -- Bound valid date matches only
        VALID_TS_RANGE(
            TRY_TO_TIMESTAMP(GAME_DATE),
            '2009-10-27'::TIMESTAMP_NTZ, -- When LoL was released
            CURRENT_TIMESTAMP()
        ) AS GAME_DATE,
        GAME_VERSION,
        INITCAP(AVERAGE_RANK) AS AVERAGE_RANK,
        -- Replace -1 sentinel in ban sequences with 0 for champions reference
        REPLACE(BLUE_BANS, '-1', '0') AS BLUE_BANS,
        REPLACE(RED_BANS, '-1', '0') AS RED_BANS
    FROM BRONZE.MATCHES_SUMMARY_BRONZE_STM
)

SELECT
    NULLIFY_CAPLEN(MATCH_ID, 64) AS MATCH_ID,
    GAME_DURATION,
    NULLIFY_CAPLEN(WINNING_TEAM, 16) AS WINNING_TEAM,
    GAME_DATE,
    NULLIFY_CAPLEN(GAME_VERSION, 64) AS GAME_VERSION,
    NULLIFY_CAPLEN(AVERAGE_RANK, 16) AS AVERAGE_RANK,
    NULLIFY_CAPLEN(BLUE_BANS, 64) AS BLUE_BANS,
    NULLIFY_CAPLEN(RED_BANS, 64) AS RED_BANS
FROM CLEANING
;


-------------------------------------------------------------------------------------------
    -- 2. SILVER TABLE: One row per match end summary. PK on MATCH_ID
-------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS SILVER.MATCHES_SUMMARY_SILVER (
    MATCH_ID        VARCHAR(64) NOT NULL,
    GAME_DURATION   NUMBER(38,0),
    WINNING_TEAM    VARCHAR(16),
    GAME_DATE       TIMESTAMP_NTZ,
    GAME_VERSION    VARCHAR(64),
    AVERAGE_RANK    VARCHAR(16),
    BLUE_BANS       VARCHAR(64),
    RED_BANS        VARCHAR(64),
    CONSTRAINT MATCHES_SUMMARY_SILVER_PKEY PRIMARY KEY (MATCH_ID)
)
COMMENT = '[SILVER] Cleaned match summary. Types cast, team normalized, bans sanitized.';


-------------------------------------------------------------------------------------------
    -- 3. TASK: Merge new/changed rows from cleaning view into MATCHES_SUMMARY_SILVER
-------------------------------------------------------------------------------------------
CREATE TASK IF NOT EXISTS SILVER.BRONZE_TO_SILVER_MATCHES_TASK
    WAREHOUSE = COMPUTE_WH
    SCHEDULE  = '1 MINUTE'
    SUSPEND_TASK_AFTER_NUM_FAILURES = 3
    WHEN SYSTEM$STREAM_HAS_DATA('BRONZE.MATCHES_SUMMARY_BRONZE_STM')
AS
MERGE INTO SILVER.MATCHES_SUMMARY_SILVER AS tgt
USING (
    SELECT *
    FROM SILVER.MATCHES_SUMMARY_BRONZE_STM_TO_SILVER
    WHERE MATCH_ID IS NOT NULL
) AS src
    ON tgt.MATCH_ID = src.MATCH_ID
WHEN MATCHED THEN UPDATE SET
    tgt.GAME_DURATION = src.GAME_DURATION,
    tgt.WINNING_TEAM  = src.WINNING_TEAM,
    tgt.GAME_DATE     = src.GAME_DATE,
    tgt.GAME_VERSION  = src.GAME_VERSION,
    tgt.AVERAGE_RANK  = src.AVERAGE_RANK,
    tgt.BLUE_BANS     = src.BLUE_BANS,
    tgt.RED_BANS      = src.RED_BANS
WHEN NOT MATCHED THEN INSERT (
    MATCH_ID,
    GAME_DURATION,
    WINNING_TEAM,
    GAME_DATE,
    GAME_VERSION,
    AVERAGE_RANK,
    BLUE_BANS,
    RED_BANS
) VALUES (
    src.MATCH_ID,
    src.GAME_DURATION,
    src.WINNING_TEAM,
    src.GAME_DATE,
    src.GAME_VERSION,
    src.AVERAGE_RANK,
    src.BLUE_BANS,
    src.RED_BANS
);
