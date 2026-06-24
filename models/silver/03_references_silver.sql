USE SCHEMA SILVER;


-------------------------------------------------------------------------------------------
    -- 1. CLEANING VIEW
-------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW SILVER.ITEMS_REF_BRONZE_STM_TO_SILVER AS
SELECT
    ITEM_ID,
    TRIM(ITEM_NAME) AS ITEM_NAME,
    ITEM_CATEGORY
FROM BRONZE.ITEMS_REF_BRONZE_STM
;


-------------------------------------------------------------------------------------------
    -- 2. SILVER TABLE: One row per item. PK on ITEM_ID.
-------------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE SILVER.ITEMS_REF_SILVER (
    ITEM_ID       NUMBER(38,0) NOT NULL,
    ITEM_NAME     VARCHAR(255),
    ITEM_CATEGORY VARCHAR(255),
    
    CONSTRAINT ITEMS_REF_SILVER_PKEY PRIMARY KEY (ITEM_ID)
)
COMMENT = '[SILVER] Cleaned item reference. Deduped by name, HTML names extracted.';


-------------------------------------------------------------------------------------------
    -- 3. TASK: Merge new/changed rows from cleaning view into ITEMS_REF_SILVER
-------------------------------------------------------------------------------------------
CREATE OR REPLACE TASK SILVER.BRONZE_TO_SILVER_ITEMS_TASK
    WAREHOUSE = COMPUTE_WH
    SCHEDULE  = '1 MINUTE'
    WHEN SYSTEM$STREAM_HAS_DATA('BRONZE.ITEMS_REF_BRONZE_STM')
AS
MERGE INTO SILVER.ITEMS_REF_SILVER AS tgt
USING (
    SELECT *
    FROM SILVER.ITEMS_REF_BRONZE_STM_TO_SILVER
    WHERE ITEM_ID IS NOT NULL
) AS src
    ON tgt.ITEM_ID = src.ITEM_ID
WHEN MATCHED THEN
    UPDATE SET tgt.ITEM_NAME = src.ITEM_NAME,
               tgt.ITEM_CATEGORY = src.ITEM_CATEGORY
WHEN NOT MATCHED THEN
    INSERT (ITEM_ID, ITEM_NAME, ITEM_CATEGORY)
    VALUES (src.ITEM_ID, src.ITEM_NAME, src.ITEM_CATEGORY);

-------------------------------------------------------------------------------------------
    -- 4. CLEANING VIEW: Split PascalCase champion names into Title Case, trim
-------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW SILVER.CHAMPIONS_REF_BRONZE_STM_TO_SILVER AS
SELECT
    CHAMPION_ID,
    -- Inserts space before uppercase letters that follow lowercase, e.g.:
    -- 'TwistedFate' --> 'Twisted Fate', 'MissFortune' --> 'Miss Fortune'
    TRIM(REGEXP_REPLACE(
        CHAMPION_NAME, '([a-z])([A-Z])', '\\1 \\2'
    )) AS CHAMPION_NAME
FROM BRONZE.CHAMPIONS_REF_BRONZE_STM;


-------------------------------------------------------------------------------------------
    -- 5. SILVER TABLE: One row per champion. PK on CHAMPION_ID.
-------------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE SILVER.CHAMPIONS_REF_SILVER (
    CHAMPION_ID    NUMBER(38,0) NOT NULL,
    CHAMPION_NAME  VARCHAR(255),
    
    CONSTRAINT CHAMPIONS_REF_SILVER_PKEY PRIMARY KEY (CHAMPION_ID)
)
COMMENT = '[SILVER] Cleaned champion reference. PascalCase names split to Title Case.';


-------------------------------------------------------------------------------------------
    -- 6. TASK: Merge new/changed rows from cleaning view into CHAMPIONS_REF_SILVER
-------------------------------------------------------------------------------------------
CREATE OR REPLACE TASK SILVER.BRONZE_TO_SILVER_CHAMPIONS_TASK
    WAREHOUSE = COMPUTE_WH
    SCHEDULE  = '1 MINUTE'
    WHEN SYSTEM$STREAM_HAS_DATA('BRONZE.CHAMPIONS_REF_BRONZE_STM')
AS
MERGE INTO SILVER.CHAMPIONS_REF_SILVER AS tgt
USING (
    SELECT *
    FROM SILVER.CHAMPIONS_REF_BRONZE_STM_TO_SILVER
    WHERE CHAMPION_ID IS NOT NULL
) AS src
    ON tgt.CHAMPION_ID = src.CHAMPION_ID
WHEN MATCHED THEN
    UPDATE SET tgt.CHAMPION_NAME = src.CHAMPION_NAME
WHEN NOT MATCHED THEN
    INSERT (CHAMPION_ID, CHAMPION_NAME)
    VALUES (src.CHAMPION_ID, src.CHAMPION_NAME)
;
