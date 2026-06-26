-------------------------------------------------------------------------------------------
-- GOLD DATA-QUALITY ASSERTIONS
-- Runs all checks against the 5 GOLD dynamic tables and reports PASS/FAIL per check.
--
-- HOW-TO-USE:
--     01. Hit 'Run All' to run the full script from top to bottom.
--     OUTPUT -> (final result): summary grid — one row per check.

--     02. Within the same session, if you want to drill down on specific records, uncomment 
--     and query the temp tables _DQ_FAILURES (must be queried in the same session)
--     OUTPUT -> (drill-down): _DQ_FAILURES temp table holds every offending key with a reason. 

-- CHECKS:
--     1 Existence 
--     2 Record uniqueness
--     3 Missing records from parents (orphaned rows)
--     4 Champions name linked to refs
--     5 Logical values
--     6 Win-rate plausibility
--     7 Refresh state

-- FUTURE CHECKS:
--     1. Cross validations between TABLES
--     2. Balance anomalies (Detect any mysterious anomalous gameplay values e.g. item usage rate over 99%)
-------------------------------------------------------------------------------------------
USE WAREHOUSE COMPUTE_WH;

USE DATABASE LEAGUE_RECORDS;

CREATE OR REPLACE TEMPORARY TABLE _DQ_FAILURES (
    CHECK_ID      INT,
    CHECK_NAME    STRING,
    SEVERITY      STRING,
    MODEL         STRING,
    OFFENDING_KEY STRING,   -- key to investigate (composite keys joined with '|')
    DETAIL        STRING     -- human-readable reason / observed values
);
-------------------------------------------------------------------------------------------
-- CHECK 1 — Existence of data
-- Simple check ensuring at least 50 rows of records per table to confirm existence of data.
-------------------------------------------------------------------------------------------
INSERT INTO _DQ_FAILURES
SELECT 
    1, 
    'Existence of data', 
    'HARD', 
    T.MODEL,
    T.MODEL,
    'row_count=' || T.N || ' < floor=50'
FROM (
    SELECT 
        'PLAYER_STATS_SUMMARY' AS MODEL, 
        COUNT(*) AS N 
    FROM GOLD.PLAYER_STATS_SUMMARY
        UNION ALL 
    SELECT 'CHAMPION_INTERVALS', COUNT(*) FROM GOLD.CHAMPION_INTERVALS
        UNION ALL 
    SELECT 'CHAMPION_OVERVIEW', COUNT(*) FROM GOLD.CHAMPION_OVERVIEW
        UNION ALL 
    SELECT 'MATCH_TEAM_STATS_SUMMARY', COUNT(*) FROM GOLD.MATCH_TEAM_STATS_SUMMARY
        UNION ALL 
    SELECT 'ITEM_STATS_AND_RECOMMENDATIONS', COUNT(*) FROM GOLD.ITEM_STATS_AND_RECOMMENDATIONS
) AS T
WHERE T.N < 50;
-------------------------------------------------------------------------------------------
-- CHECK 2 — Record uniqueness
-- Ensure one row per composite key
-------------------------------------------------------------------------------------------
INSERT INTO _DQ_FAILURES
SELECT 2, 'Grain uniqueness', 'HARD', 'PLAYER_STATS_SUMMARY',
       MATCH_ID || '|' || PARTICIPANT_POS_ID, 'duplicate_rows=' || COUNT(*)
FROM GOLD.PLAYER_STATS_SUMMARY
GROUP BY MATCH_ID, PARTICIPANT_POS_ID 
HAVING COUNT(*) > 1;

INSERT INTO _DQ_FAILURES
SELECT 2, 'Grain uniqueness', 'HARD', 'CHAMPION_INTERVALS',
       CHAMPION || '|' || MINUTE, 'duplicate_rows=' || COUNT(*)
FROM GOLD.CHAMPION_INTERVALS
GROUP BY CHAMPION, MINUTE 
HAVING COUNT(*) > 1;

