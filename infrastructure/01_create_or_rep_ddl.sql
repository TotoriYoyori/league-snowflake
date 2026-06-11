-- 1. Create database
CREATE DATABASE IF NOT EXISTS LEAGUE_RECORDS
    COMMENT = 'League of Legends match analytics: data vault modeling on in-game interval snapshots.';

-- 2. Create four data vault schema layers
CREATE SCHEMA IF NOT EXISTS LEAGUE_RECORDS.L00_STG
    COMMENT = 'STAGING LAYER: raw data ingestion';
    
CREATE SCHEMA IF NOT EXISTS LEAGUE_RECORDS.L10_RDV
    COMMENT = 'RAW DATA VAULT: single hub and monolithic satellite per source, keyed and hash-diffed.';
    
CREATE SCHEMA IF NOT EXISTS LEAGUE_RECORDS.L20_BDV
    COMMENT = 'BUSINESS DATA VAULT: domain-split satellites (KDA, economy, items, objectives).';
    
CREATE SCHEMA IF NOT EXISTS LEAGUE_RECORDS.L30_ID
    COMMENT = 'INFORMATION DELIVERY: star dimensional models built from the business vault.';
