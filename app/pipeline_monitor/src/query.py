# Fully qualified SQL builder classes for pipeline monitor dashboard
# Co-authored with CoCo
"""
SQL builder classes — live Snowflake mode.

Each class is a typed object that knows how to `.build()` itself into a SQL
(or SHOW/system function) string. Mirrors the `src_query.py` pattern used by
`analysis/item_browser`: no query is executed here, that's `data.py`'s job.

Queries are lifted near-verbatim from the corresponding models/*/monitor.ipynb
notebook so this dashboard and the underlying notebook never drift apart in
meaning — only in presentation.
"""

from __future__ import annotations

DB = "LEAGUE_RECORDS"


class MonitorQuery:
    """Base class for a buildable query. Subclasses implement `build()`."""

    def build(self) -> str:  # pragma: no cover - interface
        raise NotImplementedError


# ===========================================================================
# SEED (models/_infra/monitor.ipynb)
# ===========================================================================
class SeedObjectInventory(MonitorQuery):
    def build(self) -> str:
        return f"""
            SELECT
                TABLE_TYPE AS OBJECT_TYPE,
                TABLE_NAME AS OBJECT_NAME,
                ROW_COUNT,
                ROUND(BYTES / 1024, 0)::INTEGER AS SIZE_KB,
                CREATED,
                LAST_ALTERED,
                COMMENT
            FROM {DB}.INFORMATION_SCHEMA.TABLES
            WHERE TABLE_SCHEMA = 'SEED'
            ORDER BY TABLE_TYPE, TABLE_NAME
        """


class SeedStages(MonitorQuery):
    def build(self) -> str:
        return f"SHOW STAGES IN SCHEMA {DB}.SEED"


class SeedProcedures(MonitorQuery):
    def build(self) -> str:
        return f"SHOW PROCEDURES IN SCHEMA {DB}.SEED"


class SeedRowCountValidation(MonitorQuery):
    """CSV-vs-table row count reconciliation per seed dataset."""

    def build(self) -> str:
        return f"""
            WITH table_counts AS (
                SELECT 'matches_summary' AS DATASET, COUNT(*) AS TABLE_ROWS FROM {DB}.SEED.SEED_MATCHES_SUMMARY
                    UNION ALL
                SELECT 'players_summary', COUNT(*) FROM {DB}.SEED.SEED_PLAYERS_SUMMARY
                    UNION ALL
                SELECT 'intervals', COUNT(*) FROM {DB}.SEED.SEED_MATCH_INTERVALS
                    UNION ALL
                SELECT 'items_ref', COUNT(*) FROM {DB}.SEED.SEED_ITEMS_REF
                    UNION ALL
                SELECT 'champions_ref', COUNT(*) FROM {DB}.SEED.SEED_CHAMPIONS_REF
            ),
            csv_counts AS (
                SELECT 'matches_summary' AS DATASET, COUNT(*) AS CSV_ROWS
                FROM @{DB}.SEED.SEED_UPLOAD_STG (PATTERN => '.*matches_summary.*')
                    UNION ALL
                SELECT 'players_summary', COUNT(*)
                FROM @{DB}.SEED.SEED_UPLOAD_STG (PATTERN => '.*players_summary.*')
                    UNION ALL
                SELECT 'intervals', COUNT(*)
                FROM @{DB}.SEED.SEED_UPLOAD_STG (PATTERN => '.*intervals.*')
                    UNION ALL
                SELECT 'items_ref', COUNT(*)
                FROM @{DB}.SEED.SEED_UPLOAD_STG (PATTERN => '.*items_ref.*')
                    UNION ALL
                SELECT 'champions_ref', COUNT(*)
                FROM @{DB}.SEED.SEED_UPLOAD_STG (PATTERN => '.*champions_ref.*')
            )
            SELECT
                t.DATASET,
                t.TABLE_ROWS,
                c.CSV_ROWS,
                CASE WHEN t.TABLE_ROWS = c.CSV_ROWS THEN 'PASS' ELSE 'MISMATCH' END AS STATUS
            FROM table_counts t
            JOIN csv_counts c ON t.DATASET = c.DATASET
            ORDER BY t.DATASET
        """