INSERT INTO _DQ_FAILURES
SELECT 2, 'Grain uniqueness', 'HARD', 'CHAMPION_OVERVIEW',
       TO_VARCHAR(CHAMPION_ID), 'duplicate_rows=' || COUNT(*)
FROM GOLD.CHAMPION_OVERVIEW
GROUP BY CHAMPION_ID 
HAVING COUNT(*) > 1;

INSERT INTO _DQ_FAILURES
SELECT 2, 'Grain uniqueness', 'HARD', 'MATCH_TEAM_STATS_SUMMARY',
       TO_VARCHAR(MATCH_ID), 'duplicate_rows=' || COUNT(*)
FROM GOLD.MATCH_TEAM_STATS_SUMMARY
GROUP BY MATCH_ID 
HAVING COUNT(*) > 1;

INSERT INTO _DQ_FAILURES
SELECT 2, 'Grain uniqueness', 'HARD', 'ITEM_STATS_AND_RECOMMENDATIONS',
       CHAMPION || '|' || ITEM, 'duplicate_rows=' || COUNT(*)
FROM GOLD.ITEM_STATS_AND_RECOMMENDATIONS
GROUP BY CHAMPION, ITEM 
HAVING COUNT(*) > 1;
-------------------------------------------------------------------------------------------
-- CHECK 3 — Coverage vs silver parent (two-sided: drops + orphans)
--   M1 should be row-identical to PLAYERS_SUMMARY_SILVER on (MATCH_ID, PARTICIPANT_POS_ID).
--   M4 should cover every MATCH_ID in MATCHES_SUMMARY_SILVER.
-------------------------------------------------------------------------------------------
-- M1: in players_silver, missing from gold (player had no interval snapshot to carry)
INSERT INTO _DQ_FAILURES
SELECT 3, 'Coverage vs silver parent', 'HARD', 'PLAYER_STATS_SUMMARY',
       s.MATCH_ID || '|' || s.PARTICIPANT_POS_ID, 'missing_from_gold (no interval snapshot?)'
FROM SILVER.PLAYERS_SUMMARY_SILVER s
LEFT JOIN GOLD.PLAYER_STATS_SUMMARY g
       ON g.MATCH_ID = s.MATCH_ID AND g.PARTICIPANT_POS_ID = s.PARTICIPANT_POS_ID
WHERE g.MATCH_ID IS NULL;

-- M1: in gold, no players_silver parent (orphan / key drift)
INSERT INTO _DQ_FAILURES
SELECT 3, 'Coverage vs silver parent', 'HARD', 'PLAYER_STATS_SUMMARY',
       g.MATCH_ID || '|' || g.PARTICIPANT_POS_ID, 'orphan_in_gold (no players_silver parent)'
FROM GOLD.PLAYER_STATS_SUMMARY g
LEFT JOIN SILVER.PLAYERS_SUMMARY_SILVER s
       ON s.MATCH_ID = g.MATCH_ID AND s.PARTICIPANT_POS_ID = g.PARTICIPANT_POS_ID
WHERE s.MATCH_ID IS NULL;

-- M4: in matches_silver, missing from gold (match had no team-interval rows)
INSERT INTO _DQ_FAILURES
SELECT 3, 'Coverage vs silver parent', 'HARD', 'MATCH_TEAM_STATS_SUMMARY',
       TO_VARCHAR(m.MATCH_ID), 'missing_from_gold (no team interval rows?)'
FROM SILVER.MATCHES_SUMMARY_SILVER m
LEFT JOIN GOLD.MATCH_TEAM_STATS_SUMMARY g ON g.MATCH_ID = m.MATCH_ID
WHERE g.MATCH_ID IS NULL;

-- M4: in gold, no matches_silver parent (orphan)
INSERT INTO _DQ_FAILURES
SELECT 3, 'Coverage vs silver parent', 'HARD', 'MATCH_TEAM_STATS_SUMMARY',
       TO_VARCHAR(g.MATCH_ID), 'orphan_in_gold (no matches_silver parent)'
