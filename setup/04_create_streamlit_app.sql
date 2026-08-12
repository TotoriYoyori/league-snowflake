-------------------------------------------------------------------------------------------
-- 00. CREATE DEDICATED STREAMLIT WAREHOUSE
-------------------------------------------------------------------------------------------
CREATE WAREHOUSE IF NOT EXISTS STREAMLIT_WH
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Dedicated warehouse for Streamlit app execution';


-------------------------------------------------------------------------------------------
-- 01. READ-ONLY API INTEGRATIONS
-------------------------------------------------------------------------------------------
CREATE API INTEGRATION IF NOT EXISTS GITHUB_TOTORI_YOYORI
    API_PROVIDER = git_https_api
    API_ALLOWED_PREFIXES = ('https://github.com/TotoriYoyori')
    ENABLED = TRUE;


-------------------------------------------------------------------------------------------
-- 02. CREATE GIT REPOSITORIES FOR ALL THREE APPS (all /TotoriYoyori repos)
-------------------------------------------------------------------------------------------
CREATE GIT REPOSITORY IF NOT EXISTS LEAGUE_RECORDS.GOLD.ROLE_IMPORTANCE_ST_REPO
    API_INTEGRATION = GITHUB_TOTORI_YOYORI
    ORIGIN = 'https://github.com/TotoriYoyori/league-snowflake-role-importance.git';

CREATE GIT REPOSITORY IF NOT EXISTS LEAGUE_RECORDS.GOLD.ITEM_BROWSER_ST_REPO
    API_INTEGRATION = GITHUB_TOTORI_YOYORI
    ORIGIN = 'https://github.com/TotoriYoyori/league-snowflake-item-browser.git';

-- !!! OUTDATED - NO LONGER DEPLOYED (2026/08/12, USE PER-LAYER MONITORING NOTEBOOKS OR HEALTH_CHECKS.SQL) !!!
-- CREATE GIT REPOSITORY IF NOT EXISTS LEAGUE_RECORDS.GOLD.PIPELINE_MONITOR_ST_REPO
--     API_INTEGRATION = GITHUB_TOTORI_YOYORI
--     ORIGIN = 'https://github.com/TotoriYoyori/league-snowflake-pipeline-monitor.git';


-------------------------------------------------------------------------------------------
-- 03. FETCH FROM ALL THREE
-------------------------------------------------------------------------------------------
ALTER GIT REPOSITORY LEAGUE_RECORDS.GOLD.ROLE_IMPORTANCE_ST_REPO FETCH;
ALTER GIT REPOSITORY LEAGUE_RECORDS.GOLD.ITEM_BROWSER_ST_REPO FETCH;

-- ALTER GIT REPOSITORY LEAGUE_RECORDS.GOLD.PIPELINE_MONITOR_ST_REPO FETCH;


-------------------------------------------------------------------------------------------
-- 04. DEPLOY STREAMLIT APP FROM EACH
-------------------------------------------------------------------------------------------
----- Logit Role Importance
CREATE OR REPLACE STREAMLIT LEAGUE_RECORDS.GOLD.ROLE_IMPORTANCE
    FROM @LEAGUE_RECORDS.GOLD.ROLE_IMPORTANCE_ST_REPO/branches/snowflake/
    MAIN_FILE = 'streamlit_app.py'
    QUERY_WAREHOUSE = STREAMLIT_WH
    TITLE = 'LANE GOLD-DIFF WIN COEFFICIENT TRACKER';

ALTER STREAMLIT LEAGUE_RECORDS.GOLD.ROLE_IMPORTANCE ADD LIVE VERSION FROM LAST;

----- Item Browser
CREATE OR REPLACE STREAMLIT LEAGUE_RECORDS.GOLD.ITEM_BROWSER
    FROM @LEAGUE_RECORDS.GOLD.ITEM_BROWSER_ST_REPO/branches/snowflake/
    MAIN_FILE = 'streamlit_app.py'
    QUERY_WAREHOUSE = STREAMLIT_WH
    TITLE = 'ITEMS EXPLORER';

ALTER STREAMLIT LEAGUE_RECORDS.GOLD.ITEM_BROWSER ADD LIVE VERSION FROM LAST;

-- !!! OUTDATED - NO LONGER DEPLOYED (2026/08/12, USE PER-LAYER MONITORING NOTEBOOKS OR HEALTH_CHECKS.SQL) !!!
-- CREATE OR REPLACE STREAMLIT LEAGUE_RECORDS.GOLD.PIPELINE_MONITOR
--     FROM @LEAGUE_RECORDS.GOLD.PIPELINE_MONITOR_ST_REPO/branches/snowflake/
--     MAIN_FILE = 'streamlit_app.py'
--     QUERY_WAREHOUSE = STREAMLIT_WH
--     TITLE = 'PIPELINE MONITORING DASHBOARD';

-- ALTER STREAMLIT LEAGUE_RECORDS.GOLD.PIPELINE_MONITOR ADD LIVE VERSION FROM LAST;
