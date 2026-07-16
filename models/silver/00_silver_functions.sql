USE SCHEMA SILVER;


-------------------------------------------------------------------------------------------
    -- HELPER UDF: Collection of reusable cleaning functions in the silver layer
-------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION SILVER.NULLIFY_OVERSIZED(RAW_VALUE VARCHAR, MAX_LEN NUMBER)
RETURNS VARCHAR
COMMENT = '[SILVER] Nullifies RAW_VALUE when LENGTH(RAW_VALUE) > MAX_LEN.'
AS
$$ CASE WHEN LENGTH(RAW_VALUE) <= MAX_LEN THEN RAW_VALUE ELSE NULL END $$;


CREATE OR REPLACE FUNCTION SILVER.PASCAL_TO_TITLE_CASE(RAW_VALUE VARCHAR)
RETURNS VARCHAR
COMMENT = '[SILVER] Splits PascalCase into Title Case e.g. TwistedFate -> Twisted Fate.'
AS
$$ TRIM(REGEXP_REPLACE(RAW_VALUE, '([a-z])([A-Z])', '\\1 \\2')) $$;
