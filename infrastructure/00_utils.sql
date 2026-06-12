-------------------------------------------------------------------------------------------
    -- 0. DECLARE WORKING CONTEXT
-------------------------------------------------------------------------------------------
USE DATABASE LEAGUE_RECORDS;

USE SCHEMA PUBLIC;


-------------------------------------------------------------------------------------------
    -- PROCEDURES
-------------------------------------------------------------------------------------------
CREATE PROCEDURE EXAMINE_DB_SCHEMAS(DB_NAME VARCHAR)
RETURNS TABLE (
    NAME VARCHAR, 
    COMMENT VARCHAR, 
    CREATED_ON TIMESTAMP_LTZ
)
LANGUAGE SQL
COMMENT = 'Lists all schemas in the given database with their name, comment, and creation time.'
AS
  $$
    BEGIN
      SHOW SCHEMAS IN DATABASE IDENTIFIER(:DB_NAME);
      LET rs RESULTSET := (
        SELECT 
            "name"::VARCHAR AS NAME, 
            "comment"::VARCHAR AS COMMENT, 
            "created_on"::TIMESTAMP_LTZ AS CREATED_ON
        FROM TABLE(
            RESULT_SCAN(LAST_QUERY_ID())
        )
      );
      RETURN TABLE(rs);
    END;
  $$;
