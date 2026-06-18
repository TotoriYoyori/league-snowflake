USE SCHEMA SEED;

-------------------------------------------------------------------------------------------
-- VALIDATE_SEED_UPLOAD: Checks that all required files exist in SEED_UPLOAD_STG
-- before proceeding with COPY INTO. Raises an exception if any are missing.
--
-- Expected file prefixes:
--   matches_summary, players_summary, intervals, items_ref, champions_ref
-------------------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE SEED.VALIDATE_SEED_UPLOAD()
RETURNS VARCHAR
LANGUAGE SQL
COMMENT = 'Guards seed ingestion by verifying all required CSV files exist in @SEED.SEED_UPLOAD_STG.'
AS
$$
DECLARE
    v_missing ARRAY DEFAULT ARRAY_CONSTRUCT();
    v_count   NUMBER;

BEGIN
    -- Check matches_summary
    SELECT COUNT(*) INTO :v_count
    FROM DIRECTORY(@SEED.SEED_UPLOAD_STG)
    WHERE RELATIVE_PATH ILIKE 'matches_summary%';
    IF (:v_count = 0) THEN
        v_missing := ARRAY_APPEND(:v_missing, 'matches_summary');
    END IF;

    -- Check players_summary
    SELECT COUNT(*) INTO :v_count
    FROM DIRECTORY(@SEED.SEED_UPLOAD_STG)
    WHERE RELATIVE_PATH ILIKE 'players_summary%';
    IF (:v_count = 0) THEN
        v_missing := ARRAY_APPEND(:v_missing, 'players_summary');
    END IF;

    -- Check intervals
    SELECT COUNT(*) INTO :v_count
    FROM DIRECTORY(@SEED.SEED_UPLOAD_STG)
    WHERE RELATIVE_PATH ILIKE 'intervals%';
    IF (:v_count = 0) THEN
        v_missing := ARRAY_APPEND(:v_missing, 'intervals');
    END IF;

    -- Check items_ref
    SELECT COUNT(*) INTO :v_count
    FROM DIRECTORY(@SEED.SEED_UPLOAD_STG)
    WHERE RELATIVE_PATH ILIKE 'items_ref%';
    IF (:v_count = 0) THEN
        v_missing := ARRAY_APPEND(:v_missing, 'items_ref');
    END IF;

    -- Check champions_ref
    SELECT COUNT(*) INTO :v_count
    FROM DIRECTORY(@SEED.SEED_UPLOAD_STG)
    WHERE RELATIVE_PATH ILIKE 'champions_ref%';
    IF (:v_count = 0) THEN
        v_missing := ARRAY_APPEND(:v_missing, 'champions_ref');
    END IF;

    -- Halt if any missing (deliberate error to stop calling script)
    IF (ARRAY_SIZE(:v_missing) > 0) THEN
        LET v_msg VARCHAR := 'MISSING_FILES___' || ARRAY_TO_STRING(:v_missing, '__');
        EXECUTE IMMEDIATE 'SELECT * FROM ' || :v_msg;
    END IF;

    RETURN 'All required files present in @SEED.SEED_UPLOAD_STG.';
END;
$$;
