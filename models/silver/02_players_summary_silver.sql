USE SCHEMA SILVER;


-------------------------------------------------------------------------------------------
    -- 1. CLEANING VIEW
-------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW SILVER.PLAYERS_SUMMARY_BRONZE_STM_TO_SILVER AS
WITH CLEANING AS (
    SELECT
        TRY_TO_NUMBER(ID) AS ID,
        UPPER(MATCH_ID) AS MATCH_ID,
        -- Clamp participant_id to 1-10
       VALID_NUM_RANGE(
           TRY_TO_NUMBER(PARTICIPANT_ID),
           1, 10
       ) AS PARTICIPANT_POS_ID,
        -- Normalize team (100/200 → Blue/Red)
        CASE TEAM_ID
            WHEN '100' THEN 'Blue'
            WHEN '200' THEN 'Red'
            ELSE NULL
        END AS TEAM,
        -- Split PascalCase to Title Case: 'TwistedFate' --> 'Twisted Fate'
        -- Known exception: raw source spells this champion 'FiddleSticks' (PascalCase, splits to
        -- 'Fiddle Sticks'), but CHAMPIONS_REF's raw source spells it 'Fiddlesticks' (one word, no
        -- case transition for the regex to catch).
        REPLACE(
            PASCAL_TO_TITLE_CASE(CHAMPION),
            'Fiddle Sticks', 'Fiddlesticks'
        ) AS CHAMPION,
        -- Standardize + Normalize lane naming
        CASE UPPER(INDIVIDUAL_POSITION)
            WHEN 'INVALID' THEN NULL
            WHEN 'TOPJUNGLE' THEN 'Top'
            WHEN 'UTILITY' THEN 'Support'
            ELSE INITCAP(INDIVIDUAL_POSITION)
        END AS LANE
    FROM BRONZE.PLAYERS_SUMMARY_BRONZE_STM
)

SELECT
    ID,
    NULLIFY_CAPLEN(MATCH_ID, 64) AS MATCH_ID,
    PARTICIPANT_POS_ID,
    NULLIFY_CAPLEN(TEAM, 16) AS TEAM,
    NULLIFY_CAPLEN(CHAMPION, 64) AS CHAMPION,
    NULLIFY_CAPLEN(LANE, 16) AS LANE
FROM CLEANING;


-------------------------------------------------------------------------------------------
    -- 2. SILVER TABLE: One row per player per match. FK to MATCHES_SUMMARY_SILVER.
-------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS SILVER.PLAYERS_SUMMARY_SILVER (
    ID                  NUMBER(38,0) NOT NULL,
    MATCH_ID            VARCHAR(64) NOT NULL,
    PARTICIPANT_POS_ID  NUMBER(38,0) NOT NULL,
    TEAM                VARCHAR(16),
    CHAMPION            VARCHAR(64),
    LANE                VARCHAR(16),
    CONSTRAINT PLAYERS_SUMMARY_SILVER_PKEY PRIMARY KEY (ID),
    CONSTRAINT PLAYERS_SUMMARY_SILVER_CONTEXT_PKEY UNIQUE (MATCH_ID, PARTICIPANT_POS_ID),
    CONSTRAINT PLAYERS_SUMMARY_SILVER_MATCH_FK
        FOREIGN KEY (MATCH_ID) REFERENCES SILVER.MATCHES_SUMMARY_SILVER (MATCH_ID)
)
COMMENT = '[SILVER] Cleaned player summary. Team normalized, lane standardized, champion PascalCase split.';


-------------------------------------------------------------------------------------------
    -- 3. TASK: Merge new/changed rows from cleaning view into PLAYERS_SUMMARY_SILVER
-------------------------------------------------------------------------------------------
CREATE TASK IF NOT EXISTS SILVER.BRONZE_TO_SILVER_PLAYERS_TASK
    WAREHOUSE = COMPUTE_WH
    SCHEDULE  = '1 MINUTE'
    SUSPEND_TASK_AFTER_NUM_FAILURES = 3
    WHEN SYSTEM$STREAM_HAS_DATA('BRONZE.PLAYERS_SUMMARY_BRONZE_STM')
AS
MERGE INTO SILVER.PLAYERS_SUMMARY_SILVER AS tgt
USING (
    SELECT * 
    FROM SILVER.PLAYERS_SUMMARY_BRONZE_STM_TO_SILVER
    WHERE PARTICIPANT_POS_ID IS NOT NULL
        AND MATCH_ID IS NOT NULL
        AND ID IS NOT NULL
) AS src
    ON tgt.ID = src.ID
WHEN MATCHED THEN UPDATE SET
    tgt.MATCH_ID           = src.MATCH_ID,
    tgt.PARTICIPANT_POS_ID = src.PARTICIPANT_POS_ID,
    tgt.TEAM               = src.TEAM,
    tgt.CHAMPION           = src.CHAMPION,
    tgt.LANE               = src.LANE
WHEN NOT MATCHED THEN INSERT (
    ID,
    MATCH_ID,
    PARTICIPANT_POS_ID,
    TEAM,
    CHAMPION,
    LANE
) VALUES (
    src.ID,
    src.MATCH_ID,
    src.PARTICIPANT_POS_ID,
    src.TEAM,
    src.CHAMPION,
    src.LANE
);