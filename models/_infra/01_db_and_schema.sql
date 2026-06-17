-------------------------------------------------------------------------------------------
    -- 1. CREATE SCHEMAS (database created in setup/01_deploy.sql)
-------------------------------------------------------------------------------------------
USE DATABASE LEAGUE_RECORDS;

CREATE SCHEMA IF NOT EXISTS LEAGUE_RECORDS.SEED
    COMMENT = 'Make-pretend source system: full big CSVs loaded once, as if from a database. Used in simulated ingestion.';

CREATE SCHEMA IF NOT EXISTS LEAGUE_RECORDS.BRONZE
    COMMENT = 'Raw ingestion layer: unmodified source data with load metadata.';

CREATE SCHEMA IF NOT EXISTS LEAGUE_RECORDS.SILVER
    COMMENT = 'Cleaned and enriched layer: typed, deduplicated, derived columns.';

CREATE SCHEMA IF NOT EXISTS LEAGUE_RECORDS.GOLD
    COMMENT = 'Analytical layer: aggregated views and summary tables for consumption.';
