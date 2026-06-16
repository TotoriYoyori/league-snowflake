-------------------------------------------------------------------------------------------
    -- 0. DECLARE WORKING CONTEXT
-------------------------------------------------------------------------------------------
USE DATABASE LEAGUE_RECORDS;

USE SCHEMA SILVER;


-------------------------------------------------------------------------------------------
    -- 1. CLEANING VIEW: Normalize team (100/200 → Blue/Red), split PascalCase champion
    --    names, standardize lane (Invalid→NULL, TopJungle→Top, Utility→Support),
    --    bound participant_id to 1-10
-------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW PLAYERS_SUMMARY_BRONZE_STM_TO_SILVER AS
SELECT
    ID,
    UPPER(TRIM(MATCH_ID))                                           AS MATCH_ID,
    CASE
        WHEN PARTICIPANT_ID BETWEEN 1 AND 10 THEN PARTICIPANT_ID
        ELSE NULL
    END                                                             AS PARTICIPANT_POS_ID,
    CASE TEAM_ID
        WHEN 100 THEN 'Blue'
        WHEN 200 THEN 'Red'
        ELSE NULL
    END                                                             AS TEAM,
    -- Split PascalCase to Title Case: 'TwistedFate' --> 'Twisted Fate'
    TRIM(REGEXP_REPLACE(CHAMPION, '([a-z])([A-Z])', '\\1 \\2'))     AS CHAMPION,
    CASE UPPER(TRIM(INDIVIDUAL_POSITION))
        WHEN 'INVALID'    THEN NULL
        WHEN 'TOPJUNGLE'  THEN 'Top'
        WHEN 'UTILITY'    THEN 'Support'
        ELSE INITCAP(TRIM(INDIVIDUAL_POSITION))
    END                                                             AS LANE
FROM BRONZE.PLAYERS_SUMMARY_BRONZE_STM;


-------------------------------------------------------------------------------------------
    -- 2. SILVER TABLE: One row per player per match. FK to MATCHES_SUMMARY_SILVER.
-------------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE PLAYERS_SUMMARY_SILVER (
    ID                  NUMBER(38,0) NOT NULL,
    MATCH_ID            VARCHAR(64) NOT NULL,
    PARTICIPANT_POS_ID  NUMBER(38,0),
    TEAM                VARCHAR(4),
    CHAMPION            VARCHAR(64),
    LANE                VARCHAR(16),
    CONSTRAINT PLAYERS_SUMMARY_SILVER_PKEY PRIMARY KEY (ID),
    CONSTRAINT PLAYERS_SUMMARY_SILVER_MATCH_FK
        FOREIGN KEY (MATCH_ID) REFERENCES MATCHES_SUMMARY_SILVER (MATCH_ID)
)
COMMENT = '[SILVER] Cleaned player summary. Team normalized, lane standardized, champion PascalCase split.';


-------------------------------------------------------------------------------------------
    -- 3. TASK: Merge new/changed rows from cleaning view into PLAYERS_SUMMARY_SILVER
-------------------------------------------------------------------------------------------
CREATE OR REPLACE TASK BRONZE_TO_SILVER_PLAYERS_TASK
    WAREHOUSE = DV_COMPUTE_WH
    SCHEDULE  = '1 MINUTE'
    WHEN SYSTEM$STREAM_HAS_DATA('BRONZE.PLAYERS_SUMMARY_BRONZE_STM')
AS
MERGE INTO SILVER.PLAYERS_SUMMARY_SILVER AS tgt
USING SILVER.PLAYERS_SUMMARY_BRONZE_STM_TO_SILVER AS src
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