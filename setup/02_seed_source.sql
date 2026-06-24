-------------------------------------------------------------------------------------------
-- SEED THE FULL HISTORICAL DATASET
--
-- BEFORE RUNNING: Upload your CSV files to @LEAGUE_RECORDS.SEED.SEED_UPLOAD_STG
-- via the Snowsight UI (Databases > LEAGUE_RECORDS > SEED > Stages > SEED_UPLOAD_STG > Upload).
--
-- Expected files:
--   matches_summary.csv      
--   players_summary.csv      
--   intervals.csv.gz          
--   items_ref.csv     
--   champions_ref.csv        
-------------------------------------------------------------------------------------------
USE WAREHOUSE COMPUTE_WH;

USE DATABASE LEAGUE_RECORDS;

USE SCHEMA SEED;


-------------------------------------------------------------------------------------------
-- 0. VALIDATE: Ensure all required files are present before proceeding
-------------------------------------------------------------------------------------------
CALL SEED.VALIDATE_SEED_UPLOAD();


-------------------------------------------------------------------------------------------
-- 1. LOAD FROM STAGE INTO SEED TABLES
-------------------------------------------------------------------------------------------
COPY INTO LEAGUE_RECORDS.SEED.SEED_MATCHES_SUMMARY
    FROM @LEAGUE_RECORDS.SEED.SEED_UPLOAD_STG/matches_summary;

COPY INTO LEAGUE_RECORDS.SEED.SEED_PLAYERS_SUMMARY
    FROM @LEAGUE_RECORDS.SEED.SEED_UPLOAD_STG/players_summary;

COPY INTO LEAGUE_RECORDS.SEED.SEED_MATCH_INTERVALS
    FROM @LEAGUE_RECORDS.SEED.SEED_UPLOAD_STG/intervals;

COPY INTO LEAGUE_RECORDS.SEED.SEED_ITEMS_REF
    FROM @LEAGUE_RECORDS.SEED.SEED_UPLOAD_STG/items_ref;

COPY INTO LEAGUE_RECORDS.SEED.SEED_CHAMPIONS_REF
    FROM @LEAGUE_RECORDS.SEED.SEED_UPLOAD_STG/champions_ref;


-------------------------------------------------------------------------------------------
-- 2. VERIFY ROW COUNTS
-------------------------------------------------------------------------------------------
SELECT 'SEED_MATCHES_SUMMARY' AS TABLE_NAME, COUNT(*) AS ROW_COUNT
FROM LEAGUE_RECORDS.SEED.SEED_MATCHES_SUMMARY
    UNION ALL
SELECT 'SEED_PLAYERS_SUMMARY', COUNT(*)
FROM LEAGUE_RECORDS.SEED.SEED_PLAYERS_SUMMARY
    UNION ALL
SELECT 'SEED_MATCH_INTERVALS', COUNT(*)
FROM LEAGUE_RECORDS.SEED.SEED_MATCH_INTERVALS
    UNION ALL
SELECT 'SEED_ITEMS_REF', COUNT(*)
FROM LEAGUE_RECORDS.SEED.SEED_ITEMS_REF
    UNION ALL
SELECT 'SEED_CHAMPIONS_REF', COUNT(*)
FROM LEAGUE_RECORDS.SEED.SEED_CHAMPIONS_REF;


-------------------------------------------------------------------------------------------
-- 3. ONE-TIME: STAGE REFERENCE DATA AND REFRESH REFERENCE PIPES
-------------------------------------------------------------------------------------------
COPY INTO @LEAGUE_RECORDS.BRONZE.ITEMS_REF_STG/items_ref.csv
FROM (
    SELECT 
        ITEM_ID, 
        ITEM_NAME, 
        ITEM_CATEGORY 
    FROM LEAGUE_RECORDS.SEED.SEED_ITEMS_REF
)
    OVERWRITE = TRUE
    SINGLE = TRUE
    HEADER = TRUE;

COPY INTO @LEAGUE_RECORDS.BRONZE.CHAMPIONS_REF_STG/champions_ref.csv
FROM (SELECT CHAMPION_ID, CHAMPION_NAME FROM LEAGUE_RECORDS.SEED.SEED_CHAMPIONS_REF)
    OVERWRITE = TRUE
    SINGLE = TRUE
    HEADER = TRUE;

ALTER PIPE LEAGUE_RECORDS.BRONZE.ITEMS_REF_PP REFRESH;
ALTER PIPE LEAGUE_RECORDS.BRONZE.CHAMPIONS_REF_PP REFRESH;
