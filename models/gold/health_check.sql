-------------------------------------------------------------------------------------------
-- GOLD DATA QUALITY ASSERTIONS
-- Runs all checks against the 5 GOLD dynamic tables.
--
-- HOW-TO-USE:
--     01. Hit 'Run All' to run the full script from top to bottom.
--     OUTPUT -> (final result): summary grid one row per check.

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

-- SCOPE NOTE:
--     GOLD.DIFF_INTERVALS is intentionally NOT covered by these checks. It's just
--     SILVER.INTERVALS joined to SILVER.PLAYERS to attach team/lane/champion identity.
--     No aggregation or derived logic of its own, so it carries no independent data
--     quality risk beyond what the SILVER layer already guarantees.
-------------------------------------------------------------------------------------------
USE WAREHOUSE COMPUTE_WH;

USE DATABASE LEAGUE_RECORDS;

CREATE OR REPLACE TEMPORARY TABLE _DQ_FAILURES (
    CHECK_ID INT,
    CHECK_NAME VARCHAR,
    MODEL VARCHAR,
    OFFENDING_KEY VARCHAR, -- key to investigate (composite keys denoted with '|')
    DETAIL VARCHAR -- reason / observed values
)
;
-------------------------------------------------------------------------------------------
-- CHECK 1: Existence
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
        'MATCHEND_PLAYER_STATS' AS MODEL,
        COUNT(*) AS N
    FROM GOLD.MATCHEND_PLAYER_STATS
        UNION ALL
    SELECT 'CHAMPION_INTERVALS', COUNT(*) FROM GOLD.CHAMPION_INTERVALS
        UNION ALL
    SELECT 'CHAMPION_OVERVIEWS', COUNT(*) FROM GOLD.CHAMPION_OVERVIEWS
        UNION ALL
    SELECT 'MATCHEND_PIVOT_TEAMSTATS', COUNT(*) FROM GOLD.MATCHEND_PIVOT_TEAMSTATS
        UNION ALL
    SELECT 'ITEM_RECOMMENDATIONS', COUNT(*) FROM GOLD.ITEM_RECOMMENDATIONS
) AS T
WHERE T.N < 50
;
-------------------------------------------------------------------------------------------
-- CHECK 2: Record uniqueness
-- Ensure one row per composite key
-------------------------------------------------------------------------------------------
INSERT INTO _DQ_FAILURES
SELECT
    2,
    'Record uniqueness',
    'MATCHEND_PLAYER_STATS',
    MATCH_ID || '|' || PARTICIPANT_POS_ID,
    'duplicate_rows=' || COUNT(*)
FROM GOLD.MATCHEND_PLAYER_STATS
GROUP BY MATCH_ID, PARTICIPANT_POS_ID
HAVING COUNT(*) > 1
;

INSERT INTO _DQ_FAILURES
SELECT
    2,
    'Record uniqueness',
    'CHAMPION_INTERVALS',
    CHAMPION_NAME || '|' || MINUTE,
    'duplicate_rows=' || COUNT(*)
FROM GOLD.CHAMPION_INTERVALS
GROUP BY CHAMPION_NAME, MINUTE
HAVING COUNT(*) > 1
;

INSERT INTO _DQ_FAILURES
SELECT
    2,
    'Record uniqueness',
    'CHAMPION_OVERVIEWS',
    TO_VARCHAR(CHAMPION_ID),
    'duplicate_rows=' || COUNT(*)
FROM GOLD.CHAMPION_OVERVIEWS
GROUP BY CHAMPION_ID
HAVING COUNT(*) > 1
;

INSERT INTO _DQ_FAILURES
SELECT
    2,
    'Record uniqueness',
    'MATCHEND_PIVOT_TEAMSTATS',
    TO_VARCHAR(MATCH_ID),
    'duplicate_rows=' || COUNT(*)
