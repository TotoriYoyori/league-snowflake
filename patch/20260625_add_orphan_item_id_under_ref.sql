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
    ITEM_ID, 
    ITEM_NAME, 
    ITEM_CATEGORY,
    LDTS,
    FILE_NAME,
    FILE_ROW_NUMBER,
    RSRC
)
VALUES
    (2510, 'Dusk and Dawn', 'Legendary', CURRENT_TIMESTAMP(), '_NULL.csv', 1, 'Manual backfill'),
    (8010, 'Bloodletter''s Curse', 'Legendary', CURRENT_TIMESTAMP(), '_NULL.csv', 2, 'Manual backfill'),
    (3097, 'Stormrazor', 'Legendary', CURRENT_TIMESTAMP(), '_NULL.csv', 3, 'Manual backfill'),
    (2517, 'Endless Hunger', 'Legendary', CURRENT_TIMESTAMP(), '_NULL.csv', 4, 'Manual backfill'),
    (2525, 'Protoplasm Harness', 'Legendary', CURRENT_TIMESTAMP(), '_NULL.csv', 5, 'Manual backfill'),
    (2522, 'Actualizer', 'Legendary', CURRENT_TIMESTAMP(), '_NULL.csv', 6, 'Manual backfill'),
    (2526, 'Whispering Circlet', 'Legendary', CURRENT_TIMESTAMP(), '_NULL.csv', 7, 'Manual backfill'),
    (3340, 'Stealth Ward', 'Trinket', CURRENT_TIMESTAMP(), '_NULL.csv', 8, 'Manual backfill'),
    (2524, 'Bandlepipes', 'Legendary', CURRENT_TIMESTAMP(), '_NULL.csv', 9, 'Manual backfill'),
    (2512, 'Fiendhunter Bolts', 'Legendary', CURRENT_TIMESTAMP(), '_NULL.csv', 10, 'Manual backfill'),
    (2523, 'Hexoptics C44', 'Legendary', CURRENT_TIMESTAMP(), '_NULL.csv', 11, 'Manual backfill'),
    (2520, 'Bastionbreaker', 'Legendary', CURRENT_TIMESTAMP(), '_NULL.csv', 12, 'Manual backfill')
;

-------------------------------------------------------------------------------------------
    -- VERIFY: Verify that BRONZE.ITEMS_REF_BRONZE have received the change and all downstream
    -- propagations happen for this schema (ITEMS_REF_SILVER)
-------------------------------------------------------------------------------------------
SELECT 
    COUNT(B.ITEM_ID) AS BRONZE_ROWS_INSERTED,
    COUNT(S.ITEM_ID) AS SILVER_ROWS_INSERTED,
    COUNT(B.ITEM_ID) = COUNT(S.ITEM_ID) AS ALL_RECORDS_PROPAGATED
FROM (
    SELECT ITEM_ID
    FROM BRONZE.ITEMS_REF_BRONZE 
    WHERE RSRC = 'Manual backfill'
        AND TO_CHAR(LDTS, 'YYYY-MM-DD') = '2026-06-25'
) AS B
JOIN SILVER.ITEMS_REF_SILVER AS S
    ON S.ITEM_ID = B.ITEM_ID
;
