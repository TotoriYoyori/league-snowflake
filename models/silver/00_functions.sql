USE SCHEMA SILVER;


-------------------------------------------------------------------------------------------
    -- HELPER UDF: Collection of reusable cleaning functions in the silver layer
-------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION SILVER.VALID_NUM_RANGE(
   NUM_VAL NUMBER,
   NUM_MIN NUMBER,
   NUM_MAX NUMBER
) RETURNS NUMBER
COMMENT = '[SILVER] Nullifies NUM_VAL when outside of valid [NUM_MIN, NUM_MAX] range'
AS
$$ CASE WHEN NUM_VAL BETWEEN NUM_MIN AND NUM_MAX THEN NUM_VAL ELSE NULL END $$
;


CREATE OR REPLACE FUNCTION SILVER.VALID_TS_RANGE(
    TS_VAL TIMESTAMP_NTZ,
    TS_MIN TIMESTAMP_NTZ,
    TS_MAX TIMESTAMP_NTZ
) RETURNS TIMESTAMP_NTZ
COMMENT = '[SILVER] Nullifies TS_VAL when outside of valid [TS_MIN, TS_MAX] range'
AS
$$ CASE WHEN TS_VAL BETWEEN TS_MIN AND TS_MAX THEN TS_VAL ELSE NULL END $$
;


CREATE OR REPLACE FUNCTION SILVER.NULLIFY_CAPLEN(RAW_VALUE VARCHAR, MAX_LEN NUMBER)
RETURNS VARCHAR
COMMENT = '[SILVER] Nullifies RAW_VALUE when LENGTH(RAW_VALUE) > MAX_LEN.'
AS
$$ CASE WHEN LENGTH(RAW_VALUE) <= MAX_LEN THEN RAW_VALUE ELSE NULL END $$
;


CREATE OR REPLACE FUNCTION SILVER.PASCAL_TO_TITLE_CASE(RAW_VALUE VARCHAR)
RETURNS VARCHAR
COMMENT = '[SILVER] Normalizes PascalCase or inconsistently-cased text into Title Case, e.g. TwistedFate -> Twisted Fate.'
AS
$$
INITCAP(TRIM(
    REGEXP_REPLACE(RAW_VALUE, '([a-z])([A-Z])', '\\1 \\2')
))
$$
;


CREATE OR REPLACE FUNCTION SILVER.SAFECAST_TO_INT(RAW_VALUE VARCHAR)
RETURNS NUMBER
COMMENT = '[SILVER] Expects and converts numeric-like strings to integer, regardless of decimals (rounds to nearest). NULL if cannot be converted.'
AS
$$
TRY_TO_NUMBER(
    ROUND(TRY_TO_NUMBER(RAW_VALUE, 38, 6), 0)
, 38, 0)
$$
;
