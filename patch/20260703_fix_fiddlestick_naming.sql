USE DATABASE LEAGUE_RECORDS;

USE SCHEMA SILVER;
-------------------------------------------------------------------------------------------
    -- PROBLEM: Out of all champions, Fiddlesticks has a naming inconsistency between the raw reference
    -- table ('Fiddlesticks') and other raw tables ('FiddleSticks'). This causes the normalization step
    -- in silver to not catch Fiddlesticks. Other champions are all fine.
-------------------------------------------------------------------------------------------
-- LEFT JOIN ref -> summary: every CHAMPION_NAME under refs find a match in summary, except `Fiddlesticks` in refs.
SELECT DISTINCT REF.CHAMPION_NAME AS MISSING_NAME -- MISSING_NAME -> 'Fiddlesticks'
FROM SILVER.CHAMPIONS_REF_SILVER AS REF
LEFT JOIN SILVER.PLAYERS_SUMMARY_SILVER AS PS
    ON PS.CHAMPION = REF.CHAMPION_NAME
WHERE PS.MATCH_ID IS NULL AND REF.CHAMPION_NAME NOT ILIKE '%no champion%'
;

-- LEFT JOIN summary -> ref: every CHAMPION under summary can be find under refs, except `Fiddle Sticks` in summary.
WITH SUMMARY_CHAMPION_NAME AS (
    SELECT DISTINCT CHAMPION AS CHAMPION_NAME
    FROM SILVER.PLAYERS_SUMMARY_SILVER
),

REF_CHAMPION_NAME AS (
    SELECT *
    FROM SILVER.CHAMPIONS_REF_SILVER 
    WHERE LOWER(CHAMPION_NAME) != 'no champion'
)

SELECT * -- CHAMPION_NAME -> 'Fiddle Sticks', CHAMPION_ID -> 'Null'
FROM SUMMARY_CHAMPION_NAME 
LEFT JOIN REF_CHAMPION_NAME USING (CHAMPION_NAME)
WHERE CHAMPION_ID IS NULL
;

-------------------------------------------------------------------------------------------
    -- SOLUTION: Perform a one-time update set statement on the summary table, conforming it
    -- to ref's conventions. All 'Fiddle Sticks' become 'Fiddlesticks' after task-stream transformation.
    -- Downstream gold's transformation will inherit all change. 
-------------------------------------------------------------------------------------------
UPDATE SILVER.PLAYERS_SUMMARY_SILVER
SET CHAMPION = 'Fiddlesticks'
WHERE CHAMPION = 'Fiddle Sticks'
;

-------------------------------------------------------------------------------------------
    -- FUTURE NOTES: Consider adding a new patch-cycle alert to notify naming inconsistency 
    -- found in source bronze data. 
-------------------------------------------------------------------------------------------