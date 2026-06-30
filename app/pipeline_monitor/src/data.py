# Fix schema resolution and SHOW result handling for deployed Streamlit app
# Co-authored with CoCo
"""
Data access — the ONLY module that talks to Snowflake.

Mode is decided once via `running_in_snowflake()` (presence of the SiS
session token), same pattern as `analysis/item_browser/src_data.py`:

* In Streamlit-in-Snowflake: queries run through `st.connection("snowflake")`
  (thread-safe, required on container/SPCS runtimes — `get_active_session`
  is not safe there). Results are cached with short TTLs (see
  `settings.CacheSettings`) so a burst of widget reruns doesn't hammer the
  warehouse, while still feeling "live" to the user.
* Locally (no token): the same logical checks are read from CSVs in
  `assets/sample_data/`, one file per check, via `mock.py`.

Every public function here returns a pandas DataFrame and takes no Snowflake-
specific arguments, so `ui.py` never needs to know which mode it's in.
"""

from __future__ import annotations

import os

import pandas as pd
import streamlit as st

from src import mock, query as q
from settings import Settings


def running_in_snowflake() -> bool:
    """Reliable SiS detection: the session token only exists inside Snowflake."""
    return os.path.isfile("/snowflake/session/token")


@st.cache_resource
def get_session(_settings: Settings):
    """Return the Snowpark session in SiS, or None when running locally."""
    if _settings.is_local:
        return None
    conn = st.connection("snowflake", ttl=_settings.snowflake.connection_ttl)
    return conn.session()


def _run(session, sql: str) -> pd.DataFrame:
    return session.sql(sql).to_pandas()


# ===========================================================================
# SEED
# ===========================================================================
def load_seed_object_inventory(settings: Settings) -> pd.DataFrame:
    @st.cache_data(ttl=settings.cache.object_inventory_ttl, show_spinner="Loading seed object inventory…")
    def _load():
        if settings.is_local:
            return mock.seed_object_inventory(settings.sample_data_dir)
        return _run(get_session(settings), q.SeedObjectInventory().build())

    return _load()


def load_seed_stages(settings: Settings) -> pd.DataFrame:
    @st.cache_data(ttl=settings.cache.object_inventory_ttl, show_spinner="Loading seed stages…")
    def _load():
        if settings.is_local:
            return mock.seed_stages(settings.sample_data_dir)
        return _run(get_session(settings), q.SeedStages().build())

    return _load()


def load_seed_procedures(settings: Settings) -> pd.DataFrame:
    @st.cache_data(ttl=settings.cache.object_inventory_ttl, show_spinner="Loading seed procedures…")
    def _load():
        if settings.is_local:
            return mock.seed_procedures(settings.sample_data_dir)
        return _run(get_session(settings), q.SeedProcedures().build())

    return _load()


def load_seed_row_count_validation(settings: Settings) -> pd.DataFrame:
    @st.cache_data(ttl=settings.cache.row_count_ttl, show_spinner="Validating seed row counts…")
    def _load():
        if settings.is_local:
            return mock.seed_row_count_validation(settings.sample_data_dir)
        return _run(get_session(settings), q.SeedRowCountValidation().build())

    return _load()


def load_seed_stage_files(settings: Settings) -> pd.DataFrame:
    @st.cache_data(ttl=settings.cache.stage_file_ttl, show_spinner="Listing seed stage files…")
    def _load():
        if settings.is_local:
            return mock.seed_stage_files(settings.sample_data_dir)
        return _run(get_session(settings), q.SeedStageFiles().build())

    return _load()


def load_seed_load_state(settings: Settings) -> pd.DataFrame:
    @st.cache_data(ttl=settings.cache.load_state_ttl, show_spinner="Checking simulated load state…")
    def _load():
        if settings.is_local:
            return mock.seed_load_state(settings.sample_data_dir)
        return _run(get_session(settings), q.SeedLoadState().build())

    return _load()


