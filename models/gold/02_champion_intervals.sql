USE SCHEMA GOLD;
-------------------------------------------------------------------------------------------
    -- KNOWN LIMITATIONS:
    --     a. Later intervals have very few matches as not all games go to late games (40+ minutes)
    --     so make sure to double check ROWS_SAMPLED and use your discretion!
-------------------------------------------------------------------------------------------
CREATE OR REPLACE DYNAMIC TABLE GOLD.CHAMPION_INTERVALS
TARGET_LAG = '1 day'
WAREHOUSE = COMPUTE_WH
REFRESH_MODE = FULL
COMMENT = 'Champion per-interval aggregated statistics, averaged across all ranks and patches.'
AS
-------------------------------------------------------------------------------------------
    -- CHAMPION_INTERVALS: Champion-minute grain. Aggregated performance of champions over time.
-------------------------------------------------------------------------------------------
WITH PLAYER_INTERVAL_CHAMPION AS (
    SELECT
        PS.CHAMPION_NAME,
        PIV.MINUTE,
        PIV.LEVEL,
        PIV.KILLS,
        PIV.DEATHS,
        PIV.ASSISTS,
        (PIV.CS + PIV.JUNGLE_CS) AS CS,
        PIV.TOTAL_GOLD
    FROM SILVER.INTERVALS AS PIV
    JOIN SILVER.PLAYERS AS PS
        ON PS.MATCH_ID = PIV.MATCH_ID
        AND PS.PARTICIPANT_POS_ID = PIV.PARTICIPANT_POS_ID
),

AGGS AS (
    SELECT
        CHAMPION_NAME,
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
    GROUP BY CHAMPION_NAME, MINUTE
)
-------------------------------------------------------------------------------------------
    -- Select all above for complete query (Verify and test results here as well)
-------------------------------------------------------------------------------------------
SELECT * FROM AGGS;
-------------------------------------------------------------------------------------------
    -- Column-specific comments
-------------------------------------------------------------------------------------------
COMMENT ON COLUMN GOLD.CHAMPION_INTERVALS.CHAMPION_NAME IS
'Champion these stats are aggregated for.'
;
COMMENT ON COLUMN GOLD.CHAMPION_INTERVALS.MINUTE IS
'Minute mark of this snapshot, in 5-minute intervals.'
;
COMMENT ON COLUMN GOLD.CHAMPION_INTERVALS.ROWS_SAMPLED IS
'Number of rows averaged into this row. Use to judge sample size.'
;
COMMENT ON COLUMN GOLD.CHAMPION_INTERVALS.AVG_LEVEL IS
'Average champion level across all sampled rows at this minute mark.'
;
COMMENT ON COLUMN GOLD.CHAMPION_INTERVALS.AVG_CUMU_KILLS IS
'Average cumulative kills across all sampled rows at this minute mark.'
;
COMMENT ON COLUMN GOLD.CHAMPION_INTERVALS.AVG_CUMU_DEATHS IS
'Average cumulative deaths across all sampled rows at this minute mark.'
;
COMMENT ON COLUMN GOLD.CHAMPION_INTERVALS.AVG_CUMU_ASSISTS IS
'Average cumulative assists across all sampled rows at this minute mark.'
;
COMMENT ON COLUMN GOLD.CHAMPION_INTERVALS.AVG_CUMU_CS IS
'Average cumulative combined lane + jungle creep score across all sampled rows at this minute mark.'
;
COMMENT ON COLUMN GOLD.CHAMPION_INTERVALS.AVG_CUMU_TOTAL_GOLD IS
'Average cumulative gold earned across all sampled rows at this minute mark.'
;
