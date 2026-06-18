-------------------------------------------------------------------------------------------
    -- 1. CREATE SCHEMAS (database set by the calling deploy script)
-------------------------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS SEED
    COMMENT = 'Make-pretend source system: full big CSVs loaded once, as if from a database. Used in simulated ingestion.';

CREATE SCHEMA IF NOT EXISTS BRONZE
    COMMENT = 'Raw ingestion layer: unmodified source data with load metadata.';

CREATE SCHEMA IF NOT EXISTS SILVER
    COMMENT = 'Cleaned and enriched layer: typed, deduplicated, derived columns.';

CREATE SCHEMA IF NOT EXISTS GOLD
    COMMENT = 'Analytical layer: aggregated views and summary tables for consumption.';