def load_seed_date_index(settings: Settings) -> pd.DataFrame:
    @st.cache_data(ttl=settings.cache.load_state_ttl, show_spinner="Loading recent ingestion dates…")
    def _load():
        if settings.is_local:
            return mock.seed_date_index(settings.sample_data_dir)
        return _run(get_session(settings), q.SeedDateIndex().build())

    return _load()


# ===========================================================================
# BRONZE
# ===========================================================================
def load_bronze_object_inventory(settings: Settings) -> pd.DataFrame:
    @st.cache_data(ttl=settings.cache.object_inventory_ttl, show_spinner="Loading bronze object inventory…")
    def _load():
        if settings.is_local:
            return mock.bronze_object_inventory(settings.sample_data_dir)
        return _run(get_session(settings), q.BronzeObjectInventory().build())

    return _load()


def load_bronze_stages(settings: Settings) -> pd.DataFrame:
    @st.cache_data(ttl=settings.cache.object_inventory_ttl, show_spinner="Loading bronze stages…")
    def _load():
        if settings.is_local:
            return mock.bronze_stages(settings.sample_data_dir)
        return _run(get_session(settings), q.BronzeStages().build())

    return _load()


def load_bronze_pipes(settings: Settings) -> pd.DataFrame:
    @st.cache_data(ttl=settings.cache.object_inventory_ttl, show_spinner="Loading bronze pipes…")
    def _load():
        if settings.is_local:
            return mock.bronze_pipes(settings.sample_data_dir)
        return _run(get_session(settings), q.BronzePipes().build())

    return _load()


def load_bronze_streams(settings: Settings) -> pd.DataFrame:
    @st.cache_data(ttl=settings.cache.object_inventory_ttl, show_spinner="Loading bronze streams…")
    def _load():
        if settings.is_local:
            return mock.bronze_streams(settings.sample_data_dir)
        return _run(get_session(settings), q.BronzeStreams().build())

    return _load()


def load_bronze_file_formats(settings: Settings) -> pd.DataFrame:
    @st.cache_data(ttl=settings.cache.object_inventory_ttl, show_spinner="Loading bronze file formats…")
    def _load():
        if settings.is_local:
            return mock.bronze_file_formats(settings.sample_data_dir)
        return _run(get_session(settings), q.BronzeFileFormats().build())

    return _load()


def load_bronze_row_counts(settings: Settings) -> pd.DataFrame:
    @st.cache_data(ttl=settings.cache.row_count_ttl, show_spinner="Counting bronze rows…")
    def _load():
        if settings.is_local:
            return mock.bronze_row_counts(settings.sample_data_dir)
        return _run(get_session(settings), q.BronzeRowCounts().build())

    return _load()


def load_bronze_pipe_status(settings: Settings) -> pd.DataFrame:
    @st.cache_data(ttl=settings.cache.pipe_stream_state_ttl, show_spinner="Checking pipe status…")
    def _load():
        if settings.is_local:
            return mock.bronze_pipe_status(settings.sample_data_dir)
        return _run(get_session(settings), q.BronzePipeStatus().build())

    return _load()


def load_bronze_copy_history(settings: Settings) -> pd.DataFrame:
    @st.cache_data(ttl=settings.cache.copy_history_ttl, show_spinner="Loading copy history…")
    def _load():
        if settings.is_local:
            return mock.bronze_copy_history(settings.sample_data_dir)
        return _run(
            get_session(settings),
            q.BronzeCopyHistory(settings.ui.copy_history_lookback_hours).build(),
        )

    return _load()


def load_bronze_stage_files(settings: Settings) -> pd.DataFrame:
    @st.cache_data(ttl=settings.cache.stage_file_ttl, show_spinner="Listing bronze stage files…")
    def _load():
        if settings.is_local:
            return mock.bronze_stage_files(settings.sample_data_dir)
        return _run(get_session(settings), q.BronzeStageFiles().build())

    return _load()


def load_bronze_stream_state(settings: Settings) -> pd.DataFrame:
    @st.cache_data(ttl=settings.cache.pipe_stream_state_ttl, show_spinner="Checking bronze stream state…")
    def _load():
        if settings.is_local:
            return mock.bronze_stream_state(settings.sample_data_dir)
        return _run(get_session(settings), q.BronzeStreamState().build())

    return _load()


