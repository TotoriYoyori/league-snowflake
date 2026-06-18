-- Silver reference tables: items and champions cleaning views, tables, and merge tasks
-- Co-authored with CoCo
-------------------------------------------------------------------------------------------
    -- 0. DECLARE WORKING CONTEXT (set by calling deploy script)
-------------------------------------------------------------------------------------------
USE SCHEMA SILVER;


-------------------------------------------------------------------------------------------
    -- 1. CLEANING VIEW: Deduplicate items (same name, multiple IDs → keep smallest ID),
    --    extract item names from HTML-wrapped entries (<rarityLegendary> tags), trim
-------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW ITEMS_REF_BRONZE_STM_TO_SILVER AS
WITH cleaned AS (
    SELECT
        ITEM_ID,
        TRIM(
            CASE
                -- Captures item name from HTML-wrapped entries, e.g.:
                -- '<rarityLegendary>Death's Daughter</rarityLegendary><br>...' --> 'Death's Daughter'
                WHEN ITEM_NAME LIKE '%<rarityLegendary>%'
                THEN REGEXP_SUBSTR(ITEM_NAME, '<rarityLegendary>(.*?)</rarityLegendary>', 1, 1, 'e')
                ELSE ITEM_NAME
            END
        ) AS ITEM_NAME
    FROM BRONZE.ITEMS_REF_BRONZE_STM
)
SELECT
    ITEM_ID,
    ITEM_NAME
FROM cleaned
WHERE ITEM_NAME IS NULL
   OR QUALIFY ROW_NUMBER() OVER (PARTITION BY ITEM_NAME ORDER BY ITEM_ID ASC) = 1;


-------------------------------------------------------------------------------------------
    -- 2. SILVER TABLE: One row per item. PK on ITEM_ID.
-------------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE ITEMS_REF_SILVER (
    ITEM_ID    NUMBER(38,0) NOT NULL,
    ITEM_NAME  VARCHAR(255),
    CONSTRAINT ITEMS_REF_SILVER_PKEY PRIMARY KEY (ITEM_ID)
)
COMMENT = '[SILVER] Cleaned item reference. Deduped by name, HTML names extracted.';


-------------------------------------------------------------------------------------------
    -- 3. TASK: Merge new/changed rows from cleaning view into ITEMS_REF_SILVER
-------------------------------------------------------------------------------------------
CREATE OR REPLACE TASK BRONZE_TO_SILVER_ITEMS_TASK
    WAREHOUSE = COMPUTE_WH
    SCHEDULE  = '1 MINUTE'
    WHEN SYSTEM$STREAM_HAS_DATA('BRONZE.ITEMS_REF_BRONZE_STM')
AS
MERGE INTO SILVER.ITEMS_REF_SILVER AS tgt
USING SILVER.ITEMS_REF_BRONZE_STM_TO_SILVER AS src
    ON tgt.ITEM_ID = src.ITEM_ID
WHEN MATCHED THEN
    UPDATE SET tgt.ITEM_NAME = src.ITEM_NAME
WHEN NOT MATCHED THEN
    INSERT (ITEM_ID, ITEM_NAME)
    VALUES (src.ITEM_ID, src.ITEM_NAME);


-------------------------------------------------------------------------------------------
    -- 4. CLEANING VIEW: Split PascalCase champion names into Title Case, trim
-------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW CHAMPIONS_REF_BRONZE_STM_TO_SILVER AS
SELECT
    CHAMPION_ID,
    -- Inserts space before uppercase letters that follow lowercase, e.g.:
    -- 'TwistedFate' --> 'Twisted Fate', 'MissFortune' --> 'Miss Fortune'
    TRIM(REGEXP_REPLACE(CHAMPION_NAME, '([a-z])([A-Z])', '\\1 \\2')) AS CHAMPION_NAME
FROM BRONZE.CHAMPIONS_REF_BRONZE_STM;


-------------------------------------------------------------------------------------------
    -- 5. SILVER TABLE: One row per champion. PK on CHAMPION_ID.
-------------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE CHAMPIONS_REF_SILVER (
    CHAMPION_ID    NUMBER(38,0) NOT NULL,
    CHAMPION_NAME  VARCHAR(255),
    CONSTRAINT CHAMPIONS_REF_SILVER_PKEY PRIMARY KEY (CHAMPION_ID)
)
COMMENT = '[SILVER] Cleaned champion reference. PascalCase names split to Title Case.';


-------------------------------------------------------------------------------------------
    -- 6. TASK: Merge new/changed rows from cleaning view into CHAMPIONS_REF_SILVER
-------------------------------------------------------------------------------------------
CREATE OR REPLACE TASK BRONZE_TO_SILVER_CHAMPIONS_TASK
    WAREHOUSE = COMPUTE_WH
    SCHEDULE  = '1 MINUTE'
    WHEN SYSTEM$STREAM_HAS_DATA('BRONZE.CHAMPIONS_REF_BRONZE_STM')
AS
MERGE INTO SILVER.CHAMPIONS_REF_SILVER AS tgt
USING SILVER.CHAMPIONS_REF_BRONZE_STM_TO_SILVER AS src
    ON tgt.CHAMPION_ID = src.CHAMPION_ID
WHEN MATCHED THEN
    UPDATE SET tgt.CHAMPION_NAME = src.CHAMPION_NAME
WHEN NOT MATCHED THEN
    INSERT (CHAMPION_ID, CHAMPION_NAME)
    VALUES (src.CHAMPION_ID, src.CHAMPION_NAME);
