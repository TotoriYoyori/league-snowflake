USE SCHEMA SILVER;

-------------------------------------------------------------------------------------------
    -- SILVER TABLE: Team-minute grain, deduplicated from the 5 identical player
    -- rows per team per minute. Surrogate numeric ID hashed from the natural key.
-------------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE SILVER.TEAM_INTERVAL_SILVER (
    -- Primary key
    ID                      NUMBER(38,0) NOT NULL,
    -- Natural composite key
    MATCH_ID                VARCHAR(64) NOT NULL,
    TEAM                    VARCHAR(4) NOT NULL,
    MINUTE                  NUMBER(38,0) NOT NULL,
    -- Team Objective Stats
    TEAM_KILLS              NUMBER(38,0),
    TEAM_INHIBITORS         NUMBER(38,0),
    TEAM_TOWERS             NUMBER(38,0),
    TEAM_DRAGONS_FIRE       NUMBER(38,0),
    TEAM_DRAGONS_WATER      NUMBER(38,0),
    TEAM_DRAGONS_EARTH      NUMBER(38,0),
    TEAM_DRAGONS_AIR        NUMBER(38,0),
    TEAM_DRAGONS_CHEMTECH   NUMBER(38,0),
    TEAM_DRAGONS_HEXTECH    NUMBER(38,0),
    TEAM_DRAGONS            NUMBER(38,0),
    TEAM_BARONS             NUMBER(38,0),
    TEAM_VOID_GRUBS         NUMBER(38,0),
    TEAM_HERALDS            NUMBER(38,0),
    TEAM_GOLD_DIFF          NUMBER(38,0),
    -- Constraints
    CONSTRAINT TEAM_INTERVAL_SILVER_PKEY PRIMARY KEY (ID),
    CONSTRAINT TEAM_INTERVAL_SILVER_CONTEXT_PKEY UNIQUE (MATCH_ID, TEAM, MINUTE),
    CONSTRAINT TEAM_INTERVAL_SILVER_MATCH_FKEY
        FOREIGN KEY (MATCH_ID) REFERENCES SILVER.MATCHES_SUMMARY_SILVER (MATCH_ID)
)
COMMENT = '[SILVER] Cleaned team-minute interval snapshots. Deduplicated from player-minute grain (one row per team per minute, not per player).';