# ===========================================================================
# SILVER
# ===========================================================================
def load_silver_object_inventory(settings: Settings) -> pd.DataFrame:
    @st.cache_data(ttl=settings.cache.object_inventory_ttl, show_spinner="Loading silver object inventory…")
    def _load():
        if settings.is_local:
            return mock.silver_object_inventory(settings.sample_data_dir)
        session = get_session(settings)
        sq = q.SilverObjectInventory()
        tables = _run(session, sq.build_tables())
        views = _run(session, sq.build_views())
        tasks = _run(session, sq.build_tasks())

        def _extract_names(df, obj_type):
            """Extract object names from a SHOW result regardless of column casing."""
            df.columns = [c.strip('"').lower() for c in df.columns]
            if "name" not in df.columns:
                return pd.DataFrame(columns=["OBJECT_TYPE", "OBJECT_NAME"])
            result = df[["name"]].copy()
            result.columns = ["OBJECT_NAME"]
            result["OBJECT_TYPE"] = obj_type
            return result[["OBJECT_TYPE", "OBJECT_NAME"]]

        combined = pd.concat(
            [_extract_names(tables, "TABLE"),
             _extract_names(views, "VIEW"),
             _extract_names(tasks, "TASK")],
            ignore_index=True,
        )
        return combined

    return _load()


def load_silver_task_history(settings: Settings) -> pd.DataFrame:
    @st.cache_data(ttl=settings.cache.task_history_ttl, show_spinner="Loading silver task history…")
    def _load():
        if settings.is_local:
            return mock.silver_task_history(settings.sample_data_dir)
        return _run(
            get_session(settings),
            q.SilverTaskHistory(settings.ui.task_history_lookback_hours).build(),
        )

    return _load()


def load_silver_task_summary(settings: Settings) -> pd.DataFrame:
    @st.cache_data(ttl=settings.cache.task_history_ttl, show_spinner="Summarizing silver tasks…")
    def _load():
        if settings.is_local:
            return mock.silver_task_summary(settings.sample_data_dir)
        return _run(
            get_session(settings),
            q.SilverTaskSummary(settings.ui.task_history_lookback_hours).build(),
        )

    return _load()


def load_silver_stream_state(settings: Settings) -> pd.DataFrame:
    @st.cache_data(ttl=settings.cache.pipe_stream_state_ttl, show_spinner="Checking silver stream state…")
    def _load():
        if settings.is_local:
            return mock.silver_stream_state(settings.sample_data_dir)
        return _run(get_session(settings), q.SilverStreamState().build())

    return _load()


def load_silver_row_counts(settings: Settings) -> pd.DataFrame:
    @st.cache_data(ttl=settings.cache.row_count_ttl, show_spinner="Counting silver rows…")
    def _load():
        if settings.is_local:
            return mock.silver_row_counts(settings.sample_data_dir)
        return _run(get_session(settings), q.SilverRowCounts().build())

    return _load()


def load_silver_vs_gold_counts(settings: Settings) -> pd.DataFrame:
    @st.cache_data(ttl=settings.cache.row_count_ttl, show_spinner="Comparing silver vs gold row counts…")
    def _load():
        if settings.is_local:
            return mock.silver_vs_gold_counts(settings.sample_data_dir)
        return _run(get_session(settings), q.SilverVsGoldCounts().build())

    return _load()