FROM GOLD.MATCH_TEAM_STATS_SUMMARY g
LEFT JOIN SILVER.MATCHES_SUMMARY_SILVER m ON m.MATCH_ID = g.MATCH_ID
WHERE m.MATCH_ID IS NULL;

-------------------------------------------------------------------------------------------
-- CHECK 4 — Champion name resolves to CHAMPIONS_REF_SILVER
--   Scope M1/M2/M5: these carry raw PS.CHAMPION with no normalization CASE.
--   (M3 sources its champion from the ref directly, so it always resolves — excluded.)
-------------------------------------------------------------------------------------------
INSERT INTO _DQ_FAILURES
SELECT 
    4, 
    'Champion name resolves to ref', 
    'HARD',
    M.MODEL,
    M.CHAMPION,
    'unresolved champion name'
FROM (
    SELECT DISTINCT 'PLAYER_STATS_SUMMARY' AS MODEL, CHAMPION FROM GOLD.PLAYER_STATS_SUMMARY
        UNION ALL 
    SELECT DISTINCT 'CHAMPION_INTERVALS', CHAMPION FROM GOLD.CHAMPION_INTERVALS
        UNION ALL 
    SELECT DISTINCT 'ITEM_STATS_AND_RECOMMENDATIONS', CHAMPION FROM GOLD.ITEM_STATS_AND_RECOMMENDATIONS
) AS M
LEFT JOIN SILVER.CHAMPIONS_REF_SILVER AS R 
    ON R.CHAMPION_NAME = M.CHAMPION
WHERE R.CHAMPION_NAME IS NULL;
-------------------------------------------------------------------------------------------
-- 05. CHECK FOR LOGICAL VALUES
-- No negative values where it shouldn't be, no malformed, giant values...
-------------------------------------------------------------------------------------------
-- GOLD.PLAYER_STATS_SUMMARY
INSERT INTO _DQ_FAILURES
SELECT 5, 'Domain bounds', 'HARD', 'PLAYER_STATS_SUMMARY',
       MATCH_ID || '|' || PARTICIPANT_POS_ID,
       'level=' || LEVEL || 
       ' k=' || KILLS || 
       ' d=' || DEATHS || 
       ' a=' || ASSISTS || 
       ' cs=' || CS || 
       ' gold=' || TOTAL_GOLD || 
       ' team=' || COALESCE(TEAM,'<null>')
FROM GOLD.PLAYER_STATS_SUMMARY
WHERE LEVEL NOT BETWEEN 1 AND 20
   OR LEAST(KILLS, DEATHS, ASSISTS, CS, TOTAL_GOLD) < 0
   OR UNLOGGED_DURATION < 0
   OR TEAM NOT IN ('Blue', 'Red');

-- GOLD.CHAMPION_INTERVALS
INSERT INTO _DQ_FAILURES
SELECT 5, 'Domain bounds', 'HARD', 'CHAMPION_INTERVALS',
       CHAMPION || '|' || MINUTE,
       'avg_level=' || AVG_LEVEL || ' rows_sampled=' || ROWS_SAMPLED || ' minute=' || MINUTE
FROM GOLD.CHAMPION_INTERVALS
WHERE AVG_LEVEL NOT BETWEEN 1 AND 18
   OR LEAST(AVG_CUMU_KILLS, AVG_CUMU_DEATHS, AVG_CUMU_ASSISTS, AVG_CUMU_CS, AVG_CUMU_TOTAL_GOLD) < 0
   OR ROWS_SAMPLED < 1
   OR MINUTE < 0;

-- M3  (NULL win rate is legitimate: champion with no win-eligible games — not flagged)
INSERT INTO _DQ_FAILURES
SELECT 5, 'Domain bounds', 'HARD', 'CHAMPION_OVERVIEW',
       TO_VARCHAR(CHAMPION_ID),
       'pick=' || GLOBAL_PICK_RATE || ' win=' || COALESCE(TO_VARCHAR(GLOBAL_WIN_RATE),'<null>')
       || ' ban=' || GLOBAL_BAN_RATE || ' lane_share=' || PRIMARY_LANE_SHARE
