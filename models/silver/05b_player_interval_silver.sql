USE SCHEMA SILVER;

-------------------------------------------------------------------------------------------
    -- PLAYER_INTERVAL_SILVER TABLE: Player-minute grain. (MATCH_ID, TEAM, MINUTE) FK toward
    -- the team-minute grain. 
    
    -- 01. Editted: 2026/06/25 12:58 
    -- ITEM_0 -> 7 as VARCHAR(255) presented as name --> Is numeric type to keep base ID 
-------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS SILVER.PLAYER_INTERVAL_SILVER (
    -- Primary key
    ID                  NUMBER(38,0) NOT NULL,
    -- Natural composite key
    MATCH_ID            VARCHAR(64) NOT NULL,
    PARTICIPANT_POS_ID  NUMBER(38,0) NOT NULL,
    TEAM                VARCHAR(16) NOT NULL,
    MINUTE              NUMBER(38,0) NOT NULL,
    -- Economy
    CURRENT_GOLD        NUMBER(38,0),
    TOTAL_GOLD          NUMBER(38,0),
    CS                  NUMBER(38,0),
    JUNGLE_CS           NUMBER(38,0),
    XP                  NUMBER(38,0),
    LEVEL               NUMBER(38,0),
    -- KDA
    KILLS               NUMBER(38,0),
    DEATHS              NUMBER(38,0),
    ASSISTS             NUMBER(38,0),
    -- Itemization
    ITEM_0              NUMBER(38,0),
    ITEM_1              NUMBER(38,0),
    ITEM_2              NUMBER(38,0),
    ITEM_3              NUMBER(38,0),
    ITEM_4              NUMBER(38,0),
    ITEM_5              NUMBER(38,0),
    ITEM_6              NUMBER(38,0),
    -- Stats Diff
    GOLD_DIFF           NUMBER(38,0),
    XP_DIFF             NUMBER(38,0),
    CONSTRAINT PLAYER_INTERVAL_SILVER_PKEY PRIMARY KEY (ID),
    CONSTRAINT PLAYER_INTERVAL_SILVER_PLAYER_FKEY
        FOREIGN KEY (MATCH_ID, PARTICIPANT_POS_ID)
        REFERENCES SILVER.PLAYERS_SUMMARY_SILVER (MATCH_ID, PARTICIPANT_POS_ID),
    CONSTRAINT PLAYER_INTERVAL_SILVER_TEAM_FKEY
        FOREIGN KEY (MATCH_ID, TEAM, MINUTE)
        REFERENCES SILVER.TEAM_INTERVAL_SILVER (MATCH_ID, TEAM, MINUTE)
)
COMMENT = '[SILVER] Cleaned per-player per-minute interval snapshots. Player-minute grain; team-level stats live in TEAM_INTERVAL_SILVER.';
