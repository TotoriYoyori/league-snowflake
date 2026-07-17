USE DATABASE LEAGUE_RECORDS;

USE SCHEMA BRONZE;
-------------------------------------------------------------------------------------------
    -- PROBLEM: There are 12 items referred to by MATCH_INTERVALS_SILVER ITEM_0 -> ITEM_7 
    -- that do not have corresponding reference rows under ITEMS_REF_SILVER
-------------------------------------------------------------------------------------------
WITH ALL_PURCHASED_ITEMS_ID AS (
    SELECT
        MATCH_ID,
        PARTICIPANT_POS_ID,
        ITEM.VALUE AS ITEM_ID
    FROM (
        SELECT 
            MATCH_ID,
            PARTICIPANT_POS_ID,
            ARRAY_SORT(ARRAY_CONSTRUCT_COMPACT(
                ITEM_0, ITEM_1, ITEM_2, ITEM_3, ITEM_4, ITEM_5, ITEM_6
            )) AS ITEM_ARRAY
        FROM SILVER.PLAYER_INTERVAL_SILVER
    ) AS BASE
    CROSS JOIN LATERAL FLATTEN(INPUT => BASE.ITEM_ARRAY) AS ITEM
    WHERE ITEM.VALUE != 0
)

SELECT DISTINCT AP.ITEM_ID
FROM ALL_PURCHASED_ITEMS_ID AS AP
LEFT JOIN SILVER.ITEMS_REF_SILVER AS IR
    ON IR.ITEM_ID = AP.ITEM_ID
WHERE IR.ITEM_NAME IS NULL
;
-- 2524, 3097, 2512, 8010, 2522, 3340, 2510, 2517, 2525, 2520, 2523, 2526 << Orphaned ITEM_ID
    
-------------------------------------------------------------------------------------------
    -- SOLUTION: Manually discover and seed the 12 missing entries into ITEMS_REF_BRONZE 
    -- 01. Research what the items are corresponding to the orphaned ID.
    -- 02. Manual insert using INSERT() VALUES()
    -- 03. Bronze stream picks up delta
    -- 04. Task handles dedup and propagate new data downstream
-------------------------------------------------------------------------------------------
INSERT INTO BRONZE.ITEMS_REF_BRONZE (
    ITEM_ID, ITEM_NAME, ITEM_CATEGORY, LDTS, FILE_NAME, FILE_ROW_NUMBER, RSRC
)
SELECT
    v.ITEM_ID,
    v.ITEM_NAME,
    v.ITEM_CATEGORY,
    CURRENT_TIMESTAMP(),
    '_NULL.csv',
    v.FILE_ROW_NUMBER,
    'Manual backfill'
FROM (
    SELECT * FROM VALUES
        (2510, 'Dusk and Dawn',          'Legendary', 1),
        (8010, 'Bloodletter''s Curse',   'Legendary', 2),
        (3097, 'Stormrazor',             'Legendary', 3),
        (2517, 'Endless Hunger',         'Legendary', 4),
        (2525, 'Protoplasm Harness',     'Legendary', 5),
        (2522, 'Actualizer',             'Legendary', 6),
        (2526, 'Whispering Circlet',     'Legendary', 7),
        (3340, 'Stealth Ward',           'Trinket',   8),
        (2524, 'Bandlepipes',            'Legendary', 9),
        (2512, 'Fiendhunter Bolts',      'Legendary', 10),
        (2523, 'Hexoptics C44',          'Legendary', 11),
        (2520, 'Bastionbreaker',         'Legendary', 12)
    AS v(ITEM_ID, ITEM_NAME, ITEM_CATEGORY, FILE_ROW_NUMBER)
) AS v
WHERE NOT EXISTS (
    SELECT 1
    FROM BRONZE.ITEMS_REF_BRONZE AS tgt
    WHERE tgt.ITEM_ID = v.ITEM_ID
);

-------------------------------------------------------------------------------------------
    -- VERIFY: Verify that BRONZE.ITEMS_REF_BRONZE have received the change and all downstream
    -- propagations happen for this schema (ITEMS_REF_SILVER)
-------------------------------------------------------------------------------------------
--SELECT
--    COUNT(B.ITEM_ID) AS BRONZE_ROWS_INSERTED,
--    COUNT(S.ITEM_ID) AS SILVER_ROWS_INSERTED,
--    COUNT(B.ITEM_ID) = COUNT(S.ITEM_ID) AS ALL_RECORDS_PROPAGATED
--FROM (
--    SELECT ITEM_ID
--    FROM BRONZE.ITEMS_REF_BRONZE
--    WHERE RSRC = 'Manual backfill'
--) AS B
--JOIN SILVER.ITEMS_REF_SILVER AS S
--    ON S.ITEM_ID = B.ITEM_ID
--;
