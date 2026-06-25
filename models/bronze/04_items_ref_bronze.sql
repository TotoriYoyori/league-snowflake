USE SCHEMA BRONZE;


-------------------------------------------------------------------------------------------
    -- 1. BRONZE TABLE: Items reference lookup
-------------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE BRONZE.ITEMS_REF_BRONZE (
    ITEM_ID       NUMBER(38,0) NOT NULL,
    ITEM_NAME     VARCHAR(255),
    ITEM_CATEGORY VARCHAR(255),
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
CREATE OR REPLACE STREAM BRONZE.ITEMS_REF_BRONZE_STM
    ON TABLE BRONZE.ITEMS_REF_BRONZE
    COMMENT = 'ITEMS_REF_BRONZE delta --> BRONZE_TO_SILVER_ITEMS_TASK --> ITEMS_REF_SILVER';


-------------------------------------------------------------------------------------------
    -- 3. STAGE: Internal stage for items reference CSV
-------------------------------------------------------------------------------------------
CREATE OR REPLACE STAGE BRONZE.ITEMS_REF_STG
    FILE_FORMAT = BRONZE.LEAGUE_CSV_FMT
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Stage for item reference CSV. Expected file: items_ref.csv';

-------------------------------------------------------------------------------------------
    -- 4. PIPE: Ingest from stage into bronze table
-------------------------------------------------------------------------------------------
CREATE OR REPLACE PIPE BRONZE.ITEMS_REF_PP
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
);
