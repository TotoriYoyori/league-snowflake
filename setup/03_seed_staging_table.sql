-------------------------------------------------------------------------------------------
-- SEED THE FULL HISTORICAL DATASET INTO SEED_INTERVALS
-- Run this manually after 02_deploy.sql has created the pipeline objects.
-- Update the file path below to match your local machine.
-------------------------------------------------------------------------------------------
USE WAREHOUSE DV_COMPUTE_WH;
USE DATABASE LEAGUE_RECORDS;
USE SCHEMA BRONZE;

-- 1. Upload the CSV from GitHub Releases into the SEED_INTERVALS table stage.
PUT file:///path/to/intervals.csv @%SEED_INTERVALS
    AUTO_COMPRESS = TRUE
    OVERWRITE = TRUE;

-- 2. Load from table stage into SEED_INTERVALS.
COPY INTO SEED_INTERVALS
    FILE_FORMAT = MATCH_INTERVAL_FMT;

-- 3. Verify row count.
SELECT COUNT(*) AS seed_row_count FROM SEED_INTERVALS;
