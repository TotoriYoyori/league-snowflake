-------------------------------------------------------------------------------------------
-- GOLD DATA QUALITY ASSERTIONS
-- Runs all checks against the 5 GOLD dynamic tables.
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
--     7 Global win balance
--     8 Refresh state

-- FUTURE CHECKS:
--     1. Cross validations between TABLES
--     2. Balance anomalies (Detect any mysterious anomalous gameplay values e.g. item usage rate over 99%)
-------------------------------------------------------------------------------------------
USE WAREHOUSE COMPUTE_WH;

USE DATABASE LEAGUE_RECORDS;

CREATE OR REPLACE TEMPORARY TABLE _DQ_FAILURES (
    CHECK_ID      INT,
    CHECK_NAME    STRING,
    MODEL         STRING,
    OFFENDING_KEY STRING,   -- key to investigate (composite keys denoted with '|')
    DETAIL        STRING    -- reason / observed values
)
;
-------------------------------------------------------------------------------------------
-- CHECK 1 — Existence
-- Simple check ensuring at least 50 rows of records per table
-------------------------------------------------------------------------------------------
INSERT INTO _DQ_FAILURES
SELECT
    1,
    'Existence',
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
WHERE T.N < 50
;

-------------------------------------------------------------------------------------------
-- CHECK 2 — Record uniqueness
-- Ensure one row per composite key
-------------------------------------------------------------------------------------------
INSERT INTO _DQ_FAILURES
SELECT
    2,
    'Record uniqueness',
    'PLAYER_STATS_SUMMARY',
    MATCH_ID || '|' || PARTICIPANT_POS_ID,
    'duplicate_rows=' || COUNT(*)
FROM GOLD.PLAYER_STATS_SUMMARY
GROUP BY MATCH_ID, PARTICIPANT_POS_ID
HAVING COUNT(*) > 1
;

INSERT INTO _DQ_FAILURES
SELECT
    2,
    'Record uniqueness',
    'CHAMPION_INTERVALS',
    CHAMPION || '|' || MINUTE,
    'duplicate_rows=' || COUNT(*)
FROM GOLD.CHAMPION_INTERVALS
GROUP BY CHAMPION, MINUTE
HAVING COUNT(*) > 1
;

INSERT INTO _DQ_FAILURES
SELECT
    2,
    'Record uniqueness',
    'CHAMPION_OVERVIEW',
    TO_VARCHAR(CHAMPION_ID),
    'duplicate_rows=' || COUNT(*)
FROM GOLD.CHAMPION_OVERVIEW
GROUP BY CHAMPION_ID
HAVING COUNT(*) > 1
;

INSERT INTO _DQ_FAILURES
SELECT
    2,
    'Record uniqueness',
    'MATCH_TEAM_STATS_SUMMARY',
    TO_VARCHAR(MATCH_ID),
    'duplicate_rows=' || COUNT(*)
FROM GOLD.MATCH_TEAM_STATS_SUMMARY
GROUP BY MATCH_ID
HAVING COUNT(*) > 1
;

INSERT INTO _DQ_FAILURES
SELECT
    2,
    'Record uniqueness',
    'ITEM_STATS_AND_RECOMMENDATIONS',
    CHAMPION || '|' || ITEM,
    'duplicate_rows=' || COUNT(*)
FROM GOLD.ITEM_STATS_AND_RECOMMENDATIONS
GROUP BY CHAMPION, ITEM
HAVING COUNT(*) > 1
;

