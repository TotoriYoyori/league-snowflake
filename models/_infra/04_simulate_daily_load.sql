USE SCHEMA SEED;


-------------------------------------------------------------------------------------------
    -- 1. STAGE_MATCHES_SUMMARY: Extracts one day of matches from seed → stage
-------------------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE SEED.STAGE_MATCHES_SUMMARY(P_GAME_DATE DATE)
RETURNS VARCHAR
LANGUAGE SQL
COMMENT = 'Stages matches_summary rows for a given date into @MATCHES_SUMMARY_STG.'
AS
$$
DECLARE
    v_file_name VARCHAR;
    v_sql       VARCHAR;
    
BEGIN
    v_file_name := 'matches_' || TO_CHAR(:P_GAME_DATE, 'YYYYMMDD') || '.csv';
    v_sql := '
        COPY INTO @BRONZE.MATCHES_SUMMARY_STG/' || :v_file_name || '
        FROM (
            SELECT 
                s.MATCH_ID, 
                s.GAME_DURATION, 
                s.PATCH_VERSION, 
                s.WINNING_TEAM,
                s.GAME_DATE, 
                s.GAME_VERSION, 
                s.GAME_MODE, 
                s.QUEUE_ID,
                s.REGION, 
                s.AVERAGE_RANK, 
                s.BLUE_BANS, 
                s.RED_BANS
            FROM SEED.SEED_MATCHES_SUMMARY s
            JOIN SEED.SEED_MATCH_DATE_INDEX AS idx 
                ON s.MATCH_ID = idx.MATCH_ID
            WHERE idx.GAME_DATE_DAY = ''' || :P_GAME_DATE || '''
        )
        FILE_FORMAT = BRONZE.LEAGUE_CSV_FMT
        HEADER = TRUE
        OVERWRITE = FALSE
        SINGLE = TRUE';

    EXECUTE IMMEDIATE v_sql;

    RETURN 'Staged matches for ' || :P_GAME_DATE || ' → @MATCHES_SUMMARY_STG/' || :v_file_name;
END;
$$;


-------------------------------------------------------------------------------------------
    -- 2. STAGE_PLAYERS_SUMMARY: Extracts players for one day's matches from seed → stage
-------------------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE SEED.STAGE_PLAYERS_SUMMARY(P_GAME_DATE DATE)
RETURNS VARCHAR
LANGUAGE SQL
COMMENT = 'Stages players_summary rows for a given date into @PLAYERS_SUMMARY_STG.'
AS
$$
DECLARE
    v_file_name VARCHAR;
    v_sql       VARCHAR;
    
BEGIN
    v_file_name := 'players_' || TO_CHAR(:P_GAME_DATE, 'YYYYMMDD') || '.csv';
    v_sql := '
        COPY INTO @BRONZE.PLAYERS_SUMMARY_STG/' || :v_file_name || '
        FROM (
            SELECT
                p.ID,
                p.MATCH_ID,
                p.PARTICIPANT_ID,
                p.TEAM_ID,
                p.CHAMPION,
                p.ROLE,
                p.INDIVIDUAL_POSITION
            FROM SEED.SEED_PLAYERS_SUMMARY p
            JOIN SEED.SEED_MATCH_DATE_INDEX idx
                ON p.MATCH_ID = idx.MATCH_ID
            WHERE idx.GAME_DATE_DAY = ''' || :P_GAME_DATE || '''
        )
        FILE_FORMAT = BRONZE.LEAGUE_CSV_FMT
        HEADER    = TRUE
        OVERWRITE = FALSE
        SINGLE    = TRUE';
        
    EXECUTE IMMEDIATE v_sql;
    
    RETURN 'Staged players for ' || :P_GAME_DATE || ' → @PLAYERS_SUMMARY_STG/' || :v_file_name;
END;
$$;

-------------------------------------------------------------------------------------------
    -- 3. STAGE_MATCH_INTERVALS: Extracts intervals for one day's matches from seed → stage