FROM GOLD.MATCHEND_PIVOT_TEAMSTATS
GROUP BY MATCH_ID
HAVING COUNT(*) > 1
;

INSERT INTO _DQ_FAILURES
SELECT
    2,
    'Record uniqueness',
    'ITEM_RECOMMENDATIONS',
    CHAMPION_NAME || '|' || ITEM_NAME,
    'duplicate_rows=' || COUNT(*)
FROM GOLD.ITEM_RECOMMENDATIONS
GROUP BY CHAMPION_NAME, ITEM_NAME
HAVING COUNT(*) > 1
;
-------------------------------------------------------------------------------------------
-- CHECK 3: Missing records from parents (orphaned rows)
--     The following two gold models that must equal their silver parent:
--     M1 GOLD.MATCHEND_PLAYER_STATS  <-> SILVER.PLAYERS (MATCH_ID, PARTICIPANT_POS_ID)
--     M4 GOLD.MATCHEND_PIVOT_TEAMSTATS  <-> SILVER.MATCHES (MATCH_ID)
-------------------------------------------------------------------------------------------
-- MATCHEND_PLAYER_STATS: in players_silver, missing from gold (player had no interval snapshot to carry)
INSERT INTO _DQ_FAILURES
SELECT
    3,
    'Missing records from parents (orphaned rows)',
    'MATCHEND_PLAYER_STATS',
    S.MATCH_ID || '|' || S.PARTICIPANT_POS_ID,
    'missing_from_gold (no interval snapshot?)'
FROM SILVER.PLAYERS AS S
LEFT JOIN GOLD.MATCHEND_PLAYER_STATS AS G
    ON G.MATCH_ID = S.MATCH_ID
    AND G.PARTICIPANT_POS_ID = S.PARTICIPANT_POS_ID
WHERE G.MATCH_ID IS NULL
;

-- MATCHEND_PLAYER_STATS: in gold, no players_silver parent (orphan / key drift)
INSERT INTO _DQ_FAILURES
SELECT
    3,
    'Missing records from parents (orphaned rows)',
    'MATCHEND_PLAYER_STATS',
    G.MATCH_ID || '|' || G.PARTICIPANT_POS_ID,
    'orphan_in_gold (no players_silver parent)'
FROM GOLD.MATCHEND_PLAYER_STATS AS G
LEFT JOIN SILVER.PLAYERS AS S
    ON S.MATCH_ID = G.MATCH_ID
    AND S.PARTICIPANT_POS_ID = G.PARTICIPANT_POS_ID
WHERE S.MATCH_ID IS NULL
;

-- MATCHEND_PIVOT_TEAMSTATS: in matches_silver, missing from gold (match had no team-interval rows)
INSERT INTO _DQ_FAILURES
SELECT
    3,
    'Missing records from parents (orphaned rows)',
    'MATCHEND_PIVOT_TEAMSTATS',
    TO_VARCHAR(M.MATCH_ID),
    'missing_from_gold (no team interval rows?)'
FROM SILVER.MATCHES AS M
LEFT JOIN GOLD.MATCHEND_PIVOT_TEAMSTATS AS G
    ON G.MATCH_ID = M.MATCH_ID
WHERE G.MATCH_ID IS NULL
;

-- MATCHEND_PIVOT_TEAMSTATS: in gold, no matches_silver parent (orphan)
INSERT INTO _DQ_FAILURES
SELECT
    3,
    'Missing records from parents (orphaned rows)',
    'MATCHEND_PIVOT_TEAMSTATS',
    TO_VARCHAR(G.MATCH_ID),
    'orphan_in_gold (no matches_silver parent)'
FROM GOLD.MATCHEND_PIVOT_TEAMSTATS AS G
LEFT JOIN SILVER.MATCHES AS M
    ON M.MATCH_ID = G.MATCH_ID
WHERE M.MATCH_ID IS NULL
;

