USE DATABASE LEAGUE_RECORDS;

USE SCHEMA GOLD;

-------------------------------------------------------------------------------------------
    -- PLAYER_STATS_BASE: Pure facts joined from source to become analytical ready
-------------------------------------------------------------------------------------------
WITH MATCH_LAST_INTERVAL AS (
    SELECT MATCH_ID, MAX(MINUTE) AS END_INTERVAL
    FROM SILVER.PLAYER_INTERVAL_SILVER
    GROUP BY MATCH_ID
),

MATCH_STATS_AT_END AS (
    SELECT
        -- Composite key
        ML.MATCH_ID,
        PIV.PARTICIPANT_POS_ID,
        -- Stats 
        PIV.LEVEL,
        PIV.KILLS,
        PIV.DEATHS,
        PIV.ASSISTS,
        (PIV.CS + PIV.JUNGLE_CS) AS CS,
        PIV.TOTAL_GOLD,
        -- Build
        PIV.ITEM_0, 
        PIV.ITEM_1, 
        PIV.ITEM_2, 
        PIV.ITEM_3,
        PIV.ITEM_4, 
        PIV.ITEM_5, 
        PIV.ITEM_6
    FROM MATCH_LAST_INTERVAL AS ML
    JOIN SILVER.PLAYER_INTERVAL_SILVER AS PIV
        ON PIV.MATCH_ID = ML.MATCH_ID
        AND PIV.MINUTE = ML.END_INTERVAL
),

WITH_PLAYER_SUMMARY AS (
    SELECT
        -- Composite key
        SE.MATCH_ID,
        SE.PARTICIPANT_POS_ID,
        -- Context
        PS.TEAM,
        (PS.TEAM = MAT.WINNING_TEAM) AS WIN,
        -- Filter
        PS.CHAMPION,
        PS.LANE,
        -- Stats
        SE.LEVEL,
        SE.KILLS,
        SE.DEATHS,
        SE.ASSISTS,
        SE.CS,
        SE.TOTAL_GOLD,
        -- Build
        SE.ITEM_0,
        SE.ITEM_1,
        SE.ITEM_2,
        SE.ITEM_3,
        SE.ITEM_4,
        SE.ITEM_5,
        SE.ITEM_6
    FROM MATCH_STATS_AT_END AS SE
    JOIN SILVER.MATCHES_SUMMARY_SILVER AS MAT
        ON MAT.MATCH_ID = SE.MATCH_ID
    JOIN SILVER.PLAYERS_SUMMARY_SILVER AS PS
        ON PS.MATCH_ID = SE.MATCH_ID
        AND PS.PARTICIPANT_POS_ID = SE.PARTICIPANT_POS_ID
)

SELECT *
FROM WITH_PLAYER_SUMMARY
ORDER BY MATCH_ID, PARTICIPANT_POS_ID
;
