USE DATABASE LEAGUE_RECORDS;
USE SCHEMA GOLD;

-- CREATE OR REPLACE DYNAMIC TABLE GOLD.ITEM_RECOMMEND
--     TARGET_LAG = '1 hour'
--     WAREHOUSE = COMPUTE_WH
-- AS
-------------------------------------------------------------------------------------------
    -- 01. FINAL_SNAPSHOT -> FINAL_SNAPSHOT_WITH_STATS (Base)
    -- Capture only the last-logged snapshot in player interval data.
-------------------------------------------------------------------------------------------
WITH FINAL_SNAPSHOT AS (
    SELECT *
    FROM SILVER.PLAYER_INTERVAL_SILVER
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY MATCH_ID, PARTICIPANT_POS_ID
        ORDER BY MINUTE DESC
    ) = 1
),

FINAL_SNAPSHOT_WITH_STATS AS (
    SELECT
        -- Join key 
        FS.MATCH_ID,
        FS.PARTICIPANT_POS_ID,
        -- Context
        (PS.TEAM = MAT.WINNING_TEAM) AS WIN,
        PS.CHAMPION,
        -- Last-interval KDA
        FS.KILLS, 
        FS.DEATHS, 
        FS.ASSISTS,
        -- Item Build
        ARRAY_SORT(ARRAY_CONSTRUCT_COMPACT(
            FS.ITEM_0, FS.ITEM_1, FS.ITEM_2, FS.ITEM_3, FS.ITEM_4, FS.ITEM_5, FS.ITEM_6
        )) AS ITEM_BUILD,
    FROM FINAL_SNAPSHOT AS FS
    JOIN SILVER.MATCHES_SUMMARY_SILVER AS MAT
        ON MAT.MATCH_ID = FS.MATCH_ID
    JOIN SILVER.PLAYERS_SUMMARY_SILVER AS PS
        ON PS.MATCH_ID = FS.MATCH_ID
        AND PS.PARTICIPANT_POS_ID = FS.PARTICIPANT_POS_ID
),
-------------------------------------------------------------------------------------------
    -- 02. FLATTENED_ITEM --> FLATTENED_ITEMS_WITH_REF
    -- Break up item's build array and stitch back per player's last logged interval.
    -- Afterward joined with ITEMS_REF_SILVER to get name and its category
-------------------------------------------------------------------------------------------
FLATTENED_ITEMS AS (
    SELECT
        FS.MATCH_ID,
        FS.PARTICIPANT_POS_ID,
        FS.WIN, 
        FS.CHAMPION,
        FS.KILLS, 
        FS.DEATHS, 
        FS.ASSISTS, 
        -- Exploded one item_id per match-participant
        ITEM.VALUE::VARCHAR AS ITEM_ID
    FROM FINAL_SNAPSHOT_WITH_STATS AS FS
    CROSS JOIN LATERAL FLATTEN(INPUT => FS.ITEM_BUILD) AS ITEM
),

FLATTENED_ITEMS_WITH_REF AS (
    SELECT
        FI.MATCH_ID,
        FI.PARTICIPANT_POS_ID,
        FI.WIN, 
        FI.CHAMPION,
        FI.KILLS, 
        FI.DEATHS, 
        FI.ASSISTS, 
        -- Joined from ITEMS_REF_SILVER
        FI.ITEM_ID,
        IR.ITEM_NAME,
        IR.ITEM_CATEGORY,
        -- Rank item's category for recommendation system (only recommend equal or higher rank items)
        CASE IR.ITEM_CATEGORY
            WHEN 'Trinket'    THEN 1
            WHEN 'Consumable' THEN 2
            WHEN 'Starter'    THEN 3
            WHEN 'Basic'      THEN 4
            WHEN 'Boots'      THEN 5
            WHEN 'Epic'       THEN 6
            WHEN 'Legendary'  THEN 7
            -- IN ('Others', 'Distributed', 'Legacy'). These do not get recommendations. 
            ELSE NULL
        END AS TIER_RANK
    FROM FLATTENED_ITEMS AS FI
    LEFT JOIN SILVER.ITEMS_REF_SILVER AS IR
        ON IR.ITEM_ID = FI.ITEM_ID
)

