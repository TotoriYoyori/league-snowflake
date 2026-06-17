-- Resume all bronze-to-silver tasks after pipeline deployment and seeding are complete
-- Co-authored with CoCo
-------------------------------------------------------------------------------------------
-- TASK ACTIVATION
-- Run this AFTER 01_deploy.sql and 02_seed_source.sql have completed successfully.
-- Tasks are created in a suspended state by default; this script resumes them.
-------------------------------------------------------------------------------------------
USE DATABASE LEAGUE_RECORDS;


-------------------------------------------------------------------------------------------
-- 1. RESUME ALL BRONZE-TO-SILVER TASKS
-------------------------------------------------------------------------------------------
ALTER TASK SILVER.BRONZE_TO_SILVER_MATCHES_TASK RESUME;
ALTER TASK SILVER.BRONZE_TO_SILVER_PLAYERS_TASK RESUME;
ALTER TASK SILVER.BRONZE_TO_SILVER_ITEMS_TASK RESUME;
ALTER TASK SILVER.BRONZE_TO_SILVER_CHAMPIONS_TASK RESUME;
ALTER TASK SILVER.BRONZE_TO_SILVER_INTERVALS_TASK RESUME;