FROM GOLD.CHAMPION_OVERVIEW
WHERE GLOBAL_WIN_RATE   NOT BETWEEN 0 AND 1   -- NULL passes (UNKNOWN), intended
   OR GLOBAL_BAN_RATE   NOT BETWEEN 0 AND 1
   OR PRIMARY_LANE_SHARE NOT BETWEEN 0 AND 1
   OR GLOBAL_PICK_RATE < 0                     -- pick rate may exceed 1 by design; only floor it
   OR GLOBAL_GAMES_PLAYED < 0;

-- M4  (WINNING_GOLD_DIFF may be negative by design — not bounded.
--       BLUE_*/RED_* must be present and non-negative.)
INSERT INTO _DQ_FAILURES
SELECT 5, 'Domain bounds', 'HARD', 'MATCH_TEAM_STATS_SUMMARY',
       TO_VARCHAR(MATCH_ID),
       'winning_team=' || COALESCE(WINNING_TEAM,'<null>')
       || ' blue_kills=' || COALESCE(TO_VARCHAR(BLUE_KILLS),'<null>')
       || ' red_kills='  || COALESCE(TO_VARCHAR(RED_KILLS),'<null>')
FROM GOLD.MATCH_TEAM_STATS_SUMMARY
WHERE WINNING_TEAM NOT IN ('Blue', 'Red')
   OR GAME_DURATION < 0
   OR UNLOGGED_DURATION < 0
   OR BLUE_KILLS IS NULL OR RED_KILLS IS NULL
   OR BLUE_TOWERS IS NULL OR RED_TOWERS IS NULL
   OR BLUE_DRAGONS IS NULL OR RED_DRAGONS IS NULL
   OR BLUE_VOID_GRUBS IS NULL OR RED_VOID_GRUBS IS NULL
   OR BLUE_HERALDS IS NULL OR RED_HERALDS IS NULL
   OR BLUE_BARONS IS NULL OR RED_BARONS IS NULL
   OR LEAST(BLUE_KILLS, RED_KILLS, BLUE_TOWERS, RED_TOWERS, BLUE_DRAGONS, RED_DRAGONS,
            BLUE_VOID_GRUBS, RED_VOID_GRUBS, BLUE_HERALDS, RED_HERALDS, BLUE_BARONS, RED_BARONS) < 0;

-- M5  (MOST_COMMON_FIRST_PURCHASE_MINUTE nullable — NULL passes the >= 0 floor)
INSERT INTO _DQ_FAILURES
SELECT 5, 'Domain bounds', 'HARD', 'ITEM_STATS_AND_RECOMMENDATIONS',
       CHAMPION || '|' || ITEM,
       'purchase_rate=' || PLAYER_PURCHASE_RATE || ' win=' || WIN_RATE || ' kda=' || AVG_KDA
FROM GOLD.ITEM_STATS_AND_RECOMMENDATIONS
WHERE PLAYER_PURCHASE_RATE NOT BETWEEN 0 AND 1
   OR WIN_RATE NOT BETWEEN 0 AND 1
   OR AVG_KDA < 0
   OR MOST_COMMON_FIRST_PURCHASE_MINUTE < 0;

-------------------------------------------------------------------------------------------
-- CHECK 6 — Win-rate plausibility band [0.40, 0.60] among adequately-sampled champions
--   LoL champion win rates realistically sit ~40-60%. Outside that, with enough games,
--   usually signals a join/denominator bug rather than real signal.  (M5 deferred — see header.)
-------------------------------------------------------------------------------------------
INSERT INTO _DQ_FAILURES
SELECT 6, 'Win-rate plausibility 0.40-0.60 (n>=30)', 'WARN', 'CHAMPION_OVERVIEW',
       TO_VARCHAR(CHAMPION_ID),
       'win_rate=' || GLOBAL_WIN_RATE || ' games=' || GLOBAL_GAMES_PLAYED
