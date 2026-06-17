-------------------------------------------------------------------------------------------
    -- 0. DECLARE WORKING CONTEXT
-------------------------------------------------------------------------------------------
USE DATABASE LEAGUE_RECORDS;

USE SCHEMA SILVER;


-------------------------------------------------------------------------------------------
    -- 1. HELPER UDF: impute NULL with a supplied average, floor at CLAMP_FLOOR
-------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION IMPUTE_WITH_AVG(RAW_VALUE NUMBER, AVG_VALUE FLOAT, CLAMP_FLOOR NUMBER)
RETURNS NUMBER
AS
$$
    GREATEST(COALESCE(RAW_VALUE, AVG_VALUE), CLAMP_FLOOR)
$$
COMMENT = '[SILVER] Imputes NULL with AVG_VALUE, floored at CLAMP_FLOOR.';


-------------------------------------------------------------------------------------------
    -- 2. BASE: Normalizing columns
-------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW MATCH_INTERVALS_BRONZE_STM_TO_SILVER AS
WITH base AS (
    SELECT
        ID,
        UPPER(TRIM(MATCH_ID))                   AS MATCH_ID,
        -- Decode bronze's PLAYER_ID encoding into PLAYERS_SUMMARY_SILVER's PARTICIPANT_POS_ID
        ((PLAYER_ID - 1) % 10) + 1              AS PARTICIPANT_POS_ID,
        -- Position 1-5 is always Blue side, 6-10 is always Red side
        CASE 
            WHEN ((PLAYER_ID - 1) % 10) + 1 BETWEEN 1 AND 5 THEN 'Blue' 
            ELSE 'Red' END
        AS TEAM,
        -- Snap to the nearest 5-minute mark; raw values are mostly exact but have edge noise
        ROUND(MINUTE / 5.0) * 5                 AS MINUTE,
        -- Economy 
        CURRENT_GOLD, TOTAL_GOLD, CS, JUNGLE_CS, XP, LEVEL,
        -- KDA
        KILLS, DEATHS, ASSISTS,
        -- Item id 0 means "no item" -- normalize to NULL before the ref lookup
        NULLIF(ITEM_0, 0) AS ITEM_0, 
        NULLIF(ITEM_1, 0) AS ITEM_1, 
        NULLIF(ITEM_2, 0) AS ITEM_2,
        NULLIF(ITEM_3, 0) AS ITEM_3, 
        NULLIF(ITEM_4, 0) AS ITEM_4, 
        NULLIF(ITEM_5, 0) AS ITEM_5,
        NULLIF(ITEM_6, 0) AS ITEM_6,
        -- Team objective counters
        TEAM_KILLS, TEAM_INHIBITORS, TEAM_TOWERS,
        TEAM_DRAGONS_FIRE, TEAM_DRAGONS_WATER, TEAM_DRAGONS_EARTH,
        TEAM_DRAGONS_AIR, TEAM_DRAGONS_CHEMTECH, TEAM_DRAGONS_HEXTECH, TEAM_DRAGONS,
        TEAM_BARONS, TEAM_VOID_GRUBS, TEAM_HERALDS,
        -- Stats Diff
        GOLD_DIFF, XP_DIFF, TEAM_GOLD_DIFF
    FROM BRONZE.MATCH_INTERVALS_BRONZE_STM
    -- Drop rows with no valid minute entirely, per spec
    WHERE MINUTE >= 0
),

-------------------------------------------------------------------------------------------
    -- 3. AVERAGE_CALC: The global per-minute average for columns that need null-imputation. 
-------------------------------------------------------------------------------------------
average_calc AS (
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
    FROM base
    GROUP BY MINUTE
),

-------------------------------------------------------------------------------------------
    -- 4. IMPUTED: apply IMPUTE_WITH_AVG(raw, avg, clamp_floor) per column.
