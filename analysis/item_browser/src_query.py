"""Query builders for the Itemization Explorer.

Mirrors the `src_query.py` pattern from `probability_of_kda`: each query is a
small typed object that knows how to `.build()` itself into a SQL string. No
query is executed here — that is the sole job of `src_data.py`.

The only non-obvious bit is the `Fiddle Sticks` -> `Fiddlesticks` fix: the item
gold table carries the raw champion name, while the overview table normalises
it. Without the CASE the join silently drops Fiddlesticks.
"""

from __future__ import annotations

DB = "LEAGUE_RECORDS"
GOLD = f"{DB}.GOLD"

# A single place to normalise champion names so every query agrees on them.
CHAMPION_NORMALISE = "CASE WHEN {col} = 'Fiddle Sticks' THEN 'Fiddlesticks' ELSE {col} END"


class AnalysisQuery:
    """Base class for a buildable query. Subclasses implement `build()`.

    Kept as a plain class (no pydantic) so the app depends only on packages
    pre-installed in the Snowflake container runtime — no External Access
    Integration required.
    """

    def build(self) -> str:  # pragma: no cover - interface
        raise NotImplementedError


class ItemStatsQuery(AnalysisQuery):
    """One row per champion-item, with the champion's total games attached.

    GLOBAL_GAMES_PLAYED is what lets `src_stats` reconstruct the real sample
    size behind each win rate (effective n = purchase_rate * games_played).
    """

    def build(self) -> str:
        champ = CHAMPION_NORMALISE.format(col="i.CHAMPION")
        return f"""
            SELECT
                {champ}                          AS CHAMPION,
                i.ITEM,
                i.ITEM_CATEGORY,
                i.PLAYER_PURCHASE_RATE,
                i.WIN_RATE,
                i.AVG_KDA,
                i.MOST_COMMON_FIRST_PURCHASE_MINUTE,
                i.TOP_ITEM_1,
                i.TOP_ITEM_2,
                i.TOP_ITEM_3,
                o.GLOBAL_GAMES_PLAYED
            FROM {GOLD}.ITEM_STATS_AND_RECOMMENDATIONS AS i
            LEFT JOIN {GOLD}.CHAMPION_OVERVIEW AS o
                ON o.CHAMPION_NAME = {champ}
        """


class ChampionOverviewQuery(AnalysisQuery):
    """Champion-level meta used for the picker and the hero header."""

    def build(self) -> str:
        return f"""
            SELECT
                CHAMPION_NAME      AS CHAMPION,
                MOST_PICKED_LANE,
                PRIMARY_LANE_SHARE,
                GLOBAL_GAMES_PLAYED,
                GLOBAL_PICK_RATE,
                GLOBAL_WIN_RATE,
                GLOBAL_BAN_RATE
            FROM {GOLD}.CHAMPION_OVERVIEW
            ORDER BY CHAMPION_NAME
        """