class SeedStageFiles(MonitorQuery):
    def build(self) -> str:
        return f"""
            SELECT
                RELATIVE_PATH,
                ROUND(SIZE / 1024, 0)::INTEGER AS FILE_SIZE_KB,
                LAST_MODIFIED,
                FILE_URL
            FROM DIRECTORY(@{DB}.SEED.SEED_UPLOAD_STG)
            ORDER BY RELATIVE_PATH
        """


class SeedLoadState(MonitorQuery):
    """Simulated daily ingestion pointer. DAYS_REMAINING = 0 means fully loaded."""

    def build(self) -> str:
        return f"""
            SELECT
                CURRENT_LOAD_DATE,
                MIN_DATE,
                MAX_DATE,
                LAST_LOADED_AT,
                DATEDIFF('day', CURRENT_LOAD_DATE, MAX_DATE) AS DAYS_INGESTED,
                DATEDIFF('day', MIN_DATE, CURRENT_LOAD_DATE) AS DAYS_REMAINING
            FROM {DB}.SEED.SEED_LOAD_STATE
        """


class SeedDateIndex(MonitorQuery):
    def __init__(self, limit: int = 10):
        self.limit = limit

    def build(self) -> str:
        return f"""
            SELECT
                GAME_DATE_DAY,
                COUNT(*) AS MATCHES_ON_DATE
            FROM {DB}.SEED.SEED_MATCH_DATE_INDEX
            GROUP BY GAME_DATE_DAY
            ORDER BY GAME_DATE_DAY DESC
            LIMIT {self.limit}
        """


# ===========================================================================
# BRONZE (models/bronze/monitor.ipynb)
# ===========================================================================
class BronzeObjectInventory(MonitorQuery):
    def build(self) -> str:
        return f"""
            SELECT
                TABLE_TYPE AS OBJECT_TYPE,
                TABLE_NAME AS OBJECT_NAME,
                ROW_COUNT,
                ROUND(BYTES / 1024, 0)::INTEGER AS SIZE_KB,
                CREATED,
                LAST_ALTERED,
                COMMENT
            FROM {DB}.INFORMATION_SCHEMA.TABLES
            WHERE TABLE_SCHEMA = 'BRONZE'
            ORDER BY TABLE_TYPE, TABLE_NAME
        """


class BronzeStages(MonitorQuery):
    def build(self) -> str:
        return f"SHOW STAGES IN SCHEMA {DB}.BRONZE"


class BronzePipes(MonitorQuery):
    def build(self) -> str:
        return f"SHOW PIPES IN SCHEMA {DB}.BRONZE"


class BronzeStreams(MonitorQuery):
    def build(self) -> str:
        return f"SHOW STREAMS IN SCHEMA {DB}.BRONZE"


class BronzeFileFormats(MonitorQuery):
    def build(self) -> str:
        return f"SHOW FILE FORMATS IN SCHEMA {DB}.BRONZE"


class BronzeRowCounts(MonitorQuery):
    def build(self) -> str:
        return f"""
            SELECT 'MATCHES_SUMMARY_BRONZE' AS TABLE_NAME, COUNT(*) AS ROW_COUNT
            FROM {DB}.BRONZE.MATCHES_SUMMARY_BRONZE
                UNION ALL
            SELECT 'PLAYERS_SUMMARY_BRONZE', COUNT(*)
            FROM {DB}.BRONZE.PLAYERS_SUMMARY_BRONZE
                UNION ALL
            SELECT 'MATCH_INTERVALS_BRONZE', COUNT(*)
            FROM {DB}.BRONZE.MATCH_INTERVALS_BRONZE
                UNION ALL
            SELECT 'ITEMS_REF_BRONZE', COUNT(*)
            FROM {DB}.BRONZE.ITEMS_REF_BRONZE
                UNION ALL
            SELECT 'CHAMPIONS_REF_BRONZE', COUNT(*)
            FROM {DB}.BRONZE.CHAMPIONS_REF_BRONZE
        """


