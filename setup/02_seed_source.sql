-------------------------------------------------------------------------------------------
-- SEED THE FULL HISTORICAL DATASET
--
-- BEFORE RUNNING: Upload your CSV files to @LEAGUE_RECORDS.SEED.UPLOAD_STG
-- via the Snowsight UI (Databases > LEAGUE_RECORDS > SEED > Stages > UPLOAD_STG > Upload).
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
COPY INTO LEAGUE_RECORDS.SEED.MATCHES
    FROM @LEAGUE_RECORDS.SEED.UPLOAD_STG/matches_summary;

COPY INTO LEAGUE_RECORDS.SEED.PLAYERS
    FROM @LEAGUE_RECORDS.SEED.UPLOAD_STG/players_summary;

COPY INTO LEAGUE_RECORDS.SEED.INTERVALS
    FROM @LEAGUE_RECORDS.SEED.UPLOAD_STG/intervals;

COPY INTO LEAGUE_RECORDS.SEED.ITEMS_REF
    FROM @LEAGUE_RECORDS.SEED.UPLOAD_STG/items_ref;

COPY INTO LEAGUE_RECORDS.SEED.CHAMPIONS_REF
    FROM @LEAGUE_RECORDS.SEED.UPLOAD_STG/champions_ref;


-------------------------------------------------------------------------------------------
-- 2. ONE-TIME: STAGE REFERENCE DATA AND REFRESH REFERENCE PIPES
-------------------------------------------------------------------------------------------
COPY INTO @LEAGUE_RECORDS.BRONZE.ITEMS_REF_STG/items_ref.csv
FROM (
    SELECT 
        ITEM_ID, 
        ITEM_NAME, 
        ITEM_CATEGORY 
    FROM LEAGUE_RECORDS.SEED.ITEMS_REF
)
    OVERWRITE = TRUE
    SINGLE = TRUE
    HEADER = TRUE;

COPY INTO @LEAGUE_RECORDS.BRONZE.CHAMPIONS_REF_STG/champions_ref.csv
FROM (SELECT CHAMPION_ID, CHAMPION_NAME FROM LEAGUE_RECORDS.SEED.CHAMPIONS_REF)
    OVERWRITE = TRUE
    SINGLE = TRUE
    HEADER = TRUE;

ALTER PIPE LEAGUE_RECORDS.BRONZE.ITEMS_REF_PP REFRESH;
ALTER PIPE LEAGUE_RECORDS.BRONZE.CHAMPIONS_REF_PP REFRESH;


-------------------------------------------------------------------------------------------
-- 4. KICKSTART: Load the first simulated day now
-------------------------------------------------------------------------------------------
CALL SEED.SIMULATE_DAILY_LOAD();
