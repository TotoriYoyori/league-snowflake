USE DATABASE LEAGUE_RECORDS;
USE SCHEMA GOLD;
-------------------------------------------------------------------------------------------
    -- PLAYER_STATS_BASE: Pure facts joined from source
    --
    -- GRAIN: One row per (MATCH_ID, PARTICIPANT_POS_ID) — i.e. one row per player per match.
    --
    -- KNOWN LIMITATIONS:
    -- 1. "End of match" stats (KILLS/DEATHS/ASSISTS/CS/TOTAL_GOLD/ITEM_BUILD/LEVEL) reflect
    --    the LAST LOGGED INTERVAL, not the literal game-end state. Source data is sampled
    --    every 5 minutes, so depending on when a match actually ended relative to the nearest
    --    5-minute checkpoint, up to ~4-5 minutes of late-game state (item purchases, kills,
    --    gold gain) may be missing. This is a source-data sampling limitation
    -- 2. ITEM_BUILD preserves duplicate items (e.g. 2x Control Ward, 2x Infinity Edge).DESC
    -- 3. ITEM_BUILD is ARRAY_SORT'ed alphabetically by item name.
    --
    -- FUTURE IMPROVEMENTS:
    -- - If/when an end-of-match participant snapshot becomes available from the data source
    --   (separate from the timeline/interval endpoint), prefer that for "final build" and
    --   final KDA/gold specifically, and keep interval data only for time-series analysis.
-------------------------------------------------------------------------------------------
CREATE OR REPLACE DYNAMIC TABLE GOLD.PLAYER_STATS_BASE
TARGET_LAG = '1 day'         
WAREHOUSE = COMPUTE_WH    
COMMENT = 'One end game player stat per (MATCH_ID, PARTICIPANT_POS_ID). 
KNOWN LIMITATION: end-of-match stats reflect the last logged 5-minute interval, 
not literal game-end state -- may undercount late-game item builds, kills, gold by up to ~5 minutes of unlogged activity.'
AS

WITH MATCH_STATS_AT_END AS (
    SELECT
        -- Composite key
        PIV.MATCH_ID,
        PIV.PARTICIPANT_POS_ID,
        -- Context
        PIV.MINUTE,
        -- Stats
        PIV.LEVEL,
        PIV.KILLS,
        PIV.DEATHS,
        PIV.ASSISTS,
        (PIV.CS + PIV.JUNGLE_CS) AS CS,
        PIV.TOTAL_GOLD,
        -- Build (A->Z sorted)
        ARRAY_SORT(ARRAY_CONSTRUCT_COMPACT(
            PIV.ITEM_0, PIV.ITEM_1, PIV.ITEM_2, PIV.ITEM_3,
            PIV.ITEM_4, PIV.ITEM_5, PIV.ITEM_6
        )) AS ITEM_BUILD
    FROM SILVER.PLAYER_INTERVAL_SILVER AS PIV
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY PIV.MATCH_ID, PIV.PARTICIPANT_POS_ID 
        ORDER BY PIV.MINUTE DESC
    ) = 1
),

WITH_PLAYER_SUMMARY AS (
    SELECT
        -- Composite key
        SE.MATCH_ID,
        SE.PARTICIPANT_POS_ID,
        -- Context
        SE.MINUTE AS LAST_LOGGED_MINUTE,
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
        SE.ITEM_BUILD
    FROM MATCH_STATS_AT_END AS SE
    JOIN SILVER.MATCHES_SUMMARY_SILVER AS MAT
        ON MAT.MATCH_ID = SE.MATCH_ID
    JOIN SILVER.PLAYERS_SUMMARY_SILVER AS PS
        ON PS.MATCH_ID = SE.MATCH_ID
        AND PS.PARTICIPANT_POS_ID = SE.PARTICIPANT_POS_ID
)
-------------------------------------------------------------------------------------------
-- Diagnostic only. Use to investigate the logging-gap
-- limitation described in the header notes for a specific match/player if needed.
-- DIAGNOSTIC_LAST_INTERVAL_GAP AS (
--     SELECT
--         SE.MATCH_ID,
--         SE.PARTICIPANT_POS_ID,
--         SE.MINUTE AS LAST_LOGGED_MINUTE,
--         MAT.GAME_DURATION,
--         ROUND(MAT.GAME_DURATION / 60.0, 1) AS GAME_DURATION_MINUTES,
--         ROUND(MAT.GAME_DURATION / 60.0, 1) - SE.MINUTE AS UNLOGGED_GAP_MINUTES
--     FROM MATCH_STATS_AT_END AS SE
--     JOIN SILVER.MATCHES_SUMMARY_SILVER AS MAT
--         ON MAT.MATCH_ID = SE.MATCH_ID
-- )

-- SELECT *
-- FROM DIAGNOSTIC_LAST_INTERVAL_GAP
-- ;
-------------------------------------------------------------------------------------------
SELECT *
FROM WITH_PLAYER_SUMMARY
;

COMMENT ON COLUMN PLAYER_STATS_BASE.ITEM_BUILD IS
'Final item build at last logged interval, alphabetically sorted. May appear incomplete near game end due to 5-minute logging granularity.'
;

COMMENT ON COLUMN PLAYER_STATS_BASE.WIN IS
'Denormalized from TEAM = WINNING_TEAM (joined from SILVER.MATCHES_SUMMARY_SILVER).'
;