class BronzePipeStatus(MonitorQuery):
    def build(self) -> str:
        return f"""
            SELECT
                PIPE_NAME,
                STATUS:executionState::VARCHAR AS EXECUTION_STATE,
                STATUS:pendingFileCount::INTEGER AS PENDING_FILE_COUNT,
                STATUS:lastIngestedFilePath::VARCHAR AS LAST_INGESTED_FILE_PATH,
                STATUS:lastIngestedTimestamp::TIMESTAMP_LTZ AS LAST_INGESTED_TIMESTAMP
            FROM (
                SELECT 'MATCHES_SUMMARY_PP' AS PIPE_NAME, PARSE_JSON(SYSTEM$PIPE_STATUS('{DB}.BRONZE.MATCHES_SUMMARY_PP')) AS STATUS
                UNION ALL
                SELECT 'PLAYERS_SUMMARY_PP', PARSE_JSON(SYSTEM$PIPE_STATUS('{DB}.BRONZE.PLAYERS_SUMMARY_PP'))
                UNION ALL
                SELECT 'MATCH_INTERVALS_PP', PARSE_JSON(SYSTEM$PIPE_STATUS('{DB}.BRONZE.MATCH_INTERVALS_PP'))
                UNION ALL
                SELECT 'ITEMS_REF_PP', PARSE_JSON(SYSTEM$PIPE_STATUS('{DB}.BRONZE.ITEMS_REF_PP'))
                UNION ALL
                SELECT 'CHAMPIONS_REF_PP', PARSE_JSON(SYSTEM$PIPE_STATUS('{DB}.BRONZE.CHAMPIONS_REF_PP'))
            )
        """


class BronzeCopyHistory(MonitorQuery):
    def __init__(self, lookback_hours: int = 24 * 14):
        self.lookback_hours = lookback_hours

    def build(self) -> str:
        tables = [
            "MATCHES_SUMMARY_BRONZE",
            "PLAYERS_SUMMARY_BRONZE",
            "MATCH_INTERVALS_BRONZE",
            "ITEMS_REF_BRONZE",
            "CHAMPIONS_REF_BRONZE",
        ]
        unions = "\n    UNION ALL\n".join(
            f"""
            SELECT *
            FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
                TABLE_NAME => '{DB}.BRONZE.{t}',
                START_TIME => DATEADD(HOUR, -{self.lookback_hours}, CURRENT_TIMESTAMP())
            ))"""
            for t in tables
        )
        return f"""
            SELECT
                TABLE_NAME,
                FILE_NAME,
                ROW_COUNT,
                ROW_PARSED,
                ERROR_COUNT,
                LAST_LOAD_TIME,
                STATUS
            FROM ({unions})
            ORDER BY TABLE_NAME ASC, LAST_LOAD_TIME DESC
        """


class BronzeStageFiles(MonitorQuery):
    def build(self) -> str:
        return f"""
            SELECT 'MATCHES_SUMMARY_STG' AS STAGE, RELATIVE_PATH, ROUND(SIZE / 1024, 0)::INTEGER AS SIZE_KB, LAST_MODIFIED
            FROM DIRECTORY(@{DB}.BRONZE.MATCHES_SUMMARY_STG)
                UNION ALL
            SELECT 'PLAYERS_SUMMARY_STG', RELATIVE_PATH, ROUND(SIZE / 1024, 0)::INTEGER, LAST_MODIFIED
            FROM DIRECTORY(@{DB}.BRONZE.PLAYERS_SUMMARY_STG)
                UNION ALL
            SELECT 'MATCH_INTERVALS_STG', RELATIVE_PATH, ROUND(SIZE / 1024, 0)::INTEGER, LAST_MODIFIED
            FROM DIRECTORY(@{DB}.BRONZE.MATCH_INTERVALS_STG)
                UNION ALL
            SELECT 'ITEMS_REF_STG', RELATIVE_PATH, ROUND(SIZE / 1024, 0)::INTEGER, LAST_MODIFIED
            FROM DIRECTORY(@{DB}.BRONZE.ITEMS_REF_STG)
                UNION ALL
            SELECT 'CHAMPIONS_REF_STG', RELATIVE_PATH, ROUND(SIZE / 1024, 0)::INTEGER, LAST_MODIFIED
            FROM DIRECTORY(@{DB}.BRONZE.CHAMPIONS_REF_STG)
            ORDER BY STAGE, RELATIVE_PATH
        """


