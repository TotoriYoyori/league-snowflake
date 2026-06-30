"""Data access — the ONLY module that talks to Snowflake.

Two modes, chosen automatically by a presence check for the SiS session token:

* In Streamlit-in-Snowflake, queries run through `st.connection("snowflake")`
  (the thread-safe connection required on container runtimes; `get_active_session`
  is not safe there). Results are cached with a TTL roughly aligned to the gold
  tables' refresh lag.
* Locally (no token), the same logical tables are read from CSVs in
  `LOCAL_DATA_DIR`, with the champion-name normalisation + join reproduced in
  pandas, so development and demos are fully offline.

Keeping this behind `load_item_stats()` / `load_overview()` means the rest of the
app never knows which mode it is in.
"""

from __future__ import annotations

import os

import pandas as pd
import streamlit as st

from src_query import ItemStatsQuery, ChampionOverviewQuery

# Aligned to the gold tables' TARGET_LAG. Item table lags ~7 days; overview ~1.
_ITEM_TTL = 6 * 60 * 60
_OVERVIEW_TTL = 60 * 60

LOCAL_DATA_DIR = os.environ.get("LOCAL_DATA_DIR", os.path.join(os.path.dirname(__file__), "data"))
_ITEM_CSV = "05_item_stats_and_recommendations.csv"
_OVERVIEW_CSV = "03_champion_overview.csv"


def running_in_snowflake() -> bool:
    """Reliable SiS detection: the session token only exists inside Snowflake."""
    return os.path.isfile("/snowflake/session/token")


@st.cache_resource
def get_session():
    """Return the Snowpark session in SiS, or None when running locally."""
    if not running_in_snowflake():
        return None
    conn = st.connection("snowflake", ttl=os.getenv("SNOWFLAKE_CONNECTION_TTL"))
    return conn.session()


def _normalise_champion(s: pd.Series) -> pd.Series:
    return s.replace({"Fiddle Sticks": "Fiddlesticks"})


@st.cache_data(ttl=_ITEM_TTL, show_spinner="Loading item stats…")
def load_item_stats() -> pd.DataFrame:
    session = get_session()
    if session is not None:
        return session.sql(ItemStatsQuery().build()).to_pandas()

    items = pd.read_csv(os.path.join(LOCAL_DATA_DIR, _ITEM_CSV))
    overview = pd.read_csv(os.path.join(LOCAL_DATA_DIR, _OVERVIEW_CSV))
    items["CHAMPION"] = _normalise_champion(items["CHAMPION"])
    games = overview[["CHAMPION_NAME", "GLOBAL_GAMES_PLAYED"]].rename(
        columns={"CHAMPION_NAME": "CHAMPION"}
    )
    return items.merge(games, on="CHAMPION", how="left")


@st.cache_data(ttl=_OVERVIEW_TTL, show_spinner="Loading champions…")
def load_overview() -> pd.DataFrame:
    session = get_session()
    if session is not None:
        return session.sql(ChampionOverviewQuery().build()).to_pandas()

    overview = pd.read_csv(os.path.join(LOCAL_DATA_DIR, _OVERVIEW_CSV))
    return overview.rename(columns={"CHAMPION_NAME": "CHAMPION"}).sort_values("CHAMPION")


def data_health(items: pd.DataFrame, overview: pd.DataFrame) -> dict:
    """Small diagnostics surfaced in the UI — this is an internal dev tool, so
    showing source/size/mode is a feature, not clutter."""
    return {
        "mode": "Snowflake (live)" if running_in_snowflake() else "Local CSV",
        "item_rows": len(items),
        "champions": items["CHAMPION"].nunique(),
    }