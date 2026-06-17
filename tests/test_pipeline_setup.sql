-- Test pipeline: mock DB, seed stage upload, bronze table, and pipe to verify end-to-end flow
-- Co-authored with CoCo
-------------------------------------------------------------------------------------------
-- TEST PIPELINE: Validates the full flow from seed stage → bronze stage → pipe → bronze table
-- 
-- STEPS:
--   1. Run this script to create all mock objects
--   2. Upload items_ref.csv to @TEST_PIPELINE_DB.SEED.SEED_UPLOAD_STG via Snowsight UI
--   3. Run the COPY INTO to move data from seed stage → seed table
--   4. Run the COPY INTO to stage reference data into the bronze stage
--   5. Refresh the pipe to load into the bronze table
--   6. Query the bronze table to verify
-------------------------------------------------------------------------------------------
USE WAREHOUSE COMPUTE_WH;


-------------------------------------------------------------------------------------------
-- 1. CREATE MOCK DATABASE, SCHEMAS
-------------------------------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS TEST_PIPELINE_DB;
CREATE SCHEMA IF NOT EXISTS TEST_PIPELINE_DB.SEED;
CREATE SCHEMA IF NOT EXISTS TEST_PIPELINE_DB.BRONZE;

USE DATABASE TEST_PIPELINE_DB;


-------------------------------------------------------------------------------------------
-- 2. FILE FORMAT (same as production)
-------------------------------------------------------------------------------------------
CREATE OR REPLACE FILE FORMAT BRONZE.TEST_CSV_FMT
    TYPE = 'CSV'
    FIELD_DELIMITER = ','
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    TRIM_SPACE = TRUE
    NULL_IF = ('', 'NULL')
    EMPTY_FIELD_AS_NULL = TRUE
    COMPRESSION = 'AUTO';


-------------------------------------------------------------------------------------------
-- 3. SEED LAYER: Upload stage + seed table
-------------------------------------------------------------------------------------------
CREATE STAGE IF NOT EXISTS SEED.SEED_UPLOAD_STG
    FILE_FORMAT = BRONZE.TEST_CSV_FMT
    COMMENT = 'Upload items_ref.csv here via Snowsight UI.';

CREATE OR REPLACE TABLE SEED.SEED_ITEMS_REF (
    ITEM_ID    NUMBER(38,0) NOT NULL,
    ITEM_NAME  VARCHAR(255)
);


-------------------------------------------------------------------------------------------
-- 4. BRONZE LAYER: Stage + table + pipe
-------------------------------------------------------------------------------------------
CREATE OR REPLACE STAGE BRONZE.REFERENCE_STG
    FILE_FORMAT = BRONZE.TEST_CSV_FMT
    COMMENT = 'Bronze stage for reference data (simulates production REFERENCE_STG).';

CREATE OR REPLACE TABLE BRONZE.ITEMS_REF_BRONZE (
    ITEM_ID         NUMBER(38,0) NOT NULL,
    ITEM_NAME       VARCHAR(255),
    LDTS            TIMESTAMP_NTZ(9) NOT NULL,
    FILE_NAME       VARCHAR(255) NOT NULL,
    FILE_ROW_NUMBER NUMBER(38,0) NOT NULL,
    RSRC            VARCHAR(255) NOT NULL
);

CREATE OR REPLACE PIPE BRONZE.ITEMS_REF_PP
    COMMENT = 'Test pipe: loads items from REFERENCE_STG into ITEMS_REF_BRONZE.'
AS
COPY INTO BRONZE.ITEMS_REF_BRONZE
FROM (
    SELECT
        $1,
        $2,
        CURRENT_TIMESTAMP(),
        METADATA$FILENAME,
        METADATA$FILE_ROW_NUMBER,
        'Test Pipeline'
    FROM @BRONZE.REFERENCE_STG/items_ref
);