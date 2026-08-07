USE SCHEMA GOLD;
-------------------------------------------------------------------------------------------
    -- KNOWN LIMITATIONS:
    --     a. "End of match" stats (KILLS/DEATHS/ASSISTS/CS/TOTAL_GOLD/ITEM_BUILD/LEVEL) reflect
    --     the LAST LOGGED INTERVAL, not the literal game-end state. Source data is sampled
    --     every 5 minutes, so up to ~4-5 minutes of unrecorded state (item purchases, kills,
    --     gold gain) may be missing between last logged interval and actual end time.
    --     b. UNLOGGED_DURATION is added as a column to inform end users how stale each record can be,
    --
    -- FUTURE IMPROVEMENTS:
    --     If/when an end-of-match participant snapshot becomes available from the data source
    --     (separate from the timeline/interval endpoint), prefer that for final build and
    --     final KDA/gold specifically, and keep interval data only for time-series analysis.
-------------------------------------------------------------------------------------------
CREATE OR REPLACE DYNAMIC TABLE GOLD.MATCHEND_PLAYER_STATS
TARGET_LAG = '1 day'
WAREHOUSE = COMPUTE_WH
REFRESH_MODE = FULL
COMMENT = 'One end game player stat per (MATCH_ID, PARTICIPANT_POS_ID).'
AS
-------------------------------------------------------------------------------------------
    -- 01. FINAL_SNAPSHOT -> MATCH_STATS_AT_END
    --     Pull only the last interval snapshot as a player's pseudo end-game result.
-------------------------------------------------------------------------------------------
WITH FINAL_SNAPSHOT AS (
    SELECT *
    FROM SILVER.INTERVALS
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY MATCH_ID, PARTICIPANT_POS_ID
        ORDER BY MINUTE DESC
    ) = 1
),

MATCH_STATS_AT_END AS (
    SELECT
        MATCH_ID,
        PARTICIPANT_POS_ID,
        MINUTE,
        LEVEL,
        KILLS,
        DEATHS,
        ASSISTS,
        (CS + JUNGLE_CS) AS CS,
        TOTAL_GOLD
    FROM FINAL_SNAPSHOT
),
-------------------------------------------------------------------------------------------
    -- 02. ITEM_ID_ARRAY -> FLATTENED_ITEM_IDS -> NAMED_ITEM_BUILD
-------------------------------------------------------------------------------------------
ITEM_ID_ARRAY AS (
    SELECT
        MATCH_ID,
        PARTICIPANT_POS_ID,
        ARRAY_CONSTRUCT_COMPACT(
            ITEM_0, ITEM_1, ITEM_2, ITEM_3, ITEM_4, ITEM_5, ITEM_6
        ) AS ITEM_IDS
    FROM FINAL_SNAPSHOT
),

FLATTENED_ITEM_IDS AS (
    SELECT
        IA.MATCH_ID,
        IA.PARTICIPANT_POS_ID,
        ITEM.VALUE::INT AS ITEM_ID
    FROM ITEM_ID_ARRAY AS IA
    CROSS JOIN LATERAL FLATTEN(INPUT => IA.ITEM_IDS) AS ITEM
),

NAMED_ITEM_BUILD AS (
    SELECT
        FI.MATCH_ID,
        FI.PARTICIPANT_POS_ID,
        ARRAY_SORT(
            ARRAY_COMPACT(ARRAY_AGG(IR.ITEM_NAME))
        ) AS ITEM_BUILD
    FROM FLATTENED_ITEM_IDS AS FI
    LEFT JOIN SILVER.ITEMS_REF AS IR
        ON IR.ITEM_ID = FI.ITEM_ID
    GROUP BY FI.MATCH_ID, FI.PARTICIPANT_POS_ID
),
-------------------------------------------------------------------------------------------
    -- 03. WITH_PLAYER_SUMMARY
    --     Join interval snapshot with matches summary, player summary, and the
    --     resolved item-name build array.
    --     (e.g. derive Win/Lose, Champion Name, Champion Role)
