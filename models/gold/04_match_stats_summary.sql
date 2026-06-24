USE DATABASE LEAGUE_RECORDS;
USE SCHEMA GOLD;
-------------------------------------------------------------------------------------------
-- MATCH_STATS_SUMMARY: Match-grain summary of final team stats and match context.
--
-- GRAIN: One row per MATCH_ID, including remakes/unfinished games. 
--
-- DESIGN NOTES:
-- 1. WINNING_GOLD_DIFF reports the gold differential of whichever team won, so it's always
--    framed as "the winner's gold lead" rather than "blue's gold lead." 
-------------------------------------------------------------------------------------------
CREATE OR REPLACE DYNAMIC TABLE MATCH_STATS_SUMMARY
TARGET_LAG = '5 minutes'
WAREHOUSE = COMPUTE_WH
COMMENT = 'Match-grain summary of final team stats (kills, towers, dragons, void grubs, heralds, barons, gold diff) 
and match context (duration, date, winner, average rank).'
AS

WITH TEAM_FINAL AS (
    SELECT 
        MATCH_ID,
        TEAM,
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
        -- Gold diff of the winning team only; NULL when WINNING_TEAM isn't 'Blue'/'Red'
        -- (e.g. an unresolved/remade match with no clean winner).
        CASE 
            WHEN M.WINNING_TEAM = 'Blue' THEN P.BLUE_GOLD_DIFF
            WHEN M.WINNING_TEAM = 'Red'  THEN P.RED_GOLD_DIFF
        END AS WINNING_GOLD_DIFF
    FROM PIVOT_TEAM_STATS AS P
    JOIN SILVER.MATCHES_SUMMARY_SILVER AS M
        ON P.MATCH_ID = M.MATCH_ID
)

SELECT *
FROM MATCH_STATS_SUMMARY_CTE
;

-- Column-level comments
COMMENT ON COLUMN MATCH_STATS_SUMMARY.WINNING_GOLD_DIFF IS
'Gold differential of the WINNING_TEAM specifically (not Blue''s gold diff) at the final recorded minute. NULL if WINNING_TEAM is not exactly Blue or Red.';
