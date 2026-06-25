USE SCHEMA GOLD;
-------------------------------------------------------------------------------------------
    -- DESIGN NOTES:
    --     WINNING_GOLD_DIFF reports the gold differential of whichever team won, so it's always
    --     framed as "the winner's gold lead" rather than "blue's gold lead." A winning team
    --     that was at a gold loss will report negative WINNING_GOLD_DIFF.
-------------------------------------------------------------------------------------------
CREATE OR REPLACE DYNAMIC TABLE GOLD.MATCH_TEAM_STATS_SUMMARY
TARGET_LAG = '1 day'
WAREHOUSE = COMPUTE_WH
COMMENT = 'Match-grain summary with team statistics.'
AS
-------------------------------------------------------------------------------------------
    -- 01. TEAM_FINAL -> PIVOT_TEAM_STATS
    --     Capture team stats only at last snapshot interval and pivot them for wide view.
-------------------------------------------------------------------------------------------
WITH TEAM_FINAL AS (
    SELECT 
        MATCH_ID,
        TEAM,
        MINUTE,
        TEAM_KILLS,
        TEAM_TOWERS,
        TEAM_DRAGONS,
        TEAM_VOID_GRUBS,
        TEAM_HERALDS,
        TEAM_BARONS,
        TEAM_GOLD_DIFF
    FROM SILVER.TEAM_INTERVAL_SILVER
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY MATCH_ID, TEAM
        ORDER BY MINUTE DESC
    ) = 1
),

PIVOT_TEAM_STATS AS (
    SELECT MATCH_ID,
        MAX(MINUTE) AS LAST_LOGGED_MINUTE,
        MAX(CASE WHEN TEAM = 'Blue' THEN TEAM_KILLS END) AS BLUE_KILLS,
        MAX(CASE WHEN TEAM = 'Red' THEN TEAM_KILLS END) AS RED_KILLS,
        MAX(CASE WHEN TEAM = 'Blue' THEN TEAM_TOWERS END) AS BLUE_TOWERS,
        MAX(CASE WHEN TEAM = 'Red' THEN TEAM_TOWERS END) AS RED_TOWERS,
        MAX(CASE WHEN TEAM = 'Blue' THEN TEAM_DRAGONS END) AS BLUE_DRAGONS,
        MAX(CASE WHEN TEAM = 'Red' THEN TEAM_DRAGONS END) AS RED_DRAGONS,
        MAX(CASE WHEN TEAM = 'Blue' THEN TEAM_VOID_GRUBS END) AS BLUE_VOID_GRUBS,
        MAX(CASE WHEN TEAM = 'Red' THEN TEAM_VOID_GRUBS END) AS RED_VOID_GRUBS,
        MAX(CASE WHEN TEAM = 'Blue' THEN TEAM_HERALDS END) AS BLUE_HERALDS,
        MAX(CASE WHEN TEAM = 'Red' THEN TEAM_HERALDS END) AS RED_HERALDS,
        MAX(CASE WHEN TEAM = 'Blue' THEN TEAM_BARONS END) AS BLUE_BARONS,
        MAX(CASE WHEN TEAM = 'Red' THEN TEAM_BARONS END) AS RED_BARONS,
        MAX(CASE WHEN TEAM = 'Blue' THEN TEAM_GOLD_DIFF END) AS BLUE_GOLD_DIFF,
        MAX(CASE WHEN TEAM = 'Red' THEN TEAM_GOLD_DIFF END) AS RED_GOLD_DIFF
    FROM TEAM_FINAL
    GROUP BY MATCH_ID
),
-------------------------------------------------------------------------------------------
    -- 02. MATCH_STATS_SUMMARY_CTE
-------------------------------------------------------------------------------------------
MATCH_STATS_SUMMARY_CTE AS (
    SELECT 
        -- Primary key
        P.MATCH_ID,
        -- Context
        M.GAME_DURATION,
        M.GAME_DATE,
        M.WINNING_TEAM,
        M.AVERAGE_RANK,
        -- Stats
        P.BLUE_KILLS,
        P.RED_KILLS,
        P.BLUE_TOWERS,
        P.RED_TOWERS,
        P.BLUE_DRAGONS,
        P.RED_DRAGONS,
        P.BLUE_VOID_GRUBS,
        P.RED_VOID_GRUBS,
        P.BLUE_HERALDS,
        P.RED_HERALDS,
        P.BLUE_BARONS,
        P.RED_BARONS,
        -- Gold diff of the winning team only
        CASE 
            WHEN M.WINNING_TEAM = 'Blue' THEN P.BLUE_GOLD_DIFF
            WHEN M.WINNING_TEAM = 'Red'  THEN P.RED_GOLD_DIFF
        END AS WINNING_GOLD_DIFF,
        GREATEST(M.GAME_DURATION - P.LAST_LOGGED_MINUTE * 60, 0) AS UNLOGGED_DURATION
    FROM PIVOT_TEAM_STATS AS P
    JOIN SILVER.MATCHES_SUMMARY_SILVER AS M
        ON P.MATCH_ID = M.MATCH_ID
)
-------------------------------------------------------------------------------------------
    -- Select all above for complete query (Verify and test results here as well)
-------------------------------------------------------------------------------------------
SELECT * FROM MATCH_STATS_SUMMARY_CTE;
-------------------------------------------------------------------------------------------
    -- Column-specific comments
-------------------------------------------------------------------------------------------
COMMENT ON COLUMN GOLD.MATCH_TEAM_STATS_SUMMARY.UNLOGGED_DURATION IS
'Seconds between the last logged 5-minute interval and actual match end (GAME_DURATION). Inform how stale BLUE_*/RED_* stats can be for this row.'
;

COMMENT ON COLUMN GOLD.MATCH_TEAM_STATS_SUMMARY.WINNING_GOLD_DIFF IS
'Gold differential of the WINNING_TEAM specifically. A winning team at a gold loss reports a negative value.'
;