FROM GOLD.CHAMPION_OVERVIEW
WHERE GLOBAL_WIN_RATE IS NOT NULL
  AND GLOBAL_GAMES_PLAYED >= 30
  AND GLOBAL_WIN_RATE NOT BETWEEN 0.40 AND 0.60;

-------------------------------------------------------------------------------------------
-- CHECK 7 — Global win balance ~0.5 (every match has exactly one winning team of 5)
-------------------------------------------------------------------------------------------
INSERT INTO _DQ_FAILURES
SELECT 7, 'Global win balance ~0.5', 'WARN', 'PLAYER_STATS_SUMMARY',
       'GLOBAL', 'avg_win=' || TO_VARCHAR(ROUND(W, 4)) || ' (expected 0.48-0.52)'
FROM (
    SELECT AVG(CASE WHEN WIN THEN 1.0 WHEN NOT WIN THEN 0.0 END) AS W
    FROM GOLD.PLAYER_STATS_SUMMARY
)
WHERE W NOT BETWEEN 0.48 AND 0.52;

-------------------------------------------------------------------------------------------
-- CHECK 8 — Refresh state = SUCCEEDED (state-only; manual mock pipeline, no lag check)
--   Flags the latest refresh per table if it ended in a failure state.
--   (A table that has never refreshed yields no history row and won't appear — acceptable
--    for a freshly-deployed mock pipeline.)
-------------------------------------------------------------------------------------------
INSERT INTO _DQ_FAILURES
SELECT 8, 'Refresh state = SUCCEEDED', 'WARN', MODEL, MODEL, 'last_state=' || STATE
FROM (
    SELECT 'PLAYER_STATS_SUMMARY' AS MODEL, STATE
    FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY(NAME => 'LEAGUE_RECORDS.GOLD.PLAYER_STATS_SUMMARY'))
    QUALIFY ROW_NUMBER() OVER (ORDER BY REFRESH_START_TIME DESC NULLS LAST) = 1
    UNION ALL
    SELECT 'CHAMPION_INTERVALS', STATE
    FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY(NAME => 'LEAGUE_RECORDS.GOLD.CHAMPION_INTERVALS'))
    QUALIFY ROW_NUMBER() OVER (ORDER BY REFRESH_START_TIME DESC NULLS LAST) = 1
    UNION ALL
    SELECT 'CHAMPION_OVERVIEW', STATE
    FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY(NAME => 'LEAGUE_RECORDS.GOLD.CHAMPION_OVERVIEW'))
    QUALIFY ROW_NUMBER() OVER (ORDER BY REFRESH_START_TIME DESC NULLS LAST) = 1
    UNION ALL
    SELECT 'MATCH_TEAM_STATS_SUMMARY', STATE
    FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY(NAME => 'LEAGUE_RECORDS.GOLD.MATCH_TEAM_STATS_SUMMARY'))
    QUALIFY ROW_NUMBER() OVER (ORDER BY REFRESH_START_TIME DESC NULLS LAST) = 1
    UNION ALL
    SELECT 'ITEM_STATS_AND_RECOMMENDATIONS', STATE
    FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY(NAME => 'LEAGUE_RECORDS.GOLD.ITEM_STATS_AND_RECOMMENDATIONS'))
    QUALIFY ROW_NUMBER() OVER (ORDER BY REFRESH_START_TIME DESC NULLS LAST) = 1
)
WHERE STATE NOT IN ('SUCCEEDED');
-------------------------------------------------------------------------------------------
-- REPORT — summary grid (one row per check) + OVERALL verdict row.  This is the
-- definitive PASS/FAIL output. Offending keys live in _DQ_FAILURES (see header).
-------------------------------------------------------------------------------------------
WITH CHECK_DEFS AS (
    SELECT * FROM VALUES
        (1, 'Existence / non-empty floor',            'HARD', 'all 5'),
        (2, 'Grain uniqueness',                       'HARD', 'all 5'),
        (3, 'Coverage vs silver parent',              'HARD', 'M1, M4'),
        (4, 'Champion name resolves to ref',          'HARD', 'M1, M2, M5'),
        (5, 'Domain bounds',                          'HARD', 'all 5'),
        (6, 'Win-rate plausibility 0.40-0.60 (n>=30)','WARN', 'M3'),
        (7, 'Global win balance ~0.5',                'WARN', 'M1'),
        (8, 'Refresh state = SUCCEEDED',              'WARN', 'all 5'),
        (9, 'Pick-rate sums to ~10 (bonus)',          'WARN', 'M3')
    AS T(CHECK_ID, CHECK_NAME, SEVERITY, SCOPE)
),
FAIL_COUNTS AS (
    SELECT CHECK_ID, COUNT(*) AS N FROM _DQ_FAILURES GROUP BY CHECK_ID
),
FAIL_SAMPLE AS (
    SELECT CHECK_ID,
           LISTAGG(MODEL || ':' || OFFENDING_KEY, '  |  ')
               WITHIN GROUP (ORDER BY MODEL, OFFENDING_KEY) AS SAMPLE_OFFENDERS
    FROM (
        SELECT CHECK_ID, MODEL, OFFENDING_KEY
        FROM _DQ_FAILURES
        QUALIFY ROW_NUMBER() OVER (PARTITION BY CHECK_ID ORDER BY MODEL, OFFENDING_KEY) <= 5
    )
    GROUP BY CHECK_ID
),
GRID AS (
    SELECT
        d.CHECK_ID,
        d.CHECK_NAME,
        d.SEVERITY,
        d.SCOPE,
        IFF(COALESCE(c.N, 0) = 0, 'PASS', 'FAIL') AS STATUS,
        COALESCE(c.N, 0)                          AS N_FAILURES,
        s.SAMPLE_OFFENDERS
    FROM CHECK_DEFS d
    LEFT JOIN FAIL_COUNTS  c ON c.CHECK_ID = d.CHECK_ID
    LEFT JOIN FAIL_SAMPLE  s ON s.CHECK_ID = d.CHECK_ID
)

