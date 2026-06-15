-------------------------------------------------------------------------------------------
    -- 0. DECLARE WORKING CONTEXT
-------------------------------------------------------------------------------------------
USE DATABASE LEAGUE_RECORDS;

USE SCHEMA L00_STG;


-------------------------------------------------------------------------------------------
    -- 1. SIMULATE_DAILY_LOAD: Deposits the next chunk from SEED_INTERVALS
    --    into @DAILY_MATCH_STG as match_<datetime>.csv, then refreshes the pipe.
    --    Each call simulates one day of ingestion (~20,000 rows).
-------------------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE SIMULATE_DAILY_LOAD()
RETURNS VARCHAR
LANGUAGE SQL
COMMENT = 'Simulates one day of ingestion by copying the next chunk from SEED_INTERVALS to @DAILY_MATCH_STG.'
AS
$$
DECLARE
    v_offset NUMBER;
    v_chunk_size NUMBER;
    v_total_rows NUMBER;
    v_file_name VARCHAR;
    v_rows_copied NUMBER;
BEGIN
    -- Get current state
    SELECT CURRENT_OFFSET, CHUNK_SIZE
      INTO :v_offset, :v_chunk_size
      FROM SEED_LOAD_STATE
      LIMIT 1;

    -- Check if we've exhausted the seed data
    SELECT COUNT(*) INTO :v_total_rows FROM SEED_INTERVALS;
    IF (:v_offset >= :v_total_rows) THEN
        RETURN 'No more data to load. All ' || :v_total_rows || ' rows have been chunked.';
    END IF;

    -- Generate file name with current timestamp
    v_file_name := 'match_' || TO_CHAR(CURRENT_TIMESTAMP(), 'YYYYMMDD_HH24MISS') || '.csv';

    -- Copy chunk to @DAILY_MATCH_STG
    EXECUTE IMMEDIATE
        'COPY INTO @DAILY_MATCH_STG/' || :v_file_name ||
        ' FROM (SELECT MATCH_ID, ID, PLAYER_ID, MINUTE,' ||
        ' CURRENT_GOLD, TOTAL_GOLD, CS, JUNGLE_CS, XP, LEVEL,' ||
        ' KILLS, DEATHS, ASSISTS,' ||
        ' ITEM_0, ITEM_1, ITEM_2, ITEM_3, ITEM_4, ITEM_5, ITEM_6,' ||
        ' TEAM_KILLS, TEAM_INHIBITORS, TEAM_TOWERS,' ||
        ' TEAM_DRAGONS_FIRE, TEAM_DRAGONS_WATER, TEAM_DRAGONS_EARTH, TEAM_DRAGONS_AIR,' ||
        ' TEAM_DRAGONS_CHEMTECH, TEAM_DRAGONS_HEXTECH, TEAM_DRAGONS,' ||
        ' TEAM_BARONS, TEAM_VOID_GRUBS, TEAM_HERALDS,' ||
        ' GOLD_DIFF, XP_DIFF, TEAM_GOLD_DIFF' ||
        ' FROM SEED_INTERVALS ORDER BY ID LIMIT ' || :v_chunk_size ||
        ' OFFSET ' || :v_offset || ')' ||
        ' FILE_FORMAT = (TYPE = CSV HEADER = TRUE)' ||
        ' OVERWRITE = FALSE SINGLE = TRUE';

    -- Update state
    UPDATE SEED_LOAD_STATE
       SET CURRENT_OFFSET = :v_offset + :v_chunk_size,
           LAST_LOADED_AT = CURRENT_TIMESTAMP();

    -- Refresh pipe to trigger ingestion
    ALTER PIPE DAILY_MATCH_PP REFRESH;

    v_rows_copied := LEAST(:v_chunk_size, :v_total_rows - :v_offset);
    RETURN 'Loaded ' || :v_rows_copied || ' rows into @DAILY_MATCH_STG/' || :v_file_name ||
           '. Offset now at ' || (:v_offset + :v_chunk_size) || '/' || :v_total_rows || '.';
END;
$$;