class BronzeStreamState(MonitorQuery):
    def build(self) -> str:
        return f"""
            SELECT 'MATCHES_SUMMARY_BRONZE_STM' AS STREAM, SYSTEM$STREAM_HAS_DATA('{DB}.BRONZE.MATCHES_SUMMARY_BRONZE_STM') AS HAS_DATA
                UNION ALL
            SELECT 'PLAYERS_SUMMARY_BRONZE_STM', SYSTEM$STREAM_HAS_DATA('{DB}.BRONZE.PLAYERS_SUMMARY_BRONZE_STM')
                UNION ALL
            SELECT 'MATCH_INTERVALS_BRONZE_STM', SYSTEM$STREAM_HAS_DATA('{DB}.BRONZE.MATCH_INTERVALS_BRONZE_STM')
                UNION ALL
            SELECT 'ITEMS_REF_BRONZE_STM', SYSTEM$STREAM_HAS_DATA('{DB}.BRONZE.ITEMS_REF_BRONZE_STM')
                UNION ALL
            SELECT 'CHAMPIONS_REF_BRONZE_STM', SYSTEM$STREAM_HAS_DATA('{DB}.BRONZE.CHAMPIONS_REF_BRONZE_STM')
        """


# ===========================================================================
# SILVER (models/silver/monitor.ipynb)
# ===========================================================================
class SilverObjectInventory(MonitorQuery):
    """Tables, views, and tasks combined into one inventory (3 SHOW calls in
    the notebook; concatenated client-side in mock mode and live mode alike)."""

    def build_tables(self) -> str:
        return f"SHOW TABLES IN SCHEMA {DB}.SILVER"

    def build_views(self) -> str:
        return f"SHOW VIEWS IN SCHEMA {DB}.SILVER"

    def build_tasks(self) -> str:
        return f"SHOW TASKS IN SCHEMA {DB}.SILVER"


class SilverTaskHistory(MonitorQuery):
    def __init__(self, lookback_hours: int = 24):
        self.lookback_hours = lookback_hours

    def build(self) -> str:
        return f"""
            SELECT
                NAME,
                STATE,
                SCHEDULED_TIME,
                COMPLETED_TIME,
                DATEDIFF('second', SCHEDULED_TIME, COMPLETED_TIME) AS DURATION_SEC,
                ERROR_CODE,
                ERROR_MESSAGE
            FROM TABLE({DB}.INFORMATION_SCHEMA.TASK_HISTORY(
                SCHEDULED_TIME_RANGE_START => DATEADD('hour', -{self.lookback_hours}, CURRENT_TIMESTAMP()),
                RESULT_LIMIT => 100
            ))
            WHERE SCHEMA_NAME = 'SILVER'
            ORDER BY NAME, SCHEDULED_TIME DESC
        """


class SilverTaskSummary(MonitorQuery):
    def __init__(self, lookback_hours: int = 24):
        self.lookback_hours = lookback_hours

    def build(self) -> str:
        return f"""
            SELECT
                NAME AS TASK_NAME,
                STATE,
                COUNT(*) AS RUN_COUNT,
                ROUND(AVG(DATEDIFF('second', SCHEDULED_TIME, COMPLETED_TIME)), 2) AS AVG_DURATION_SEC
            FROM TABLE({DB}.INFORMATION_SCHEMA.TASK_HISTORY(
                SCHEDULED_TIME_RANGE_START => DATEADD('hour', -{self.lookback_hours}, CURRENT_TIMESTAMP()),
                RESULT_LIMIT => 500
            ))
            WHERE SCHEMA_NAME = 'SILVER'
            GROUP BY NAME, STATE
            ORDER BY NAME, STATE
        """