SELECT CHECK_ID, CHECK_NAME, SEVERITY, SCOPE, STATUS, N_FAILURES, SAMPLE_OFFENDERS
FROM GRID
UNION ALL
SELECT
    99 AS CHECK_ID,
    IFF(SUM(IFF(STATUS = 'FAIL' AND SEVERITY = 'HARD', 1, 0)) = 0,
        'OVERALL: PASS (no HARD failures)',
        'OVERALL: HARD FAIL — investigate _DQ_FAILURES') AS CHECK_NAME,
    '' AS SEVERITY,
    '' AS SCOPE,
    IFF(SUM(IFF(STATUS = 'FAIL' AND SEVERITY = 'HARD', 1, 0)) = 0, 'PASS', 'FAIL') AS STATUS,
    SUM(IFF(STATUS = 'FAIL', 1, 0)) AS N_FAILURES,
    'HARD_fails=' || SUM(IFF(STATUS = 'FAIL' AND SEVERITY = 'HARD', 1, 0))
        || '  WARN_fails=' || SUM(IFF(STATUS = 'FAIL' AND SEVERITY = 'WARN', 1, 0)) AS SAMPLE_OFFENDERS
FROM GRID
ORDER BY CHECK_ID;

-------------------------------------------------------------------------------------------
-- DRILL-DOWN (run after the script, same session):
-------------------------------------------------------------------------------------------
WITH MISSING_MATCHES AS (
    SELECT DISTINCT SUBSTRING(OFFENDING_KEY, 1, 15) AS MATCH_ID
    FROM _DQ_FAILURES 
    WHERE CHECK_ID = 3
)

SELECT *
FROM BRONZE.MATCH_INTERVALS_BRONZE AS SS
JOIN MISSING_MATCHES AS MM
    ON MM.MATCH_ID = SS.MATCH_ID
;
