USE SCHEMA SEED;

-------------------------------------------------------------------------------------------
-- VALIDATE_SEED_UPLOAD: Checks that each required file exists exactly once in
-- SEED_UPLOAD_STG before proceeding with COPY INTO. Raises an exception if any prefix has
-- zero matches (missing) or more than one match. Zero-byte files are excluded as well.
--
-- Expected file prefixes:
--   matches_summary, players_summary, intervals, items_ref, champions_ref
-------------------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE SEED.VALIDATE_SEED_UPLOAD()
RETURNS VARCHAR
LANGUAGE SQL
COMMENT = 'Guards seed ingestion by verifying all required CSV files exist exactly once in @SEED.SEED_UPLOAD_STG.'
AS
$$
DECLARE
    v_missing   ARRAY DEFAULT ARRAY_CONSTRUCT();
    v_ambiguous ARRAY DEFAULT ARRAY_CONSTRUCT();

BEGIN
    WITH EXPECTED_PREFIXES AS (
        SELECT * FROM VALUES
            ('matches_summary'),
            ('players_summary'),
            ('intervals'),
            ('items_ref'),
            ('champions_ref')
        AS T(PREFIX)
    ),
    PREFIX_COUNTS AS (
        SELECT
            P.PREFIX,
            COUNT(D.RELATIVE_PATH) AS FILE_COUNT
        FROM EXPECTED_PREFIXES AS P
        LEFT JOIN DIRECTORY(@SEED.SEED_UPLOAD_STG) AS D
            ON D.RELATIVE_PATH ILIKE P.PREFIX || '%'
            AND D.SIZE > 0
        GROUP BY P.PREFIX
    )
    SELECT
        (SELECT ARRAY_AGG(PREFIX) WITHIN GROUP (ORDER BY PREFIX)
         FROM PREFIX_COUNTS WHERE FILE_COUNT = 0),
        (SELECT ARRAY_AGG(PREFIX || '_' || FILE_COUNT || 'FILES') WITHIN GROUP (ORDER BY PREFIX)
         FROM PREFIX_COUNTS WHERE FILE_COUNT > 1)
    INTO :v_missing, :v_ambiguous;

    -- Halt if anything is missing or ambiguous (deliberate error to stop calling script)
    IF (COALESCE(ARRAY_SIZE(:v_missing), 0) > 0 OR COALESCE(ARRAY_SIZE(:v_ambiguous), 0) > 0) THEN
        LET v_msg VARCHAR :=
            'MISSING_FILES___' || ARRAY_TO_STRING(COALESCE(:v_missing, ARRAY_CONSTRUCT()), '__')
            || '___AMBIGUOUS_FILES___' || ARRAY_TO_STRING(COALESCE(:v_ambiguous, ARRAY_CONSTRUCT()), '__');
        EXECUTE IMMEDIATE 'SELECT * FROM ' || :v_msg;
    END IF;

    RETURN 'All required files present exactly once in @SEED.SEED_UPLOAD_STG.';
END;
$$;
