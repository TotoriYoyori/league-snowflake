USE SCHEMA BRONZE;


-------------------------------------------------------------------------------------------
    -- 1. BRONZE TABLE: Items reference lookup
-------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS BRONZE.ITEMS_REF_BRONZE (
    ITEM_ID       VARCHAR NOT NULL,
    ITEM_NAME     VARCHAR,
    ITEM_CATEGORY VARCHAR,
    -- Load Metadata
    LDTS            TIMESTAMP_NTZ(9) NOT NULL,
    FILE_NAME       VARCHAR(255) NOT NULL,
    FILE_ROW_NUMBER NUMBER(38,0) NOT NULL,
    RSRC            VARCHAR(255) NOT NULL,
    -- Constraints
    CONSTRAINT ITEMS_REF_BRONZE_PKEY PRIMARY KEY (ITEM_ID)
)
COMMENT = '[BRONZE] Item reference lookup. Loaded via ITEMS_REF_PP from @ITEMS_REF_STG.';


-------------------------------------------------------------------------------------------
    -- 2. STREAM: CDC for silver consumption
-------------------------------------------------------------------------------------------
CREATE STREAM IF NOT EXISTS BRONZE.ITEMS_REF_BRONZE_STM
    ON TABLE BRONZE.ITEMS_REF_BRONZE
    COMMENT = 'ITEMS_REF_BRONZE delta --> BRONZE_TO_SILVER_ITEMS_TASK --> ITEMS_REF_SILVER';


-------------------------------------------------------------------------------------------
    -- 3. STAGE: Internal stage for items reference CSV
-------------------------------------------------------------------------------------------
CREATE STAGE IF NOT EXISTS BRONZE.ITEMS_REF_STG
    FILE_FORMAT = BRONZE.LEAGUE_CSV_FMT
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Stage for item reference CSV. Expected file: items_ref.csv';

-------------------------------------------------------------------------------------------
    -- 4. PIPE: Ingest from stage into bronze table
-------------------------------------------------------------------------------------------
CREATE PIPE IF NOT EXISTS BRONZE.ITEMS_REF_PP
COMMENT = 'Item reference lookup. Ingest frequency --> Every patch updates.'
AS
COPY INTO BRONZE.ITEMS_REF_BRONZE
FROM (
    SELECT
        $1,  -- item_id
        $2,  -- item_name
        $3,  -- item_category
        CURRENT_TIMESTAMP(),
        METADATA$FILENAME,
        METADATA$FILE_ROW_NUMBER,
        'League Static Data'
    FROM @BRONZE.ITEMS_REF_STG
)
ON_ERROR = 'SKIP_FILE_10%';


-------------------------------------------------------------------------------------------
    -- 5. _ITEMS_REF_LOAD_ERRORS: audit view over this pipe's COPY_HISTORY.
-------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW BRONZE._ITEMS_REF_LOAD_ERRORS AS
SELECT
    FILE_NAME,
    LAST_LOAD_TIME,
    ROW_COUNT,
    (ROW_PARSED - ROW_COUNT) AS ROWS_REJECTED,
    ERROR_COUNT,
    FIRST_ERROR_MESSAGE
FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
    TABLE_NAME => 'BRONZE.ITEMS_REF_BRONZE',
    START_TIME => DATEADD(DAY, -30, CURRENT_TIMESTAMP())
))
WHERE ERROR_COUNT > 0;