-------------------------------------------------------------------------------------------
-- CHECK 3 — Missing records from parents (orphaned rows)
--   Two-sided coverage for the two match-grain models that must equal their silver parent:
--     M1 PLAYER_STATS_SUMMARY      <-> PLAYERS_SUMMARY_SILVER  (MATCH_ID, PARTICIPANT_POS_ID)
--     M4 MATCH_TEAM_STATS_SUMMARY  <-> MATCHES_SUMMARY_SILVER  (MATCH_ID)
--   Champion/item reference coverage is handled by CHECK 4; CHAMPION_OVERVIEW is ref-driven
--   by construction, so it needs no coverage check here.
-------------------------------------------------------------------------------------------
-- PLAYER_STATS_SUMMARY: in players_silver, missing from gold (player had no interval snapshot to carry)
INSERT INTO _DQ_FAILURES
SELECT
    3,
    'Missing records from parents (orphaned rows)',
    'PLAYER_STATS_SUMMARY',
    S.MATCH_ID || '|' || S.PARTICIPANT_POS_ID,
    'missing_from_gold (no interval snapshot?)'
FROM SILVER.PLAYERS_SUMMARY_SILVER AS S
LEFT JOIN GOLD.PLAYER_STATS_SUMMARY AS G
    ON G.MATCH_ID = S.MATCH_ID
    AND G.PARTICIPANT_POS_ID = S.PARTICIPANT_POS_ID
WHERE G.MATCH_ID IS NULL
;

-- PLAYER_STATS_SUMMARY: in gold, no players_silver parent (orphan / key drift)
INSERT INTO _DQ_FAILURES
SELECT
    3,
    'Missing records from parents (orphaned rows)',
    'PLAYER_STATS_SUMMARY',
    G.MATCH_ID || '|' || G.PARTICIPANT_POS_ID,
    'orphan_in_gold (no players_silver parent)'
FROM GOLD.PLAYER_STATS_SUMMARY AS G
LEFT JOIN SILVER.PLAYERS_SUMMARY_SILVER AS S
    ON S.MATCH_ID = G.MATCH_ID
    AND S.PARTICIPANT_POS_ID = G.PARTICIPANT_POS_ID
WHERE S.MATCH_ID IS NULL
;

-- MATCH_TEAM_STATS_SUMMARY: in matches_silver, missing from gold (match had no team-interval rows)
INSERT INTO _DQ_FAILURES
SELECT
    3,
    'Missing records from parents (orphaned rows)',
    'MATCH_TEAM_STATS_SUMMARY',
    TO_VARCHAR(M.MATCH_ID),
    'missing_from_gold (no team interval rows?)'
FROM SILVER.MATCHES_SUMMARY_SILVER AS M
LEFT JOIN GOLD.MATCH_TEAM_STATS_SUMMARY AS G
    ON G.MATCH_ID = M.MATCH_ID
WHERE G.MATCH_ID IS NULL
;

-- MATCH_TEAM_STATS_SUMMARY: in gold, no matches_silver parent (orphan)
INSERT INTO _DQ_FAILURES
SELECT
    3,
    'Missing records from parents (orphaned rows)',
    'MATCH_TEAM_STATS_SUMMARY',
    TO_VARCHAR(G.MATCH_ID),
    'orphan_in_gold (no matches_silver parent)'
FROM GOLD.MATCH_TEAM_STATS_SUMMARY AS G
LEFT JOIN SILVER.MATCHES_SUMMARY_SILVER AS M
    ON M.MATCH_ID = G.MATCH_ID
WHERE M.MATCH_ID IS NULL
;

-------------------------------------------------------------------------------------------
-- CHECK 4 — Champions name linked to refs
--   Scope M1/M2/M5: these carry raw PS.CHAMPION with no normalization CASE.
--   (M3 sources its champion from the ref directly, so it always resolves — excluded.)
-------------------------------------------------------------------------------------------
INSERT INTO _DQ_FAILURES
SELECT
    4,
    'Champions name linked to refs',
    M.MODEL,
    M.CHAMPION,
    'unresolved champion name'
FROM (
    SELECT DISTINCT 'PLAYER_STATS_SUMMARY' AS MODEL, CHAMPION 
    FROM GOLD.PLAYER_STATS_SUMMARY
        UNION ALL
    SELECT DISTINCT 'CHAMPION_INTERVALS', CHAMPION 
    FROM GOLD.CHAMPION_INTERVALS
        UNION ALL
    SELECT DISTINCT 'ITEM_STATS_AND_RECOMMENDATIONS', CHAMPION 
    FROM GOLD.ITEM_STATS_AND_RECOMMENDATIONS
) AS M
LEFT JOIN SILVER.CHAMPIONS_REF_SILVER AS R
    ON R.CHAMPION_NAME = M.CHAMPION