class SilverStreamState(MonitorQuery):
    def build(self) -> str:
        return f"""
            SELECT 'MATCH_INTERVALS_BRONZE_STM' AS STREAM_NAME, SYSTEM$STREAM_HAS_DATA('{DB}.BRONZE.MATCH_INTERVALS_BRONZE_STM') AS HAS_DATA
                UNION ALL
            SELECT 'MATCHES_SUMMARY_BRONZE_STM', SYSTEM$STREAM_HAS_DATA('{DB}.BRONZE.MATCHES_SUMMARY_BRONZE_STM')
                UNION ALL
            SELECT 'PLAYERS_SUMMARY_BRONZE_STM', SYSTEM$STREAM_HAS_DATA('{DB}.BRONZE.PLAYERS_SUMMARY_BRONZE_STM')
                UNION ALL
            SELECT 'ITEMS_REF_BRONZE_STM', SYSTEM$STREAM_HAS_DATA('{DB}.BRONZE.ITEMS_REF_BRONZE_STM')
                UNION ALL
            SELECT 'CHAMPIONS_REF_BRONZE_STM', SYSTEM$STREAM_HAS_DATA('{DB}.BRONZE.CHAMPIONS_REF_BRONZE_STM')
        """


class SilverRowCounts(MonitorQuery):
    """Row counts + size + LAST_ALTERED, used as a freshness proxy."""

    def build(self) -> str:
        return f"""
            SELECT
                TABLE_NAME,
                ROW_COUNT,
                BYTES,
                ROUND(BYTES / 1024 / 1024, 2) AS SIZE_MB,
                LAST_ALTERED
            FROM {DB}.INFORMATION_SCHEMA.TABLES
            WHERE TABLE_SCHEMA = 'SILVER'
                AND TABLE_TYPE = 'BASE TABLE'
            ORDER BY ROW_COUNT DESC
        """


class SilverVsGoldCounts(MonitorQuery):
    """Outgoing: row count parity between Silver and Gold for key relationships."""

    def build(self) -> str:
        return f"""
            SELECT
                'MATCHES: Silver vs Gold' AS COMPARISON,
                (SELECT COUNT(*) FROM {DB}.SILVER.MATCHES_SUMMARY_SILVER) AS SILVER_ROWS,
                (SELECT COUNT(*) FROM {DB}.GOLD.MATCH_TEAM_STATS_SUMMARY) AS GOLD_ROWS,
                (SELECT COUNT(*) FROM {DB}.SILVER.MATCHES_SUMMARY_SILVER) -
                (SELECT COUNT(*) FROM {DB}.GOLD.MATCH_TEAM_STATS_SUMMARY) AS DIFF
            UNION ALL
            SELECT
                'PLAYERS: Silver vs Gold',
                (SELECT COUNT(*) FROM {DB}.SILVER.PLAYERS_SUMMARY_SILVER),
                (SELECT COUNT(*) FROM {DB}.GOLD.PLAYER_STATS_SUMMARY),
                (SELECT COUNT(*) FROM {DB}.SILVER.PLAYERS_SUMMARY_SILVER) -
                (SELECT COUNT(*) FROM {DB}.GOLD.PLAYER_STATS_SUMMARY)
            UNION ALL
            SELECT
                'CHAMPIONS: Ref vs Overview',
                (SELECT COUNT(*) FROM {DB}.SILVER.CHAMPIONS_REF_SILVER WHERE CHAMPION_ID != 0),
                (SELECT COUNT(*) FROM {DB}.GOLD.CHAMPION_OVERVIEW),
                (SELECT COUNT(*) FROM {DB}.SILVER.CHAMPIONS_REF_SILVER WHERE CHAMPION_ID != 0) -
                (SELECT COUNT(*) FROM {DB}.GOLD.CHAMPION_OVERVIEW)
        """


