-------------------------------------------------------------------------------------------
    -- 0. DECLARE WORKING CONTEXT
-------------------------------------------------------------------------------------------
USE DATABASE LEAGUE_RECORDS;

USE SCHEMA BRONZE;


-------------------------------------------------------------------------------------------
    -- 1. BRONZE TABLE: Items reference lookup
-------------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE ITEMS_REF_BRONZE (
    ITEM_ID    NUMBER(38,0) NOT NULL,
    ITEM_NAME  VARCHAR(255),
    -- Load Metadata
    LDTS            TIMESTAMP_NTZ(9) NOT NULL,
    FILE_NAME       VARCHAR(255) NOT NULL,
    FILE_ROW_NUMBER NUMBER(38,0) NOT NULL,
    RSRC            VARCHAR(255) NOT NULL,
    -- Constraints
    CONSTRAINT ITEMS_REF_BRONZE_PKEY PRIMARY KEY (ITEM_ID)
)
COMMENT = '[BRONZE] Item reference lookup. Loaded via ITEMS_REF_PP from @REFERENCE_STG.';


-------------------------------------------------------------------------------------------
    -- 2. BRONZE TABLE: Champions reference lookup
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
COMMENT = '[BRONZE] Champion reference lookup. Loaded via CHAMPIONS_REF_PP from @REFERENCE_STG.';


-------------------------------------------------------------------------------------------
    -- 3. STREAMS: CDC for silver consumption
-------------------------------------------------------------------------------------------
CREATE OR REPLACE STREAM ITEMS_REF_BRONZE_STM
    ON TABLE ITEMS_REF_BRONZE
    COMMENT = 'ITEMS_REF_BRONZE delta --> BRONZE_TO_SILVER_ITEMS_TASK --> ITEMS_REF_SILVER';

CREATE OR REPLACE STREAM CHAMPIONS_REF_BRONZE_STM
    ON TABLE CHAMPIONS_REF_BRONZE
    COMMENT = 'CHAMPIONS_REF_BRONZE delta --> BRONZE_TO_SILVER_CHAMPIONS_TASK --> CHAMPIONS_REF_SILVER';