WHERE R.CHAMPION_NAME IS NULL
;

-------------------------------------------------------------------------------------------
-- CHECK 5 — Logical values
-- No negative values where it shouldn't be, no malformed, giant values...
-------------------------------------------------------------------------------------------
-- GOLD.PLAYER_STATS_SUMMARY
INSERT INTO _DQ_FAILURES
SELECT
    5,
    'Logical values',
    'PLAYER_STATS_SUMMARY',
    MATCH_ID || '|' || PARTICIPANT_POS_ID,
    'level=' || LEVEL ||
    ' k=' || KILLS ||
    ' d=' || DEATHS ||
    ' a=' || ASSISTS ||
    ' cs=' || CS ||
    ' gold=' || TOTAL_GOLD ||
    ' team=' || COALESCE(TEAM, '<null>')
FROM GOLD.PLAYER_STATS_SUMMARY
WHERE LEVEL NOT BETWEEN 1 AND 20
   OR LEAST(KILLS, DEATHS, ASSISTS, CS, TOTAL_GOLD) < 0
   OR UNLOGGED_DURATION < 0
   OR TEAM NOT IN ('Blue', 'Red')
;

-- GOLD.CHAMPION_INTERVALS
INSERT INTO _DQ_FAILURES
SELECT
    5,
    'Logical values',
    'CHAMPION_INTERVALS',
    CHAMPION || '|' || MINUTE,
    'avg_level=' || AVG_LEVEL || ' rows_sampled=' || ROWS_SAMPLED || ' minute=' || MINUTE
FROM GOLD.CHAMPION_INTERVALS
WHERE AVG_LEVEL NOT BETWEEN 1 AND 20
   OR LEAST(AVG_CUMU_KILLS, AVG_CUMU_DEATHS, AVG_CUMU_ASSISTS, AVG_CUMU_CS, AVG_CUMU_TOTAL_GOLD) < 0
   OR ROWS_SAMPLED < 1
   OR MINUTE < 0
;

-- GOLD.CHAMPION_OVERVIEW
INSERT INTO _DQ_FAILURES
SELECT
    5,
    'Logical values',
    'CHAMPION_OVERVIEW',
    TO_VARCHAR(CHAMPION_ID),
    'pick=' || GLOBAL_PICK_RATE || ' win=' || COALESCE(TO_VARCHAR(GLOBAL_WIN_RATE), '<null>')
    || ' ban=' || GLOBAL_BAN_RATE || ' lane_share=' || PRIMARY_LANE_SHARE
FROM GOLD.CHAMPION_OVERVIEW
WHERE GLOBAL_WIN_RATE NOT BETWEEN 0 AND 1   -- NULL passes (UNKNOWN), intended
   OR GLOBAL_BAN_RATE NOT BETWEEN 0 AND 1
   OR PRIMARY_LANE_SHARE NOT BETWEEN 0 AND 1
   OR GLOBAL_PICK_RATE NOT BETWEEN 0 AND 1                  
   OR GLOBAL_GAMES_PLAYED < 0
;

-- GOLD.MATCH_TEAM_STATS_SUMMARY 
INSERT INTO _DQ_FAILURES
SELECT
    5,
    'Logical values',
    'MATCH_TEAM_STATS_SUMMARY',
    TO_VARCHAR(MATCH_ID),
    'winning_team=' || COALESCE(WINNING_TEAM, '<null>')
    || ' blue_kills=' || COALESCE(TO_VARCHAR(BLUE_KILLS), '<null>')
    || ' red_kills='  || COALESCE(TO_VARCHAR(RED_KILLS), '<null>')
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
            BLUE_VOID_GRUBS, RED_VOID_GRUBS, BLUE_HERALDS, RED_HERALDS, BLUE_BARONS, RED_BARONS) < 0
