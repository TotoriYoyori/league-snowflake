-------------------------------------------------------------------------------------------
    -- 0. DECLARE WORKING CONTEXT
-------------------------------------------------------------------------------------------
USE DATABASE LEAGUE_RECORDS;

USE SCHEMA L10_RDV;


-------------------------------------------------------------------------------------------
    -- 1. TASK TO CONSUME FROM STREAM TO POPULATE RAW DATA VAULT L10 TABLE
    -- NOTE: WHEN clause checks the raw stream (STG_INTERVALS_STRM_RDV) for new data,
    -- but the MERGE reads from the export view (STG_INTERVALS_STRM_RDV_EXPORT) which adds
    -- computed hub-key and hash-diff columns on top of that same stream.
    
    -- Schedule: 1 minute — warehouse auto-suspends when the WHEN condition is false,
    -- so no credits are consumed unless the stream has data. Cost-effective NRT loader.
-------------------------------------------------------------------------------------------
CREATE OR REPLACE TASK STG_INTERVALS_TO_RDV
    WAREHOUSE = DV_COMPUTE_WH
    SCHEDULE = '1 minute'
WHEN SYSTEM$STREAM_HAS_DATA('L00_STG.STG_INTERVALS_STRM_RDV')
AS
EXECUTE IMMEDIATE
$$
BEGIN
    -- Hub
    MERGE INTO HUB_INTERVALS AS TGT
    USING L00_STG.STG_INTERVALS_STRM_RDV_EXPORT AS SRC
        ON TGT.SHA1_HUB_INTERVAL = SRC.SHA1_HUB_INTERVAL
    WHEN NOT MATCHED THEN INSERT (
        SHA1_HUB_INTERVAL, ID, MATCH_ID, PLAYER_ID, MINUTE, LDTS, RSRC
    )
    VALUES (
        SRC.SHA1_HUB_INTERVAL, SRC.ID, SRC.MATCH_ID, SRC.PLAYER_ID, SRC.MINUTE, SRC.LDTS, SRC.RSRC
    );

    -- Satellite
    MERGE INTO SAT_INTERVALS AS TGT
    USING L00_STG.STG_INTERVALS_STRM_RDV_EXPORT AS SRC
        ON TGT.SHA1_HUB_INTERVAL = SRC.SHA1_HUB_INTERVAL
        AND TGT.HASH_INTERVAL_DIFF = SRC.HASH_INTERVAL_DIFF
    WHEN NOT MATCHED THEN INSERT (
        SHA1_HUB_INTERVAL, LDTS, RSRC,
        CURRENT_GOLD, TOTAL_GOLD,
        CS, JUNGLE_CS, XP, LEVEL,
        KILLS, DEATHS, ASSISTS,
        ITEM_0, ITEM_1, ITEM_2, ITEM_3, ITEM_4, ITEM_5, ITEM_6,
        TEAM_KILLS, TEAM_INHIBITORS, TEAM_TOWERS,
        TEAM_DRAGONS_FIRE, TEAM_DRAGONS_WATER, TEAM_DRAGONS_EARTH, TEAM_DRAGONS_AIR,
        TEAM_DRAGONS_CHEMTECH, TEAM_DRAGONS_HEXTECH, TEAM_DRAGONS,
        TEAM_BARONS, TEAM_VOID_GRUBS, TEAM_HERALDS,
        GOLD_DIFF, XP_DIFF, TEAM_GOLD_DIFF,
        HASH_INTERVAL_DIFF
    )
    VALUES (
        SRC.SHA1_HUB_INTERVAL, SRC.LDTS, SRC.RSRC,
        SRC.CURRENT_GOLD, SRC.TOTAL_GOLD,
        SRC.CS, SRC.JUNGLE_CS, SRC.XP, SRC.LEVEL,
        SRC.KILLS, SRC.DEATHS, SRC.ASSISTS,
        SRC.ITEM_0, SRC.ITEM_1, SRC.ITEM_2, SRC.ITEM_3, SRC.ITEM_4, SRC.ITEM_5, SRC.ITEM_6,
        SRC.TEAM_KILLS, SRC.TEAM_INHIBITORS, SRC.TEAM_TOWERS,
        SRC.TEAM_DRAGONS_FIRE, SRC.TEAM_DRAGONS_WATER, SRC.TEAM_DRAGONS_EARTH, SRC.TEAM_DRAGONS_AIR,
        SRC.TEAM_DRAGONS_CHEMTECH, SRC.TEAM_DRAGONS_HEXTECH, SRC.TEAM_DRAGONS,
        SRC.TEAM_BARONS, SRC.TEAM_VOID_GRUBS, SRC.TEAM_HERALDS,
        SRC.GOLD_DIFF, SRC.XP_DIFF, SRC.TEAM_GOLD_DIFF,
        SRC.HASH_INTERVAL_DIFF
    );

END;
$$;


-------------------------------------------------------------------------------------------
    -- 2. TASKS ARE OFF WHEN CREATED FIRST TIME SO TURN THEM BACK ON
-------------------------------------------------------------------------------------------
ALTER TASK STG_INTERVALS_TO_RDV RESUME;