# ===========================================================================
# GOLD (models/gold/monitor.ipynb)
# ===========================================================================
class GoldObjectInventory(MonitorQuery):
    def build(self) -> str:
        return f"SHOW DYNAMIC TABLES IN SCHEMA {DB}.GOLD"


class GoldRefreshHistory(MonitorQuery):
    def __init__(self, limit: int = 30):
        self.limit = limit

    def build(self) -> str:
        return f"""
            SELECT
                NAME AS DT_NAME,
                STATE AS REFRESH_STATE,
                REFRESH_START_TIME,
                REFRESH_END_TIME,
                DATEDIFF('second', REFRESH_START_TIME, REFRESH_END_TIME) AS REFRESH_DURATION_SEC,
                STATISTICS:"numInsertedRows"::INT AS ROWS_INSERTED,
                STATISTICS:"numDeletedRows"::INT AS ROWS_DELETED,
                STATISTICS:"numCopiedRows"::INT AS ROWS_COPIED
            FROM TABLE({DB}.INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY(
                NAME_PREFIX => '{DB}.GOLD.'
            ))
            ORDER BY REFRESH_END_TIME DESC
            LIMIT {self.limit}
        """


class GoldGrainValidation(MonitorQuery):
    """Validates gold-table grain against the silver tables they're derived
    from (existence/shape check, not the excluded sample-match recompute)."""

    def build(self) -> str:
        return f"""
            SELECT
                'PLAYER_STATS_SUMMARY grain = distinct (MATCH_ID, PARTICIPANT_POS_ID) in PLAYERS_SUMMARY_SILVER' AS "CHECK",
                (SELECT COUNT(*) FROM {DB}.SILVER.PLAYERS_SUMMARY_SILVER) AS EXPECTED,
                (SELECT COUNT(*) FROM {DB}.GOLD.PLAYER_STATS_SUMMARY) AS ACTUAL,
                CASE WHEN (SELECT COUNT(*) FROM {DB}.SILVER.PLAYERS_SUMMARY_SILVER)
                        = (SELECT COUNT(*) FROM {DB}.GOLD.PLAYER_STATS_SUMMARY)
                     THEN 'PASS' ELSE 'MISMATCH' END AS STATUS
            UNION ALL
            SELECT
                'MATCH_TEAM_STATS_SUMMARY grain = distinct MATCH_ID in MATCHES_SUMMARY_SILVER',
                (SELECT COUNT(*) FROM {DB}.SILVER.MATCHES_SUMMARY_SILVER),
                (SELECT COUNT(*) FROM {DB}.GOLD.MATCH_TEAM_STATS_SUMMARY),
                CASE WHEN (SELECT COUNT(*) FROM {DB}.SILVER.MATCHES_SUMMARY_SILVER)
                        = (SELECT COUNT(*) FROM {DB}.GOLD.MATCH_TEAM_STATS_SUMMARY)
                     THEN 'PASS' ELSE 'MISMATCH' END
            UNION ALL
            SELECT
                'CHAMPION_OVERVIEW count ≈ distinct champions in CHAMPIONS_REF_SILVER (excl. ID=0)',
                (SELECT COUNT(*) FROM {DB}.SILVER.CHAMPIONS_REF_SILVER WHERE CHAMPION_ID != 0),
                (SELECT COUNT(*) FROM {DB}.GOLD.CHAMPION_OVERVIEW),
                CASE WHEN (SELECT COUNT(*) FROM {DB}.SILVER.CHAMPIONS_REF_SILVER WHERE CHAMPION_ID != 0)
                        = (SELECT COUNT(*) FROM {DB}.GOLD.CHAMPION_OVERVIEW)
                     THEN 'PASS' ELSE 'MISMATCH' END
        """
