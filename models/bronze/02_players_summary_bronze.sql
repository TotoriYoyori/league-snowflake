-------------------------------------------------------------------------------------------
    -- 0. DECLARE WORKING CONTEXT
-------------------------------------------------------------------------------------------
USE DATABASE LEAGUE_RECORDS;

USE SCHEMA BRONZE;


-------------------------------------------------------------------------------------------
    -- 1. BRONZE TABLE: Player-level summary with load metadata
-------------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE PLAYERS_SUMMARY_BRONZE (
    -- Source columns
    ID                   NUMBER(38,0) NOT NULL,
    MATCH_ID             VARCHAR(255) NOT NULL,
    PARTICIPANT_ID       NUMBER(38,0),
    TEAM_ID              NUMBER(38,0),
    CHAMPION             VARCHAR(255),
    ROLE                 VARCHAR(255),
    INDIVIDUAL_POSITION  VARCHAR(255),
    -- Load Metadata
    LDTS                 TIMESTAMP_NTZ(9) NOT NULL,
    FILE_NAME            VARCHAR(255) NOT NULL,
    FILE_ROW_NUMBER      NUMBER(38,0) NOT NULL,
    RSRC                 VARCHAR(255) NOT NULL,
    -- Constraints
    CONSTRAINT PLAYERS_SUMMARY_BRONZE_PKEY PRIMARY KEY (ID)
)
COMMENT = '[BRONZE] Raw player summary. Loaded via PLAYERS_SUMMARY_PP from @PLAYERS_SUMMARY_STG.';


-------------------------------------------------------------------------------------------
    -- 2. STREAM: CDC for silver consumption
-------------------------------------------------------------------------------------------
CREATE OR REPLACE STREAM PLAYERS_SUMMARY_BRONZE_STM
    ON TABLE PLAYERS_SUMMARY_BRONZE
    COMMENT = 'PLAYERS_SUMMARY_BRONZE delta --> BRONZE_TO_SILVER_PLAYERS_TASK --> PLAYERS_SUMMARY_SILVER';
