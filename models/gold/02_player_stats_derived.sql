USE DATABASE LEAGUE_RECORDS;
USE SCHEMA GOLD;


-------------------------------------------------------------------------------------------
    -- PLAYER_STATS_DERIVED: Alternative to player_stats with derived statistics, 
    -- instead of base stats and itemization.
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
        PIV.TOTAL_GOLD
    FROM MATCH_LAST_INTERVAL AS ML
    JOIN SILVER.PLAYER_INTERVAL_SILVER AS PIV
        ON PIV.MATCH_ID = ML.MATCH_ID
        AND PIV.MINUTE = ML.END_INTERVAL
),

WITH_DERIVED_PLAYER_SUMMARY AS (
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
        ROUND(
            (SE.KILLS + SE.ASSISTS)::DECIMAL / (SE.DEATHS + 1)
        , 2) AS KDA,
        COALESCE(ROUND(
            (SE.TOTAL_GOLD)::DECIMAL / NULLIF(MAT.GAME_DURATION, 0) * 60
        , 2), 0) AS GOLD_PER_MIN,
        -- Adjust for spawn time, no active CS-ing occurs until 0:55 for most scenarios.
        COALESCE(ROUND(
            (SE.CS)::DECIMAL / NULLIF(MAT.GAME_DURATION - 55, 0) * 60 
        , 2), 0) AS CS_PER_MIN
    FROM MATCH_STATS_AT_END AS SE
    JOIN SILVER.MATCHES_SUMMARY_SILVER AS MAT
        ON MAT.MATCH_ID = SE.MATCH_ID
    JOIN SILVER.PLAYERS_SUMMARY_SILVER AS PS
        ON PS.MATCH_ID = SE.MATCH_ID
        AND PS.PARTICIPANT_POS_ID = SE.PARTICIPANT_POS_ID
)

SELECT *
FROM WITH_DERIVED_PLAYER_SUMMARY
ORDER BY MATCH_ID, PARTICIPANT_POS_ID
;
