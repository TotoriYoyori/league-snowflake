-------------------------------------------------------------------------------------------
-- RUN ONCE AS ACCOUNTADMIN BEFORE ANYTHING ELSE
-------------------------------------------------------------------------------------------
-- Warehouse
CREATE WAREHOUSE IF NOT EXISTS DV_COMPUTE_WH
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    COMMENT = 'Compute warehouse for data vault transformations';

-- Database (needed before Git integration can reference it)
CREATE DATABASE IF NOT EXISTS LEAGUE_RECORDS
    COMMENT = 'League of Legends match analytics: data vault modeling on in-game interval snapshots.';


-------------------------------------------------------------------------------------------
-- CONNECT PROJECT TO GITHUB
-------------------------------------------------------------------------------------------
-- Git integration
CREATE OR REPLACE API INTEGRATION LEAGUE_GITHUB
    API_PROVIDER = git_https_api
    API_ALLOWED_PREFIXES = ('https://github.com/TotoriYoyori/')
    ENABLED = TRUE;

-- Git repository
CREATE OR REPLACE GIT REPOSITORY LEAGUE_RECORDS.PUBLIC.LEAGUE_REPO
    API_INTEGRATION = LEAGUE_GITHUB
    ORIGIN = 'https://github.com/TotoriYoyori/league-snowflake';


-------------------------------------------------------------------------------------------
-- CONNECT PROJECT TO GITHUB
-------------------------------------------------------------------------------------------
ALTER GIT REPOSITORY LEAGUE_RECORDS.PUBLIC.LEAGUE_REPO FETCH;

-- 6. Run the deploy script from the repo
EXECUTE IMMEDIATE FROM @LEAGUE_RECORDS.PUBLIC.LEAGUE_REPO/branches/main/deploy.sql;