-- Test matches summary: seed upload, simulate daily load with date chunking, pipe into bronze
-- Co-authored with CoCo
-------------------------------------------------------------------------------------------
-- TEST MATCHES SUMMARY PIPELINE
-- Builds on test_pipeline_setup.sql (TEST_PIPELINE_DB must already exist).
--
-- BEFORE RUNNING: Upload matches_summary.csv to @TEST_PIPELINE_DB.SEED.SEED_UPLOAD_STG
-------------------------------------------------------------------------------------------
USE WAREHOUSE COMPUTE_WH;
USE DATABASE TEST_PIPELINE_DB;


-------------------------------------------------------------------------------------------
-- 1. ADDITIONAL SEED OBJECTS: matches seed table + date index + load state
-------------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE SEED.SEED_MATCHES_SUMMARY (
    MATCH_ID        VARCHAR(255) NOT NULL,
    GAME_DURATION   NUMBER(38,0),
    PATCH_VERSION   NUMBER(38,0),
    WINNING_TEAM    NUMBER(38,0),
    GAME_DATE       VARCHAR(255),
    GAME_VERSION    VARCHAR(255),
    GAME_MODE       VARCHAR(255),
    QUEUE_ID        NUMBER(38,0),
    REGION          VARCHAR(255),
    AVERAGE_RANK    VARCHAR(255),
    BLUE_BANS       VARCHAR(255),
    RED_BANS        VARCHAR(255)
);

CREATE OR REPLACE VIEW SEED.SEED_MATCH_DATE_INDEX AS
SELECT
    MATCH_ID,
    DATE(TRY_TO_TIMESTAMP(GAME_DATE)) AS GAME_DATE_DAY
FROM SEED.SEED_MATCHES_SUMMARY
WHERE GAME_DATE IS NOT NULL;

CREATE OR REPLACE TABLE SEED.SEED_LOAD_STATE (
    CURRENT_LOAD_DATE  DATE,
    MIN_DATE           DATE,
    MAX_DATE           DATE,
    LAST_LOADED_AT     TIMESTAMP_NTZ
);

INSERT INTO SEED.SEED_LOAD_STATE VALUES (NULL, NULL, NULL, NULL);


-------------------------------------------------------------------------------------------
-- 2. BRONZE OBJECTS: stage + table + pipe for matches summary
-------------------------------------------------------------------------------------------
CREATE OR REPLACE STAGE BRONZE.MATCHES_SUMMARY_STG
    FILE_FORMAT = BRONZE.TEST_CSV_FMT
    COMMENT = 'Test stage for match summary CSVs.';

CREATE OR REPLACE TABLE BRONZE.MATCHES_SUMMARY_BRONZE (
    MATCH_ID        VARCHAR(255) NOT NULL,
    GAME_DURATION   NUMBER(38,0),
    PATCH_VERSION   NUMBER(38,0),
    WINNING_TEAM    NUMBER(38,0),
    GAME_DATE       VARCHAR(255),
    GAME_VERSION    VARCHAR(255),
    GAME_MODE       VARCHAR(255),
    QUEUE_ID        NUMBER(38,0),
    REGION          VARCHAR(255),
    AVERAGE_RANK    VARCHAR(255),
    BLUE_BANS       VARCHAR(255),
    RED_BANS        VARCHAR(255),
    LDTS            TIMESTAMP_NTZ(9) NOT NULL,
    FILE_NAME       VARCHAR(255) NOT NULL,
    FILE_ROW_NUMBER NUMBER(38,0) NOT NULL,
    RSRC            VARCHAR(255) NOT NULL
);

CREATE OR REPLACE PIPE BRONZE.MATCHES_SUMMARY_PP
    COMMENT = 'Test pipe: loads matches from MATCHES_SUMMARY_STG into MATCHES_SUMMARY_BRONZE.'
