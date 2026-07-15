-- Deploy role_importance Streamlit app as warehouse runtime
-- Co-authored with CoCo

-- Step 1: Create a stage to hold the app files
CREATE STAGE IF NOT EXISTS LEAGUE_RECORDS.GOLD.ROLE_IMPORTANCE_STAGE
  DIRECTORY = (ENABLE = TRUE)
  COMMENT = 'Stage for Role Importance Streamlit app (warehouse runtime)';

-- Step 2: Upload files via Snowflake CLI (run from your terminal, NOT here):
--
--   cd app/role_importance
--   snow stage copy streamlit_app.py @LEAGUE_RECORDS.GOLD.ROLE_IMPORTANCE_STAGE/ --overwrite
--   snow stage copy environment.yml @LEAGUE_RECORDS.GOLD.ROLE_IMPORTANCE_STAGE/ --overwrite
--   snow stage copy settings.py @LEAGUE_RECORDS.GOLD.ROLE_IMPORTANCE_STAGE/ --overwrite
--   snow stage copy src/ @LEAGUE_RECORDS.GOLD.ROLE_IMPORTANCE_STAGE/src/ --overwrite
--   snow stage copy .streamlit/ @LEAGUE_RECORDS.GOLD.ROLE_IMPORTANCE_STAGE/.streamlit/ --overwrite
--   snow stage copy assets/ @LEAGUE_RECORDS.GOLD.ROLE_IMPORTANCE_STAGE/assets/ --overwrite
--
-- Or via SnowSQL:
--   PUT file://streamlit_app.py @LEAGUE_RECORDS.GOLD.ROLE_IMPORTANCE_STAGE/ AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
--   PUT file://environment.yml @LEAGUE_RECORDS.GOLD.ROLE_IMPORTANCE_STAGE/ AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
--   (etc. for each file/folder)

-- Step 3: Drop existing container-runtime app
DROP STREAMLIT IF EXISTS LEAGUE_RECORDS.GOLD.ROLE_IMPORTANCE;

-- Step 4: Create with warehouse runtime (no RUNTIME_NAME or COMPUTE_POOL)
CREATE STREAMLIT LEAGUE_RECORDS.GOLD.ROLE_IMPORTANCE
  FROM '@LEAGUE_RECORDS.GOLD.ROLE_IMPORTANCE_STAGE'
  MAIN_FILE = 'streamlit_app.py'
  QUERY_WAREHOUSE = COMPUTE_WH
  TITLE = 'LANE GOLD-DIFF WIN COEFFICIENT TRACKER';

-- Step 5: Publish
ALTER STREAMLIT LEAGUE_RECORDS.GOLD.ROLE_IMPORTANCE ADD LIVE VERSION FROM LAST;
