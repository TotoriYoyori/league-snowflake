USE DATABASE LEAGUE_RECORDS;
USE SCHEMA L00_STG

-- 1. Connect Azure Blob Storage with this project's database
-- -- If reproducing this project, use your own azure credentials
CREATE OR REPLACE STORAGE INTEGRATION LEAGUE_AZINT
    TYPE = EXTERNAL_STAGE
    STORAGE_PROVIDER = 'AZURE'
    AZURE_TENANT_ID = '<azure_tenant_id>'
    ENABLED = TRUE
    STORAGE_ALLOWED_LOCATIONS = (
        'azure://<storageaccount>.blob.core.windows.net/<container>/<folder>'
    )
    COMMENT = 'Linking with STORAGE ACCOUNT <storageaccount> ... on CONTAINER <container>'


-- 2. Define file format from above Azure's storage
CREATE OR REPLACE FILE FORMAT DAILY_MATCH_FMT
    TYPE = 'CSV'
    FIELD_DELIMITER = ','
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    TRIM_SPACE = TRUE
    NULL_IF = ('', 'NULL')
    EMPTY_FIELD_AS_NULL = TRUE
    COMPRESSION = 'AUTO';


-- 3. Create stage to host Azure's file using above integration and file format
CREATE OR REPLACE STAGE DAILY_MATCH_AZSTG
    URL = 'azure://<storageaccount>.blob.core.windows.net/<container>/<folder>'
    STORAGE_INTEGRATION = LEAGUE_AZINT
    FILE_FORMAT = DAILY_MATCH_FMT
    COMMENT = 'Staging WITH <storageaccount> on Azure FROM /<container>/<folder>';
