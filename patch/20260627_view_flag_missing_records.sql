USE SCHEMA BRONZE;
-------------------------------------------------------------------------------------------
-- PROBLEM: There are 73 missing matches between GOLD.PLAYER_STATS_SUMMARY and 
-- SILVER.PLAYER_SUMMARY_SILVER despite sharing the same (MATCH_ID, PARTICIPANT_POS_ID)
-- grain. Same holds for GOLD.MATCH_TEAM_STATS_SUMMARY and SILVER.MATCH_SUMMARY_SILVER
-- at the (MATCH_ID) grain.

-- HYPOTHESIS: Some matches are summarized but does not have logged interval data. 
-- (e.g. match A has summary but no logged intervals in MATCH_INTERVALS_). This causes the joinings
-- that occur in gold to drop data. 
-------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------
-- 01. ROW COUNT DIFFS: Run this to see the difference in row counts between silver vs. gold
-------------------------------------------------------------------------------------------
-- WITH SILVER_PLAYER AS (
--     SELECT COUNT(DISTINCT MATCH_ID, PARTICIPANT_POS_ID) AS ROW_COUNTS
--     FROM SILVER.PLAYERS_SUMMARY_SILVER
-- ),

-- GOLD_PLAYER AS (
--     SELECT COUNT(DISTINCT MATCH_ID, PARTICIPANT_POS_ID) AS ROW_COUNTS
--     FROM GOLD.PLAYER_STATS_SUMMARY
-- ),

-- SILVER_MATCH AS (
--     SELECT COUNT(DISTINCT MATCH_ID) AS ROW_COUNTS
--     FROM SILVER.MATCHES_SUMMARY_SILVER
-- ),

-- GOLD_MATCH AS (
--     SELECT COUNT(DISTINCT MATCH_ID) AS ROW_COUNTS
--     FROM GOLD.MATCH_TEAM_STATS_SUMMARY
-- )

-- SELECT
--     'PLAYER' AS GRAIN_NAME,
--     SP.ROW_COUNTS AS SILVER_ROW_COUNTS,
--     GP.ROW_COUNTS AS GOLD_ROW_COUNTS,
--     (SP.ROW_COUNTS - GP.ROW_COUNTS) AS ROW_MISSINGS,
--     ROUND(
--         100.0 * (SP.ROW_COUNTS - GP.ROW_COUNTS) / NULLIF(SP.ROW_COUNTS, 0)
--     , 2) AS PCT_MISSING
-- FROM SILVER_PLAYER AS SP, GOLD_PLAYER AS GP

-- UNION ALL

-- SELECT
--     'MATCH' AS GRAIN_NAME,
--     SM.ROW_COUNTS AS SILVER_ROW_COUNTS,
--     GM.ROW_COUNTS AS GOLD_ROW_COUNTS,
--     (SM.ROW_COUNTS - GM.ROW_COUNTS) AS ROW_MISSINGS,
--     ROUND(
--         100.0 * (SM.ROW_COUNTS - GM.ROW_COUNTS) / NULLIF(SM.ROW_COUNTS, 0)
--     , 2) AS PCT_MISSING
-- FROM SILVER_MATCH AS SM, GOLD_MATCH AS GM
-- ;

-------------------------------------------------------------------------------------------
-- 02. CONFIRM SOURCE-LEVEL MISSING DATA (silver vs bronze comparison)
-------------------------------------------------------------------------------------------
-- WITH MISSING_RECORDS_IN_SILVER AS (
--     SELECT COUNT(DISTINCT SL.MATCH_ID) AS UNLOGGED_INTERVAL_MATCHES
--     FROM SILVER.PLAYERS_SUMMARY_SILVER AS SL
--     LEFT JOIN SILVER.PLAYER_INTERVAL_SILVER AS SR
--         ON SL.MATCH_ID = SR.MATCH_ID
--         AND SL.PARTICIPANT_POS_ID = SR.PARTICIPANT_POS_ID
--     WHERE SR.CS IS NULL
-- ),

-- MISSING_RECORDS_AT_BRONZE AS (
--     SELECT COUNT(DISTINCT BL.MATCH_ID) AS UNLOGGED_INTERVAL_MATCHES
--     FROM BRONZE.PLAYERS_SUMMARY_BRONZE AS BL
--     LEFT JOIN BRONZE.MATCH_INTERVALS_BRONZE AS BR
--         ON BL.MATCH_ID = BR.MATCH_ID
--     WHERE BR.CS IS NULL
-- )

-- SELECT 
--     SV.UNLOGGED_INTERVAL_MATCHES AS UNLOGGED_IN_SILVER,
--     BR.UNLOGGED_INTERVAL_MATCHES AS UNLOGGED_IN_BRONZE,
--     (SV.UNLOGGED_INTERVAL_MATCHES = BR.UNLOGGED_INTERVAL_MATCHES) 
--         AS CONFIRMED_SRC_MISSING_DATA
-- FROM MISSING_RECORDS_IN_SILVER AS SV, MISSING_RECORDS_AT_BRONZE AS BR
-- ;

-------------------------------------------------------------------------------------------
-- 03. SOLUTION: View on bronze to keep an audit trail of missing matches by load date,
-- for future reference as we ingest more matches
-------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW BRONZE._UNLOGGED_MATCHES AS 
SELECT DISTINCT 
    BL.MATCH_ID AS UNLOGGED_INTERVAL_MATCH_ID, 
    BL.FILE_NAME AS UNLOGGED_INTERVAL_FILE_NAME, 
    BL.LDTS AS UNLOGGED_AT_LOAD_DATE, 
    BL.RSRC AS UNLOGGED_FROM_SOURCE
FROM BRONZE.PLAYERS_SUMMARY_BRONZE AS BL
LEFT JOIN BRONZE.MATCH_INTERVALS_BRONZE AS BR
    ON BR.MATCH_ID = BL.MATCH_ID
WHERE BR.CS IS NULL
;

-------------------------------------------------------------------------------------------
-- 04. VERIFY: Uncomment to verify 
-------------------------------------------------------------------------------------------
-- SELECT * FROM BRONZE._UNLOGGED_MATCHES LIMIT 10;
