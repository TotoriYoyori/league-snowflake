USE DATABASE LEAGUE_RECORDS;

USE SCHEMA GOLD;

-------------------------------------------------------------------------------------------
    -- 1. CLEANING VIEW
-------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW GOLD.PLAYER_STATS_ROLLUP AS 
-- Last match interval = match end statistics
WITH MATCH_LAST_INTERVAL AS (
    SELECT MATCH_ID,
        MAX(MINUTE) AS END_INTERVAL
    FROM SILVER.PLAYER_INTERVAL_SILVER
    GROUP BY MATCH_ID
), 
-- Statistics per player at end interval
MATCH_STATS_AT_END AS (
    SELECT 
        -- Context
        ML.MATCH_ID, 
        PIV.PARTICIPANT_POS_ID,
        -- Descriptor
        PIV.LEVEL,
        PIV.KILLS,
        PIV.DEATHS,
        PIV.ASSISTS,
        (PIV.CS + PIV.JUNGLE_CS) AS CS,
        PIV.TOTAL_GOLD
    FROM MATCH_LAST_INTERVAL AS ML
    JOIN SILVER.PLAYER_INTERVAL_SILVER AS PIV
        ON PIV.MATCH_ID = ML.MATCH_ID
        AND PIV.MINUTE = ML.END_INTERVAL
),
-- Replace per player with their champion and lane
PLAYER_LANE_CHAMPION AS (
    SELECT 
        -- Context
        ME.MATCH_ID, 
        ME.PARTICIPANT_POS_ID,
        -- Player Lane and Champion
        PS.LANE,
        PS.CHAMPION,
        -- Descriptor
        ME.LEVEL,
        ME.KILLS,
        ME.DEATHS,
        ME.ASSISTS,
        ME.CS,
        ME.TOTAL_GOLD
    FROM MATCH_STATS_AT_END AS ME
    JOIN SILVER.PLAYERS_SUMMARY_SILVER AS PS
        ON PS.MATCH_ID = ME.MATCH_ID
        AND PS.PARTICIPANT_POS_ID = ME.PARTICIPANT_POS_ID
)

SELECT
    -- Surrogate ID
    ROW_NUMBER() OVER(ORDER BY MATCH_ID, PARTICIPANT_POS_ID) AS ID,
    -- Record 
    LANE, 
    CHAMPION, 
    LEVEL, 
    KILLS, 
    DEATHS,
    ASSISTS,
    CS,
    TOTAL_GOLD
FROM PLAYER_LANE_CHAMPION
ORDER BY ID
;
