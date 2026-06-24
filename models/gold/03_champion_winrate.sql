USE DATABASE LEAGUE_RECORDS;
USE SCHEMA GOLD;


-------------------------------------------------------------------------------------------
-- CHAMPION_OVERVIEW: Champion-level pick rate, win rate, ban rate, and primary lane
--
-- GRAIN: One row per champion in CHAMPIONS_REF_SILVER (excluding 'No Champion', id=0)
--
-- DESIGN NOTES:
--    1. Remakes (GAME_DURATION < 300s) are excluded.
-------------------------------------------------------------------------------------------
CREATE OR REPLACE DYNAMIC TABLE CHAMPION_OVERVIEW
TARGET_LAG = '1 day'
WAREHOUSE = COMPUTE_WH
COMMENT = 'Champion-level pick/win/ban rate and primary lane.'
AS
-- Exclude remake games from being treated as fair win resolve. 
WITH NO_REMAKE_MATCHES AS (
    SELECT *
    FROM SILVER.MATCHES_SUMMARY_SILVER
    WHERE GAME_DURATION >= 300
),

PLAYER_MATCH AS (
    SELECT
    -- Only naming inconsistency from source data
        CASE 
            WHEN PS.CHAMPION = 'Fiddle Sticks' THEN 'Fiddlesticks' 
            ELSE PS.CHAMPION 
        END AS CHAMPION,
        PS.LANE,
        (PS.TEAM = MAT.WINNING_TEAM) AS WIN
    FROM NO_REMAKE_MATCHES AS MAT
    JOIN SILVER.PLAYERS_SUMMARY_SILVER AS PS
        ON PS.MATCH_ID = MAT.MATCH_ID
    -- Excludes rows with no resolvable winner.
    WHERE (PS.TEAM = MAT.WINNING_TEAM) IS NOT NULL
),
-- Global pick/win counts per champion (across all lanes), keyed on name.
CHAMPION_GLOBAL_STATS AS (
    SELECT
        CHAMPION,
        COUNT(*) AS GLOBAL_GAMES_PLAYED,
        SUM(CASE WHEN WIN THEN 1 ELSE 0 END) AS WINS
    FROM PLAYER_MATCH
    GROUP BY CHAMPION
),
-- Most-played lane per champion + that lane's share of the champion's total picks.
-- The LANE tiebreaker is for when two lanes are exactly even.
PRIMARY_LANE AS (
    SELECT
        CHAMPION,
        LANE AS MOST_PICKED_LANE,
        ROUND(
            COUNT(*) / 
            SUM(COUNT(*)) OVER (PARTITION BY CHAMPION)::FLOAT
        , 4) AS PRIMARY_LANE_SHARE
    FROM PLAYER_MATCH
    GROUP BY CHAMPION, LANE
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY CHAMPION
        ORDER BY COUNT(*) DESC, LANE
    ) = 1
),

ALL_BANS AS (
    SELECT DISTINCT MATCH_ID, CHAMPION_ID
    FROM (
        SELECT
            MATCH_ID,
            BAN_ID.VALUE::NUMBER AS CHAMPION_ID
        FROM NO_REMAKE_MATCHES,
            LATERAL SPLIT_TO_TABLE(
            BLUE_BANS || ',' || RED_BANS
            , ',') AS BAN_ID
        WHERE BAN_ID.VALUE != '0'
    )
),

BAN_COUNTS AS (
    SELECT CHAMPION_ID, COUNT(*) AS GAMES_BANNED
    FROM ALL_BANS
    GROUP BY CHAMPION_ID
),

TOTAL_MATCHES AS (
    SELECT COUNT(*) AS TOTAL_GAMES
    FROM NO_REMAKE_MATCHES
),

CHAMPION_AGGS AS (
    SELECT
        -- Key
        CR.CHAMPION_ID,
        -- Descriptors
        CR.CHAMPION_NAME,
        PL.MOST_PICKED_LANE,
        PL.PRIMARY_LANE_SHARE,
        -- Global rates
        COALESCE(CGS.GLOBAL_GAMES_PLAYED, 0) AS GLOBAL_GAMES_PLAYED,
        ROUND(
            COALESCE(CGS.GLOBAL_GAMES_PLAYED, 0) / 
            TM.TOTAL_GAMES::FLOAT
        , 4) AS GLOBAL_PICK_RATE,
        ROUND(
            CGS.WINS / 
            CGS.GLOBAL_GAMES_PLAYED::FLOAT
        , 4) AS GLOBAL_WIN_RATE,
        ROUND(
            COALESCE(BC.GAMES_BANNED, 0) / 
            TM.TOTAL_GAMES::FLOAT
        , 4) AS GLOBAL_BAN_RATE
    FROM SILVER.CHAMPIONS_REF_SILVER AS CR
    LEFT JOIN CHAMPION_GLOBAL_STATS AS CGS
        ON CGS.CHAMPION = CR.CHAMPION_NAME
    LEFT JOIN PRIMARY_LANE AS PL
        ON PL.CHAMPION = CR.CHAMPION_NAME
    LEFT JOIN BAN_COUNTS AS BC
        ON BC.CHAMPION_ID = CR.CHAMPION_ID
    CROSS JOIN TOTAL_MATCHES AS TM
)
-- Exclude 'No Champions' (CHAMPION_ID = 0) from the final presentation
SELECT *
FROM CHAMPION_AGGS
WHERE CHAMPION_ID != 0 
;

COMMENT ON COLUMN CHAMPION_OVERVIEW.MOST_PICKED_LANE IS
'The lane this champion is most commonly played in.';

COMMENT ON COLUMN CHAMPION_OVERVIEW.PRIMARY_LANE_SHARE IS
'Share of this champions total picks that occurred in MOST_PICKED_LANE.';

COMMENT ON COLUMN CHAMPION_OVERVIEW.GLOBAL_PICK_RATE IS
'GAMES_PLAYED / total matches in dataset.';

COMMENT ON COLUMN CHAMPION_OVERVIEW.GLOBAL_WIN_RATE IS
'Win rate across all games this champion was played, global across all lanes.';

COMMENT ON COLUMN CHAMPION_OVERVIEW.GLOBAL_BAN_RATE IS
'Games this champion was banned (either team) / total matches in dataset.';
