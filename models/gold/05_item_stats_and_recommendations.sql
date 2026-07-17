USE SCHEMA GOLD;


CREATE OR REPLACE DYNAMIC TABLE GOLD.ITEM_STATS_AND_RECOMMENDATIONS
TARGET_LAG = '7 days'
WAREHOUSE = COMPUTE_WH
REFRESH_MODE = FULL
COMMENT = 'Item statistics and recommendations, aggregated per champion grain.'
AS
-------------------------------------------------------------------------------------------
    -- 01. FINAL_SNAPSHOT -> FINAL_SNAPSHOT_WITH_STATS (Base)
    --     Capture only the last-logged snapshot in player interval data to represent final build.
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
        )) AS ITEM_BUILD
    FROM FINAL_SNAPSHOT AS FS
    JOIN SILVER.MATCHES_SUMMARY_SILVER AS MAT
        ON MAT.MATCH_ID = FS.MATCH_ID
    JOIN SILVER.PLAYERS_SUMMARY_SILVER AS PS
        ON PS.MATCH_ID = FS.MATCH_ID
        AND PS.PARTICIPANT_POS_ID = FS.PARTICIPANT_POS_ID
),
-------------------------------------------------------------------------------------------
    -- 02. FLATTENED_ITEM
    --     Break up item's build array and stitch back per player's last logged interval.
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
-------------------------------------------------------------------------------------------
    -- 03. FLATTENED_ITEMS_WITH_REF: 
    --     a. Attach a numeric TIER_RANK encoding item-upgrade hierarchy (low -> high):
    --     1 Trinket -> 2 Consumable -> 3 Starter -> 4 Basic -> 5 Boots -> 6 Epic -> 7 Legendary
    --     b. An item only recommends alongside items of the SAME rank or HIGHER 
    --     (e.g. Basic recommends Basic/Boots/Epic/Legendary, but Legendary only recommends other Legendaries).
-------------------------------------------------------------------------------------------
FLATTENED_ITEMS_WITH_REF AS (
    SELECT
        FI.*, 
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
            -- Excluding categories ('Other', 'Distributed', 'Legacy'). These do not get recommendations.
            ELSE NULL
        END AS TIER_RANK
    FROM FLATTENED_ITEMS AS FI
    LEFT JOIN SILVER.ITEMS_REF_SILVER AS IR
        ON IR.ITEM_ID = FI.ITEM_ID
), 
-------------------------------------------------------------------------------------------
    -- 04. ITEM_STATS -> TOTAL_PLAYERS_BY_CHAMPION
    --     Aggregated stats per champion-item grain (keyed by ITEM_ID) + total champion
    --     picks across all players in matches.
-------------------------------------------------------------------------------------------
ITEM_STATS AS (
    SELECT
        CHAMPION,
        ITEM_ID,
        COUNT(*) AS PLAYERS_PURCHASED,
        SUM(IFF(WIN, 1, 0)) AS WINS_WITH_ITEM,
        ROUND(
            AVG((KILLS + ASSISTS) / (DEATHS + 1))
        , 2) AS AVG_KDA
    FROM FLATTENED_ITEMS_WITH_REF
    GROUP BY CHAMPION, ITEM_ID
),

TOTAL_PLAYERS_BY_CHAMPION AS (
    SELECT 
        FS.CHAMPION, 
        COUNT(*) AS TOTAL_PLAYER_PICKS
    FROM FINAL_SNAPSHOT_WITH_STATS AS FS
    GROUP BY FS.CHAMPION
),
-------------------------------------------------------------------------------------------
    -- 05. CO_OCCURRENCE
    --     Recommendations are two-ways for items of equal ranks
    --     e.g Infinity Edge <--> Rapid Firecannon (intended)
    --     One way for items of lower to higher ranks
    --     e.g Doran's Blade --> Infinity Edge (does not make sense reverse)
-------------------------------------------------------------------------------------------
ITEMS_PER_PLAYER AS (
    SELECT
        CHAMPION,
        MATCH_ID,
        PARTICIPANT_POS_ID,
        ARRAY_AGG(OBJECT_CONSTRUCT('id', ITEM_ID, 'tier', TIER_RANK)) 
            WITHIN GROUP (ORDER BY TIER_RANK, ITEM_ID) AS ITEMS
    FROM FLATTENED_ITEMS_WITH_REF
    WHERE TIER_RANK IS NOT NULL
    GROUP BY CHAMPION, MATCH_ID, PARTICIPANT_POS_ID
),

CO_OCCURRENCE AS (
    SELECT
        IPP.CHAMPION,
        L.VALUE:id::VARCHAR AS ITEM_ID,
        R.VALUE:id::VARCHAR AS CO_ITEM_ID,
        COUNT(*) AS CO_PURCHASE_COUNT
    FROM ITEMS_PER_PLAYER AS IPP
    CROSS JOIN LATERAL FLATTEN(IPP.ITEMS) AS L
    CROSS JOIN LATERAL FLATTEN(IPP.ITEMS) AS R
    WHERE L.VALUE:id != R.VALUE:id
        AND L.VALUE:tier <= R.VALUE:tier
    GROUP BY IPP.CHAMPION, L.VALUE:id, R.VALUE:id
),
-------------------------------------------------------------------------------------------
    -- 06. TOP3_WIDE
    --     Format top three recommendations into wide format
