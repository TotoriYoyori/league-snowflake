-------------------------------------------------------------------------------------------
    -- 1. CREATE DATABASE
-------------------------------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS LEAGUE_RECORDS
    COMMENT = 'League of Legends match analytics: medallion architecture on in-game interval snapshots.';


-------------------------------------------------------------------------------------------
    -- 2. CREATE SCHEMAS FOR EACH MEDALLION LAYER
-------------------------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS LEAGUE_RECORDS.BRONZE
    COMMENT = 'Raw ingestion layer: unmodified source data with load metadata.';

CREATE SCHEMA IF NOT EXISTS LEAGUE_RECORDS.SILVER
    COMMENT = 'Cleaned and enriched layer: typed, deduplicated, derived columns.';

CREATE SCHEMA IF NOT EXISTS LEAGUE_RECORDS.GOLD
    COMMENT = 'Analytical layer: aggregated views and summary tables for consumption.';