# ===========================================================================
# GOLD
# ===========================================================================
def load_gold_object_inventory(settings: Settings) -> pd.DataFrame:
    @st.cache_data(ttl=settings.cache.object_inventory_ttl, show_spinner="Loading gold object inventory…")
    def _load():
        if settings.is_local:
            return mock.gold_object_inventory(settings.sample_data_dir)
        # Use .collect() instead of .to_pandas() to work around a Snowpark bug
        # where SHOW DYNAMIC TABLES metadata reports more columns than data rows contain.
        session = get_session(settings)
        result_df = session.sql(q.GoldObjectInventory().build())
        schema_names = [f.name.strip('"').lower() for f in result_df.schema.fields]
        rows = result_df.collect()
        df = pd.DataFrame([r.as_dict() for r in rows])
        df.columns = [c.strip('"').lower() for c in df.columns]
        # If schema field names are available and data columns differ, use schema
        if len(df.columns) == 0 and rows:
            df = pd.DataFrame([list(r) for r in rows], columns=schema_names[:len(rows[0])])
        result = pd.DataFrame({
            "OBJECT_TYPE": "DYNAMIC TABLE",
            "OBJECT_NAME": df.get("name", pd.Series(dtype=str)),
            "TARGET_LAG": df.get("target_lag", pd.Series(dtype=str)),
            "OWNER": df.get("owner", pd.Series(dtype=str)),
            "COMMENT": df.get("comment", pd.Series(dtype=str)),
        })
        return result

    return _load()


def load_gold_dt_freshness(settings: Settings) -> pd.DataFrame:
    @st.cache_data(ttl=settings.cache.dt_refresh_ttl, show_spinner="Checking dynamic table freshness…")
    def _load():
        if settings.is_local:
            return mock.gold_dt_freshness(settings.sample_data_dir)
        # Use .collect() to avoid the same .to_pandas() column mismatch bug
        session = get_session(settings)
        result_sf = session.sql(q.GoldObjectInventory().build())
        raw_rows = result_sf.collect()
        df = pd.DataFrame([r.as_dict() for r in raw_rows])
        if df.empty:
            return pd.DataFrame(columns=["DT_NAME", "STATE", "TARGET_LAG", "LAST_REFRESH_AT", "ACTUAL_LAG_MINUTES", "FRESHNESS_STATUS"])
        df.columns = [c.strip('"').lower() for c in df.columns]
        import re
        from datetime import datetime, timezone
        now = datetime.now(timezone.utc)
        rows = []
        for _, row in df.iterrows():
            dt_name = row["name"]
            state = row["scheduling_state"]
            target_lag = row["target_lag"]
            data_ts = pd.to_datetime(row["data_timestamp"], utc=True) if pd.notna(row.get("data_timestamp")) else None
            actual_lag_min = int((now - data_ts).total_seconds() / 60) if data_ts else None
            lag_match = re.search(r"(\d+)", str(target_lag)) if target_lag else None
            lag_num = int(lag_match.group(1)) if lag_match else 60
            target_str = str(target_lag).lower()
            if "day" in target_str:
                lag_minutes = lag_num * 24 * 60
            elif "hour" in target_str:
                lag_minutes = lag_num * 60
            else:
                lag_minutes = lag_num
            if state != "ACTIVE":
                freshness_status = "⚠ NOT ACTIVE"
            elif actual_lag_min is not None and actual_lag_min > lag_minutes * 2:
                freshness_status = "⚠ BEHIND SCHEDULE"
            else:
                freshness_status = "✓ ON TRACK"
            rows.append({
                "DT_NAME": dt_name,
                "STATE": state,
                "TARGET_LAG": target_lag,
                "LAST_REFRESH_AT": data_ts,
                "ACTUAL_LAG_MINUTES": actual_lag_min,
                "FRESHNESS_STATUS": freshness_status,
            })
        return pd.DataFrame(rows)

    return _load()


def load_gold_refresh_history(settings: Settings) -> pd.DataFrame:
    @st.cache_data(ttl=settings.cache.dt_refresh_ttl, show_spinner="Loading dynamic table refresh history…")
    def _load():
        if settings.is_local:
            return mock.gold_refresh_history(settings.sample_data_dir)
        return _run(
            get_session(settings),
            q.GoldRefreshHistory(settings.ui.dt_refresh_history_limit).build(),
        )

    return _load()


def load_gold_grain_validation(settings: Settings) -> pd.DataFrame:
    @st.cache_data(ttl=settings.cache.row_count_ttl, show_spinner="Validating gold table grain…")
    def _load():
        if settings.is_local:
            return mock.gold_grain_validation(settings.sample_data_dir)
        return _run(get_session(settings), q.GoldGrainValidation().build())

    return _load()
