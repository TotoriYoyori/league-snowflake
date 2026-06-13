-------------------------------------------------------------------------------------------
    -- 1. UPLOAD LOCAL CSV AND COPY INTO STAGING TABLE
-------------------------------------------------------------------------------------------
PUT file:///path/to/match_intervals.csv @DAILY_MATCH_AZSTG
    AUTO_COMPRESS = TRUE
    OVERWRITE = TRUE;

COPY INTO STG_INTERVALS
FROM @DAILY_MATCH_AZSTG
FILE_FORMAT = (FORMAT_NAME = 'DAILY_MATCH_FMT')
ON_ERROR = 'CONTINUE';


-------------------------------------------------------------------------------------------
    -- 2. VERIFY LOAD
-------------------------------------------------------------------------------------------
CALL EXAMINE_STAGING_HISTORY('STG_INTERVALS', 1);
