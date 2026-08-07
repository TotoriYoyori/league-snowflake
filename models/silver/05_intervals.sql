USE SCHEMA SILVER;
-------------------------------------------------------------------------------------------
    -- 1. CLEANING VIEW
-------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW SILVER.INTERVALS_STM_TO_SILVER AS
SELECT
    UPPER(MATCH_ID) AS MATCH_ID,
    -- PLAYER_ID 3210 --> PARTICIPANT_POS_ID = 10 // PLAYER_ID 3156 --> PARTICIPANT_POS_ID = 6
    ((SAFECAST_TO_INT(PLAYER_ID) - 1) % 10) + 1 AS PARTICIPANT_POS_ID,
    -- Player 1-5 --> BLUE // Player 6-10 --> RED
    CASE
        WHEN ((SAFECAST_TO_INT(PLAYER_ID) - 1) % 10) + 1 BETWEEN 1 AND 5 THEN 'BLUE'
        WHEN ((SAFECAST_TO_INT(PLAYER_ID) - 1) % 10) + 1 BETWEEN 6 AND 10 THEN 'RED'
        ELSE NULL
    END AS TEAM,
    -- Clamp to interval of 5
    VALID_NUM_RANGE(
        ROUND(SAFECAST_TO_INT(MINUTE) / 5.0) * 5,
        0, 1E4
    ) AS MINUTE,
    -- Economy
    SAFECAST_TO_INT(CURRENT_GOLD) AS CURRENT_GOLD,
    VALID_NUM_RANGE(SAFECAST_TO_INT(TOTAL_GOLD), 0, 1E9) AS TOTAL_GOLD,
    VALID_NUM_RANGE(SAFECAST_TO_INT(CS), 0, 1E4) AS CS,
    VALID_NUM_RANGE(SAFECAST_TO_INT(JUNGLE_CS), 0, 1E4) AS JUNGLE_CS,
    VALID_NUM_RANGE(SAFECAST_TO_INT(XP), 0, 1E9) AS XP,
    VALID_NUM_RANGE(SAFECAST_TO_INT(LEVEL), 0, 20) AS LEVEL,
    -- KDA
    VALID_NUM_RANGE(SAFECAST_TO_INT(KILLS), 0, 1E3) AS KILLS,
    VALID_NUM_RANGE(SAFECAST_TO_INT(DEATHS), 0, 1E3) AS DEATHS,
    VALID_NUM_RANGE(SAFECAST_TO_INT(ASSISTS), 0, 1E3) AS ASSISTS,
    -- Itemization: 0 means no item, nullify
    NULLIF(SAFECAST_TO_INT(ITEM_0), 0) AS ITEM_0,
    NULLIF(SAFECAST_TO_INT(ITEM_1), 0) AS ITEM_1,
    NULLIF(SAFECAST_TO_INT(ITEM_2), 0) AS ITEM_2,
    NULLIF(SAFECAST_TO_INT(ITEM_3), 0) AS ITEM_3,
    NULLIF(SAFECAST_TO_INT(ITEM_4), 0) AS ITEM_4,
    NULLIF(SAFECAST_TO_INT(ITEM_5), 0) AS ITEM_5,
    NULLIF(SAFECAST_TO_INT(ITEM_6), 0) AS ITEM_6,
    -- Player diffs
    SAFECAST_TO_INT(GOLD_DIFF) AS GOLD_DIFF,
    SAFECAST_TO_INT(XP_DIFF) AS XP_DIFF,
    -- Team's objectives (duplicated across the 5 players sharing a team/minute)
    VALID_NUM_RANGE(SAFECAST_TO_INT(TEAM_KILLS), 0, 1E4) AS TEAM_KILLS,
    VALID_NUM_RANGE(SAFECAST_TO_INT(TEAM_INHIBITORS), 0, 1E2) AS TEAM_INHIBITORS,
    VALID_NUM_RANGE(SAFECAST_TO_INT(TEAM_TOWERS), 0, 1E2) AS TEAM_TOWERS,
    VALID_NUM_RANGE(SAFECAST_TO_INT(TEAM_DRAGONS_FIRE), 0, 4) AS TEAM_DRAGONS_FIRE,
    VALID_NUM_RANGE(SAFECAST_TO_INT(TEAM_DRAGONS_WATER), 0, 4) AS TEAM_DRAGONS_WATER,
    VALID_NUM_RANGE(SAFECAST_TO_INT(TEAM_DRAGONS_EARTH), 0, 4) AS TEAM_DRAGONS_EARTH,
    VALID_NUM_RANGE(SAFECAST_TO_INT(TEAM_DRAGONS_AIR), 0, 4) AS TEAM_DRAGONS_AIR,
    VALID_NUM_RANGE(SAFECAST_TO_INT(TEAM_DRAGONS_CHEMTECH), 0, 4) AS TEAM_DRAGONS_CHEMTECH,
    VALID_NUM_RANGE(SAFECAST_TO_INT(TEAM_DRAGONS_HEXTECH), 0, 4) AS TEAM_DRAGONS_HEXTECH,
    VALID_NUM_RANGE(SAFECAST_TO_INT(TEAM_DRAGONS), 0, 1E2) AS TEAM_DRAGONS,
    VALID_NUM_RANGE(SAFECAST_TO_INT(TEAM_BARONS), 0, 1E2) AS TEAM_BARONS,
    VALID_NUM_RANGE(SAFECAST_TO_INT(TEAM_VOID_GRUBS), 0, 1E2) AS TEAM_VOID_GRUBS,
    VALID_NUM_RANGE(SAFECAST_TO_INT(TEAM_HERALDS), 0, 1E2) AS TEAM_HERALDS,
    SAFECAST_TO_INT(TEAM_GOLD_DIFF) AS TEAM_GOLD_DIFF
