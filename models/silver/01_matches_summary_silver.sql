USE SCHEMA SILVER;


-------------------------------------------------------------------------------------------
    -- 1. CLEANING VIEW: drop GAME_MODE/QUEUE_ID/REGION/PATCH_VERSION + below edits
-------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW SILVER.MATCHES_SUMMARY_BRONZE_STM_TO_SILVER AS
SELECT
    UPPER(TRIM(MATCH_ID))                                            AS MATCH_ID,
    CASE WHEN GAME_DURATION <= 0 THEN NULL ELSE GAME_DURATION END    AS GAME_DURATION,
    -- Normalize 100/200 ID for team into Blue and Red side
    CASE WINNING_TEAM
        WHEN 100 THEN 'Blue'
        WHEN 200 THEN 'Red'
        ELSE NULL
    END                                                             AS WINNING_TEAM,
    TRY_TO_TIMESTAMP(GAME_DATE)                                     AS GAME_DATE,
    -- Ensure good game version e.g. 16.2.741.3171
    CASE
        WHEN TRIM(GAME_VERSION) REGEXP '^[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+$' 
            THEN TRIM(GAME_VERSION)
        ELSE NULL
    END                                                             AS GAME_VERSION,
    INITCAP(TRIM(AVERAGE_RANK))                                     AS AVERAGE_RANK,
    -- Replace -1 sentinel in ban sequences with 0 for champions reference
    TRIM(REPLACE(BLUE_BANS, '-1', '0'))                             AS BLUE_BANS,
    TRIM(REPLACE(RED_BANS, '-1', '0'))                              AS RED_BANS
FROM BRONZE.MATCHES_SUMMARY_BRONZE_STM;


-------------------------------------------------------------------------------------------
    -- 2. SILVER TABLE: One row per match end summary. PK on MATCH_ID
-------------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE SILVER.MATCHES_SUMMARY_SILVER (
    MATCH_ID        VARCHAR(64) NOT NULL,
    GAME_DURATION   NUMBER(38,0),
    WINNING_TEAM    VARCHAR(16),
    GAME_DATE       TIMESTAMP_NTZ,
    GAME_VERSION    VARCHAR(64),
    AVERAGE_RANK    VARCHAR(64),
    BLUE_BANS       VARCHAR(64),
    RED_BANS        VARCHAR(64),
    CONSTRAINT MATCHES_SUMMARY_SILVER_PKEY PRIMARY KEY (MATCH_ID)
)
COMMENT = '[SILVER] Cleaned match summary. Types cast, team normalized, bans sanitized.';


-------------------------------------------------------------------------------------------
    -- 3. TASK: Merge new/changed rows from cleaning view into MATCHES_SUMMARY_SILVER
-------------------------------------------------------------------------------------------
CREATE OR REPLACE TASK SILVER.BRONZE_TO_SILVER_MATCHES_TASK
    WAREHOUSE = COMPUTE_WH
    SCHEDULE  = '1 MINUTE'
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
