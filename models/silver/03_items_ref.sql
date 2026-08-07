USE SCHEMA SILVER;
-------------------------------------------------------------------------------------------
    -- 1. CLEANING VIEW
-------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW SILVER.ITEMS_REF_STM_TO_SILVER AS
SELECT
    SAFECAST_TO_INT(ITEM_ID) AS ITEM_ID,
    INITCAP(ITEM_NAME) AS ITEM_NAME,
    INITCAP(ITEM_CATEGORY) AS ITEM_CATEGORY
FROM BRONZE.ITEMS_REF_STM
;
-------------------------------------------------------------------------------------------
    -- 2. SILVER TABLE: One row per item. PK on ITEM_ID.
-------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS SILVER.ITEMS_REF (
    ITEM_ID NUMBER(38,0) NOT NULL,
    ITEM_NAME VARCHAR COMMENT 'Display name of the item.',
    ITEM_CATEGORY VARCHAR COMMENT 'Category the item belongs to.',

    CONSTRAINT SILVER_ITEMS_REF_PKEY PRIMARY KEY (ITEM_ID)
)
COMMENT = '[SILVER] Cleaned item reference.';
-------------------------------------------------------------------------------------------
    -- 3. TASK: Merge new/changed rows from cleaning view into ITEMS_REF
-------------------------------------------------------------------------------------------
CREATE TASK IF NOT EXISTS SILVER.BRONZE_TO_SILVER_ITEMS_REF_TASK
    WAREHOUSE = COMPUTE_WH
    SCHEDULE  = '1 MINUTE'
    SUSPEND_TASK_AFTER_NUM_FAILURES = 3
    WHEN SYSTEM$STREAM_HAS_DATA('BRONZE.ITEMS_REF_STM')
AS
MERGE INTO SILVER.ITEMS_REF AS tgt
USING (
    SELECT *
    FROM SILVER.ITEMS_REF_STM_TO_SILVER
    WHERE ITEM_ID IS NOT NULL
) AS src
    ON tgt.ITEM_ID = src.ITEM_ID
WHEN MATCHED THEN UPDATE SET
    tgt.ITEM_NAME     = src.ITEM_NAME,
    tgt.ITEM_CATEGORY = src.ITEM_CATEGORY
WHEN NOT MATCHED THEN INSERT (
    ITEM_ID,
    ITEM_NAME,
    ITEM_CATEGORY
) VALUES (
    src.ITEM_ID,
    src.ITEM_NAME,
    src.ITEM_CATEGORY
);
