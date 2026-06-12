-------------------------------------------------------------------------------------------
    -- 0. DECLARE WORKING CONTEXT
-------------------------------------------------------------------------------------------
USE DATABASE LEAGUE_RECORDS;

USE SCHEMA L00_STG;

-------------------------------------------------------------------------------------------
    -- 1. CREATE STORAGE INTEGRATION WITH AZURE BLOB 
-------------------------------------------------------------------------------------------
CREATE OR REPLACE STORAGE INTEGRATION LEAGUE_AZINT
    TYPE = EXTERNAL_STAGE
    STORAGE_PROVIDER = 'AZURE'
    AZURE_TENANT_ID = '<azure_tenant_id>'
    ENABLED = TRUE
    STORAGE_ALLOWED_LOCATIONS = (
        'azure://<storageaccount>.blob.core.windows.net/<container>/<folder>'
    )
    COMMENT = 'Linking with STORAGE ACCOUNT <storageaccount> ... on CONTAINER <container>';


-------------------------------------------------------------------------------------------
    -- 2. CREATE NOTIFICATION INTEGRATION WITH AZURE BLOB FOR AUTO-INGEST
-------------------------------------------------------------------------------------------
CREATE OR REPLACE NOTIFICATION INTEGRATION LEAGUE_AZNOTI
    ENABLED = true
    TYPE = QUEUE
    NOTIFICATION_PROVIDER = AZURE_STORAGE_QUEUE
    AZURE_STORAGE_QUEUE_PRIMARY_URI = (
        'https://<storageaccount>.queue.core.windows.net/<message_queue>'
    )
    AZURE_TENANT_ID = '<azure_tenant_id>';
    

-------------------------------------------------------------------------------------------
    -- 3. DECLARE FILE FORMAT FOR THE STORAGE INTEGRATION
-------------------------------------------------------------------------------------------
CREATE OR REPLACE FILE FORMAT DAILY_MATCH_FMT
    TYPE = 'CSV'
    FIELD_DELIMITER = ','
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    TRIM_SPACE = TRUE
    NULL_IF = ('', 'NULL')
    EMPTY_FIELD_AS_NULL = TRUE
    COMPRESSION = 'AUTO';


-------------------------------------------------------------------------------------------
    -- 4. CREATE STAGE CONNECTED WITH AZURE BLOB
-------------------------------------------------------------------------------------------
CREATE OR REPLACE STAGE DAILY_MATCH_AZSTG
    URL = 'azure://<storageaccount>.blob.core.windows.net/<container>/<folder>'
    STORAGE_INTEGRATION = LEAGUE_AZINT
    FILE_FORMAT = DAILY_MATCH_FMT
    COMMENT = 'Staging WITH <storageaccount> on Azure FROM /<container>/<folder>';
