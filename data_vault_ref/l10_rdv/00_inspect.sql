-------------------------------------------------------------------------------------------
    -- 0. DECLARE WORKING CONTEXT
    -- Diagnostic queries to inspect the Raw Data Vault layer of LEAGUE_RECORDS.
    -- Run each block individually — NOT meant to be executed top-to-bottom.
-------------------------------------------------------------------------------------------
USE DATABASE LEAGUE_RECORDS;

USE SCHEMA L10_RDV;


-------------------------------------------------------------------------------------------
    -- 1. INSPECT SAMPLE FROM HUB TABLE
-------------------------------------------------------------------------------------------
SELECT *
FROM LEAGUE_RECORDS.L10_RDV.HUB_INTERVALS
ORDER BY LDTS DESC
LIMIT 5;


-------------------------------------------------------------------------------------------
    -- 2. INSPECT SAMPLE FROM SATELLITE TABLE
-------------------------------------------------------------------------------------------
SELECT *
FROM LEAGUE_RECORDS.L10_RDV.SAT_INTERVALS
ORDER BY LDTS DESC
LIMIT 5;


-------------------------------------------------------------------------------------------
    -- 3. INSPECT ROW COUNTS
-------------------------------------------------------------------------------------------
SELECT 
    'HUB_INTERVALS' AS TABLE_NAME, 
    COUNT(*) AS ROW_COUNT 
FROM HUB_INTERVALS
UNION ALL
SELECT 
    'SAT_INTERVALS', 
    COUNT(*) 
FROM SAT_INTERVALS;


-------------------------------------------------------------------------------------------
    -- 4. INSPECT TASK DEFINITION
-------------------------------------------------------------------------------------------
DESC TASK STG_INTERVALS_TO_RDV;


-------------------------------------------------------------------------------------------
    -- 5. INSPECT TASK EXECUTION HISTORY
-------------------------------------------------------------------------------------------
SELECT *
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY())
WHERE DATABASE_NAME = 'LEAGUE_RECORDS'
ORDER BY SCHEDULED_TIME DESC;
