USE SCHEMA SILVER;

-------------------------------------------------------------------------------------------
    -- TASK: Single task merges the shared cleaning view's delta into BOTH
    -- PLAYER_INTERVAL_SILVER and TEAM_INTERVAL_SILVER inside one explicit transaction. 
-------------------------------------------------------------------------------------------
CREATE OR REPLACE TASK SILVER.BRONZE_TO_SILVER_INTERVALS_TASK
    WAREHOUSE = COMPUTE_WH
    SCHEDULE  = '1 MINUTE'
    WHEN SYSTEM$STREAM_HAS_DATA('BRONZE.MATCH_INTERVALS_BRONZE_STM')
AS
EXECUTE IMMEDIATE $$
BEGIN
    BEGIN TRANSACTION;

    MERGE INTO SILVER.TEAM_INTERVAL_SILVER AS tgt
    USING (
        SELECT
            ABS(HASH(MATCH_ID, TEAM, MINUTE))  AS ID,
            MATCH_ID, TEAM, MINUTE,
            MAX(TEAM_KILLS)            AS TEAM_KILLS,
            MAX(TEAM_INHIBITORS)       AS TEAM_INHIBITORS,
            MAX(TEAM_TOWERS)           AS TEAM_TOWERS,
            MAX(TEAM_DRAGONS_FIRE)     AS TEAM_DRAGONS_FIRE,
            MAX(TEAM_DRAGONS_WATER)    AS TEAM_DRAGONS_WATER,
            MAX(TEAM_DRAGONS_EARTH)    AS TEAM_DRAGONS_EARTH,
            MAX(TEAM_DRAGONS_AIR)      AS TEAM_DRAGONS_AIR,
            MAX(TEAM_DRAGONS_CHEMTECH) AS TEAM_DRAGONS_CHEMTECH,
            MAX(TEAM_DRAGONS_HEXTECH)  AS TEAM_DRAGONS_HEXTECH,
            MAX(TEAM_DRAGONS)          AS TEAM_DRAGONS,
            MAX(TEAM_BARONS)           AS TEAM_BARONS,
            MAX(TEAM_VOID_GRUBS)       AS TEAM_VOID_GRUBS,
            MAX(TEAM_HERALDS)          AS TEAM_HERALDS,
            MAX(TEAM_GOLD_DIFF)        AS TEAM_GOLD_DIFF
        FROM SILVER.MATCH_INTERVALS_BRONZE_STM_TO_SILVER
        GROUP BY MATCH_ID, TEAM, MINUTE
    ) AS src
        ON  tgt.MATCH_ID = src.MATCH_ID
        AND tgt.TEAM     = src.TEAM
        AND tgt.MINUTE   = src.MINUTE
    WHEN MATCHED THEN UPDATE SET
        tgt.TEAM_KILLS              = src.TEAM_KILLS,
        tgt.TEAM_INHIBITORS         = src.TEAM_INHIBITORS,
        tgt.TEAM_TOWERS             = src.TEAM_TOWERS,
        tgt.TEAM_DRAGONS_FIRE       = src.TEAM_DRAGONS_FIRE,
        tgt.TEAM_DRAGONS_WATER      = src.TEAM_DRAGONS_WATER,
        tgt.TEAM_DRAGONS_EARTH      = src.TEAM_DRAGONS_EARTH,
        tgt.TEAM_DRAGONS_AIR        = src.TEAM_DRAGONS_AIR,
        tgt.TEAM_DRAGONS_CHEMTECH   = src.TEAM_DRAGONS_CHEMTECH,
        tgt.TEAM_DRAGONS_HEXTECH    = src.TEAM_DRAGONS_HEXTECH,
        tgt.TEAM_DRAGONS            = src.TEAM_DRAGONS,
        tgt.TEAM_BARONS             = src.TEAM_BARONS,
        tgt.TEAM_VOID_GRUBS         = src.TEAM_VOID_GRUBS,
        tgt.TEAM_HERALDS            = src.TEAM_HERALDS,
        tgt.TEAM_GOLD_DIFF          = src.TEAM_GOLD_DIFF
    WHEN NOT MATCHED THEN INSERT (
        ID, MATCH_ID, TEAM, MINUTE, TEAM_KILLS, TEAM_INHIBITORS, TEAM_TOWERS,
        TEAM_DRAGONS_FIRE, TEAM_DRAGONS_WATER, TEAM_DRAGONS_EARTH, TEAM_DRAGONS_AIR,
        TEAM_DRAGONS_CHEMTECH, TEAM_DRAGONS_HEXTECH, TEAM_DRAGONS, TEAM_BARONS,
        TEAM_VOID_GRUBS, TEAM_HERALDS, TEAM_GOLD_DIFF
    ) VALUES (
        src.ID, src.MATCH_ID, src.TEAM, src.MINUTE, src.TEAM_KILLS, src.TEAM_INHIBITORS,
        src.TEAM_TOWERS, src.TEAM_DRAGONS_FIRE, src.TEAM_DRAGONS_WATER, src.TEAM_DRAGONS_EARTH,
        src.TEAM_DRAGONS_AIR, src.TEAM_DRAGONS_CHEMTECH, src.TEAM_DRAGONS_HEXTECH,
        src.TEAM_DRAGONS, src.TEAM_BARONS, src.TEAM_VOID_GRUBS, src.TEAM_HERALDS,
        src.TEAM_GOLD_DIFF
    );

    MERGE INTO SILVER.PLAYER_INTERVAL_SILVER AS tgt
    USING SILVER.MATCH_INTERVALS_BRONZE_STM_TO_SILVER AS src
        ON tgt.ID = src.ID
    WHEN MATCHED THEN UPDATE SET
        tgt.MATCH_ID           = src.MATCH_ID,
        tgt.PARTICIPANT_POS_ID = src.PARTICIPANT_POS_ID,
        tgt.TEAM                = src.TEAM,
        tgt.MINUTE              = src.MINUTE,
        tgt.CURRENT_GOLD        = src.CURRENT_GOLD,
        tgt.TOTAL_GOLD          = src.TOTAL_GOLD,
        tgt.CS                  = src.CS,
        tgt.JUNGLE_CS           = src.JUNGLE_CS,
        tgt.XP                  = src.XP,
        tgt.LEVEL               = src.LEVEL,
        tgt.KILLS               = src.KILLS,
        tgt.DEATHS              = src.DEATHS,
        tgt.ASSISTS             = src.ASSISTS,
        tgt.ITEM_0              = src.ITEM_0,
        tgt.ITEM_1              = src.ITEM_1,
        tgt.ITEM_2              = src.ITEM_2,
        tgt.ITEM_3              = src.ITEM_3,
        tgt.ITEM_4              = src.ITEM_4,
        tgt.ITEM_5              = src.ITEM_5,
        tgt.ITEM_6              = src.ITEM_6,
        tgt.GOLD_DIFF           = src.GOLD_DIFF,
        tgt.XP_DIFF             = src.XP_DIFF
    WHEN NOT MATCHED THEN INSERT (
        ID, MATCH_ID, PARTICIPANT_POS_ID, TEAM, MINUTE, CURRENT_GOLD, TOTAL_GOLD, CS, JUNGLE_CS,
        XP, LEVEL, KILLS, DEATHS, ASSISTS, ITEM_0, ITEM_1, ITEM_2, ITEM_3, ITEM_4, ITEM_5,
        ITEM_6, GOLD_DIFF, XP_DIFF
    ) VALUES (
        src.ID, src.MATCH_ID, src.PARTICIPANT_POS_ID, src.TEAM, src.MINUTE, src.CURRENT_GOLD,
        src.TOTAL_GOLD, src.CS, src.JUNGLE_CS, src.XP, src.LEVEL, src.KILLS, src.DEATHS,
        src.ASSISTS, src.ITEM_0, src.ITEM_1, src.ITEM_2, src.ITEM_3, src.ITEM_4, src.ITEM_5,
        src.ITEM_6, src.GOLD_DIFF, src.XP_DIFF
    );

    COMMIT;
END;
$$;
