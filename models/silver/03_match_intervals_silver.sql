-- Silver layer: match intervals cleaning view and table DDL.
-- Co-authored with CoCo
-------------------------------------------------------------------------------------------
    -- 0. DECLARE WORKING CONTEXT
-------------------------------------------------------------------------------------------
USE DATABASE LEAGUE_RECORDS;

USE SCHEMA SILVER;


-------------------------------------------------------------------------------------------
    -- 1. CLEANING VIEW: Match intervals from bronze stream
    -- TODO: Define cleaning/enrichment logic after discussion
-------------------------------------------------------------------------------------------
-- CREATE OR REPLACE VIEW MATCH_INTERVALS_BRONZE_STM_TO_SILVER AS ...


-------------------------------------------------------------------------------------------
    -- 2. SILVER TABLE: Cleaned/enriched per-minute interval snapshots
    -- TODO: Define schema after discussion
-------------------------------------------------------------------------------------------
-- CREATE OR REPLACE TABLE MATCH_INTERVALS_SILVER ( ... );
