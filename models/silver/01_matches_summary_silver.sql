-------------------------------------------------------------------------------------------
    -- 0. DECLARE WORKING CONTEXT
-------------------------------------------------------------------------------------------
USE DATABASE LEAGUE_RECORDS;

USE SCHEMA SILVER;


-------------------------------------------------------------------------------------------
    -- 1. CLEANING VIEW: Cast GAME_DATE to timestamp, normalize WINNING_TEAM (100/200 →
    --    Blue/Red), null negative durations, replace -1 sentinel in ban sequences with 0,
    --    INITCAP average rank, drop GAME_MODE/QUEUE_ID/REGION/PATCH_VERSION
-------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW MATCHES_SUMMARY_BRONZE_STM_TO_SILVER AS
SELECT
    UPPER(TRIM(MATCH_ID))                                           AS MATCH_ID,
    CASE WHEN GAME_DURATION < 0 THEN NULL ELSE GAME_DURATION END    AS GAME_DURATION,
    CASE WINNING_TEAM
        WHEN 100 THEN 'Blue'
        WHEN 200 THEN 'Red'
        ELSE NULL
    END                                                             AS WINNING_TEAM,
    TRY_TO_TIMESTAMP(GAME_DATE)                                     AS GAME_DATE,
    TRIM(GAME_VERSION)                                              AS GAME_VERSION,
    INITCAP(TRIM(AVERAGE_RANK))                                     AS AVERAGE_RANK,
    TRIM(REPLACE(BLUE_BANS, '-1', '0'))                             AS BLUE_BANS,
    TRIM(REPLACE(RED_BANS, '-1', '0'))                              AS RED_BANS
FROM BRONZE.MATCHES_SUMMARY_BRONZE_STM;


-------------------------------------------------------------------------------------------
    -- 2. SILVER TABLE: One row per match. PK on MATCH_ID.
-------------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE MATCHES_SUMMARY_SILVER (
    MATCH_ID        VARCHAR(64) NOT NULL,
    GAME_DURATION   NUMBER(38,0),
    WINNING_TEAM    VARCHAR(4),
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
CREATE OR REPLACE TASK BRONZE_TO_SILVER_MATCHES_TASK
    WAREHOUSE = COMPUTE_WH
    SCHEDULE  = '1 MINUTE'
    WHEN SYSTEM$STREAM_HAS_DATA('BRONZE.MATCHES_SUMMARY_BRONZE_STM')
AS
MERGE INTO SILVER.MATCHES_SUMMARY_SILVER AS tgt
USING SILVER.MATCHES_SUMMARY_BRONZE_STM_TO_SILVER AS src
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