-------------------------------------------------------------------------------------------
-- CHECK 4: Champions name linked to refs
--     Scope M1/M2/M5: these carry raw PS.CHAMPION_NAME with no normalization CASE.
--     (M3 sources its champion from the ref directly, so it always resolves — excluded.)
-------------------------------------------------------------------------------------------
INSERT INTO _DQ_FAILURES
SELECT
    4,
    'Champions name linked to refs',
    M.MODEL,
    M.CHAMPION_NAME,
    'unresolved champion name'
FROM (
    SELECT DISTINCT 'MATCHEND_PLAYER_STATS' AS MODEL, CHAMPION_NAME
    FROM GOLD.MATCHEND_PLAYER_STATS
        UNION ALL
    SELECT DISTINCT 'CHAMPION_INTERVALS', CHAMPION_NAME
    FROM GOLD.CHAMPION_INTERVALS
        UNION ALL
    SELECT DISTINCT 'ITEM_RECOMMENDATIONS', CHAMPION_NAME
    FROM GOLD.ITEM_RECOMMENDATIONS
) AS M
LEFT JOIN SILVER.CHAMPIONS_REF AS R
    ON R.CHAMPION_NAME = M.CHAMPION_NAME
WHERE R.CHAMPION_NAME IS NULL
;

-------------------------------------------------------------------------------------------
-- CHECK 5: Logical values
--     No negative values where it shouldn't be, no malformed, giant values...
-------------------------------------------------------------------------------------------
-- GOLD.MATCHEND_PLAYER_STATS
INSERT INTO _DQ_FAILURES
SELECT
    5,
    'Logical values',
    'MATCHEND_PLAYER_STATS',
    MATCH_ID || '|' || PARTICIPANT_POS_ID,
    'level=' || LEVEL ||
    ' k=' || KILLS ||
    ' d=' || DEATHS ||
    ' a=' || ASSISTS ||
    ' cs=' || CS ||
    ' gold=' || TOTAL_GOLD ||
    ' team=' || COALESCE(TEAM, '<null>')
FROM GOLD.MATCHEND_PLAYER_STATS
WHERE LEVEL NOT BETWEEN 1 AND 20
    OR LEAST(KILLS, DEATHS, ASSISTS, CS, TOTAL_GOLD) < 0
    OR UNLOGGED_DURATION < 0
    OR TEAM NOT IN ('BLUE', 'RED')
;

-- GOLD.CHAMPION_INTERVALS
INSERT INTO _DQ_FAILURES
SELECT
    5,
    'Logical values',
    'CHAMPION_INTERVALS',
    CHAMPION_NAME || '|' || MINUTE,
    'avg_level=' || AVG_LEVEL || ' rows_sampled=' || ROWS_SAMPLED || ' minute=' || MINUTE
FROM GOLD.CHAMPION_INTERVALS
WHERE AVG_LEVEL NOT BETWEEN 1 AND 20
    OR LEAST(AVG_CUMU_KILLS, AVG_CUMU_DEATHS, AVG_CUMU_ASSISTS, AVG_CUMU_CS, AVG_CUMU_TOTAL_GOLD) < 0
    OR ROWS_SAMPLED < 1
    OR MINUTE < 0
;

-- GOLD.CHAMPION_OVERVIEWS
INSERT INTO _DQ_FAILURES
SELECT
    5,
    'Logical values',
    'CHAMPION_OVERVIEWS',
    TO_VARCHAR(CHAMPION_ID),
    'pick=' || GLOBAL_PICK_RATE || ' win=' || COALESCE(TO_VARCHAR(GLOBAL_WIN_RATE), '<null>')
    || ' ban=' || GLOBAL_BAN_RATE || ' lane_share=' || PRIMARY_LANE_SHARE
FROM GOLD.CHAMPION_OVERVIEWS
WHERE GLOBAL_WIN_RATE NOT BETWEEN 0 AND 1
    OR GLOBAL_BAN_RATE NOT BETWEEN 0 AND 1
    OR PRIMARY_LANE_SHARE NOT BETWEEN 0 AND 1
    OR GLOBAL_PICK_RATE NOT BETWEEN 0 AND 1
    OR GLOBAL_GAMES_PLAYED < 0
