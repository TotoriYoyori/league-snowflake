-------------------------------------------------------------------------------------------
    -- 0. DECLARE WORKING CONTEXT
-------------------------------------------------------------------------------------------
USE WAREHOUSE DV_COMPUTE_WH;

USE DATABASE LEAGUE_RECORDS;

USE SCHEMA L10_RDV;


-------------------------------------------------------------------------------------------
    -- 1. BUILD HUB AND SATELLITE TABLE FOR INCOMING FROM L00_STG.STG_TABLE_STRM_EXPORT
-------------------------------------------------------------------------------------------
-- Hub
CREATE OR REPLACE TABLE HUB_INTERVALS (
    -- Key
    SHA1_HUB_INTERVAL BINARY NOT NULL,
    -- Business Key
    ID NUMBER NOT NULL,
    MATCH_ID VARCHAR(255) NOT NULL,
    PLAYER_ID NUMBER NOT NULL,
    MINUTE NUMBER(2,0) NOT NULL,
    -- Meta
    LDTS TIMESTAMP_NTZ NOT NULL,
    RSRC VARCHAR(255) NOT NULL,
    -- Constraint
    CONSTRAINT HUB_INTERVALS_PKEY PRIMARY KEY(SHA1_HUB_INTERVAL)
)
COMMENT = '[HUB] Snapshot of individual player statistics every 5 minute per match.';

-- Satellite
CREATE OR REPLACE TABLE SAT_INTERVALS (
    -- Key
    SHA1_HUB_INTERVAL BINARY NOT NULL,
    -- Meta
    LDTS TIMESTAMP_NTZ NOT NULL, 
    RSRC VARCHAR(255) NOT NULL,
    -- Economy
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
    TEAM_GOLD_DIFF NUMBER(38,0),
    -- Hash
    HASH_INTERVAL_DIFF BINARY NOT NULL,
    -- Constraint
    CONSTRAINT SAT_INTERVALS_PKEY PRIMARY KEY(SHA1_HUB_INTERVAL, LDTS),
    CONSTRAINT SAT_INTERVALS_FKEY 
        FOREIGN KEY(SHA1_HUB_INTERVAL) REFERENCES HUB_INTERVALS(SHA1_HUB_INTERVAL)
)
COMMENT = '[SAT] Snapshot of individual player statistics every 5 minute per match.';