;

-- GOLD.ITEM_STATS_AND_RECOMMENDATION
INSERT INTO _DQ_FAILURES
SELECT
    5,
    'Logical values',
    'ITEM_STATS_AND_RECOMMENDATIONS',
    CHAMPION || '|' || ITEM,
    'purchase_rate=' || PLAYER_PURCHASE_RATE || ' win=' || WIN_RATE || ' kda=' || AVG_KDA
FROM GOLD.ITEM_STATS_AND_RECOMMENDATIONS
WHERE PLAYER_PURCHASE_RATE NOT BETWEEN 0 AND 1
   OR WIN_RATE NOT BETWEEN 0 AND 1
   OR AVG_KDA < 0
   OR MOST_COMMON_FIRST_PURCHASE_MINUTE < 0
   OR TOP_ITEM_1 = TOP_ITEM_2
   OR TOP_ITEM_2 = TOP_ITEM_3
   OR TOP_ITEM_1 = TOP_ITEM_3
;
-------------------------------------------------------------------------------------------
-- CHECK 6 — Win-rate plausibility
--   Per champion: realistic win rates sit ~40-60%. Outside that, with enough games,
--   usually signals a join/denominator bug rather than real signal.
-------------------------------------------------------------------------------------------
INSERT INTO _DQ_FAILURES
SELECT
    6,
    'Win-rate plausibility',
    'CHAMPION_OVERVIEW',
    TO_VARCHAR(CHAMPION_ID),
    'win_rate=' || GLOBAL_WIN_RATE || ' games=' || GLOBAL_GAMES_PLAYED
FROM GOLD.CHAMPION_OVERVIEW
WHERE GLOBAL_WIN_RATE IS NOT NULL
  AND GLOBAL_GAMES_PLAYED >= 30
  AND GLOBAL_WIN_RATE NOT BETWEEN 0.40 AND 0.60;

-------------------------------------------------------------------------------------------
-- CHECK 7 — Global win balance ~0.5
--   Every match has one winning team of 5, so the overall win rate must sit ~0.5.
--   Drift here is a stakeholder-visible red flag (broken WIN derivation).
-------------------------------------------------------------------------------------------
INSERT INTO _DQ_FAILURES
SELECT
    7,
    'Global win balance',
    'PLAYER_STATS_SUMMARY',
    'GLOBAL',
    'avg_win=' || TO_VARCHAR(ROUND(W, 4)) || ' (expected 0.48-0.52)'
FROM (
    SELECT AVG(CASE WHEN WIN THEN 1.0 WHEN NOT WIN THEN 0.0 END) AS W
    FROM GOLD.PLAYER_STATS_SUMMARY
)
WHERE W NOT BETWEEN 0.48 AND 0.52
;

-------------------------------------------------------------------------------------------
-- CHECK 8 — Refresh state = SUCCEEDED (state-only; manual mock pipeline, no lag check)
--   Flags the latest refresh per table if it ended in a failure state.
-------------------------------------------------------------------------------------------
INSERT INTO _DQ_FAILURES
SELECT
    8,
    'Refresh state',
    MODEL,
    MODEL,
    'last_state=' || STATE
