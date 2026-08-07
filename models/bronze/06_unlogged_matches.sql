USE SCHEMA BRONZE;
-------------------------------------------------------------------------------------------
    -- DESIGN NOTES:
    --     Not all matches under BRONZE.MATCHES have logged interval data. This view
    --     gives ongoing visibility into that.
    --
    --     HISTORICAL NOTE: This monitoring view was originally introduced reactively, after
    --     73 matches were found missing from GOLD.MATCHEND_PLAYER_STATS / MATCHEND_PIVOT_TEAMSTATS
    --     despite sharing the same key with their Silver parents. See
    --     patch/20260627_view_flag_missing_records.sql for the original notes.
-------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW BRONZE._UNLOGGED_MATCHES AS
SELECT
    BL.MATCH_ID AS UNLOGGED_INTERVAL_MATCH_ID,
    BL.FILE_NAME AS UNLOGGED_INTERVAL_FILE_NAME,
    BL.LDTS AS UNLOGGED_AT_LOAD_DATE,
    BL.RSRC AS UNLOGGED_FROM_SOURCE
FROM BRONZE.MATCHES AS BL
LEFT JOIN BRONZE.INTERVALS AS BR
    ON BR.MATCH_ID = BL.MATCH_ID
WHERE BR.MATCH_ID IS NULL
;
-------------------------------------------------------------------------------------------
    -- REFERENCE: Diagnostic queries from the original investigation, updated to current
    -- naming and to the corrected match-grain join. Uncomment to re-run ad hoc.
-------------------------------------------------------------------------------------------
-- 01. ROW COUNT DIFFS: Silver vs. Gold, at both grains.
-- WITH SILVER_PLAYER AS (
--     SELECT COUNT(DISTINCT MATCH_ID, PARTICIPANT_POS_ID) AS ROW_COUNTS
--     FROM SILVER.PLAYERS
-- ),
--
-- GOLD_PLAYER AS (
--     SELECT COUNT(DISTINCT MATCH_ID, PARTICIPANT_POS_ID) AS ROW_COUNTS
--     FROM GOLD.MATCHEND_PLAYER_STATS
-- ),
--
-- SILVER_MATCH AS (
--     SELECT COUNT(DISTINCT MATCH_ID) AS ROW_COUNTS
--     FROM SILVER.MATCHES
-- ),
--
-- GOLD_MATCH AS (
--     SELECT COUNT(DISTINCT MATCH_ID) AS ROW_COUNTS
--     FROM GOLD.MATCHEND_PIVOT_TEAMSTATS
-- )
--
-- SELECT
--     'PLAYER' AS GRAIN_NAME,
--     SP.ROW_COUNTS AS SILVER_ROW_COUNTS,
--     GP.ROW_COUNTS AS GOLD_ROW_COUNTS,
--     (SP.ROW_COUNTS - GP.ROW_COUNTS) AS ROW_MISSINGS,
--     ROUND(
--         100.0 * (SP.ROW_COUNTS - GP.ROW_COUNTS) / NULLIF(SP.ROW_COUNTS, 0)
--     , 2) AS PCT_MISSING
-- FROM SILVER_PLAYER AS SP, GOLD_PLAYER AS GP
--
-- UNION ALL
--
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

-- 02. CONFIRM SOURCE-LEVEL MISSING DATA (Silver vs. Bronze comparison)
-- WITH MISSING_RECORDS_IN_SILVER AS (
--     SELECT COUNT(DISTINCT SL.MATCH_ID) AS UNLOGGED_INTERVAL_MATCHES
--     FROM SILVER.PLAYERS AS SL
--     LEFT JOIN SILVER.INTERVALS AS SR
--         ON SL.MATCH_ID = SR.MATCH_ID
--         AND SL.PARTICIPANT_POS_ID = SR.PARTICIPANT_POS_ID
--     WHERE SR.CS IS NULL
-- ),
--
-- MISSING_RECORDS_AT_BRONZE AS (
--     SELECT COUNT(DISTINCT BL.MATCH_ID) AS UNLOGGED_INTERVAL_MATCHES
--     FROM BRONZE.MATCHES AS BL
--     LEFT JOIN BRONZE.INTERVALS AS BR
--         ON BL.MATCH_ID = BR.MATCH_ID
--     WHERE BR.MATCH_ID IS NULL
-- )
--
-- SELECT
--     SV.UNLOGGED_INTERVAL_MATCHES AS UNLOGGED_IN_SILVER,
--     BR.UNLOGGED_INTERVAL_MATCHES AS UNLOGGED_IN_BRONZE,
--     (SV.UNLOGGED_INTERVAL_MATCHES = BR.UNLOGGED_INTERVAL_MATCHES)
--         AS CONFIRMED_SRC_MISSING_DATA
-- FROM MISSING_RECORDS_IN_SILVER AS SV, MISSING_RECORDS_AT_BRONZE AS BR
-- ;

-------------------------------------------------------------------------------------------
    -- VERIFY: Uncomment to verify
-------------------------------------------------------------------------------------------
-- SELECT * FROM BRONZE._UNLOGGED_MATCHES LIMIT 10;