-------------------------------------------------------------------------------------------
TOP3_WIDE AS (
    SELECT
        CHAMPION, 
        ITEM_ID,
        -- Top 3
        MAX(IFF(CO_RANK = 1, CO_ITEM_NAME, NULL)) AS TOP_ITEM_1,
        MAX(IFF(CO_RANK = 2, CO_ITEM_NAME, NULL)) AS TOP_ITEM_2,
        MAX(IFF(CO_RANK = 3, CO_ITEM_NAME, NULL)) AS TOP_ITEM_3
    FROM (
        SELECT 
            CO.CHAMPION,
            CO.ITEM_ID,
            IR.ITEM_NAME AS CO_ITEM_NAME,
            ROW_NUMBER() OVER (
                PARTITION BY CO.CHAMPION, CO.ITEM_ID 
                ORDER BY CO.CO_PURCHASE_COUNT DESC, IR.ITEM_NAME
            ) AS CO_RANK
        FROM CO_OCCURRENCE AS CO
        LEFT JOIN SILVER.ITEMS_REF_SILVER AS IR
            ON IR.ITEM_ID = CO.CO_ITEM_ID
        QUALIFY CO_RANK <= 3
    )
    GROUP BY CHAMPION, ITEM_ID
),
-------------------------------------------------------------------------------------------
    -- 07. FIRST_PURCHASE: 
    --     Most common first purchase time interval for items, grouped by champion-item
-------------------------------------------------------------------------------------------
ITEM_APPEARANCES AS (
    SELECT
        PI.MATCH_ID, 
        PI.PARTICIPANT_POS_ID, 
        PI.MINUTE,
        ITEM.VALUE::VARCHAR AS ITEM_ID
    FROM SILVER.PLAYER_INTERVAL_SILVER AS PI
    CROSS JOIN LATERAL FLATTEN(INPUT => ARRAY_CONSTRUCT_COMPACT(
        PI.ITEM_0, PI.ITEM_1, PI.ITEM_2, PI.ITEM_3, PI.ITEM_4, PI.ITEM_5, PI.ITEM_6
    )) AS ITEM
),

FIRST_PURCHASE AS (
    SELECT
        IA.MATCH_ID,
        IA.PARTICIPANT_POS_ID,
        IA.ITEM_ID,
        MIN(IA.MINUTE) AS FIRST_MINUTE
    FROM ITEM_APPEARANCES AS IA
    INNER JOIN SILVER.ITEMS_REF_SILVER AS IR
        ON IR.ITEM_ID = IA.ITEM_ID
    WHERE IR.ITEM_CATEGORY NOT IN ('Other', 'Legacy', 'Distributed')
    GROUP BY IA.MATCH_ID, IA.PARTICIPANT_POS_ID, IA.ITEM_ID
),

FIRST_PURCHASE_COUNTS AS (
    SELECT 
        PS.CHAMPION, 
        FP.ITEM_ID, 
        FP.FIRST_MINUTE, 
        COUNT(*) AS CNT
    FROM FIRST_PURCHASE AS FP
    JOIN SILVER.PLAYERS_SUMMARY_SILVER AS PS
        ON PS.MATCH_ID = FP.MATCH_ID
        AND PS.PARTICIPANT_POS_ID = FP.PARTICIPANT_POS_ID
    GROUP BY PS.CHAMPION, FP.ITEM_ID, FP.FIRST_MINUTE
),

MOST_COMMON_FIRST_PURCHASE AS (
    SELECT
        CHAMPION,
        ITEM_ID,
        FIRST_MINUTE AS MOST_COMMON_FIRST_PURCHASE_MINUTE
    FROM FIRST_PURCHASE_COUNTS
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY CHAMPION, ITEM_ID 
        ORDER BY CNT DESC, FIRST_MINUTE
    ) = 1
),
-------------------------------------------------------------------------------------------
    -- 08. ITEM_STATS_FINAL
-------------------------------------------------------------------------------------------
ITEM_STATS_FINAL AS (
    SELECT
        IS_.CHAMPION,
        IR.ITEM_NAME AS ITEM,
        IR.ITEM_CATEGORY,
        ROUND(IS_.PLAYERS_PURCHASED / TP.TOTAL_PLAYER_PICKS::FLOAT, 4) AS PLAYER_PURCHASE_RATE,
        ROUND(IS_.WINS_WITH_ITEM / IS_.PLAYERS_PURCHASED::FLOAT, 4) AS WIN_RATE,
        IS_.AVG_KDA,
        MCFP.MOST_COMMON_FIRST_PURCHASE_MINUTE,
        T3.TOP_ITEM_1,
        T3.TOP_ITEM_2,
        T3.TOP_ITEM_3
    FROM ITEM_STATS AS IS_
    LEFT JOIN SILVER.ITEMS_REF_SILVER AS IR
        ON IR.ITEM_ID = IS_.ITEM_ID
    JOIN TOTAL_PLAYERS_BY_CHAMPION AS TP
        ON TP.CHAMPION = IS_.CHAMPION
    LEFT JOIN TOP3_WIDE AS T3
        ON T3.CHAMPION = IS_.CHAMPION 
        AND T3.ITEM_ID = IS_.ITEM_ID
    LEFT JOIN MOST_COMMON_FIRST_PURCHASE AS MCFP
        ON MCFP.CHAMPION = IS_.CHAMPION 
        AND MCFP.ITEM_ID = IS_.ITEM_ID
)
-------------------------------------------------------------------------------------------
    -- Select all above for complete query (Verify and test results here as well)
-------------------------------------------------------------------------------------------
SELECT * FROM ITEM_STATS_FINAL;