-------------------------------------------------------------------------------------------
imputed AS (
    SELECT
        b.ID, b.MATCH_ID, b.PARTICIPANT_POS_ID, b.TEAM, b.MINUTE,
        -- Economy: current gold may legitimately dip negative, total gold may not
        IMPUTE_WITH_AVG(b.CURRENT_GOLD, a.AVG_CURRENT_GOLD, -9999) AS CURRENT_GOLD,
        IMPUTE_WITH_AVG(b.TOTAL_GOLD, a.AVG_TOTAL_GOLD, 0)         AS TOTAL_GOLD,
        IMPUTE_WITH_AVG(b.CS, a.AVG_CS, 0)                         AS CS,
        IMPUTE_WITH_AVG(b.JUNGLE_CS, a.AVG_JUNGLE_CS, 0)           AS JUNGLE_CS,
        IMPUTE_WITH_AVG(b.LEVEL, a.AVG_LEVEL, 0)                   AS LEVEL,
        IMPUTE_WITH_AVG(b.XP, a.AVG_XP, 0)                         AS XP,
        -- KDA
        IMPUTE_WITH_AVG(b.KILLS, a.AVG_KILLS, 0)                   AS KILLS,
        IMPUTE_WITH_AVG(b.DEATHS, a.AVG_DEATHS, 0)                 AS DEATHS,
        IMPUTE_WITH_AVG(b.ASSISTS, a.AVG_ASSISTS, 0)               AS ASSISTS,
        -- Items carried through untouched, resolved to names in ITEM_NAMES below
        b.ITEM_0, b.ITEM_1, b.ITEM_2, b.ITEM_3, b.ITEM_4, b.ITEM_5, b.ITEM_6,
        -- Team objectives
        IMPUTE_WITH_AVG(b.TEAM_KILLS, a.AVG_TEAM_KILLS, 0)                       AS TEAM_KILLS,
        IMPUTE_WITH_AVG(b.TEAM_INHIBITORS, a.AVG_TEAM_INHIBITORS, 0)             AS TEAM_INHIBITORS,
        IMPUTE_WITH_AVG(b.TEAM_TOWERS, a.AVG_TEAM_TOWERS, 0)                     AS TEAM_TOWERS,
        IMPUTE_WITH_AVG(b.TEAM_DRAGONS_FIRE, a.AVG_TEAM_DRAGONS_FIRE, 0)         AS TEAM_DRAGONS_FIRE,
        IMPUTE_WITH_AVG(b.TEAM_DRAGONS_WATER, a.AVG_TEAM_DRAGONS_WATER, 0)       AS TEAM_DRAGONS_WATER,
        IMPUTE_WITH_AVG(b.TEAM_DRAGONS_EARTH, a.AVG_TEAM_DRAGONS_EARTH, 0)       AS TEAM_DRAGONS_EARTH,
        IMPUTE_WITH_AVG(b.TEAM_DRAGONS_AIR, a.AVG_TEAM_DRAGONS_AIR, 0)           AS TEAM_DRAGONS_AIR,
        IMPUTE_WITH_AVG(b.TEAM_DRAGONS_CHEMTECH, a.AVG_TEAM_DRAGONS_CHEMTECH, 0) AS TEAM_DRAGONS_CHEMTECH,
        IMPUTE_WITH_AVG(b.TEAM_DRAGONS_HEXTECH, a.AVG_TEAM_DRAGONS_HEXTECH, 0)   AS TEAM_DRAGONS_HEXTECH,
        IMPUTE_WITH_AVG(b.TEAM_DRAGONS, a.AVG_TEAM_DRAGONS, 0)                   AS TEAM_DRAGONS,
        IMPUTE_WITH_AVG(b.TEAM_BARONS, a.AVG_TEAM_BARONS, 0)                     AS TEAM_BARONS,
        IMPUTE_WITH_AVG(b.TEAM_VOID_GRUBS, a.AVG_TEAM_VOID_GRUBS, 0)             AS TEAM_VOID_GRUBS,
        IMPUTE_WITH_AVG(b.TEAM_HERALDS, a.AVG_TEAM_HERALDS, 0)                   AS TEAM_HERALDS,
        -- Signed diffs: allowed negative, bounded at a large negative floor
        IMPUTE_WITH_AVG(b.GOLD_DIFF, a.AVG_GOLD_DIFF, -100000)                 AS GOLD_DIFF,
        IMPUTE_WITH_AVG(b.XP_DIFF, a.AVG_XP_DIFF, -100000)                     AS XP_DIFF,
        IMPUTE_WITH_AVG(b.TEAM_GOLD_DIFF, a.AVG_TEAM_GOLD_DIFF, -100000)       AS TEAM_GOLD_DIFF
    FROM base AS b
    JOIN average_calc AS a ON a.MINUTE = b.MINUTE
),