FROM BRONZE.INTERVALS_STM
;
-------------------------------------------------------------------------------------------
    -- 2. SILVER TABLE: Player-minute grain, with team-level objective stats attached
    -- (duplicated across the 5 players sharing a team/minute). FK to PLAYERS.
-------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS SILVER.INTERVALS (
    -- Key
    MATCH_ID VARCHAR NOT NULL,
    PARTICIPANT_POS_ID NUMBER(38,0) NOT NULL COMMENT 'The index position of the player at queue time. 1-5 for BLUE side, 6-10 for RED side.',
    TEAM VARCHAR NOT NULL COMMENT 'BLUE or RED.',
    MINUTE NUMBER(38,0) NOT NULL COMMENT 'Minute mark of this snapshot, in 5-minute intervals.',
    -- Economy
    CURRENT_GOLD NUMBER(38,0) COMMENT 'Unspent gold on hand at this minute mark.',
    TOTAL_GOLD NUMBER(38,0) COMMENT 'Cumulative gold earned by this minute mark.',
    CS NUMBER(38,0) COMMENT 'Minion/lane creep score at this minute mark.',
    JUNGLE_CS NUMBER(38,0) COMMENT 'Jungle creep score at this minute mark.',
    XP NUMBER(38,0) COMMENT 'Cumulative experience at this minute mark.',
    LEVEL NUMBER(38,0) COMMENT 'Champion level at this minute mark.',
    -- KDA
    KILLS NUMBER(38,0) COMMENT 'Player kills at this minute mark.',
    DEATHS NUMBER(38,0) COMMENT 'Player deaths at this minute mark.',
    ASSISTS NUMBER(38,0) COMMENT 'Player assists at this minute mark.',
    -- Itemization
    ITEM_0 NUMBER(38,0) COMMENT 'Item in inventory slot 0.',
    ITEM_1 NUMBER(38,0) COMMENT 'Item in inventory slot 1.',
    ITEM_2 NUMBER(38,0) COMMENT 'Item in inventory slot 2.',
    ITEM_3 NUMBER(38,0) COMMENT 'Item in inventory slot 3.',
    ITEM_4 NUMBER(38,0) COMMENT 'Item in inventory slot 4.',
    ITEM_5 NUMBER(38,0) COMMENT 'Item in inventory slot 5.',
    ITEM_6 NUMBER(38,0) COMMENT 'Item in inventory slot 6.',
    -- Player diffs
    GOLD_DIFF NUMBER(38,0) COMMENT '(Player gold - their lane opponent gold) at this minute mark.',
    XP_DIFF NUMBER(38,0) COMMENT '(Player XP - their lane opponent XP) at this minute mark.',
    -- Team's objectives (duplicated across the 5 players sharing a team/minute)
    TEAM_KILLS NUMBER(38,0) COMMENT 'Team total kills at this minute mark.',
    TEAM_INHIBITORS NUMBER(38,0) COMMENT 'Team inhibitors destroyed at this minute mark.',
    TEAM_TOWERS NUMBER(38,0) COMMENT 'Team towers destroyed at this minute mark.',
    TEAM_DRAGONS_FIRE NUMBER(38,0) COMMENT 'Infernal (fire) dragons taken by this team.',
    TEAM_DRAGONS_WATER NUMBER(38,0) COMMENT 'Ocean (water) dragons taken by this team.',
    TEAM_DRAGONS_EARTH NUMBER(38,0) COMMENT 'Mountain (earth) dragons taken by this team.',
    TEAM_DRAGONS_AIR NUMBER(38,0) COMMENT 'Cloud (air) dragons taken by this team.',
    TEAM_DRAGONS_CHEMTECH NUMBER(38,0) COMMENT 'Chemtech dragons taken by this team.',
    TEAM_DRAGONS_HEXTECH NUMBER(38,0) COMMENT 'Hextech dragons taken by this team.',
    TEAM_DRAGONS NUMBER(38,0) COMMENT 'Total dragons of any element taken by this team.',
    TEAM_BARONS NUMBER(38,0) COMMENT 'Baron Nashors taken by this team.',
    TEAM_VOID_GRUBS NUMBER(38,0) COMMENT 'Void Grubs taken by this team.',
    TEAM_HERALDS NUMBER(38,0) COMMENT 'Rift Heralds taken by this team.',
    TEAM_GOLD_DIFF NUMBER(38,0) COMMENT '(Team gold - enemy team gold) at this minute mark.',

    CONSTRAINT SILVER_INTERVALS_PKEY PRIMARY KEY (MATCH_ID, PARTICIPANT_POS_ID, MINUTE),
    CONSTRAINT SILVER_INTERVALS_MATCHES_FKEY FOREIGN KEY (MATCH_ID) REFERENCES SILVER.MATCHES (MATCH_ID),
    CONSTRAINT SILVER_INTERVALS_PLAYERS_FKEY
        FOREIGN KEY (MATCH_ID, PARTICIPANT_POS_ID) REFERENCES SILVER.PLAYERS (MATCH_ID, PARTICIPANT_POS_ID)
)
COMMENT = '[SILVER] Classic mode (Summoner''s Rift 5v5, draft queue) player-minute grain interval snapshots, with team-level objective stats attached.';