-------------------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE SEED.STAGE_MATCH_INTERVALS(P_GAME_DATE DATE)
RETURNS VARCHAR
LANGUAGE SQL
COMMENT = 'Stages match_intervals rows for a given date into @MATCH_INTERVALS_STG.'
AS
$$
DECLARE
    v_file_name VARCHAR;
    v_sql       VARCHAR;
    
BEGIN
    v_file_name := 'intervals_' || TO_CHAR(:P_GAME_DATE, 'YYYYMMDD') || '.csv';
    v_sql := '
        COPY INTO @BRONZE.MATCH_INTERVALS_STG/' || :v_file_name || '
        FROM (
            SELECT
                i.ID,
                i.MATCH_ID,
                i.PLAYER_ID,
                i.MINUTE,
                i.CURRENT_GOLD,
                i.TOTAL_GOLD,
                i.CS,
                i.JUNGLE_CS,
                i.XP,
                i.LEVEL,
                i.KILLS,
                i.DEATHS,
                i.ASSISTS,
                i.ITEM_0,
                i.ITEM_1,
                i.ITEM_2,
                i.ITEM_3,
                i.ITEM_4,
                i.ITEM_5,
                i.ITEM_6,
                i.TEAM_KILLS,
                i.TEAM_INHIBITORS,
                i.TEAM_TOWERS,
                i.TEAM_DRAGONS_FIRE,
                i.TEAM_DRAGONS_WATER,
                i.TEAM_DRAGONS_EARTH,
                i.TEAM_DRAGONS_AIR,
                i.TEAM_DRAGONS_CHEMTECH,
                i.TEAM_DRAGONS_HEXTECH,
                i.TEAM_DRAGONS,
                i.TEAM_BARONS,
                i.TEAM_VOID_GRUBS,
                i.TEAM_HERALDS,
                i.GOLD_DIFF,
                i.XP_DIFF,
                i.TEAM_GOLD_DIFF
            FROM SEED.SEED_MATCH_INTERVALS i
            JOIN SEED.SEED_MATCH_DATE_INDEX idx
                ON i.MATCH_ID = idx.MATCH_ID
            WHERE idx.GAME_DATE_DAY = ''' || :P_GAME_DATE || '''
        )
        FILE_FORMAT = BRONZE.LEAGUE_CSV_FMT
        HEADER    = TRUE
        OVERWRITE = FALSE
        SINGLE    = TRUE';
        
    EXECUTE IMMEDIATE v_sql;
    
    RETURN 'Staged intervals for ' || :P_GAME_DATE || ' → @MATCH_INTERVALS_STG/' || :v_file_name;
END;
$$;


-------------------------------------------------------------------------------------------
    -- 4. INITIALIZE_SEED_LOAD_STATE: Sets initial date boundaries on first run
-------------------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE SEED.INITIALIZE_SEED_LOAD_STATE()
RETURNS VARCHAR
LANGUAGE SQL
COMMENT = 'Initializes SEED_LOAD_STATE with max/min dates from SEED_MATCH_DATE_INDEX. No-op if already initialized.'
AS
$$
DECLARE
    v_current DATE;
    
BEGIN
    SELECT CURRENT_LOAD_DATE 
    INTO :v_current 
    FROM SEED.SEED_LOAD_STATE 
    LIMIT 1;

    IF (:v_current IS NOT NULL) THEN
        RETURN 'Already initialized. Current date: ' || :v_current;
    END IF;

    UPDATE SEED.SEED_LOAD_STATE
       SET CURRENT_LOAD_DATE = (SELECT MAX(GAME_DATE_DAY) FROM SEED.SEED_MATCH_DATE_INDEX),
           MIN_DATE          = (SELECT MIN(GAME_DATE_DAY) FROM SEED.SEED_MATCH_DATE_INDEX),
           MAX_DATE          = (SELECT MAX(GAME_DATE_DAY) FROM SEED.SEED_MATCH_DATE_INDEX);

    RETURN 'Initialized. Starting from ' || (SELECT MAX(GAME_DATE_DAY) FROM SEED.SEED_MATCH_DATE_INDEX);
