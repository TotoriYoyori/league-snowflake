-------------------------------------------------------------------------------------------
-- SEED THE ORIGINAL DATASET INTO @DAILY_MATCH_SEED_STG
-- This stage holds the full historical dataset. The pipeline stage
-- (@DAILY_MATCH_AZSTG) is populated separately via the simulate_stream script.
-------------------------------------------------------------------------------------------

-- 1. Upload the CSV you downloaded from GitHub Releases into the seed stage.
--    Update the file path below to match your local machine.
PUT file:///path/to/intervals.csv @DAILY_MATCH_SEED_STG
    AUTO_COMPRESS = TRUE
    OVERWRITE = TRUE;

-- 2. Verify the file landed
LIST @DAILY_MATCH_SEED_STG;