-------------------------------------------------------------------------------------------
    -- 3. TASK: Merge new/changed rows from cleaning view into INTERVALS
-------------------------------------------------------------------------------------------
CREATE TASK IF NOT EXISTS SILVER.BRONZE_TO_SILVER_INTERVALS_TASK
    WAREHOUSE = COMPUTE_WH
    SCHEDULE  = '1 MINUTE'
    SUSPEND_TASK_AFTER_NUM_FAILURES = 3
    WHEN SYSTEM$STREAM_HAS_DATA('BRONZE.INTERVALS_STM')
AS
MERGE INTO SILVER.INTERVALS AS tgt
USING (
    SELECT *
    FROM SILVER.INTERVALS_STM_TO_SILVER
    WHERE MATCH_ID IS NOT NULL
        AND PARTICIPANT_POS_ID IS NOT NULL
        AND TEAM IS NOT NULL
        AND MINUTE IS NOT NULL
) AS src
    ON  tgt.MATCH_ID           = src.MATCH_ID
    AND tgt.PARTICIPANT_POS_ID = src.PARTICIPANT_POS_ID
    AND tgt.MINUTE             = src.MINUTE
WHEN MATCHED THEN UPDATE SET
    tgt.TEAM                  = src.TEAM,
    tgt.CURRENT_GOLD          = src.CURRENT_GOLD,
    tgt.TOTAL_GOLD            = src.TOTAL_GOLD,
    tgt.CS                    = src.CS,
    tgt.JUNGLE_CS             = src.JUNGLE_CS,
    tgt.XP                    = src.XP,
    tgt.LEVEL                 = src.LEVEL,
    tgt.KILLS                 = src.KILLS,
    tgt.DEATHS                = src.DEATHS,
    tgt.ASSISTS               = src.ASSISTS,
    tgt.ITEM_0                = src.ITEM_0,
    tgt.ITEM_1                = src.ITEM_1,
    tgt.ITEM_2                = src.ITEM_2,
    tgt.ITEM_3                = src.ITEM_3,
    tgt.ITEM_4                = src.ITEM_4,
    tgt.ITEM_5                = src.ITEM_5,
    tgt.ITEM_6                = src.ITEM_6,
    tgt.GOLD_DIFF             = src.GOLD_DIFF,
    tgt.XP_DIFF               = src.XP_DIFF,
    tgt.TEAM_KILLS            = src.TEAM_KILLS,
    tgt.TEAM_INHIBITORS       = src.TEAM_INHIBITORS,
    tgt.TEAM_TOWERS           = src.TEAM_TOWERS,
    tgt.TEAM_DRAGONS_FIRE     = src.TEAM_DRAGONS_FIRE,
    tgt.TEAM_DRAGONS_WATER    = src.TEAM_DRAGONS_WATER,
    tgt.TEAM_DRAGONS_EARTH    = src.TEAM_DRAGONS_EARTH,
    tgt.TEAM_DRAGONS_AIR      = src.TEAM_DRAGONS_AIR,
    tgt.TEAM_DRAGONS_CHEMTECH = src.TEAM_DRAGONS_CHEMTECH,
    tgt.TEAM_DRAGONS_HEXTECH  = src.TEAM_DRAGONS_HEXTECH,
    tgt.TEAM_DRAGONS          = src.TEAM_DRAGONS,
    tgt.TEAM_BARONS           = src.TEAM_BARONS,
    tgt.TEAM_VOID_GRUBS       = src.TEAM_VOID_GRUBS,
    tgt.TEAM_HERALDS          = src.TEAM_HERALDS,
    tgt.TEAM_GOLD_DIFF        = src.TEAM_GOLD_DIFF
