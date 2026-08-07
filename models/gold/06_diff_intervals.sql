USE SCHEMA GOLD;
-------------------------------------------------------------------------------------------
    -- DESIGN NOTES:
    --     Grain is (MATCH_ID, PARTICIPANT_POS_ID, MINUTE) -- one row per player, per 5 minute.
-------------------------------------------------------------------------------------------
CREATE OR REPLACE DYNAMIC TABLE GOLD.DIFF_INTERVALS
TARGET_LAG = '1 hour'
WAREHOUSE = COMPUTE_WH
REFRESH_MODE = FULL
COMMENT = 'Silver player interval diff state enriched with lane/champion identity only.'
AS
-------------------------------------------------------------------------------------------
    -- 01. PLAYER_DIFF_INTERVAL_STATE_CTE
    --     Join silver player-minute intervals to player identity (team/lane/champion).
-------------------------------------------------------------------------------------------
WITH PLAYER_DIFF_INTERVAL_STATE_CTE AS (
    SELECT
        -- Primary key
        S.MATCH_ID,
        S.PARTICIPANT_POS_ID,
        S.MINUTE,
        -- Player / lane identity
        P.TEAM,
        P.CHAMPION_ROLE,
        P.CHAMPION_NAME,
        -- Player-minute diffs
        S.GOLD_DIFF,
        S.XP_DIFF
    FROM SILVER.INTERVALS AS S
    JOIN SILVER.PLAYERS AS P
        ON S.MATCH_ID = P.MATCH_ID
        AND S.PARTICIPANT_POS_ID = P.PARTICIPANT_POS_ID
)
-------------------------------------------------------------------------------------------
    -- Select all above for complete query (Verify and test results here as well)
-------------------------------------------------------------------------------------------
SELECT *
FROM PLAYER_DIFF_INTERVAL_STATE_CTE;
-------------------------------------------------------------------------------------------
    -- Column-specific comments
-------------------------------------------------------------------------------------------
COMMENT ON COLUMN GOLD.DIFF_INTERVALS.PARTICIPANT_POS_ID IS
'The index position of the player at queue time. 1-5 for BLUE side, 6-10 for RED side.'
;

COMMENT ON COLUMN GOLD.DIFF_INTERVALS.MINUTE IS
'Minute mark of this snapshot, in 5-minute intervals.'
;

COMMENT ON COLUMN GOLD.DIFF_INTERVALS.TEAM IS
'BLUE or RED.'
;

COMMENT ON COLUMN GOLD.DIFF_INTERVALS.CHAMPION_ROLE IS
'Resolved role played, based on in-game signals.'
;

COMMENT ON COLUMN GOLD.DIFF_INTERVALS.CHAMPION_NAME IS
'Champion played.'
;

COMMENT ON COLUMN GOLD.DIFF_INTERVALS.GOLD_DIFF IS
'This player''s TOTAL_GOLD minus their direct lane opponent''s TOTAL_GOLD, at this MINUTE snapshot.'
;

COMMENT ON COLUMN GOLD.DIFF_INTERVALS.XP_DIFF IS
'This player''s XP minus their direct lane opponent''s XP, at this MINUTE snapshot.'
;
