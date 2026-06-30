"""
Environment configuration, packed into dataclasses.

`get_settings()` is the single entry point the rest of the app uses. It picks
LOCAL (mock CSVs, no Snowflake) or PRODUCTION (live Snowflake, Streamlit-in-
Snowflake) automatically by checking for the SiS session token, unless
APP_ENV is forced via env var.
"""

from __future__ import annotations

import os
from dataclasses import dataclass, field


@dataclass(frozen=True)
class SnowflakeSettings:
    database: str = "LEAGUE_RECORDS"
    warehouse: str = "COMPUTE_WH"
    schemas: dict = field(
        default_factory=lambda: {
            "seed": "SEED",
            "bronze": "BRONZE",
            "silver": "SILVER",
            "gold": "GOLD",
        }
    )
    connection_ttl: int | None = None  # st.connection ttl, None = forever


@dataclass(frozen=True)
class CacheSettings:
    # TTLs in seconds. Mirrors item_browser's pattern: short enough to feel
    # live, long enough to survive a burst of widget reruns.
    object_inventory_ttl: int = 60
    row_count_ttl: int = 60
    pipe_stream_state_ttl: int = 30
    copy_history_ttl: int = 120
    task_history_ttl: int = 60
    dt_refresh_ttl: int = 60
    stage_file_ttl: int = 60
    load_state_ttl: int = 60


@dataclass(frozen=True)
class UISettings:
    app_title: str = "Pipeline Monitor"
    app_subtitle_en: str = "League of Legends ELT Pipeline — Health & Activity"
    app_subtitle_zh: str = "英雄联盟数据管道 — 健康与活动监控"
    layers: tuple = ("seed", "bronze", "silver", "gold")
    layer_labels: dict = field(
        default_factory=lambda: {
            "seed": ("Seed", "数据来源"),
            "bronze": ("Bronze", "铜层"),
            "silver": ("Silver", "银层"),
            "gold": ("Gold", "金层"),
        }
    )
    copy_history_lookback_hours: int = 24 * 14  # 14 days, matches bronze monitor
    task_history_lookback_hours: int = 24
    dt_refresh_history_limit: int = 30


@dataclass(frozen=True)
class Settings:
    env: str
    is_local: bool
    snowflake: SnowflakeSettings
    cache: CacheSettings
    ui: UISettings
    sample_data_dir: str


def _running_in_snowflake() -> bool:
    """Reliable SiS detection: the session token only exists inside Snowflake."""
    return os.path.isfile("/snowflake/session/token")


def get_settings() -> Settings:
    forced_env = os.environ.get("APP_ENV", "").strip().lower()
    if forced_env in ("local", "production"):
        is_local = forced_env == "local"
    else:
        is_local = not _running_in_snowflake()

    return Settings(
        env="local" if is_local else "production",
        is_local=is_local,
        snowflake=SnowflakeSettings(),
        cache=CacheSettings(),
        ui=UISettings(),
        sample_data_dir=os.environ.get(
            "LOCAL_DATA_DIR",
            os.path.join(os.path.dirname(__file__), "assets", "sample_data"),
        ),
    )
