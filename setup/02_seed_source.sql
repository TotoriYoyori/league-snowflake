-- Seed source data: upload CSVs to table stages, load into seed tables, and stage reference data for pipes
-- Co-authored with CoCo
-------------------------------------------------------------------------------------------
-- SEED THE FULL HISTORICAL DATASET
-- Run this manually after 01_deploy.sql has created all pipeline objects.
-------------------------------------------------------------------------------------------
USE WAREHOUSE COMPUTE_WH;
USE DATABASE LEAGUE_RECORDS;
USE SCHEMA SEED;


-------------------------------------------------------------------------------------------
-- 1. UPLOAD CSVs TO TABLE STAGES
-------------------------------------------------------------------------------------------
PUT 'file://C:/postgres_staging/league/matches_summary.csv'
    @LEAGUE_RECORDS.SEED.%SEED_MATCHES_SUMMARY
    AUTO_COMPRESS = TRUE
    OVERWRITE = TRUE;
    
PUT 'file://C:/postgres_staging/league/players_summary.csv'
    @LEAGUE_RECORDS.SEED.%SEED_PLAYERS_SUMMARY
    AUTO_COMPRESS = TRUE
    OVERWRITE = TRUE;
    
PUT 'file://C:/postgres_staging/league/match_intervals.csv'
    @LEAGUE_RECORDS.SEED.%SEED_MATCH_INTERVALS
    AUTO_COMPRESS = TRUE
    OVERWRITE = TRUE;
    
PUT 'file://C:/postgres_staging/league/items_ref.csv'
    @LEAGUE_RECORDS.SEED.%SEED_ITEMS_REF
    AUTO_COMPRESS = TRUE
    OVERWRITE = TRUE;
    
PUT 'file://C:/postgres_staging/league/champions_ref.csv'
    @LEAGUE_RECORDS.SEED.%SEED_CHAMPIONS_REF
    AUTO_COMPRESS = TRUE
    OVERWRITE = TRUE;


-------------------------------------------------------------------------------------------
-- 2. LOAD FROM TABLE STAGES INTO SEED TABLES
-------------------------------------------------------------------------------------------
COPY INTO LEAGUE_RECORDS.SEED.SEED_MATCHES_SUMMARY 
    FILE_FORMAT = LEAGUE_RECORDS.BRONZE.LEAGUE_CSV_FMT;
    
COPY INTO LEAGUE_RECORDS.SEED.SEED_PLAYERS_SUMMARY 
    FILE_FORMAT = LEAGUE_RECORDS.BRONZE.LEAGUE_CSV_FMT;
    
COPY INTO LEAGUE_RECORDS.SEED.SEED_MATCH_INTERVALS 
    FILE_FORMAT = LEAGUE_RECORDS.BRONZE.LEAGUE_CSV_FMT;
    
COPY INTO LEAGUE_RECORDS.SEED.SEED_ITEMS_REF 
    FILE_FORMAT = LEAGUE_RECORDS.BRONZE.LEAGUE_CSV_FMT;
    
COPY INTO LEAGUE_RECORDS.SEED.SEED_CHAMPIONS_REF 
    FILE_FORMAT = LEAGUE_RECORDS.BRONZE.LEAGUE_CSV_FMT;


-------------------------------------------------------------------------------------------
-- 3. VERIFY ROW COUNTS
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
-- 4. ONE TIME COPY OF REFERENCE DATA REFRESH REFERENCE PIPES
-------------------------------------------------------------------------------------------
COPY INTO @LEAGUE_RECORDS.BRONZE.REFERENCE_STG/items_ref.csv
FROM (SELECT ITEM_ID, ITEM_NAME FROM LEAGUE_RECORDS.SEED.SEED_ITEMS_REF)
    FILE_FORMAT = (TYPE = CSV HEADER = TRUE) 
    OVERWRITE = TRUE 
    SINGLE = TRUE;

COPY INTO @LEAGUE_RECORDS.BRONZE.REFERENCE_STG/champions_ref.csv
FROM (SELECT CHAMPION_ID, CHAMPION_NAME FROM LEAGUE_RECORDS.SEED.SEED_CHAMPIONS_REF)
    FILE_FORMAT = (TYPE = CSV HEADER = TRUE) 
    OVERWRITE = TRUE 
    SINGLE = TRUE;

ALTER PIPE LEAGUE_RECORDS.BRONZE.ITEMS_REF_PP REFRESH;
ALTER PIPE LEAGUE_RECORDS.BRONZE.CHAMPIONS_REF_PP REFRESH;
