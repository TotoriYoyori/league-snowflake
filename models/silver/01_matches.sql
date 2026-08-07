USE SCHEMA SILVER;
-------------------------------------------------------------------------------------------
    -- 1. CLEANING VIEW: drop GAME_MODE/QUEUE_ID/REGION/PATCH_VERSION + below edits
-------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW SILVER.MATCHES_STM_TO_SILVER AS
SELECT
    UPPER(MATCH_ID) AS MATCH_ID,
    -- Standardize team's side to BLUE or RED (Riot API: 100 = BLUE, 200 = RED)
    CASE WINNING_TEAM
        WHEN '100' THEN 'BLUE'
        WHEN '200' THEN 'RED'
        ELSE NULL
    END AS WINNING_TEAM,
    -- Cap game duration to a realistic 0-3hr window
    VALID_NUM_RANGE(
        SAFECAST_TO_INT(GAME_DURATION),
        0,
        3 * 60 * 60
    ) AS GAME_DURATION,
    -- Bound valid date matches only
    VALID_TS_RANGE(
        TRY_TO_TIMESTAMP(GAME_DATE),
        '2009-10-27'::TIMESTAMP_NTZ, -- When LoL was released
        CURRENT_TIMESTAMP()
    ) AS GAME_DATE,
    GAME_VERSION,
    INITCAP(AVERAGE_RANK) AS AVERAGE_RANK,
    -- Split ban sequence into an array of ints, -1 sentinel replaced with 0
    TRANSFORM(
        SPLIT(BLUE_BANS, ','),
        X VARCHAR -> IFF(TRY_TO_NUMBER(X) = -1, 0, TRY_TO_NUMBER(X))
    )::ARRAY(NUMBER) AS BLUE_BANS,
    TRANSFORM(
        SPLIT(RED_BANS, ','),
        X VARCHAR -> IFF(TRY_TO_NUMBER(X) = -1, 0, TRY_TO_NUMBER(X))
    )::ARRAY(NUMBER) AS RED_BANS
FROM BRONZE.MATCHES_STM
;
-------------------------------------------------------------------------------------------
    -- 2. SILVER TABLE: One row per match end summary. PK on MATCH_ID
-------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS SILVER.MATCHES (
    -- Key
    MATCH_ID VARCHAR NOT NULL,
    WINNING_TEAM VARCHAR NOT NULL COMMENT 'BLUE or RED. Not null for joins.',
    -- Description
    GAME_DURATION NUMBER(38,0) COMMENT 'Match duration in seconds.',
    GAME_DATE TIMESTAMP_NTZ COMMENT 'Match end timestamp.',
    GAME_VERSION VARCHAR COMMENT 'Game client version string.',
    AVERAGE_RANK VARCHAR COMMENT 'Average rank of match participants, Title Cased.',
    BLUE_BANS ARRAY(NUMBER) COMMENT 'Blue team champion ban sequence.',
    RED_BANS ARRAY(NUMBER) COMMENT 'Red team champion ban sequence.',

    CONSTRAINT SILVER_MATCHES_PKEY PRIMARY KEY (MATCH_ID)
)
COMMENT = '[SILVER] Classic mode (Summoner''s Rift 5v5, draft queue) match summary. Types cast, team normalized, bans parsed into arrays.';
-------------------------------------------------------------------------------------------
    -- 3. TASK: Merge new/changed rows from cleaning view into MATCHES
-------------------------------------------------------------------------------------------
CREATE TASK IF NOT EXISTS SILVER.BRONZE_TO_SILVER_MATCHES_TASK
    WAREHOUSE = COMPUTE_WH
    SCHEDULE  = '1 MINUTE'
    SUSPEND_TASK_AFTER_NUM_FAILURES = 3
    WHEN SYSTEM$STREAM_HAS_DATA('BRONZE.MATCHES_STM')
AS
MERGE INTO SILVER.MATCHES AS tgt
USING (
    SELECT *
    FROM SILVER.MATCHES_STM_TO_SILVER
    WHERE MATCH_ID IS NOT NULL
        AND WINNING_TEAM IS NOT NULL
) AS src
    ON tgt.MATCH_ID = src.MATCH_ID
WHEN MATCHED THEN UPDATE SET
    tgt.WINNING_TEAM  = src.WINNING_TEAM,
    tgt.GAME_DURATION = src.GAME_DURATION,
    tgt.GAME_DATE     = src.GAME_DATE,
    tgt.GAME_VERSION  = src.GAME_VERSION,
    tgt.AVERAGE_RANK  = src.AVERAGE_RANK,
    tgt.BLUE_BANS     = src.BLUE_BANS,
    tgt.RED_BANS      = src.RED_BANS
WHEN NOT MATCHED THEN INSERT (
    MATCH_ID,
    WINNING_TEAM,
    GAME_DURATION,
    GAME_DATE,
    GAME_VERSION,
    AVERAGE_RANK,
    BLUE_BANS,
    RED_BANS
) VALUES (
    src.MATCH_ID,
    src.WINNING_TEAM,
    src.GAME_DURATION,
    src.GAME_DATE,
    src.GAME_VERSION,
    src.AVERAGE_RANK,
    src.BLUE_BANS,
    src.RED_BANS
);
