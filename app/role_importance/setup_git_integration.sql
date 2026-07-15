-- ============================================================
-- Step 1: Create API integration (read-and-fetch only)
-- ============================================================
CREATE API INTEGRATION IF NOT EXISTS GITHUB_TOTORI_YOYORI
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/TotoriYoyori')
  ENABLED = TRUE;

-- ============================================================
-- Step 2: Create Git repository stage
-- ============================================================
CREATE GIT REPOSITORY IF NOT EXISTS LEAGUE_RECORDS.GOLD.LEAGUE_SNOWFLAKE_REPO
  API_INTEGRATION = GITHUB_TOTORI_YOYORI
  ORIGIN = 'https://github.com/TotoriYoyori/league-snowflake.git';

-- ============================================================
-- Step 3: Fetch latest commits
-- ============================================================
ALTER GIT REPOSITORY LEAGUE_RECORDS.GOLD.LEAGUE_SNOWFLAKE_REPO FETCH;

-- ============================================================
-- Step 4: Deploy the Streamlit app (warehouse runtime)
-- ============================================================
CREATE OR REPLACE STREAMLIT LEAGUE_RECORDS.GOLD.ROLE_IMPORTANCE
  FROM @LEAGUE_RECORDS.GOLD.LEAGUE_SNOWFLAKE_REPO/branches/main/app/role_importance/
  MAIN_FILE = 'streamlit_app.py'
  QUERY_WAREHOUSE = COMPUTE_WH
  TITLE = 'LANE GOLD-DIFF WIN COEFFICIENT TRACKER';

ALTER STREAMLIT LEAGUE_RECORDS.GOLD.ROLE_IMPORTANCE ADD LIVE VERSION FROM LAST;

-- ============================================================
-- UPDATING THE APP (after new commits are pushed to main)
-- ============================================================
-- ALTER GIT REPOSITORY LEAGUE_RECORDS.GOLD.LEAGUE_SNOWFLAKE_REPO FETCH;
-- ALTER STREAMLIT LEAGUE_RECORDS.GOLD.ROLE_IMPORTANCE PULL;
