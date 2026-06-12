-------------------------------------------------------------------------------------------
    -- 0. DECLARE WORKING CONTEXT
-------------------------------------------------------------------------------------------
USE DATABASE LEAGUE_RECORDS;

USE SCHEMA L00_STG;


-------------------------------------------------------------------------------------------
    -- UTILITY FUNCTIONS 
-------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION FASTHASH("TXT" VARCHAR)
RETURNS BINARY
LANGUAGE SQL
COMMENT = 'Returns a SHA1 binary hash of the input text after trimming whitespace and converting to uppercase.'
AS
$$
    SHA1_BINARY(UPPER(TRIM(TXT)))
$$;

CREATE OR REPLACE FUNCTION TRIHASH(STR1 VARCHAR, STR2 VARCHAR, STR3 VARCHAR)
RETURNS BINARY
LANGUAGE SQL
COMMENT = 'Hashes three concatenated strings (joined by "^") into a single SHA1 binary.'
AS
$$
    FASTHASH(ARRAY_TO_STRING(ARRAY_CONSTRUCT(
        TRIM(STR1),
        TRIM(STR2),
        TRIM(STR3)
    ), '^'))
$$;


-------------------------------------------------------------------------------------------
    -- UTILITY PROCEDURES
-------------------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE EXAMINE_STAGING_HISTORY(
    TABLE_NAME_ARG VARCHAR, 
    N_DAYS INT
)
RETURNS TABLE (
    FILE_NAME VARCHAR,
    STAGE_LOCATION VARCHAR,
    LAST_LOAD_TIME TIMESTAMP_LTZ,
    ROW_COUNT NUMBER
)
LANGUAGE SQL
COMMENT = 'Returns copy history for a given table over the last N days.'
AS
$$
BEGIN
    LET rs RESULTSET := (
        SELECT 
            FILE_NAME::VARCHAR AS FILE_NAME, 
            STAGE_LOCATION::VARCHAR AS STAGE_LOCATION, 
            LAST_LOAD_TIME::TIMESTAMP_LTZ AS LAST_LOAD_TIME, 
            ROW_COUNT::NUMBER AS ROW_COUNT
        FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
            TABLE_NAME => :TABLE_NAME_ARG,
            START_TIME => DATEADD('day', -:N_DAYS, CURRENT_TIMESTAMP())
        ))
    );
    RETURN TABLE(rs);
END;
$$;