-------------------------------------------------------------------------------------------
    -- 5. ITEM_NAMES: resolve the 6 item ids to names. 
-------------------------------------------------------------------------------------------
item_names AS (
    SELECT
        x.ID,
        r0.ITEM_NAME AS ITEM_0, 
        r1.ITEM_NAME AS ITEM_1,
        r2.ITEM_NAME AS ITEM_2,
        r3.ITEM_NAME AS ITEM_3, 
        r4.ITEM_NAME AS ITEM_4,
        r5.ITEM_NAME AS ITEM_5,
        r6.ITEM_NAME AS ITEM_6
    FROM (SELECT ID, ITEM_0, ITEM_1, ITEM_2, ITEM_3, ITEM_4, ITEM_5, ITEM_6 FROM base) x
    LEFT JOIN SILVER.ITEMS_REF_SILVER r0 ON r0.ITEM_ID = x.ITEM_0
    LEFT JOIN SILVER.ITEMS_REF_SILVER r1 ON r1.ITEM_ID = x.ITEM_1
    LEFT JOIN SILVER.ITEMS_REF_SILVER r2 ON r2.ITEM_ID = x.ITEM_2
    LEFT JOIN SILVER.ITEMS_REF_SILVER r3 ON r3.ITEM_ID = x.ITEM_3
    LEFT JOIN SILVER.ITEMS_REF_SILVER r4 ON r4.ITEM_ID = x.ITEM_4
    LEFT JOIN SILVER.ITEMS_REF_SILVER r5 ON r5.ITEM_ID = x.ITEM_5
    LEFT JOIN SILVER.ITEMS_REF_SILVER r6 ON r6.ITEM_ID = x.ITEM_6
)

-------------------------------------------------------------------------------------------
    -- 6. FINAL SELECT: join IMPUTED to ITEM_NAMES on ID, apply the
-------------------------------------------------------------------------------------------
SELECT
    i.ID, i.MATCH_ID, i.PARTICIPANT_POS_ID, i.TEAM, i.MINUTE,
    -- Current gold can't exceed total gold; total gold can't be less than current/0
    LEAST(i.CURRENT_GOLD, i.TOTAL_GOLD)            AS CURRENT_GOLD,
    GREATEST(i.TOTAL_GOLD, i.CURRENT_GOLD, 0)      AS TOTAL_GOLD,
    i.CS, i.JUNGLE_CS, i.XP, i.LEVEL, 
    i.KILLS, i.DEATHS, i.ASSISTS,
    n.ITEM_0, n.ITEM_1, n.ITEM_2, n.ITEM_3, n.ITEM_4, n.ITEM_5, n.ITEM_6,
    i.TEAM_KILLS, i.TEAM_INHIBITORS, i.TEAM_TOWERS,
    i.TEAM_DRAGONS_FIRE, i.TEAM_DRAGONS_WATER, i.TEAM_DRAGONS_EARTH,
    i.TEAM_DRAGONS_AIR, i.TEAM_DRAGONS_CHEMTECH, i.TEAM_DRAGONS_HEXTECH, i.TEAM_DRAGONS,
    i.TEAM_BARONS, i.TEAM_VOID_GRUBS, i.TEAM_HERALDS,
    i.GOLD_DIFF, i.XP_DIFF, i.TEAM_GOLD_DIFF
FROM imputed i
JOIN item_names n ON n.ID = i.ID;