END;
$$;


-------------------------------------------------------------------------------------------
    -- 5. ADVANCE_LOAD_STATE: Finds next date descending, advances pointer
-------------------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE SEED.ADVANCE_LOAD_STATE(P_CURRENT_DATE DATE)
RETURNS VARCHAR
LANGUAGE SQL
COMMENT = 'Advances SEED_LOAD_STATE to the next available date below P_CURRENT_DATE (skips gaps).'
AS
$$
DECLARE
    v_next_date DATE;
    v_min_date  DATE;
    
BEGIN
    SELECT MIN_DATE 
    INTO :v_min_date 
    FROM SEED.SEED_LOAD_STATE 
    LIMIT 1;

    SELECT MAX(GAME_DATE_DAY) 
    INTO :v_next_date
    FROM SEED.SEED_MATCH_DATE_INDEX
    WHERE GAME_DATE_DAY < :P_CURRENT_DATE;

    IF (:v_next_date IS NULL) THEN
        v_next_date := DATEADD(DAY, -1, :v_min_date);
    END IF;

    UPDATE SEED.SEED_LOAD_STATE
       SET CURRENT_LOAD_DATE = :v_next_date,
           LAST_LOADED_AT = CURRENT_TIMESTAMP();

    RETURN 'Advanced to ' || :v_next_date || ' (min: ' || :v_min_date || ')';
END;
$$;


-------------------------------------------------------------------------------------------
    -- 6. READ_SEED_LOAD_STATE: Returns current load date, or NULL if exhausted
-------------------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE SEED.READ_SEED_LOAD_STATE()
RETURNS DATE
LANGUAGE SQL
COMMENT = 'Returns CURRENT_LOAD_DATE if data remains, NULL if all dates have been ingested.'
AS
$$
DECLARE
    v_load_date DATE;
    v_min_date  DATE;
    
BEGIN
    SELECT CURRENT_LOAD_DATE, MIN_DATE
    INTO :v_load_date, :v_min_date
    FROM SEED.SEED_LOAD_STATE
    LIMIT 1;

    IF (:v_load_date IS NULL OR :v_load_date < :v_min_date) THEN
        RETURN NULL;
    END IF;

    RETURN :v_load_date;
END;
$$;


-------------------------------------------------------------------------------------------
    -- 7. SIMULATE_DAILY_LOAD: Orchestrator
    --    Calls initialize, reads state, stages all 3 tables, refreshes pipes, advances state.
-------------------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE SEED.SIMULATE_DAILY_LOAD()
RETURNS VARCHAR
LANGUAGE SQL
COMMENT = 'Orchestrates one simulated day: stages all 3 fact tables for the next date (descending), refreshes pipes, advances state.'
AS
$$
DECLARE
    v_load_date DATE;
    v_advance_result VARCHAR;

BEGIN
    CALL SEED.INITIALIZE_SEED_LOAD_STATE();

    CALL SEED.READ_SEED_LOAD_STATE() INTO :v_load_date;
    IF (:v_load_date IS NULL) THEN
        RETURN 'No more data to load. All dates have been ingested.';
    END IF;

    CALL SEED.STAGE_MATCHES_SUMMARY(:v_load_date);
    CALL SEED.STAGE_PLAYERS_SUMMARY(:v_load_date);
    CALL SEED.STAGE_MATCH_INTERVALS(:v_load_date);

    ALTER PIPE BRONZE.MATCHES_SUMMARY_PP REFRESH;
    ALTER PIPE BRONZE.PLAYERS_SUMMARY_PP REFRESH;
    ALTER PIPE BRONZE.MATCH_INTERVALS_PP REFRESH;

    CALL SEED.ADVANCE_LOAD_STATE(:v_load_date) INTO :v_advance_result;

    RETURN 'Loaded date ' || :v_load_date || '. ' || :v_advance_result;
END;
$$;