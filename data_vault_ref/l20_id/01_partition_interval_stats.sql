-------------------------------------------------------------------------------------------
    -- 0. DECLARE WORKING CONTEXT
-------------------------------------------------------------------------------------------
USE DATABASE LEAGUE_RECORDS;

USE SCHEMA L20_ID;


-------------------------------------------------------------------------------------------
    -- 1. STREAM ON SAT_INTERVALS FOR INCREMENTAL LOADING
-------------------------------------------------------------------------------------------
CREATE OR REPLACE STREAM SAT_INTERVALS_STRM_ID
ON TABLE L10_RDV.SAT_INTERVALS
COMMENT = 'Captures new satellite rows for Information Delivery partition loading.';


-------------------------------------------------------------------------------------------
    -- 2. INTERVALS_KDA: Player combat performance per interval
-------------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE INTERVALS_KDA (
    ID NUMBER(38,0) NOT NULL,
    MATCH_ID VARCHAR(255) NOT NULL,
    PLAYER_ID NUMBER(38,0) NOT NULL,
    MINUTE NUMBER(2,0) NOT NULL,
    KILLS NUMBER(38,0),
    DEATHS NUMBER(38,0),
    ASSISTS NUMBER(38,0),
    KDA_RATIO NUMBER(10,2)
)
COMMENT = 'Player KDA stats per interval with derived KDA ratio.';


-------------------------------------------------------------------------------------------
    -- 3. INTERVALS_ECONOMY: Player economic performance per interval
-------------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE INTERVALS_ECONOMY (
    ID NUMBER(38,0) NOT NULL,
    MATCH_ID VARCHAR(255) NOT NULL,
    PLAYER_ID NUMBER(38,0) NOT NULL,
    MINUTE NUMBER(2,0) NOT NULL,
    CURRENT_GOLD NUMBER(38,0),
    TOTAL_GOLD NUMBER(38,0),
    CS NUMBER(38,0),
    JUNGLE_CS NUMBER(38,0),
    XP NUMBER(38,0),
    LEVEL NUMBER(38,0),
    GOLD_DIFF NUMBER(38,0),
    XP_DIFF NUMBER(38,0),
    NET_CS NUMBER(38,0),
    GOLD_PER_MIN NUMBER(10,2)
)
COMMENT = 'Player economy stats per interval with derived net CS and gold/min.';


-------------------------------------------------------------------------------------------
    -- 4. INTERVALS_ITEMS: Player itemization per interval
-------------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE INTERVALS_ITEMS (
    ID NUMBER(38,0) NOT NULL,
    MATCH_ID VARCHAR(255) NOT NULL,
    PLAYER_ID NUMBER(38,0) NOT NULL,
    MINUTE NUMBER(2,0) NOT NULL,
    ITEM_0 NUMBER(38,0),
    ITEM_1 NUMBER(38,0),
    ITEM_2 NUMBER(38,0),
    ITEM_3 NUMBER(38,0),
    ITEM_4 NUMBER(38,0),
    ITEM_5 NUMBER(38,0),
    ITEM_6 NUMBER(38,0)
)
COMMENT = 'Player item slots per interval.';


-------------------------------------------------------------------------------------------
    -- 5. INTERVALS_TEAM_OBJ: Team objectives per interval
-------------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE INTERVALS_TEAM_OBJ (
    ID NUMBER(38,0) NOT NULL,
    MATCH_ID VARCHAR(255) NOT NULL,
    PLAYER_ID NUMBER(38,0) NOT NULL,
    MINUTE NUMBER(2,0) NOT NULL,
    TEAM_KILLS NUMBER(38,0),
    TEAM_INHIBITORS NUMBER(38,0),
    TEAM_TOWERS NUMBER(38,0),
    TEAM_DRAGONS_FIRE NUMBER(38,0),
    TEAM_DRAGONS_WATER NUMBER(38,0),
    TEAM_DRAGONS_EARTH NUMBER(38,0),
    TEAM_DRAGONS_AIR NUMBER(38,0),
    TEAM_DRAGONS_CHEMTECH NUMBER(38,0),
    TEAM_DRAGONS_HEXTECH NUMBER(38,0),
    TEAM_DRAGONS NUMBER(38,0),
    TEAM_BARONS NUMBER(38,0),
    TEAM_VOID_GRUBS NUMBER(38,0),
    TEAM_HERALDS NUMBER(38,0),
    TEAM_GOLD_DIFF NUMBER(38,0),
    TOTAL_OBJECTIVES NUMBER(38,0)
)
COMMENT = 'Team objective stats per interval with derived total objectives count.';