FROM (
    SELECT 
        'PLAYER_STATS_SUMMARY' AS MODEL, 
        STATE
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
WHERE STATE NOT IN ('SUCCEEDED')
;

-------------------------------------------------------------------------------------------
-- REPORT — summary grid (one row per check)
-------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------
-- REPORT — summary grid (one row per check)
--   STATUS: PASS = clean. FAIL = pipeline defect (data is wrong).
--           REVIEW = data likely correct but unusual; worth a human look (balance outliers).
--   OVERALL keys off FAIL only — a REVIEW never turns the pipeline red.
-------------------------------------------------------------------------------------------
WITH CHECK_DEFS AS (
    SELECT * FROM VALUES
        (1, 'Existence',                                    'FAIL',   'all 5'),
        (2, 'Record uniqueness',                            'FAIL',   'all 5'),
        (3, 'Missing records from parents (orphaned rows)', 'FAIL',   'M1, M4'),
        (4, 'Champions name linked to refs',                'FAIL',   'M1, M2, M5'),
        (5, 'Logical values',                               'FAIL',   'all 5'),
        (6, 'Win-rate plausibility',                        'REVIEW', 'M3'),
        (7, 'Global win balance',                           'REVIEW', 'M1'),
        (8, 'Refresh state',                                'FAIL',   'all 5')
    AS T(CHECK_ID, CHECK_NAME, TRIP_STATUS, SCOPE)
),

FAIL_COUNTS AS (
    SELECT CHECK_ID, COUNT(*) AS N
    FROM _DQ_FAILURES
    GROUP BY CHECK_ID
),

FAIL_SAMPLE AS (
    SELECT
        CHECK_ID,
        LISTAGG(MODEL || ':' || OFFENDING_KEY, '  |  ')
            WITHIN GROUP (ORDER BY MODEL, OFFENDING_KEY) AS SAMPLE_OFFENDERS
    FROM (
        SELECT CHECK_ID, MODEL, OFFENDING_KEY
        FROM _DQ_FAILURES
        QUALIFY ROW_NUMBER() OVER (
            PARTITION BY CHECK_ID
            ORDER BY MODEL, OFFENDING_KEY
        ) <= 5
    )
    GROUP BY CHECK_ID
),

GRID AS (
    SELECT
        D.CHECK_ID,
        D.CHECK_NAME,
        D.SCOPE,
        -- Clean -> PASS. Tripped -> FAIL for defects, REVIEW for plausibility flags.
        CASE
            WHEN COALESCE(C.N, 0) = 0 THEN 'PASS'
            ELSE D.TRIP_STATUS
        END AS STATUS,
        COALESCE(C.N, 0) AS N_FAILURES,
        S.SAMPLE_OFFENDERS
    FROM CHECK_DEFS AS D
    LEFT JOIN FAIL_COUNTS AS C
        ON C.CHECK_ID = D.CHECK_ID
    LEFT JOIN FAIL_SAMPLE AS S
        ON S.CHECK_ID = D.CHECK_ID
)

SELECT
    CHECK_ID,
    CHECK_NAME,
    SCOPE,
    STATUS,
    N_FAILURES,
    SAMPLE_OFFENDERS
FROM GRID
    UNION ALL
SELECT
    99,
    IFF(
        SUM(IFF(STATUS = 'FAIL', 1, 0)) = 0,
        'OVERALL: PASS',
        'OVERALL: FAIL — investigate _DQ_FAILURES'
    ),
    '',
    IFF(
        SUM(IFF(STATUS = 'FAIL', 1, 0)) = 0,
        'PASS',
        'FAIL'
    ),
    SUM(IFF(STATUS = 'FAIL', 1, 0)),
    'FAILS=' || SUM(IFF(STATUS = 'FAIL', 1, 0))
        || '  REVIEWS=' || SUM(IFF(STATUS = 'REVIEW', 1, 0))
FROM GRID
ORDER BY CHECK_ID;

-------------------------------------------------------------------------------------------
-- DRILL-DOWN: Uncomment and run after the script, same session
-------------------------------------------------------------------------------------------
-- WITH MISSING_MATCHES AS (
--     SELECT DISTINCT SUBSTRING(OFFENDING_KEY, 1, 15) AS MATCH_ID
--     FROM _DQ_FAILURES
--     WHERE CHECK_ID = 3
-- )
-- SELECT *
-- FROM BRONZE.MATCH_INTERVALS_BRONZE AS SS
-- JOIN MISSING_MATCHES AS MM
--     ON MM.MATCH_ID = SS.MATCH_ID
-- ;
SELECT GC.*
FROM _DQ_FAILURES AS DQ
JOIN GOLD.CHAMPION_OVERVIEW AS GC
    ON GC.CHAMPION_ID = DQ.OFFENDING_KEY
WHERE CHECK_ID = 6
;
