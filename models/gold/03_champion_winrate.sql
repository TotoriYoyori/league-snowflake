USE DATABASE LEAGUE_RECORDS;
USE SCHEMA GOLD;
-------------------------------------------------------------------------------------------
    -- CHAMPION_OVERVIEW: Champion-level pick rate, win rate, ban rate, and primary lane
    --
    -- GRAIN: One row per CHAMPION.
    --
    -- DESIGN NOTES:
    -- 1. MOST_PICKED_LANE is METADATA, not a filter. GLOBAL_PICK_RATE / GLOBAL_WIN_RATE are
    --    computed GLOBALLY across all lanes that champion has been played in -- column
    --    names are prefixed GLOBAL_ to make this explicit. MOST_PICKED_LANE only labels
    --    which lane that champion is most commonly played in, and LANE_PICK_RATE shows
    --    what share of that champion's total picks happened in that specific lane.
    -- 2. GLOBAL_BAN_RATE is inherently champion-wide -- bans happen during champion select,
    --    before lanes are assigned, so there is no lane-scoped version of this stat.
-------------------------------------------------------------------------------------------
-- CREATE OR REPLACE DYNAMIC TABLE CHAMPION_OVERVIEW
-- TARGET_LAG = '1 day'
-- WAREHOUSE = COMPUTE_WH
-- COMMENT = 'Champion-level pick rate, win rate, ban rate, and primary lane. MOST_PICKED_LANE/LANE_PICK_RATE are metadata about that champions most common lane -- they do not filter GLOBAL_PICK_RATE/GLOBAL_WIN_RATE/GLOBAL_BAN_RATE, which are global across all lanes.'
-- AS
WITH PLAYER_MATCH AS (
    SELECT
        PS.CHAMPION,
        PS.LANE,
        (PS.TEAM = MAT.WINNING_TEAM) AS WIN
    FROM SILVER.MATCHES_SUMMARY_SILVER AS MAT
    JOIN SILVER.PLAYERS_SUMMARY_SILVER AS PS
        ON PS.MATCH_ID = MAT.MATCH_ID
),
-- Global per champion pick/win counts
CHAMPION_GLOBAL_STATS AS (
    SELECT
        CHAMPION,
        COUNT(*) AS GAMES_PLAYED,
        SUM(CASE WHEN WIN THEN 1 ELSE 0 END) AS WINS
    FROM PLAYER_MATCH
    GROUP BY CHAMPION
),
-- Global most-played lane per champion, with that lane's share of total picks
PRIMARY_LANE AS (
    SELECT
        CHAMPION,
        LANE AS MOST_PICKED_LANE,
        ROUND(
            COUNT(*) / SUM(COUNT(*)) OVER(PARTITION BY CHAMPION)::FLOAT
        , 4) AS LANE_PICK_RATE
    FROM PLAYER_MATCH
    GROUP BY CHAMPION, LANE
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY CHAMPION
        ORDER BY COUNT(*) DESC
    ) = 1
),
ALL_BANS AS (
   SELECT DISTINCT
        AB.MATCH_ID,
        CR.CHAMPION_NAME AS CHAMPION
    FROM (
        SELECT
            MATCH_ID,
            BAN_ID.VALUE::NUMBER AS CHAMPION_ID
        FROM SILVER.MATCHES_SUMMARY_SILVER,
            LATERAL SPLIT_TO_TABLE(BLUE_BANS, ',') AS BAN_ID
        WHERE BAN_ID.VALUE != '0'

        UNION ALL

        SELECT
            MATCH_ID,
            BAN_ID.VALUE::NUMBER AS CHAMPION_ID
        FROM SILVER.MATCHES_SUMMARY_SILVER,
            LATERAL SPLIT_TO_TABLE(RED_BANS, ',') AS BAN_ID
        WHERE BAN_ID.VALUE != '0'
    ) AS AB
    JOIN SILVER.CHAMPIONS_REF_SILVER AS CR
        ON CR.CHAMPION_ID = AB.CHAMPION_ID
),
BAN_COUNTS AS (
    SELECT
        CHAMPION,
        COUNT(*) AS GAMES_BANNED
    FROM ALL_BANS
    GROUP BY CHAMPION
),
CHAMPION_OVERVIEW_FINAL AS (
    SELECT
        CGS.CHAMPION,
        PL.MOST_PICKED_LANE,
        PL.LANE_PICK_RATE,
        CGS.GAMES_PLAYED,
        ROUND(CGS.GAMES_PLAYED / TM.TOTAL_GAMES::FLOAT, 4)              AS GLOBAL_PICK_RATE,
        ROUND(CGS.WINS / CGS.GAMES_PLAYED::FLOAT, 4)                    AS GLOBAL_WIN_RATE,
        ROUND(COALESCE(BC.GAMES_BANNED, 0) / TM.TOTAL_GAMES::FLOAT, 4)  AS GLOBAL_BAN_RATE
    FROM CHAMPION_GLOBAL_STATS AS CGS
    JOIN PRIMARY_LANE AS PL
        ON PL.CHAMPION = CGS.CHAMPION
    LEFT JOIN BAN_COUNTS AS BC
        ON BC.CHAMPION = CGS.CHAMPION
    CROSS JOIN (SELECT COUNT(*) AS TOTAL_GAMES FROM SILVER.MATCHES_SUMMARY_SILVER) AS TM
)

SELECT *
FROM CHAMPION_OVERVIEW_FINAL

;

-- Column-level comments
-- COMMENT ON COLUMN CHAMPION_OVERVIEW.MOST_PICKED_LANE IS
-- 'Metadata label: the lane this champion is most commonly played in. Does NOT filter GLOBAL_PICK_RATE/GLOBAL_WIN_RATE/GLOBAL_BAN_RATE, which are global across all lanes.';

-- COMMENT ON COLUMN CHAMPION_OVERVIEW.LANE_PICK_RATE IS
-- 'Share of this champions total picks that occurred in MOST_PICKED_LANE specifically (lane games / champion total games). Companion metric to MOST_PICKED_LANE.';

-- COMMENT ON COLUMN CHAMPION_OVERVIEW.GLOBAL_PICK_RATE IS
-- 'GAMES_PLAYED / total matches in dataset. Global across all lanes, not scoped to MOST_PICKED_LANE.';

-- COMMENT ON COLUMN CHAMPION_OVERVIEW.GLOBAL_WIN_RATE IS
-- 'Win rate across all games this champion was played, global across all lanes, not scoped to MOST_PICKED_LANE.';

-- COMMENT ON COLUMN CHAMPION_OVERVIEW.GLOBAL_BAN_RATE IS
-- 'Games this champion was banned (either team) / total matches in dataset. Inherently champion-wide -- bans occur before lane assignment.';
