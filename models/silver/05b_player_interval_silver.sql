-- Silver player interval table DDL
-- Co-authored with CoCo
USE SCHEMA SILVER;

-------------------------------------------------------------------------------------------
    -- PLAYER_INTERVAL_SILVER TABLE: Player-minute grain. (MATCH_ID, TEAM, MINUTE) FK toward
    -- the team-minute grain. 
-------------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE PLAYER_INTERVAL_SILVER (
    ID                  NUMBER(38,0) NOT NULL,
    MATCH_ID            VARCHAR(64) NOT NULL,
    PARTICIPANT_POS_ID  NUMBER(38,0) NOT NULL,
    TEAM                VARCHAR(4) NOT NULL,
    MINUTE              NUMBER(3,0),
    CURRENT_GOLD        NUMBER(38,0),
    TOTAL_GOLD          NUMBER(38,0),
    CS                  NUMBER(38,0),
    JUNGLE_CS           NUMBER(38,0),
    XP                  NUMBER(38,0),
    LEVEL               NUMBER(38,0),
    KILLS               NUMBER(38,0),
    DEATHS              NUMBER(38,0),
    ASSISTS             NUMBER(38,0),
    ITEM_0              VARCHAR(255),
    ITEM_1              VARCHAR(255),
    ITEM_2              VARCHAR(255),
    ITEM_3              VARCHAR(255),
    ITEM_4              VARCHAR(255),
    ITEM_5              VARCHAR(255),
    ITEM_6              VARCHAR(255),
    GOLD_DIFF           NUMBER(38,0),
    XP_DIFF             NUMBER(38,0),
    CONSTRAINT PLAYER_INTERVAL_SILVER_PKEY PRIMARY KEY (ID),
    CONSTRAINT PLAYER_INTERVAL_SILVER_PLAYER_FKEY
        FOREIGN KEY (MATCH_ID, PARTICIPANT_POS_ID)
        REFERENCES PLAYERS_SUMMARY_SILVER (MATCH_ID, PARTICIPANT_POS_ID),
    CONSTRAINT PLAYER_INTERVAL_SILVER_TEAM_FKEY
        FOREIGN KEY (MATCH_ID, TEAM, MINUTE)
        REFERENCES TEAM_INTERVAL_SILVER (MATCH_ID, TEAM, MINUTE)
)
COMMENT = '[SILVER] Cleaned per-player per-minute interval snapshots. Player-minute grain; team-level stats live in TEAM_INTERVAL_SILVER.';