;

-- GOLD.MATCHEND_PIVOT_TEAMSTATS 
INSERT INTO _DQ_FAILURES
SELECT
    5,
    'Logical values',
    'MATCHEND_PIVOT_TEAMSTATS',
    TO_VARCHAR(MATCH_ID),
    'winning_team=' || COALESCE(WINNING_TEAM, '<null>')
    || ' blue_kills=' || COALESCE(TO_VARCHAR(BLUE_KILLS), '<null>')
    || ' red_kills='  || COALESCE(TO_VARCHAR(RED_KILLS), '<null>')
FROM GOLD.MATCHEND_PIVOT_TEAMSTATS
WHERE WINNING_TEAM NOT IN ('BLUE', 'RED')
    OR GAME_DURATION < 0
    OR UNLOGGED_DURATION < 0
    OR BLUE_KILLS IS NULL OR RED_KILLS IS NULL
    OR BLUE_TOWERS IS NULL OR RED_TOWERS IS NULL
    OR BLUE_INHIBITORS IS NULL OR RED_INHIBITORS IS NULL
    OR BLUE_DRAGONS IS NULL OR RED_DRAGONS IS NULL
    OR BLUE_VOID_GRUBS IS NULL OR RED_VOID_GRUBS IS NULL
    OR BLUE_HERALDS IS NULL OR RED_HERALDS IS NULL
    OR BLUE_BARONS IS NULL OR RED_BARONS IS NULL
    OR LEAST(BLUE_KILLS, RED_KILLS, BLUE_TOWERS, RED_TOWERS, BLUE_INHIBITORS, RED_INHIBITORS,
            BLUE_DRAGONS, RED_DRAGONS, BLUE_VOID_GRUBS, RED_VOID_GRUBS, BLUE_HERALDS, RED_HERALDS,
            BLUE_BARONS, RED_BARONS) < 0
;

-- GOLD.ITEM_RECOMMENDATIONS
INSERT INTO _DQ_FAILURES
SELECT
    5,
    'Logical values',
    'ITEM_RECOMMENDATIONS',
    CHAMPION_NAME || '|' || ITEM_NAME,
    'purchase_rate=' || PLAYER_PURCHASE_RATE || ' win=' || WIN_RATE || ' kda=' || AVG_KDA
FROM GOLD.ITEM_RECOMMENDATIONS
WHERE PLAYER_PURCHASE_RATE NOT BETWEEN 0 AND 1
    OR WIN_RATE NOT BETWEEN 0 AND 1
    OR AVG_KDA < 0
    OR MOST_COMMON_FIRST_PURCHASE_MINUTE < 0
    OR TOP_ITEM_1 = TOP_ITEM_2
    OR TOP_ITEM_2 = TOP_ITEM_3
    OR TOP_ITEM_1 = TOP_ITEM_3
;
-------------------------------------------------------------------------------------------
-- CHECK 6: Win-rate plausibility
--     Per champion: realistic win rates sit ~40-60%. Outside that, with enough games,
--     usually signals a join/denominator bug rather than real signal.
-------------------------------------------------------------------------------------------
INSERT INTO _DQ_FAILURES
SELECT
    6,
    'Win-rate plausibility',
    'CHAMPION_OVERVIEWS',
    TO_VARCHAR(CHAMPION_ID),
    'win_rate=' || GLOBAL_WIN_RATE || ' games=' || GLOBAL_GAMES_PLAYED
FROM GOLD.CHAMPION_OVERVIEWS
WHERE GLOBAL_WIN_RATE IS NOT NULL
    AND GLOBAL_GAMES_PLAYED >= 30
    AND GLOBAL_WIN_RATE NOT BETWEEN 0.40 AND 0.60;

