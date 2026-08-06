USE SCHEMA SILVER;

-------------------------------------------------------------------------------------------
    -- 1. CLEANING VIEW
-------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW SILVER.CHAMPIONS_REF_STM_TO_SILVER AS
SELECT
    SAFECAST_TO_INT(CHAMPION_ID) AS CHAMPION_ID,
    UPPER(CHAMPION_NAME) AS CHAMPION_NAME
FROM BRONZE.CHAMPIONS_REF_STM
;

-------------------------------------------------------------------------------------------
    -- 2. SILVER TABLE: One row per champion. PK on CHAMPION_ID.
-------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS SILVER.CHAMPIONS_REF (
    CHAMPION_ID NUMBER(38,0) NOT NULL,
    CHAMPION_NAME VARCHAR COMMENT 'Display name of the champion, uppercased.',

    CONSTRAINT SILVER_CHAMPIONS_REF_PKEY PRIMARY KEY (CHAMPION_ID)
)
COMMENT = '[SILVER] Cleaned champion reference, uppercased for consistency.';

-------------------------------------------------------------------------------------------
    -- 3. TASK: Merge new/changed rows from cleaning view into CHAMPIONS_REF
-------------------------------------------------------------------------------------------
CREATE TASK IF NOT EXISTS SILVER.BRONZE_TO_SILVER_CHAMPIONS_REF_TASK
    WAREHOUSE = COMPUTE_WH
    SCHEDULE  = '1 MINUTE'
    SUSPEND_TASK_AFTER_NUM_FAILURES = 3
    WHEN SYSTEM$STREAM_HAS_DATA('BRONZE.CHAMPIONS_REF_STM')
AS
MERGE INTO SILVER.CHAMPIONS_REF AS tgt
USING (
    SELECT *
    FROM SILVER.CHAMPIONS_REF_STM_TO_SILVER
    WHERE CHAMPION_ID IS NOT NULL
) AS src
    ON tgt.CHAMPION_ID = src.CHAMPION_ID
WHEN MATCHED THEN UPDATE SET
    tgt.CHAMPION_NAME = src.CHAMPION_NAME
WHEN NOT MATCHED THEN INSERT (
    CHAMPION_ID,
    CHAMPION_NAME
) VALUES (
    src.CHAMPION_ID,
    src.CHAMPION_NAME
);
