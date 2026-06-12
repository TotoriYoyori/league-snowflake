-------------------------------------------------------------------------------------------
    -- 0. DECLARE WORKING CONTEXT
-------------------------------------------------------------------------------------------
USE DATABASE LEAGUE_RECORDS;

USE SCHEMA L00_STG;


-------------------------------------------------------------------------------------------
    -- 1. CREATING STAGING TABLE FOR RAW DATA LANDING
-------------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE STG_INTERVALS (
    -- Identifier
	MATCH_ID VARCHAR(255) NOT NULL,
	ID NUMBER(38,0) NOT NULL,
	PLAYER_ID NUMBER(38,0) NOT NULL,
    -- Economy
	MINUTE NUMBER(2,0) NOT NULL,
	CURRENT_GOLD NUMBER(38,0),
	TOTAL_GOLD NUMBER(38,0),
	CS NUMBER(38,0),
	JUNGLE_CS NUMBER(38,0),
	XP NUMBER(38,0),
	LEVEL NUMBER(38,0),
    -- KDA
	KILLS NUMBER(38,0),
	DEATHS NUMBER(38,0),
	ASSISTS NUMBER(38,0),
    -- Itemization
	ITEM_0 NUMBER(38,0),
	ITEM_1 NUMBER(38,0),
	ITEM_2 NUMBER(38,0),
	ITEM_3 NUMBER(38,0),
	ITEM_4 NUMBER(38,0),
	ITEM_5 NUMBER(38,0),
	ITEM_6 NUMBER(38,0),
    -- Team's Objective
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
    -- Stats Diff
	GOLD_DIFF NUMBER(38,0),
	XP_DIFF NUMBER(38,0),
	TEAM_GOLD_DIFF NUMBER(38,0),
    -- Metadata
	LDTS TIMESTAMP_NTZ(9) NOT NULL,
	FILE_NAME VARCHAR(255) NOT NULL,
	FILE_ROW_NUMBER NUMBER(38,0) NOT NULL,
	RSRC VARCHAR(255) NOT NULL
)
COMMENT = 'League matches statistics, snapshot every 5 minutes.';


-------------------------------------------------------------------------------------------
    -- 2. CREATING SNOWPIPE TO INGEST FROM STAGE TO STAGING TABLE
-------------------------------------------------------------------------------------------
CREATE OR REPLACE PIPE AUTO_LEAGUE_PP
COMMENT = 'Auto-ingests league matches from Azure stage, expected batch daily.'
AUTO_INGEST = TRUE
INTEGRATION = 'LEAGUE_AZNOTI'
AS
COPY INTO STG_INTERVALS
FROM (
    SELECT 
        $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, 
        $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, 
        $21, $22, $23, $24, $25, $26, $27, $28, $29, $30, 
        $31, $32, $33, $34, $35, $36, $37,
        METADATA$FILENAME,
        METADATA$FILE_ROW_NUMBER,
        'League Client Daily Logger'
    FROM @DAILY_MATCH_AZSTG
);


-------------------------------------------------------------------------------------------
    -- 3. REFRESH ABOVE PIPE FOR FIRST TIME RUN OR MANUAL TRIGGER
-------------------------------------------------------------------------------------------
ALTER PIPE L00_STG.AUTO_LEAGUE_PP REFRESH;
