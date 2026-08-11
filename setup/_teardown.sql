-------------------------------------------------------------------------------------------
-- FULL TEARDOWN for the whole ELT pipeline: every schema, table, stream, stage, pipe, task,
-- dynamic table, procedure, function, git repository, and Streamlit app living inside
-- LEAGUE_RECORDS. Plus the account-level warehouse and API integration created for the
-- Streamlit apps.
--
-- DO NOT RUN THIS UNLESS YOU TRULY WANT TO TAKE EVERYTHING DOWN!
-------------------------------------------------------------------------------------------
DROP DATABASE IF EXISTS LEAGUE_RECORDS;

DROP WAREHOUSE IF EXISTS STREAMLIT_WH;

DROP INTEGRATION IF EXISTS GITHUB_TOTORI_YOYORI;
