-------------------------------------------------------------------------------------------
    -- PRODUCTION SETUP STORY
    --
    -- In production, Riot's game client would upload a CSV snapshot to Cloud Blob Storage
    -- at the end of each match. Event Grid publishes a message to a Storage Queue on every
    -- new upload, which Snowpipe consumes to trigger an automatic COPY INTO STG_INTERVALS.
    --
    -- The four objects below wire that up, using Azure as the storage provider for demonstration.
    -- The result is an NRT loading (near real time) experience at no extra cost!
    --
    -- LEAGUE_AZINT         authenticates Snowflake against the blob container
    -- LEAGUE_AZNOTI        listens to the Storage Queue for new blob events
    -- DAILY_MATCH_FMT      defines how the CSV files are parsed
    -- DAILY_MATCH_AZSTG    landing stage on Snowflake's side

    -- Cost note: Because ingestion is event-driven, this pipeline is essentially free at rest
    -- and near real-time in motion.
-------------------------------------------------------------------------------------------

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
    --  Snowpipe subscribes to these messages to know exactly which file just landed
    --  rather than polling on a schedule. Allows for NRT loading. 
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
    