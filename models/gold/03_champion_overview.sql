
USE SCHEMA GOLD;
-------------------------------------------------------------------------------------------
    -- DESIGN NOTES:
    --     To properly inform win rates, all remakes/unfinished games (GAME_DURATION < 300s)
    --     are excluded (since LoL remakes occur between 1:30 - 5:00). Other statistics use
    --     all matches.
-------------------------------------------------------------------------------------------
CREATE OR REPLACE DYNAMIC TABLE GOLD.CHAMPION_OVERVIEW
TARGET_LAG = '1 day'
WAREHOUSE = COMPUTE_WH
REFRESH_MODE = FULL
COMMENT = 'Champion-level pick/win/ban rate and primary lane.'
AS
-------------------------------------------------------------------------------------------
    -- 01. PLAYER_MATCH_ALL / PLAYER_MATCH_NO_REMAKE
    --     Pick/ban/lane stats use ALL matches. Win rate uses NO_REMAKE_MATCHES
-------------------------------------------------------------------------------------------
WITH PLAYER_MATCH_ALL AS (
    SELECT
        MAT.MATCH_ID,
        PS.CHAMPION,
        PS.LANE
    FROM SILVER.MATCHES_SUMMARY_SILVER AS MAT
    JOIN SILVER.PLAYERS_SUMMARY_SILVER AS PS
        ON PS.MATCH_ID = MAT.MATCH_ID
),

PLAYER_MATCH_NO_REMAKE AS (
    SELECT
        PS.CHAMPION,
        (PS.TEAM = MAT.WINNING_TEAM) AS WIN
    FROM (
        SELECT * FROM SILVER.MATCHES_SUMMARY_SILVER
        WHERE GAME_DURATION >= 300
    ) AS MAT
    JOIN SILVER.PLAYERS_SUMMARY_SILVER AS PS
        ON PS.MATCH_ID = MAT.MATCH_ID
),
-------------------------------------------------------------------------------------------
    -- 02. CHAMPION_PICK_STATS (all matches) / CHAMPION_WIN_STATS (no-remake only)
-------------------------------------------------------------------------------------------
CHAMPION_PICK_STATS AS (
    SELECT
        CHAMPION,
        COUNT(*) AS GLOBAL_GAMES_PLAYED
    FROM PLAYER_MATCH_ALL
    GROUP BY CHAMPION
),

CHAMPION_WIN_STATS AS (
    SELECT
        CHAMPION,
        COUNT(*) AS WIN_ELIGIBLE_GAMES,
        SUM(CASE WHEN WIN THEN 1 ELSE 0 END) AS WINS
    FROM PLAYER_MATCH_NO_REMAKE
    WHERE WIN IS NOT NULL
    GROUP BY CHAMPION
),
-------------------------------------------------------------------------------------------
    -- 03. PRIMARY_LANE
-------------------------------------------------------------------------------------------
PRIMARY_LANE AS (
    SELECT
        CHAMPION,
        LANE AS MOST_PICKED_LANE,
        ROUND(
            COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY CHAMPION)::FLOAT
        , 4) AS PRIMARY_LANE_SHARE
    FROM PLAYER_MATCH_ALL
    GROUP BY CHAMPION, LANE
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY CHAMPION 
        ORDER BY COUNT(*) DESC, LANE -- Tiebreaker for if same count
    ) = 1
),
-------------------------------------------------------------------------------------------
    -- 04. ALL_BANS -> BAN_COUNTS
-------------------------------------------------------------------------------------------
ALL_BANS AS (
    SELECT DISTINCT MATCH_ID, CHAMPION_ID
    FROM (
        SELECT 
            MATCH_ID, 
            BAN_ID.VALUE::NUMBER AS CHAMPION_ID
        FROM SILVER.MATCHES_SUMMARY_SILVER
        CROSS JOIN LATERAL FLATTEN(
            INPUT => SPLIT(BLUE_BANS || ',' || RED_BANS, ',')
        ) AS BAN_ID
        WHERE BAN_ID.VALUE != '0'
    )
),

BAN_COUNTS AS (
    SELECT CHAMPION_ID, COUNT(*) AS GAMES_BANNED
    FROM ALL_BANS
    GROUP BY CHAMPION_ID
),
-------------------------------------------------------------------------------------------
    -- 05. TOTAL_GAMES_ALL -> CALC_AGGS
-------------------------------------------------------------------------------------------
TOTAL_GAMES_ALL AS (
    SELECT COUNT(*) AS TOTAL_GAMES 
    FROM SILVER.MATCHES_SUMMARY_SILVER
),

CALC_AGGS AS (
    SELECT
        CR.CHAMPION_ID,
        CR.CHAMPION_NAME,
        PL.MOST_PICKED_LANE,
        PL.PRIMARY_LANE_SHARE,
        COALESCE(CPS.GLOBAL_GAMES_PLAYED, 0) AS GLOBAL_GAMES_PLAYED,
        ROUND(
            COALESCE(CPS.GLOBAL_GAMES_PLAYED, 0) / 
            TGA.TOTAL_GAMES::FLOAT
        , 4) AS GLOBAL_PICK_RATE,
        ROUND(
            CWS.WINS /
            CWS.WIN_ELIGIBLE_GAMES::FLOAT
        , 4) AS GLOBAL_WIN_RATE,
        ROUND(
            COALESCE(BC.GAMES_BANNED, 0) / 
            TGA.TOTAL_GAMES::FLOAT
        , 4) AS GLOBAL_BAN_RATE
    FROM SILVER.CHAMPIONS_REF_SILVER AS CR
    LEFT JOIN CHAMPION_PICK_STATS AS CPS 
        ON CPS.CHAMPION = CR.CHAMPION_NAME
    LEFT JOIN CHAMPION_WIN_STATS AS CWS 
        ON CWS.CHAMPION = CR.CHAMPION_NAME
    LEFT JOIN PRIMARY_LANE AS PL 
        ON PL.CHAMPION = CR.CHAMPION_NAME
    LEFT JOIN BAN_COUNTS AS BC 
        ON BC.CHAMPION_ID = CR.CHAMPION_ID
    CROSS JOIN TOTAL_GAMES_ALL AS TGA
)
-------------------------------------------------------------------------------------------
    -- Select all above for complete query (Verify and test results here as well)
-------------------------------------------------------------------------------------------
SELECT * 
FROM CALC_AGGS
WHERE CHAMPION_ID != 0
;