AS
COPY INTO BRONZE.MATCHES_SUMMARY_BRONZE
FROM (
    SELECT
        $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12,
        CURRENT_TIMESTAMP(),
        METADATA$FILENAME,
        METADATA$FILE_ROW_NUMBER,
        'Test Pipeline'
    FROM @BRONZE.MATCHES_SUMMARY_STG
);


-------------------------------------------------------------------------------------------
-- 3. ABRIDGED SIMULATE: Staging procedure (matches only)
-------------------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE SEED.TEST_STAGE_MATCHES(P_GAME_DATE DATE)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    v_file_name VARCHAR;
BEGIN
    v_file_name := 'matches_' || TO_CHAR(:P_GAME_DATE, 'YYYYMMDD') || '.csv';

    EXECUTE IMMEDIATE
        'COPY INTO @BRONZE.MATCHES_SUMMARY_STG/' || :v_file_name ||
        ' FROM (' ||
        '  SELECT s.MATCH_ID, s.GAME_DURATION, s.PATCH_VERSION, s.WINNING_TEAM,' ||
        '         s.GAME_DATE, s.GAME_VERSION, s.GAME_MODE, s.QUEUE_ID,' ||
        '         s.REGION, s.AVERAGE_RANK, s.BLUE_BANS, s.RED_BANS' ||
        '  FROM SEED.SEED_MATCHES_SUMMARY s' ||
        '  JOIN SEED.SEED_MATCH_DATE_INDEX idx ON s.MATCH_ID = idx.MATCH_ID' ||
        '  WHERE idx.GAME_DATE_DAY = ''' || :P_GAME_DATE || '''' ||
        ')' ||
        ' FILE_FORMAT = (TYPE = CSV)' ||
        ' HEADER = TRUE' ||
        ' OVERWRITE = FALSE SINGLE = TRUE';

    RETURN 'Staged matches for ' || :P_GAME_DATE || ' → @MATCHES_SUMMARY_STG/' || :v_file_name;
END;
$$;


-------------------------------------------------------------------------------------------
-- 4. ABRIDGED SIMULATE: Orchestrator (matches only)
-------------------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE SEED.TEST_SIMULATE_DAILY_LOAD()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    v_load_date DATE;
    v_min_date DATE;
    v_next_date DATE;
BEGIN
    SELECT CURRENT_LOAD_DATE, MIN_DATE
      INTO :v_load_date, :v_min_date
      FROM SEED.SEED_LOAD_STATE
      LIMIT 1;

    -- Initialize on first run
    IF (:v_load_date IS NULL) THEN
        SELECT MAX(GAME_DATE_DAY), MIN(GAME_DATE_DAY)
          INTO :v_load_date, :v_min_date
          FROM SEED.SEED_MATCH_DATE_INDEX;

        UPDATE SEED.SEED_LOAD_STATE
           SET CURRENT_LOAD_DATE = :v_load_date,
               MIN_DATE = :v_min_date,
               MAX_DATE = :v_load_date;
    END IF;

    -- Check exhaustion
    IF (:v_load_date < :v_min_date) THEN
        RETURN 'No more data. All dates down to ' || :v_min_date || ' have been ingested.';
    END IF;

    -- Stage matches for current date
    CALL TEST_STAGE_MATCHES(:v_load_date);

    -- Refresh pipe
    ALTER PIPE BRONZE.MATCHES_SUMMARY_PP REFRESH;

    -- Find next date descending
    SELECT MAX(GAME_DATE_DAY)
      INTO :v_next_date
      FROM SEED.SEED_MATCH_DATE_INDEX
      WHERE GAME_DATE_DAY < :v_load_date;

    IF (:v_next_date IS NULL) THEN
        v_next_date := DATEADD(DAY, -1, :v_min_date);
    END IF;

    -- Advance state
    UPDATE SEED.SEED_LOAD_STATE
       SET CURRENT_LOAD_DATE = :v_next_date,
           LAST_LOADED_AT = CURRENT_TIMESTAMP();

    RETURN 'Loaded date ' || :v_load_date || '. Next: ' || :v_next_date || ' (min: ' || :v_min_date || ').';
END;
$$;
