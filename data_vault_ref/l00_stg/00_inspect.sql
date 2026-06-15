-------------------------------------------------------------------------------------------
    -- 0. DECLARE WORKING CONTEXT
    -- Diagnostic queries to inspect the staging layer of LEAGUE_RECORDS.
    -- Run each block individually — NOT meant to be executed top-to-bottom.
-------------------------------------------------------------------------------------------
USE DATABASE LEAGUE_RECORDS;
USE SCHEMA L00_STG;


-------------------------------------------------------------------------------------------
    -- 1. INSPECT SAMPLE FROM STAGING TABLE
-------------------------------------------------------------------------------------------
SELECT *
FROM LEAGUE_RECORDS.L00_STG.STG_INTERVALS
ORDER BY RANDOM()
LIMIT 5;


-------------------------------------------------------------------------------------------
    -- 2. INSPECT STAGE'S COPY HISTORY
-------------------------------------------------------------------------------------------
CALL EXAMINE_STAGING_HISTORY('STG_INTERVALS', 120);


-------------------------------------------------------------------------------------------
    -- 3. INSPECT PIPE'S STATUS
-------------------------------------------------------------------------------------------
SELECT SYSTEM$PIPE_STATUS('LEAGUE_RECORDS.L00_STG.AUTO_LEAGUE_PP');


-------------------------------------------------------------------------------------------
    -- 4. INSPECT STREAM'S STATUS
-------------------------------------------------------------------------------------------
SHOW STREAMS IN DATABASE LEAGUE_RECORDS;

SELECT *
FROM LEAGUE_RECORDS.L00_STG.STG_INTERVALS_STRM_RDV
LIMIT 10;


-------------------------------------------------------------------------------------------
    -- 5. INSPECT STREAM-VIEW EXPORT
-------------------------------------------------------------------------------------------
SELECT *
FROM LEAGUE_RECORDS.L00_STG.STG_INTERVALS_STRM_RDV_EXPORT
LIMIT 10;
