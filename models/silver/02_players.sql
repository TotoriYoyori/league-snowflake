USE SCHEMA SILVER;
-------------------------------------------------------------------------------------------
    -- 1. CLEANING VIEW
-------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW SILVER.PLAYERS_STM_TO_SILVER AS
SELECT
    UPPER(MATCH_ID) AS MATCH_ID,
    -- Clamp participant_id to 1-10
    VALID_NUM_RANGE(
        SAFECAST_TO_INT(PARTICIPANT_ID),
        1, 10
    ) AS PARTICIPANT_POS_ID,
    -- Normalize team (100/200 -> BLUE/RED)
    CASE TEAM_ID
        WHEN '100' THEN 'BLUE'
        WHEN '200' THEN 'RED'
        ELSE NULL
    END AS TEAM,
    -- Keep champion as the raw uppercase log value (no PascalCase splitting)
    UPPER(CHAMPION) AS CHAMPION_NAME,
    -- Standardize role naming (UTILITY -> SUPPORT)
    CASE
        WHEN UPPER(ROLE) = 'UTILITY' THEN 'SUPPORT'
        ELSE UPPER(ROLE)
    END AS CHAMPION_ROLE
FROM BRONZE.PLAYERS_STM
;
-------------------------------------------------------------------------------------------
    -- 2. SILVER TABLE: One row per player per match. FK to MATCHES.
-------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS SILVER.PLAYERS (
    -- Key
    MATCH_ID VARCHAR NOT NULL,
    PARTICIPANT_POS_ID NUMBER(38,0) NOT NULL COMMENT 'The index position of the player at queue time. 1-5 for BLUE side, 6-10 for RED side.',
    TEAM VARCHAR NOT NULL COMMENT 'BLUE or RED.',
    -- Description
    CHAMPION_NAME VARCHAR COMMENT 'The name of the champion as recorded in the log.',
    CHAMPION_ROLE VARCHAR COMMENT 'Resolved role played by the player, based on in-game signals, not queue selection.',

    CONSTRAINT SILVER_PLAYERS_PKEY PRIMARY KEY (MATCH_ID, PARTICIPANT_POS_ID),
    CONSTRAINT SILVER_PLAYERS_MATCHES_FKEY
        FOREIGN KEY (MATCH_ID) REFERENCES SILVER.MATCHES (MATCH_ID)
)
COMMENT = '[SILVER] Classic mode (Summoner''s Rift 5v5, draft queue) summary for individual players per match.';
-------------------------------------------------------------------------------------------
    -- 3. TASK: Merge new/changed rows from cleaning view into PLAYERS
-------------------------------------------------------------------------------------------
CREATE TASK IF NOT EXISTS SILVER.BRONZE_TO_SILVER_PLAYERS_TASK
    WAREHOUSE = COMPUTE_WH
    SCHEDULE  = '1 MINUTE'
    SUSPEND_TASK_AFTER_NUM_FAILURES = 3
    WHEN SYSTEM$STREAM_HAS_DATA('BRONZE.PLAYERS_STM')
AS
MERGE INTO SILVER.PLAYERS AS tgt
USING (
    SELECT *
    FROM SILVER.PLAYERS_STM_TO_SILVER
    WHERE MATCH_ID IS NOT NULL
        AND PARTICIPANT_POS_ID IS NOT NULL
        AND TEAM IS NOT NULL
) AS src
    ON tgt.MATCH_ID = src.MATCH_ID
    AND tgt.PARTICIPANT_POS_ID = src.PARTICIPANT_POS_ID
WHEN MATCHED THEN UPDATE SET
    tgt.TEAM          = src.TEAM,
    tgt.CHAMPION_NAME = src.CHAMPION_NAME,
    tgt.CHAMPION_ROLE = src.CHAMPION_ROLE
WHEN NOT MATCHED THEN INSERT (
    MATCH_ID,
    PARTICIPANT_POS_ID,
    TEAM,
    CHAMPION_NAME,
    CHAMPION_ROLE
) VALUES (
    src.MATCH_ID,
    src.PARTICIPANT_POS_ID,
    src.TEAM,
    src.CHAMPION_NAME,
    src.CHAMPION_ROLE
)
;
