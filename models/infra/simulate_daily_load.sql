-------------------------------------------------------------------------------------------
    -- 0. DECLARE WORKING CONTEXT
-------------------------------------------------------------------------------------------
USE DATABASE LEAGUE_RECORDS;

USE SCHEMA BRONZE;


-------------------------------------------------------------------------------------------
    -- 1. SIMULATE_DAILY_LOAD: Deposits the next batch of matches from SEED_INTERVALS
    --    into @MATCH_INTERVAL_STG as match_<datetime>.csv, then refreshes the pipe.
    --    Each call simulates one day of ingestion (~1000 matches).
-------------------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE SIMULATE_DAILY_LOAD()
RETURNS VARCHAR
LANGUAGE SQL
COMMENT = 'Simulates one day of ingestion by copying the next 1000 matches from SEED_INTERVALS to @MATCH_INTERVAL_STG.'
AS
$$
DECLARE
    v_offset NUMBER;
    v_batch_size NUMBER;
    v_total_matches NUMBER;
    v_file_name VARCHAR;
    v_rows_copied NUMBER;
BEGIN
    -- Get current state
    SELECT CURRENT_MATCH_OFFSET, MATCHES_PER_BATCH
      INTO :v_offset, :v_batch_size
      FROM SEED_LOAD_STATE
      LIMIT 1;

    -- Check if we've exhausted the seed data
    SELECT COUNT(*) INTO :v_total_matches FROM SEED_MATCH_INDEX;
    IF (:v_offset >= :v_total_matches) THEN
        RETURN 'No more data to load. All ' || :v_total_matches || ' matches have been chunked.';
    END IF;

    -- Generate file name with current timestamp
    v_file_name := 'match_' || TO_CHAR(CURRENT_TIMESTAMP(), 'YYYYMMDD_HH24MISS') || '.csv';

    -- Copy chunk to @MATCH_INTERVAL_STG (all rows for the next batch of matches)
    EXECUTE IMMEDIATE
        'COPY INTO @MATCH_INTERVAL_STG/' || :v_file_name ||
        ' FROM (SELECT s.ID, s.MATCH_ID, s.PLAYER_ID, s.MINUTE,' ||
        ' s.CURRENT_GOLD, s.TOTAL_GOLD, s.CS, s.JUNGLE_CS, s.XP, s.LEVEL,' ||
        ' s.KILLS, s.DEATHS, s.ASSISTS,' ||
        ' s.ITEM_0, s.ITEM_1, s.ITEM_2, s.ITEM_3, s.ITEM_4, s.ITEM_5, s.ITEM_6,' ||
        ' s.TEAM_KILLS, s.TEAM_INHIBITORS, s.TEAM_TOWERS,' ||
        ' s.TEAM_DRAGONS_FIRE, s.TEAM_DRAGONS_WATER, s.TEAM_DRAGONS_EARTH, s.TEAM_DRAGONS_AIR,' ||
        ' s.TEAM_DRAGONS_CHEMTECH, s.TEAM_DRAGONS_HEXTECH, s.TEAM_DRAGONS,' ||
        ' s.TEAM_BARONS, s.TEAM_VOID_GRUBS, s.TEAM_HERALDS,' ||
        ' s.GOLD_DIFF, s.XP_DIFF, s.TEAM_GOLD_DIFF' ||
        ' FROM SEED_INTERVALS s' ||
        ' JOIN SEED_MATCH_INDEX m ON s.MATCH_ID = m.MATCH_ID' ||
        ' WHERE m.MATCH_SEQ >= ' || :v_offset ||
        ' AND m.MATCH_SEQ < ' || (:v_offset + :v_batch_size) || ')' ||
        ' FILE_FORMAT = (TYPE = CSV HEADER = TRUE)' ||
        ' OVERWRITE = FALSE SINGLE = TRUE';

    -- Update state
    UPDATE SEED_LOAD_STATE
       SET CURRENT_MATCH_OFFSET = :v_offset + :v_batch_size,
           LAST_LOADED_AT = CURRENT_TIMESTAMP();

    -- Refresh pipe to trigger ingestion
    ALTER PIPE MATCH_INTERVAL_PP REFRESH;

    RETURN 'Loaded matches ' || :v_offset || '-' || (:v_offset + :v_batch_size - 1) ||
           ' into @MATCH_INTERVAL_STG/' || :v_file_name ||
           '. Match offset now at ' || (:v_offset + :v_batch_size) || '/' || :v_total_matches || '.';
END;
$$;