SELECT DISTINCT ITEM_ID
FROM FLATTENED_ITEMS_WITH_REF
WHERE ITEM_NAME IS NULL
;
-------------------------------------------------------------------------------------------
    -- FLATTENED_ITEMS_WITH_REF: join category onto flattened rows, exclude Other/Legacy/Distributed
    -- (not real recommendable shop tiers), and attach a numeric TIER_RANK encoding the
    -- LoL item-upgrade hierarchy (low -> high):
    --   1 Trinket, 2 Consumable, 3 Starter, 4 Basic, 5 Boots, 6 Epic, 7 Legendary
    -- TIER_RANK drives CO_OCCURRENCE below: an item only recommends alongside items of
    -- the SAME rank or HIGHER (e.g. Basic recommends Basic/Boots/Epic/Legendary, but
    -- Legendary -- the top of the pipeline -- only recommends other Legendaries).
-------------------------------------------------------------------------------------------
ITEM_STATS AS (
    SELECT
        CHAMPION,
        ITEM_NAME,
        ITEM_CATEGORY,
        COUNT(*)                                                AS PLAYERS_PURCHASED,
        SUM(IFF(WIN, 1, 0))                                      AS WINS_WITH_ITEM,
        ROUND(AVG((KILLS + ASSISTS) / (DEATHS + 1)), 2)          AS AVG_KDA
    FROM FLATTENED_ITEMS_WITH_REF
    GROUP BY CHAMPION, ITEM_NAME, ITEM_CATEGORY
),

-- Denominator now scoped per champion: "player-matches ON THIS CHAMPION with interval data."
TOTAL_PLAYERS_BY_CHAMPION AS (
    SELECT FS.CHAMPION, COUNT(*) AS TOTAL_PLAYER_MATCHES
    FROM FINAL_SNAPSHOT_WITH_STATS AS FS
    GROUP BY FS.CHAMPION
),

-------------------------------------------------------------------------------------------
    -- CO_OCCURRENCE: tier-hierarchy self-join, NOT a simple half-volume dedupe anymore.
    --
    -- Why this can't reuse the old "A.ITEM_NAME < B.ITEM_NAME" half-volume trick:
    -- that trick relied on the relationship being symmetric (same-category equality --
    -- if A pairs with B, B pairs with A, so compute once and mirror). Tier-hierarchy
    -- is NOT symmetric: Doran's Blade (Starter, rank 3) should recommend Infinity Edge
    -- (Legendary, rank 7), but Infinity Edge should NOT recommend Doran's Blade back --
    -- Legendary only recommends Legendary. So instead of one inequality, every ORDERED
    -- pair within a match/player/champion is computed once via A.ITEM_NAME != B.ITEM_NAME,
    -- and the tier filter (B.TIER_RANK >= A.TIER_RANK) determines which direction is
    -- kept. This computes the full N^2 ordered-pair volume per build rather than half --
    -- builds only have up to ~6-7 items, so this is not a meaningful cost increase.
-------------------------------------------------------------------------------------------
CO_OCCURRENCE AS (
    SELECT
        A.CHAMPION,
        A.ITEM_NAME AS ITEM,
        B.ITEM_NAME AS CO_ITEM,
        COUNT(*)    AS CO_PURCHASE_COUNT
    FROM FLATTENED_ITEMS_WITH_REF A
    JOIN FLATTENED_ITEMS_WITH_REF B
        ON A.MATCH_ID = B.MATCH_ID
        AND A.PARTICIPANT_POS_ID = B.PARTICIPANT_POS_ID
        AND A.CHAMPION = B.CHAMPION
        AND A.ITEM_NAME != B.ITEM_NAME
        AND B.TIER_RANK >= A.TIER_RANK   -- B is same tier or higher than A
    GROUP BY A.CHAMPION, A.ITEM_NAME, B.ITEM_NAME
),

