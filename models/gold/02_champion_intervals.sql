USE DATABASE LEAGUE_RECORDS;
USE SCHEMA GOLD;
-------------------------------------------------------------------------------------------
    -- CHAMPION_INTERVALS: Champion per-interval aggregated statistics
    --
    -- GRAIN: One row per (CHAMPION, MINUTE) — average stats for that champion at that minute.
    --
    -- KNOWN LIMITATIONS:
    -- 1. VERY FEW LONG GAMES: not all matches reach later minutes (minute
    --    35-40+). Matches that end early (stomps, early surrenders) drop out of the sample
    --    as MINUTE increases, so stats at later minutes reflect only champions/games that
    --    lasted that long.
    -- 2. PATCH AND RANK AGNOSTIC: this query aggregates the stats for champions across all
    --    patches and ranks (from Unranked to Challengers). 
-------------------------------------------------------------------------------------------
CREATE OR REPLACE DYNAMIC TABLE CHAMPION_INTERVALS
TARGET_LAG = '1 day'               
WAREHOUSE = COMPUTE_WH
COMMENT = 'Champion per-interval aggregated statistics, averaged across all ranks and patches in the dataset.
KNOWN LIMITATION: very few matches reach later minutes (minute 35-40+).'
AS

WITH PLAYER_INTERVAL_CHAMPION AS (
    SELECT
        PS.CHAMPION,
        PIV.MINUTE,
        -- Stats
        PIV.LEVEL,
        PIV.KILLS,
        PIV.DEATHS,
        PIV.ASSISTS,
        (PIV.CS + PIV.JUNGLE_CS) AS CS,
        PIV.TOTAL_GOLD
    FROM SILVER.PLAYER_INTERVAL_SILVER AS PIV
    JOIN SILVER.PLAYERS_SUMMARY_SILVER AS PS
        ON PS.MATCH_ID = PIV.MATCH_ID
        AND PS.PARTICIPANT_POS_ID = PIV.PARTICIPANT_POS_ID
),

AGGS AS (
    SELECT
        CHAMPION,
        MINUTE,
        -- Context (sample size at this minute -- use to judge sample size aggregation)
        COUNT(*) AS ROWS_SAMPLED,
        -- Agg Stats 
        ROUND(AVG(LEVEL), 0) AS AVG_LEVEL,
        ROUND(AVG(KILLS), 2) AS AVG_CUMU_KILLS,
        ROUND(AVG(DEATHS), 2) AS AVG_CUMU_DEATHS,
        ROUND(AVG(ASSISTS), 2) AS AVG_CUMU_ASSISTS,
        ROUND(AVG(CS), 0) AS AVG_CUMU_CS,
        ROUND(AVG(TOTAL_GOLD), 0) AS AVG_CUMU_TOTAL_GOLD
    FROM PLAYER_INTERVAL_CHAMPION
    GROUP BY CHAMPION, MINUTE
)

SELECT *
FROM AGGS
ORDER BY CHAMPION, MINUTE
;

COMMENT ON COLUMN CHAMPION_INTERVALS.ROWS_SAMPLED IS
'Number of rows averaged into this row. Use to judge sample size.';
