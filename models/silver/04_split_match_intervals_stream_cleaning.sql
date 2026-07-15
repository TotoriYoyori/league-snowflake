USE SCHEMA SILVER;


-------------------------------------------------------------------------------------------
    -- HELPER UDF: impute NULL with a supplied average, floor at CLAMP_FLOOR
-------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION SILVER.IMPUTE_WITH_AVG(
    RAW_VALUE NUMBER, 
    AVG_VALUE FLOAT, 
    CLAMP_FLOOR NUMBER
)
RETURNS FLOAT
COMMENT = '[SILVER] Imputes NULL with AVG_VALUE, floored at CLAMP_FLOOR.'
AS
$$
    GREATEST(COALESCE(RAW_VALUE, AVG_VALUE), CLAMP_FLOOR)
$$;


CREATE OR REPLACE VIEW SILVER.MATCH_INTERVALS_BRONZE_STM_TO_SILVER AS
-------------------------------------------------------------------------------------------
    -- 01. BASE: Normalizing columns
-------------------------------------------------------------------------------------------
WITH BASE AS (
    SELECT
        ID,
        UPPER(TRIM(MATCH_ID))                   AS MATCH_ID,
        ((PLAYER_ID - 1) % 10) + 1              AS PARTICIPANT_POS_ID,
        -- PLAYER_ID 391210 --> PARTICIPANT_POS_ID = 1 --> Blue
        -- PLAYER_ID 30156 --> PARTICIPANT_POS_ID = 6 --> Red
        CASE 
            WHEN ((PLAYER_ID - 1) % 10) + 1 BETWEEN 1 AND 5 THEN 'Blue' 
            ELSE 'Red' END                      AS TEAM,
        ROUND(MINUTE / 5.0) * 5                 AS MINUTE,
        -- Economy
        CURRENT_GOLD, 
        TOTAL_GOLD, 
        CS, 
        JUNGLE_CS, 
        XP, 
        LEVEL,
        -- KDA
        KILLS, 
        DEATHS, 
        ASSISTS,
        -- Nullify 0 (No items)
        NULLIF(TRY_TO_NUMBER(ITEM_0), 0) AS ITEM_0,
        NULLIF(TRY_TO_NUMBER(ITEM_1), 0) AS ITEM_1,
        NULLIF(TRY_TO_NUMBER(ITEM_2), 0) AS ITEM_2,
        NULLIF(TRY_TO_NUMBER(ITEM_3), 0) AS ITEM_3,
        NULLIF(TRY_TO_NUMBER(ITEM_4), 0) AS ITEM_4,
        NULLIF(TRY_TO_NUMBER(ITEM_5), 0) AS ITEM_5,
        NULLIF(TRY_TO_NUMBER(ITEM_6), 0) AS ITEM_6,
        -- Team's objective
        TEAM_KILLS, TEAM_INHIBITORS, TEAM_TOWERS,
        TEAM_DRAGONS_FIRE, TEAM_DRAGONS_WATER, TEAM_DRAGONS_EARTH,
        TEAM_DRAGONS_AIR, TEAM_DRAGONS_CHEMTECH, TEAM_DRAGONS_HEXTECH, TEAM_DRAGONS,
        TEAM_BARONS, TEAM_VOID_GRUBS, TEAM_HERALDS,
        -- Diffs
        GOLD_DIFF, 
        XP_DIFF, 
        TEAM_GOLD_DIFF
    FROM BRONZE.MATCH_INTERVALS_BRONZE_STM
    WHERE MINUTE >= 0
),
-------------------------------------------------------------------------------------------
    -- 02. AVERAGE_CALC: Calculate average to be used as imputation
-------------------------------------------------------------------------------------------
AVERAGE_CALC AS (
    SELECT MINUTE,
        AVG(CURRENT_GOLD)          AS AVG_CURRENT_GOLD,
        AVG(TOTAL_GOLD)            AS AVG_TOTAL_GOLD,
        AVG(CS)                    AS AVG_CS,
        AVG(JUNGLE_CS)             AS AVG_JUNGLE_CS,
        AVG(LEVEL)                 AS AVG_LEVEL,
        AVG(XP)                    AS AVG_XP,
        AVG(KILLS)                 AS AVG_KILLS,
        AVG(DEATHS)                AS AVG_DEATHS,
        AVG(ASSISTS)               AS AVG_ASSISTS,
        AVG(TEAM_KILLS)            AS AVG_TEAM_KILLS,
        AVG(TEAM_INHIBITORS)       AS AVG_TEAM_INHIBITORS,
        AVG(TEAM_TOWERS)           AS AVG_TEAM_TOWERS,
        AVG(TEAM_DRAGONS_FIRE)     AS AVG_TEAM_DRAGONS_FIRE,
        AVG(TEAM_DRAGONS_WATER)    AS AVG_TEAM_DRAGONS_WATER,
        AVG(TEAM_DRAGONS_EARTH)    AS AVG_TEAM_DRAGONS_EARTH,
        AVG(TEAM_DRAGONS_AIR)      AS AVG_TEAM_DRAGONS_AIR,
        AVG(TEAM_DRAGONS_CHEMTECH) AS AVG_TEAM_DRAGONS_CHEMTECH,
        AVG(TEAM_DRAGONS_HEXTECH)  AS AVG_TEAM_DRAGONS_HEXTECH,
        AVG(TEAM_DRAGONS)          AS AVG_TEAM_DRAGONS,
        AVG(TEAM_BARONS)           AS AVG_TEAM_BARONS,
        AVG(TEAM_VOID_GRUBS)       AS AVG_TEAM_VOID_GRUBS,
        AVG(TEAM_HERALDS)          AS AVG_TEAM_HERALDS,
        AVG(GOLD_DIFF)             AS AVG_GOLD_DIFF,
        AVG(XP_DIFF)               AS AVG_XP_DIFF,
        AVG(TEAM_GOLD_DIFF)        AS AVG_TEAM_GOLD_DIFF
    FROM BASE
    GROUP BY MINUTE
),
-------------------------------------------------------------------------------------------
    -- 03. IMPUTED: apply IMPUTE_WITH_AVG(raw, avg, clamp_floor) per column.