-------------------------------------------------------------------------------------------
    -- No "BOTH_DIRECTIONS" union here -- CO_OCCURRENCE above is already the complete,
    -- correctly-directional set (every ITEM only ever lists CO_ITEMs of >= its own
    -- tier). Mirroring it would reintroduce the symmetry we just removed (it would
    -- put Starter items back into Legendary's recommendation list).
-------------------------------------------------------------------------------------------
RANKED_CO_OCCURRENCE AS (
    SELECT
        CHAMPION, ITEM, CO_ITEM,
        ROW_NUMBER() OVER (
            PARTITION BY CHAMPION, ITEM ORDER BY CO_PURCHASE_COUNT DESC, CO_ITEM
        ) AS CO_RANK
    FROM CO_OCCURRENCE
    QUALIFY CO_RANK <= 3
),
TOP3_WIDE AS (
    SELECT
        CHAMPION, ITEM,
        MAX(IFF(CO_RANK = 1, CO_ITEM, NULL)) AS TOP_ITEM_1,
        MAX(IFF(CO_RANK = 2, CO_ITEM, NULL)) AS TOP_ITEM_2,
        MAX(IFF(CO_RANK = 3, CO_ITEM, NULL)) AS TOP_ITEM_3
    FROM RANKED_CO_OCCURRENCE
    GROUP BY CHAMPION, ITEM
),

-------------------------------------------------------------------------------------------
    -- First-purchase timing, scoped per champion. Same Other/Legacy/Distributed
    -- exclusion applied here for consistency with FLATTENED_ITEMS_WITH_REF (tier hierarchy itself
    -- doesn't affect this CTE -- it's a standalone per-item stat, not a pairwise one).
-------------------------------------------------------------------------------------------
ITEM_APPEARANCES AS (
    SELECT
        PI.MATCH_ID, PI.PARTICIPANT_POS_ID, PI.MINUTE,
        ITEM.VALUE::VARCHAR AS ITEM_NAME
    FROM SILVER.PLAYER_INTERVAL_SILVER AS PI,
        LATERAL FLATTEN(INPUT => ARRAY_CONSTRUCT_COMPACT(
            PI.ITEM_0, PI.ITEM_1, PI.ITEM_2, PI.ITEM_3, PI.ITEM_4, PI.ITEM_5, PI.ITEM_6
        )) AS ITEM
),

FIRST_PURCHASE AS (
    SELECT
        IA.MATCH_ID, IA.PARTICIPANT_POS_ID, IA.ITEM_NAME,
        PS.CHAMPION,
        MIN(IA.MINUTE) AS FIRST_MINUTE
    FROM ITEM_APPEARANCES AS IA
    JOIN SILVER.PLAYERS_SUMMARY_SILVER AS PS
        ON PS.MATCH_ID = IA.MATCH_ID
        AND PS.PARTICIPANT_POS_ID = IA.PARTICIPANT_POS_ID
    LEFT JOIN SILVER.ITEMS_REF_SILVER AS IR
        ON IR.ITEM_NAME = IA.ITEM_NAME
    WHERE IR.ITEM_CATEGORY NOT IN ('Other', 'Legacy', 'Distributed')
    GROUP BY IA.MATCH_ID, IA.PARTICIPANT_POS_ID, IA.ITEM_NAME, PS.CHAMPION
),

FIRST_PURCHASE_COUNTS AS (
    SELECT CHAMPION, ITEM_NAME, FIRST_MINUTE, COUNT(*) AS CNT
    FROM FIRST_PURCHASE
    GROUP BY CHAMPION, ITEM_NAME, FIRST_MINUTE
),

MOST_COMMON_FIRST_PURCHASE AS (
    SELECT
        CHAMPION,
        ITEM_NAME,
        FIRST_MINUTE AS MOST_COMMON_FIRST_PURCHASE_MINUTE,
        ROW_NUMBER() OVER (
            PARTITION BY CHAMPION, ITEM_NAME ORDER BY CNT DESC, FIRST_MINUTE
        ) AS FIRST_MINUTE_RANK
    FROM FIRST_PURCHASE_COUNTS
    QUALIFY FIRST_MINUTE_RANK = 1
),

ITEM_STATS_FINAL AS (
    SELECT
        IS_.CHAMPION,
        IS_.ITEM_NAME                                                          AS ITEM,
        IS_.ITEM_CATEGORY,
        ROUND(IS_.PLAYERS_PURCHASED / TP.TOTAL_PLAYER_MATCHES::FLOAT, 4)       AS PLAYER_PURCHASE_RATE,
        ROUND(IS_.WINS_WITH_ITEM / IS_.PLAYERS_PURCHASED::FLOAT, 4)            AS WIN_RATE,
        IS_.AVG_KDA,
        MCFP.MOST_COMMON_FIRST_PURCHASE_MINUTE,
        T3.TOP_ITEM_1,
        T3.TOP_ITEM_2,
        T3.TOP_ITEM_3
    FROM ITEM_STATS AS IS_
    JOIN TOTAL_PLAYERS_BY_CHAMPION AS TP
        ON TP.CHAMPION = IS_.CHAMPION
    LEFT JOIN TOP3_WIDE AS T3
        ON T3.CHAMPION = IS_.CHAMPION AND T3.ITEM = IS_.ITEM_NAME
    LEFT JOIN MOST_COMMON_FIRST_PURCHASE AS MCFP
        ON MCFP.CHAMPION = IS_.CHAMPION AND MCFP.ITEM_NAME = IS_.ITEM_NAME
)

SELECT *
FROM ITEM_STATS_FINAL
WHERE CHAMPION = 'Sylas'
ORDER BY PLAYER_PURCHASE_RATE DESC
;