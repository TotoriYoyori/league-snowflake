-- Test seeding workflow: create mock objects, PUT a CSV, COPY INTO, and verify
-- Co-authored with CoCo
-------------------------------------------------------------------------------------------
-- TEST SEEDING: Validates that PUT + COPY INTO works with your local file path
-- Run this AFTER 01_deploy.sql to confirm your environment can upload CSVs.
-------------------------------------------------------------------------------------------
USE WAREHOUSE COMPUTE_WH;


-------------------------------------------------------------------------------------------
-- 1. CREATE MOCK OBJECTS
-------------------------------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS TEST_SEED_DB;
CREATE SCHEMA IF NOT EXISTS TEST_SEED_DB.TEST_SEED;

CREATE OR REPLACE TABLE TEST_SEED_DB.TEST_SEED.MOCK_ITEMS_REF (
    ITEM_ID    NUMBER(38,0) NOT NULL,
    ITEM_NAME  VARCHAR(255)
);


-------------------------------------------------------------------------------------------
-- 2. PUT LOCAL CSV INTO TABLE STAGE
-------------------------------------------------------------------------------------------
PUT 'file://C:/postgres_staging/league/items_ref.csv'
    @TEST_SEED_DB.TEST_SEED.%MOCK_ITEMS_REF
    AUTO_COMPRESS = TRUE
    OVERWRITE = TRUE;


-------------------------------------------------------------------------------------------
-- 3. COPY INTO TABLE
-------------------------------------------------------------------------------------------
COPY INTO TEST_SEED_DB.TEST_SEED.MOCK_ITEMS_REF
    FILE_FORMAT = (
        TYPE = CSV
        FIELD_DELIMITER = ','
        SKIP_HEADER = 1
        FIELD_OPTIONALLY_ENCLOSED_BY = '"'
        TRIM_SPACE = TRUE
        NULL_IF = ('', 'NULL')
        EMPTY_FIELD_AS_NULL = TRUE
        COMPRESSION = AUTO
    );


-------------------------------------------------------------------------------------------
-- 4. VERIFY
-------------------------------------------------------------------------------------------
SELECT COUNT(*) AS ROW_COUNT FROM TEST_SEED_DB.TEST_SEED.MOCK_ITEMS_REF;
SELECT * FROM TEST_SEED_DB.TEST_SEED.MOCK_ITEMS_REF LIMIT 10;