WHEN NOT MATCHED THEN INSERT (
    MATCH_ID, PARTICIPANT_POS_ID, TEAM, MINUTE, CURRENT_GOLD, TOTAL_GOLD, CS, JUNGLE_CS,
    XP, LEVEL, KILLS, DEATHS, ASSISTS, ITEM_0, ITEM_1, ITEM_2, ITEM_3, ITEM_4, ITEM_5, ITEM_6,
    GOLD_DIFF, XP_DIFF, TEAM_KILLS, TEAM_INHIBITORS, TEAM_TOWERS, TEAM_DRAGONS_FIRE,
    TEAM_DRAGONS_WATER, TEAM_DRAGONS_EARTH, TEAM_DRAGONS_AIR, TEAM_DRAGONS_CHEMTECH,
    TEAM_DRAGONS_HEXTECH, TEAM_DRAGONS, TEAM_BARONS, TEAM_VOID_GRUBS, TEAM_HERALDS, TEAM_GOLD_DIFF
) VALUES (
    src.MATCH_ID, src.PARTICIPANT_POS_ID, src.TEAM, src.MINUTE, src.CURRENT_GOLD, src.TOTAL_GOLD,
    src.CS, src.JUNGLE_CS, src.XP, src.LEVEL, src.KILLS, src.DEATHS, src.ASSISTS, src.ITEM_0,
    src.ITEM_1, src.ITEM_2, src.ITEM_3, src.ITEM_4, src.ITEM_5, src.ITEM_6, src.GOLD_DIFF,
    src.XP_DIFF, src.TEAM_KILLS, src.TEAM_INHIBITORS, src.TEAM_TOWERS, src.TEAM_DRAGONS_FIRE,
    src.TEAM_DRAGONS_WATER, src.TEAM_DRAGONS_EARTH, src.TEAM_DRAGONS_AIR, src.TEAM_DRAGONS_CHEMTECH,
    src.TEAM_DRAGONS_HEXTECH, src.TEAM_DRAGONS, src.TEAM_BARONS, src.TEAM_VOID_GRUBS,
    src.TEAM_HERALDS, src.TEAM_GOLD_DIFF
);
