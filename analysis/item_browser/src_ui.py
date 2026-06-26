"""UI — one render function per feature, pure presentation.

No business logic and no data access live here: every function takes a ready
DataFrame (already passed through `src_stats`) and draws it. This is what keeps
`streamlit_app.py` readable as plain orchestration.
"""

from __future__ import annotations

import html

import pandas as pd
import streamlit as st

import src_theme

CATEGORY_ORDER = ["Starter", "Basic", "Boots", "Epic", "Legendary"]


def setup_page() -> None:
    st.set_page_config(page_title="Itemization Explorer", page_icon="⚜", layout="wide")
    src_theme.inject()


def sidebar_controls(overview: pd.DataFrame) -> dict:
    """Champion picker, tier filter, and the method knobs. Returns selections."""
    with st.sidebar:
        st.markdown("### Itemization explorer")
        champion = st.selectbox("Champion", overview["CHAMPION"].tolist())

        tiers = st.multiselect(
            "Item tier",
            CATEGORY_ORDER,
            default=["Boots", "Epic", "Legendary"],
        )

        with st.expander("Method", expanded=False):
            min_n = st.slider("Minimum sample (n)", 0, 100, 20, step=5,
                              help="Items below this purchase count are never flagged.")
            k = st.slider("Shrinkage strength (k)", 0, 100, 20, step=5,
                          help="Games of benefit-of-the-doubt given to the champion baseline. "
                               "Higher = noisy win rates pulled harder toward the champion mean.")
        return {"champion": champion, "tiers": tiers, "min_n": min_n, "k": k}


def render_hero(meta: pd.Series) -> None:
    def pct(x):
        return "—" if pd.isna(x) else f"{x * 100:.1f}%"

    name = html.escape(str(meta["CHAMPION"]))
    lane = html.escape(str(meta.get("MOST_PICKED_LANE", "")))
    st.markdown(
        f"""
        <div class="ie-hero">
          <p class="name">{name}</p>
          <p class="lane">{lane} · primary lane {pct(meta.get('PRIMARY_LANE_SHARE'))}</p>
          <div class="ie-pills">
            <span class="ie-pill">pick <b>{pct(meta.get('GLOBAL_PICK_RATE'))}</b></span>
            <span class="ie-pill">win <b>{pct(meta.get('GLOBAL_WIN_RATE'))}</b></span>
            <span class="ie-pill">ban <b>{pct(meta.get('GLOBAL_BAN_RATE'))}</b></span>
            <span class="ie-pill">games <b>{int(meta.get('GLOBAL_GAMES_PLAYED', 0)):,}</b></span>
          </div>
        </div>
        """,
        unsafe_allow_html=True,
    )


def render_item_table(df: pd.DataFrame) -> str | None:
    """Sortable item table. Returns the selected item name (or None)."""
    view = df.assign(
        Buy=df["PLAYER_PURCHASE_RATE"],
        Win=df["WIN_RATE"],
        Adj=df["ADJ_WIN_RATE"],
        n=df["EFF_N"].astype("Int64"),
        First=df["MOST_COMMON_FIRST_PURCHASE_MINUTE"],
    )[["ITEM", "ITEM_CATEGORY", "Buy", "Win", "Adj", "n", "AVG_KDA", "First", "FLAG"]]

    event = st.dataframe(
        view,
        use_container_width=True,
        hide_index=True,
        on_select="rerun",
        selection_mode="single-row",
        column_config={
            "ITEM": "Item",
            "ITEM_CATEGORY": "Tier",
            "Buy": st.column_config.NumberColumn("Buy %", format="percent"),
            "Win": st.column_config.NumberColumn("Win (raw)", format="percent"),
            "Adj": st.column_config.NumberColumn("Win (adj)", format="percent"),
            "n": st.column_config.NumberColumn("n", help="Estimated purchases"),
            "AVG_KDA": st.column_config.NumberColumn("KDA", format="%.2f"),
            "First": st.column_config.NumberColumn("1st buy", format="%d′"),
            "FLAG": "Signal",
        },
    )
    rows = event.selection.rows
    return view.iloc[rows[0]]["ITEM"] if rows else None


def render_recommendations(row: pd.Series) -> None:
    recs = [row.get(c) for c in ("TOP_ITEM_1", "TOP_ITEM_2", "TOP_ITEM_3")]
    recs = [html.escape(str(r)) for r in recs if isinstance(r, str) and r]
    if not recs:
        return
    tags = "".join(f'<span class="ie-tag">{r}</span>' for r in recs)
    st.markdown(
        f'<div style="margin:6px 0 2px;color:var(--ink-soft);font-size:13px">'
        f'Commonly built with {html.escape(str(row["ITEM"]))}</div>'
        f'<div class="ie-tags">{tags}</div>',
        unsafe_allow_html=True,
    )


def _signal_card(kind: str, title: str, rows: pd.DataFrame) -> str:
    items = ""
    for _, r in rows.iterrows():
        items += (
            f'<div class="ie-row"><span>{html.escape(str(r["ITEM"]))}</span>'
            f'<span class="v">{r["ADJ_WIN_RATE"]*100:.0f}% · buy {r["PLAYER_PURCHASE_RATE"]*100:.0f}%</span></div>'
        )
    if not items:
        items = '<div class="ie-row"><span class="v">none at this sample floor</span></div>'
    return f'<div class="ie-card {kind}"><div class="hd">{title}</div>{items}</div>'


def render_signals(df: pd.DataFrame) -> None:
    gems = df[df["FLAG"] == "gem"].sort_values("ADJ_WIN_RATE", ascending=False).head(5)
    traps = df[df["FLAG"] == "trap"].sort_values("PLAYER_PURCHASE_RATE", ascending=False).head(5)
    c1, c2 = st.columns(2)
    with c1:
        st.markdown(_signal_card("gem", "Hidden gems", gems), unsafe_allow_html=True)
    with c2:
        st.markdown(_signal_card("trap", "Trap items", traps), unsafe_allow_html=True)


def render_health(info: dict) -> None:
    st.caption(
        f"Source: {info['mode']} · {info['item_rows']:,} item rows · "
        f"{info['champions']} champions"
    )