-------------------------------------------------------------------------------------------
    -- 0. DECLARE WORKING CONTEXT
-------------------------------------------------------------------------------------------
USE DATABASE LEAGUE_RECORDS;

USE SCHEMA L20_ID;


-------------------------------------------------------------------------------------------
    -- 1. MATCH_PLAYER_SUMMARY: Aggregated view at the grain of one row per player per match
    -- Provides end-of-game stats and per-minute efficiency metrics.
-------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW MATCH_PLAYER_SUMMARY AS
SELECT
    MATCH_ID,
    PLAYER_ID,
    MAX(MINUTE) AS GAME_DURATION,
    -- Final KDA (values at last recorded interval)
    MAX_BY(KILLS, MINUTE) AS FINAL_KILLS,
    MAX_BY(DEATHS, MINUTE) AS FINAL_DEATHS,
    MAX_BY(ASSISTS, MINUTE) AS FINAL_ASSISTS,
    MAX_BY(KDA_RATIO, MINUTE) AS FINAL_KDA_RATIO,
    -- Economy at end of game
    MAX_BY(TOTAL_GOLD, MINUTE) AS FINAL_GOLD,
    MAX_BY(NET_CS, MINUTE) AS FINAL_CS,
    MAX_BY(LEVEL, MINUTE) AS FINAL_LEVEL,
    -- Efficiency metrics
    MAX_BY(TOTAL_GOLD, MINUTE) / NULLIFZERO(MAX(MINUTE)) AS GOLD_PER_MIN,
    MAX_BY(NET_CS, MINUTE) / NULLIFZERO(MAX(MINUTE)) AS CS_PER_MIN,
    -- Gold advantage
    MAX(GOLD_DIFF) AS PEAK_GOLD_ADVANTAGE,
    MAX_BY(GOLD_DIFF, MINUTE) AS FINAL_GOLD_DIFF
FROM INTERVALS_KDA K
JOIN INTERVALS_ECONOMY E USING (ID, MATCH_ID, PLAYER_ID, MINUTE)
GROUP BY MATCH_ID, PLAYER_ID;
