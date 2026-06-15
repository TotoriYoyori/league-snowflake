-------------------------------------------------------------------------------------------
    -- 0. DECLARE WORKING CONTEXT
-------------------------------------------------------------------------------------------
USE DATABASE LEAGUE_RECORDS;

USE SCHEMA BRONZE;


-------------------------------------------------------------------------------------------
    -- 1. SEED TABLE: Holds the full historical dataset for chunked replay
-------------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE SEED_INTERVALS (
    -- Identifier
  ID NUMBER(38,0) NOT NULL,
  MATCH_ID VARCHAR(255) NOT NULL,
  PLAYER_ID NUMBER(38,0) NOT NULL,
    -- Economy
  MINUTE NUMBER(2,0) NOT NULL,
  CURRENT_GOLD NUMBER(38,0),
  TOTAL_GOLD NUMBER(38,0),
  CS NUMBER(38,0),
  JUNGLE_CS NUMBER(38,0),
  XP NUMBER(38,0),
  LEVEL NUMBER(38,0),
    -- KDA
  KILLS NUMBER(38,0),
  DEATHS NUMBER(38,0),
  ASSISTS NUMBER(38,0),
    -- Itemization
  ITEM_0 NUMBER(38,0),
  ITEM_1 NUMBER(38,0),
  ITEM_2 NUMBER(38,0),
  ITEM_3 NUMBER(38,0),
  ITEM_4 NUMBER(38,0),
  ITEM_5 NUMBER(38,0),
  ITEM_6 NUMBER(38,0),
    -- Team's Objective
  TEAM_KILLS NUMBER(38,0),
  TEAM_INHIBITORS NUMBER(38,0),
  TEAM_TOWERS NUMBER(38,0),
  TEAM_DRAGONS_FIRE NUMBER(38,0),
  TEAM_DRAGONS_WATER NUMBER(38,0),
  TEAM_DRAGONS_EARTH NUMBER(38,0),
  TEAM_DRAGONS_AIR NUMBER(38,0),
  TEAM_DRAGONS_CHEMTECH NUMBER(38,0),
  TEAM_DRAGONS_HEXTECH NUMBER(38,0),
  TEAM_DRAGONS NUMBER(38,0),
  TEAM_BARONS NUMBER(38,0),
  TEAM_VOID_GRUBS NUMBER(38,0),
  TEAM_HERALDS NUMBER(38,0),
    -- Stats Diff
  GOLD_DIFF NUMBER(38,0),
  XP_DIFF NUMBER(38,0),
  TEAM_GOLD_DIFF NUMBER(38,0)
)
COMMENT = 'Full historical dataset used as source for simulated daily ingestion.';


-------------------------------------------------------------------------------------------
    -- 2. SEED_MATCH_INDEX: Deterministic ordering of distinct matches for chunking
-------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW SEED_MATCH_INDEX AS
SELECT
    MATCH_ID,
    ROW_NUMBER() OVER (ORDER BY MATCH_ID) - 1 AS MATCH_SEQ
FROM (SELECT DISTINCT MATCH_ID FROM SEED_INTERVALS);


-------------------------------------------------------------------------------------------
    -- 3. STATE TABLE: Tracks match-based chunking offset for SIMULATE_DAILY_LOAD()
-------------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE SEED_LOAD_STATE (
    CURRENT_MATCH_OFFSET NUMBER(38,0) NOT NULL DEFAULT 0,
    MATCHES_PER_BATCH NUMBER(38,0) NOT NULL DEFAULT 1000,
    LAST_LOADED_AT TIMESTAMP_NTZ
)
COMMENT = 'Tracks the current match offset for the daily load simulation procedure.';

INSERT INTO SEED_LOAD_STATE (CURRENT_MATCH_OFFSET, MATCHES_PER_BATCH, LAST_LOADED_AT)
VALUES (0, 1000, NULL);