-------------------------------------------------------------------------------------------
IMPUTED AS (
    SELECT
        B.ID, 
        B.MATCH_ID,
        B.PARTICIPANT_POS_ID,
        B.TEAM, 
        B.MINUTE,
        -- CURRENT_GOLD can be negative (Future's Market)
        SILVER.IMPUTE_WITH_AVG(B.CURRENT_GOLD, A.AVG_CURRENT_GOLD, -9999) AS CURRENT_GOLD,
        -- Others are clamped at 0
        SILVER.IMPUTE_WITH_AVG(B.TOTAL_GOLD, A.AVG_TOTAL_GOLD, 0)         AS TOTAL_GOLD,
        SILVER.IMPUTE_WITH_AVG(B.CS, A.AVG_CS, 0)                         AS CS,
        SILVER.IMPUTE_WITH_AVG(B.JUNGLE_CS, A.AVG_JUNGLE_CS, 0)           AS JUNGLE_CS,
        SILVER.IMPUTE_WITH_AVG(B.LEVEL, A.AVG_LEVEL, 0)                   AS LEVEL,
        SILVER.IMPUTE_WITH_AVG(B.XP, A.AVG_XP, 0)                         AS XP,
        SILVER.IMPUTE_WITH_AVG(B.KILLS, A.AVG_KILLS, 0)                   AS KILLS,
        SILVER.IMPUTE_WITH_AVG(B.DEATHS, A.AVG_DEATHS, 0)                 AS DEATHS,
        SILVER.IMPUTE_WITH_AVG(B.ASSISTS, A.AVG_ASSISTS, 0)               AS ASSISTS,
        -- Items
        B.ITEM_0, 
        B.ITEM_1, 
        B.ITEM_2,
        B.ITEM_3,
        B.ITEM_4, 
        B.ITEM_5, 
        B.ITEM_6,
        -- Clamped at 0
        SILVER.IMPUTE_WITH_AVG(B.TEAM_KILLS, A.AVG_TEAM_KILLS, 0)                       AS TEAM_KILLS,
        SILVER.IMPUTE_WITH_AVG(B.TEAM_INHIBITORS, A.AVG_TEAM_INHIBITORS, 0)             AS TEAM_INHIBITORS,
        SILVER.IMPUTE_WITH_AVG(B.TEAM_TOWERS, A.AVG_TEAM_TOWERS, 0)                     AS TEAM_TOWERS,
        SILVER.IMPUTE_WITH_AVG(B.TEAM_DRAGONS_FIRE, A.AVG_TEAM_DRAGONS_FIRE, 0)         AS TEAM_DRAGONS_FIRE,
        SILVER.IMPUTE_WITH_AVG(B.TEAM_DRAGONS_WATER, A.AVG_TEAM_DRAGONS_WATER, 0)       AS TEAM_DRAGONS_WATER,
        SILVER.IMPUTE_WITH_AVG(B.TEAM_DRAGONS_EARTH, A.AVG_TEAM_DRAGONS_EARTH, 0)       AS TEAM_DRAGONS_EARTH,
        SILVER.IMPUTE_WITH_AVG(B.TEAM_DRAGONS_AIR, A.AVG_TEAM_DRAGONS_AIR, 0)           AS TEAM_DRAGONS_AIR,
        SILVER.IMPUTE_WITH_AVG(B.TEAM_DRAGONS_CHEMTECH, A.AVG_TEAM_DRAGONS_CHEMTECH, 0) AS TEAM_DRAGONS_CHEMTECH,
        SILVER.IMPUTE_WITH_AVG(B.TEAM_DRAGONS_HEXTECH, A.AVG_TEAM_DRAGONS_HEXTECH, 0)   AS TEAM_DRAGONS_HEXTECH,
        SILVER.IMPUTE_WITH_AVG(B.TEAM_DRAGONS, A.AVG_TEAM_DRAGONS, 0)                   AS TEAM_DRAGONS,
        SILVER.IMPUTE_WITH_AVG(B.TEAM_BARONS, A.AVG_TEAM_BARONS, 0)                     AS TEAM_BARONS,
        SILVER.IMPUTE_WITH_AVG(B.TEAM_VOID_GRUBS, A.AVG_TEAM_VOID_GRUBS, 0)             AS TEAM_VOID_GRUBS,
        SILVER.IMPUTE_WITH_AVG(B.TEAM_HERALDS, A.AVG_TEAM_HERALDS, 0)                   AS TEAM_HERALDS,
        -- Can be negative
        SILVER.IMPUTE_WITH_AVG(B.GOLD_DIFF, A.AVG_GOLD_DIFF, -100000)                 AS GOLD_DIFF,
        SILVER.IMPUTE_WITH_AVG(B.XP_DIFF, A.AVG_XP_DIFF, -100000)                     AS XP_DIFF,
        SILVER.IMPUTE_WITH_AVG(B.TEAM_GOLD_DIFF, A.AVG_TEAM_GOLD_DIFF, -100000)       AS TEAM_GOLD_DIFF
    FROM BASE AS B
    JOIN AVERAGE_CALC AS A 
        ON A.MINUTE = B.MINUTE
),
---------------0---------------------------------------------------------------------------
    -- 05. FINAL_SELECT
-------------------------------------------------------------------------------------------
FINAL_SELECT AS (
    SELECT
        -- Primary key
        I.ID, 
        -- Composite key
        I.MATCH_ID,
        I.PARTICIPANT_POS_ID,
        I.TEAM, 
        I.MINUTE,
        -- Economy
        I.CURRENT_GOLD,
        I.TOTAL_GOLD,
        I.CS, 
        I.JUNGLE_CS, 
        I.XP, 
        I.LEVEL, 
        -- KDA
        I.KILLS, 
        I.DEATHS, 
        I.ASSISTS,
        -- Items 
        I.ITEM_0, I.ITEM_1, I.ITEM_2, I.ITEM_3, I.ITEM_4, I.ITEM_5, I.ITEM_6,
        -- Team's Objective
        I.TEAM_KILLS, I.TEAM_INHIBITORS, I.TEAM_TOWERS,
        I.TEAM_DRAGONS_FIRE, I.TEAM_DRAGONS_WATER, I.TEAM_DRAGONS_EARTH,
        I.TEAM_DRAGONS_AIR, I.TEAM_DRAGONS_CHEMTECH, I.TEAM_DRAGONS_HEXTECH, I.TEAM_DRAGONS,
        I.TEAM_BARONS, I.TEAM_VOID_GRUBS, I.TEAM_HERALDS,
        -- Diffs
        I.GOLD_DIFF, 
        I.XP_DIFF, 
        I.TEAM_GOLD_DIFF
    FROM IMPUTED AS I
)

SELECT *
FROM FINAL_SELECT
;

-------------------------------------------------------------------------------------------
    -- ! OUTDATED LEGACY !
    -- 05. ITEM_NAMES: resolve the 6 item ids to names. 
-------------------------------------------------------------------------------------------
-- item_names AS (
--     SELECT
--         x.ID,
--         r0.ITEM_NAME AS ITEM_0, 
--         r1.ITEM_NAME AS ITEM_1,
--         r2.ITEM_NAME AS ITEM_2,
--         r3.ITEM_NAME AS ITEM_3, 
--         r4.ITEM_NAME AS ITEM_4,
--         r5.ITEM_NAME AS ITEM_5,
--         r6.ITEM_NAME AS ITEM_6
--     FROM (
--         SELECT ID, ITEM_0, ITEM_1, ITEM_2, ITEM_3, ITEM_4, ITEM_5, ITEM_6 
--         FROM base
--     ) AS x
--     LEFT JOIN SILVER.ITEMS_REF_SILVER r0 ON r0.ITEM_ID = x.ITEM_0
--     LEFT JOIN SILVER.ITEMS_REF_SILVER r1 ON r1.ITEM_ID = x.ITEM_1
--     LEFT JOIN SILVER.ITEMS_REF_SILVER r2 ON r2.ITEM_ID = x.ITEM_2
--     LEFT JOIN SILVER.ITEMS_REF_SILVER r3 ON r3.ITEM_ID = x.ITEM_3
--     LEFT JOIN SILVER.ITEMS_REF_SILVER r4 ON r4.ITEM_ID = x.ITEM_4
--     LEFT JOIN SILVER.ITEMS_REF_SILVER r5 ON r5.ITEM_ID = x.ITEM_5
--     LEFT JOIN SILVER.ITEMS_REF_SILVER r6 ON r6.ITEM_ID = x.ITEM_6
-- )