-------------------------------------------------------------------------------------------
-- CHECK 7: Global win balance ~0.5
--     Every match has one winning team of 5, so the overall win rate must sit ~0.5.
-------------------------------------------------------------------------------------------
INSERT INTO _DQ_FAILURES
SELECT
    7,
    'Global win balance',
    'MATCHEND_PLAYER_STATS',
    'GLOBAL',
    'avg_win=' || TO_VARCHAR(ROUND(W, 4)) || ' (expected 0.48-0.52)'
FROM (
    SELECT AVG(CASE WHEN WIN THEN 1.0 WHEN NOT WIN THEN 0.0 END) AS W
    FROM GOLD.MATCHEND_PLAYER_STATS
)
WHERE W NOT BETWEEN 0.48 AND 0.52
;
-------------------------------------------------------------------------------------------
-- CHECK 8: Refresh state = SUCCEEDED (state-only; manual mock pipeline, no lag check)
--     Flags the latest refresh per table if it ended in a failure state.
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
        'MATCHEND_PLAYER_STATS' AS MODEL, 
        STATE
    FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY(NAME => 'LEAGUE_RECORDS.GOLD.MATCHEND_PLAYER_STATS'))
    QUALIFY ROW_NUMBER() OVER (ORDER BY REFRESH_START_TIME DESC NULLS LAST) = 1
        UNION ALL
    SELECT 'CHAMPION_INTERVALS', STATE
    FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY(NAME => 'LEAGUE_RECORDS.GOLD.CHAMPION_INTERVALS'))
    QUALIFY ROW_NUMBER() OVER (ORDER BY REFRESH_START_TIME DESC NULLS LAST) = 1
        UNION ALL
    SELECT 'CHAMPION_OVERVIEWS', STATE
    FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY(NAME => 'LEAGUE_RECORDS.GOLD.CHAMPION_OVERVIEWS'))
    QUALIFY ROW_NUMBER() OVER (ORDER BY REFRESH_START_TIME DESC NULLS LAST) = 1
        UNION ALL
    SELECT 'MATCHEND_PIVOT_TEAMSTATS', STATE
    FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY(NAME => 'LEAGUE_RECORDS.GOLD.MATCHEND_PIVOT_TEAMSTATS'))
    QUALIFY ROW_NUMBER() OVER (ORDER BY REFRESH_START_TIME DESC NULLS LAST) = 1
        UNION ALL
    SELECT 'ITEM_RECOMMENDATIONS', STATE
    FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY(NAME => 'LEAGUE_RECORDS.GOLD.ITEM_RECOMMENDATIONS'))
    QUALIFY ROW_NUMBER() OVER (ORDER BY REFRESH_START_TIME DESC NULLS LAST) = 1
)
WHERE STATE NOT IN ('SUCCEEDED')
;
-------------------------------------------------------------------------------------------
-- REPORT: summary grid (one row per check)
--   STATUS: PASS = clean. FAIL = pipeline defect (data is wrong).
--           REVIEW = data likely correct but unusual; worth a human look (balance outliers).
--   OVERALL keys off FAIL only, a REVIEW never turns the pipeline red.
-------------------------------------------------------------------------------------------
WITH CHECK_DEFS AS (
    SELECT * FROM VALUES
        (1, 'Existence', 'FAIL', 'all 5'),
        (2, 'Record uniqueness', 'FAIL', 'all 5'),
        (3, 'Missing records from parents (orphaned rows)', 'FAIL', 'M1, M4'),
        (4, 'Champions name linked to refs', 'FAIL', 'M1, M2, M5'),
        (5, 'Logical values', 'FAIL', 'all 5'),
        (6, 'Win-rate plausibility', 'REVIEW', 'M3'),
        (7, 'Global win balance', 'REVIEW', 'M1'),
        (8, 'Refresh state', 'FAIL', 'all 5')
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
ORDER BY CHECK_ID
;
