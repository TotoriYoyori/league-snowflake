-------------------------------------------------------------------------------------------
    -- 0. DECLARE WORKING CONTEXT
-------------------------------------------------------------------------------------------
USE DATABASE LEAGUE_RECORDS;

USE SCHEMA L00_STG;


-------------------------------------------------------------------------------------------
    -- 1. SET ONE STREAM ON THE STAGING TABLE FOR DOWNSTREAM TRANSFORMATION
-------------------------------------------------------------------------------------------
CREATE OR REPLACE STREAM STG_INTERVALS_STRM_RDV 
ON TABLE STG_INTERVALS
COMMENT = 'Captures changes on STG_INTERVALS for Raw Data Vault loading';


-------------------------------------------------------------------------------------------
    -- 2. USE THE STREAM-VIEW TO TRANSFORM DATA FROM STAGING
-------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW L00_STG.STG_INTERVALS_STRM_RDV_EXPORT 
COMMENT = 'Stream view that adds hub key and hash diff columns for Raw Data Vault ingestion'
AS 
SELECT 
    -- Keep all original columns
    SRC.*,
    -- With new column -> Hub Key
    FASTHASH(ARRAY_TO_STRING(ARRAY_CONSTRUCT(
        TRIM(ID),
        UPPER(TRIM(MATCH_ID)), 
        TRIM(PLAYER_ID),
        TRIM(MINUTE)
    ), '^')) AS SHA1_HUB_INTERVAL,
    -- With new column -> Record's Hash Diff
    FASTHASH(ARRAY_TO_STRING(ARRAY_CONSTRUCT(
        CURRENT_GOLD, TOTAL_GOLD,
        CS, JUNGLE_CS,
        XP, LEVEL,
        KILLS, DEATHS, ASSISTS,
        ITEM_0, ITEM_1, ITEM_2, ITEM_3, ITEM_4, ITEM_5, ITEM_6, 
        TEAM_KILLS, TEAM_INHIBITORS, TEAM_TOWERS,
        TEAM_DRAGONS_FIRE, TEAM_DRAGONS_WATER, TEAM_DRAGONS_EARTH, TEAM_DRAGONS_AIR, 
        TEAM_DRAGONS_CHEMTECH, TEAM_DRAGONS_HEXTECH, TEAM_DRAGONS,
        TEAM_BARONS, TEAM_VOID_GRUBS, TEAM_HERALDS, 
        GOLD_DIFF, XP_DIFF, TEAM_GOLD_DIFF
    ), '^')) AS HASH_INTERVAL_DIFF
FROM L00_STG.STG_INTERVALS_STRM_RDV AS SRC;
