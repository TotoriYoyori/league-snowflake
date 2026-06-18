-- Bronze champions reference: table, stream, stage, and pipe (self-contained)
-- Co-authored with CoCo
-------------------------------------------------------------------------------------------
    -- 0. DECLARE WORKING CONTEXT (set by calling deploy script)
-------------------------------------------------------------------------------------------
USE SCHEMA BRONZE;


-------------------------------------------------------------------------------------------
    -- 1. BRONZE TABLE: Champions reference lookup
-------------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE CHAMPIONS_REF_BRONZE (
    CHAMPION_ID    NUMBER(38,0) NOT NULL,
    CHAMPION_NAME  VARCHAR(255),
    -- Load Metadata
    LDTS            TIMESTAMP_NTZ(9) NOT NULL,
    FILE_NAME       VARCHAR(255) NOT NULL,
    FILE_ROW_NUMBER NUMBER(38,0) NOT NULL,
    RSRC            VARCHAR(255) NOT NULL,
    -- Constraints
    CONSTRAINT CHAMPIONS_REF_BRONZE_PKEY PRIMARY KEY (CHAMPION_ID)
)
COMMENT = '[BRONZE] Champion reference lookup. Loaded via CHAMPIONS_REF_PP from @CHAMPIONS_REF_STG.';


-------------------------------------------------------------------------------------------
    -- 2. STREAM: CDC for silver consumption
-------------------------------------------------------------------------------------------
CREATE OR REPLACE STREAM CHAMPIONS_REF_BRONZE_STM
    ON TABLE CHAMPIONS_REF_BRONZE
    COMMENT = 'CHAMPIONS_REF_BRONZE delta --> BRONZE_TO_SILVER_CHAMPIONS_TASK --> CHAMPIONS_REF_SILVER';


-------------------------------------------------------------------------------------------
    -- 3. STAGE: Internal stage for champions reference CSV
-------------------------------------------------------------------------------------------
CREATE OR REPLACE STAGE CHAMPIONS_REF_STG
    FILE_FORMAT = LEAGUE_CSV_FMT
    COMMENT = 'Stage for champion reference CSV. Expected file: champions_ref.csv';


-------------------------------------------------------------------------------------------
    -- 4. PIPE: Ingest from stage into bronze table
-------------------------------------------------------------------------------------------
CREATE OR REPLACE PIPE CHAMPIONS_REF_PP
COMMENT = 'Champion reference lookup. Ingest frequency --> Every patch updates.'
AS
COPY INTO CHAMPIONS_REF_BRONZE
FROM (
    SELECT
        $1,  -- champion_id
        $2,  -- champion_name
        CURRENT_TIMESTAMP(),
        METADATA$FILENAME,
        METADATA$FILE_ROW_NUMBER,
        'League Static Data'
    FROM @CHAMPIONS_REF_STG
);