-------------------------------------------------------------------------------------------
WITH_PLAYER_SUMMARY AS (
    SELECT
        -- Composite key
        SE.MATCH_ID,
        SE.PARTICIPANT_POS_ID,
        -- Context
        MAT.GAME_DURATION AS GAME_DURATION,
        -- Filter
        PS.TEAM,
        (PS.TEAM = MAT.WINNING_TEAM) AS WIN,
        PS.CHAMPION_NAME,
        PS.CHAMPION_ROLE,
        -- Stats
        SE.LEVEL,
        SE.KILLS,
        SE.DEATHS,
        SE.ASSISTS,
        SE.CS,
        SE.TOTAL_GOLD,
        -- Build
        NB.ITEM_BUILD,
        -- Unlogged duration for record quality check
        GREATEST(MAT.GAME_DURATION - SE.MINUTE * 60, 0) AS UNLOGGED_DURATION
    FROM MATCH_STATS_AT_END AS SE
    JOIN SILVER.MATCHES AS MAT
        ON MAT.MATCH_ID = SE.MATCH_ID
    JOIN SILVER.PLAYERS AS PS
        ON PS.MATCH_ID = SE.MATCH_ID
        AND PS.PARTICIPANT_POS_ID = SE.PARTICIPANT_POS_ID
    LEFT JOIN NAMED_ITEM_BUILD AS NB
        ON NB.MATCH_ID = SE.MATCH_ID
        AND NB.PARTICIPANT_POS_ID = SE.PARTICIPANT_POS_ID
)

SELECT * FROM WITH_PLAYER_SUMMARY;
-------------------------------------------------------------------------------------------
    -- Column-specific comments
-------------------------------------------------------------------------------------------
COMMENT ON COLUMN GOLD.MATCHEND_PLAYER_STATS.PARTICIPANT_POS_ID IS
'The index position of the player at queue time. 1-5 for BLUE side, 6-10 for RED side.'
;
COMMENT ON COLUMN GOLD.MATCHEND_PLAYER_STATS.GAME_DURATION IS
'Match duration in seconds.'
;
COMMENT ON COLUMN GOLD.MATCHEND_PLAYER_STATS.TEAM IS
'BLUE or RED.'
;
COMMENT ON COLUMN GOLD.MATCHEND_PLAYER_STATS.WIN IS
'Whether this player''s team won the match.'
;
COMMENT ON COLUMN GOLD.MATCHEND_PLAYER_STATS.CHAMPION_NAME IS
'Champion played.'
;
COMMENT ON COLUMN GOLD.MATCHEND_PLAYER_STATS.CHAMPION_ROLE IS
'Resolved role played, based on in-game signals.'
;
COMMENT ON COLUMN GOLD.MATCHEND_PLAYER_STATS.LEVEL IS
'End-of-match champion level.'
;
COMMENT ON COLUMN GOLD.MATCHEND_PLAYER_STATS.KILLS IS
'End-of-match kills.'
;
COMMENT ON COLUMN GOLD.MATCHEND_PLAYER_STATS.DEATHS IS
'End-of-match deaths.'
;
COMMENT ON COLUMN GOLD.MATCHEND_PLAYER_STATS.ASSISTS IS
'End-of-match assists.'
;
COMMENT ON COLUMN GOLD.MATCHEND_PLAYER_STATS.CS IS
'End-of-match combined lane + jungle creep score.'
;
COMMENT ON COLUMN GOLD.MATCHEND_PLAYER_STATS.TOTAL_GOLD IS
'End-of-match cumulative gold earned.'
;
COMMENT ON COLUMN GOLD.MATCHEND_PLAYER_STATS.ITEM_BUILD IS
'End-of-match sorted item names.'
;
COMMENT ON COLUMN GOLD.MATCHEND_PLAYER_STATS.UNLOGGED_DURATION IS
'Seconds between this player''s last logged 5-minute interval and actual match end (GAME_DURATION). Inform how stale each record can be.'
;
