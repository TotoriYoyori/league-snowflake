USE SCHEMA BRONZE;


-------------------------------------------------------------------------------------------
    -- 1. SHARED FILE FORMAT FOR ALL CSV INGESTION IN BRONZE STAGE
-------------------------------------------------------------------------------------------
CREATE OR REPLACE FILE FORMAT BRONZE.LEAGUE_CSV_FMT
    TYPE = 'CSV'
    FIELD_DELIMITER = ','
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    TRIM_SPACE = TRUE
    NULL_IF = ('', 'NULL')
    EMPTY_FIELD_AS_NULL = TRUE
    COMPRESSION = 'AUTO';
