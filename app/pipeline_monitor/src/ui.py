"""
UI layout. Orchestration only in `streamlit_app.py`; this module owns how
things are drawn.

Layout convention: each layer section opens with a row of summary metrics,
then every check from that layer's monitor.ipynb is rendered as its own
card with the data visible by default (no expanders) — per the "per-check
breakdown always visible" decision for this audience (DE/DS/PM).
"""

from __future__ import annotations

import textwrap

import pandas as pd
import streamlit as st

from settings import Settings
from src import data as d

PILL_OK = "pm-pill-ok"
PILL_WARN = "pm-pill-warn"
PILL_FAIL = "pm-pill-fail"
PILL_NEUTRAL = "pm-pill-neutral"


def _pill(text: str, level: str = PILL_NEUTRAL) -> str:
    return f'<span class="pm-pill {level}">{text}</span>'


def render_header(settings: Settings) -> None:
    mode_label = "Local / Mock" if settings.is_local else "Snowflake (live)"
    mode_level = PILL_NEUTRAL if settings.is_local else PILL_OK
    st.markdown(
        textwrap.dedent(f"""
        <div class="pm-header">
            <div class="pm-title">{settings.ui.app_title} {_pill(mode_label, mode_level)}</div>
            <div class="pm-subtitle-en">{settings.ui.app_subtitle_en}</div>
            <div class="pm-subtitle-zh">{settings.ui.app_subtitle_zh}</div>
        </div>
        """),
        unsafe_allow_html=True,
    )


def render_layer_header(layer_key: str, settings: Settings) -> None:
    en, zh = settings.ui.layer_labels[layer_key]
    st.markdown(
        textwrap.dedent(f"""
        <div class="pm-layer-header">
            <span class="pm-layer-en">{en}</span>
            <span class="pm-layer-zh">{zh}</span>
        </div>
        """),
        unsafe_allow_html=True,
    )


def render_card(
    name_en: str,
    name_zh: str,
    desc_en: str,
    df: pd.DataFrame,
    status_text: str | None = None,
    status_level: str = PILL_NEUTRAL,
    height: int | None = None,
) -> None:
    pill_html = _pill(status_text, status_level) if status_text else ""
    with st.container(border=True):
        st.markdown(
            textwrap.dedent(f"""
            <div class="pm-card-title">
                <div>
                    <div class="pm-card-name">{name_en} · <span style="font-weight:400;color:var(--ink-soft);">{name_zh}</span></div>
                    <div class="pm-card-desc">{desc_en}</div>
                </div>
                {pill_html}
            </div>
            """),
            unsafe_allow_html=True,
        )
        st.dataframe(df, use_container_width=True, height=height or "content", hide_index=True)


def _count_status(df: pd.DataFrame, col: str, ok_values: tuple[str, ...]) -> tuple[int, int]:
    if df.empty or col not in df.columns:
        return 0, 0
    total = len(df)
    ok = df[col].isin(ok_values).sum()
    return int(ok), total


# ===========================================================================
# SEED
# ===========================================================================
def render_seed(settings: Settings) -> None:
    render_layer_header("seed", settings)

    inventory = d.load_seed_object_inventory(settings)
    stages = d.load_seed_stages(settings)
    procedures = d.load_seed_procedures(settings)
    row_validation = d.load_seed_row_count_validation(settings)
    stage_files = d.load_seed_stage_files(settings)
    load_state = d.load_seed_load_state(settings)
    date_index = d.load_seed_date_index(settings)

    ok, total = _count_status(row_validation, "STATUS", ("PASS",))
    c1, c2, c3 = st.columns(3)
    c1.metric("Seed datasets validated", f"{ok}/{total}")
    if not load_state.empty:
        c2.metric("Days ingested", int(load_state.iloc[0]["DAYS_INGESTED"]))
        c3.metric("Days remaining", int(load_state.iloc[0]["DAYS_REMAINING"]))
    render_card(
        "Simulated Daily Load State", "模拟每日加载状态",
        "Tracks the simulated daily ingestion pointer. DAYS_REMAINING = 0 means fully loaded.",
        load_state,
    )
    render_card(
        "Object Inventory", "清单",
        "All registered objects in the SEED schema.",
        inventory,
    )
    cols = st.columns(2)
    with cols[0]:
        render_card("Stages", "暂存区", "Stages registered under SEED.", stages)
    with cols[1]:
        render_card("Procedures", "存储过程", "VALIDATE_SEED_UPLOAD / SIMULATE_DAILY_LOAD registration.", procedures)

    level = PILL_OK if ok == total and total > 0 else (PILL_WARN if ok > 0 else PILL_FAIL)
    render_card(
        "CSV vs Table Row Count Reconciliation", "CSV 与表行数核对",
        "Verifies the base COPY INTO for all 5 source datasets matched the uploaded CSVs.",
        row_validation,
        status_text=f"{ok}/{total} PASS",
        status_level=level,
    )
    render_card(
        "Stage File Listing", "暂存区文件列表",
        "Files currently present in @SEED.SEED_UPLOAD_STG.",
        stage_files,
    )
    render_card(
        "Matches Ingested per Date (recent)", "近期每日入库比赛数",
        "Most recent dates in the simulated source index.",
        date_index,
    )


# ===========================================================================
# BRONZE
# ===========================================================================
def render_bronze(settings: Settings) -> None:
    render_layer_header("bronze", settings)

    inventory = d.load_bronze_object_inventory(settings)
    stages = d.load_bronze_stages(settings)
    pipes = d.load_bronze_pipes(settings)
    streams = d.load_bronze_streams(settings)
    file_formats = d.load_bronze_file_formats(settings)
    row_counts = d.load_bronze_row_counts(settings)
    pipe_status = d.load_bronze_pipe_status(settings)
    copy_history = d.load_bronze_copy_history(settings)
    stage_files = d.load_bronze_stage_files(settings)
    stream_state = d.load_bronze_stream_state(settings)

    pending = int(pipe_status["PENDING_FILE_COUNT"].sum()) if not pipe_status.empty else 0
    running = int((pipe_status["EXECUTION_STATE"] == "RUNNING").sum()) if not pipe_status.empty else 0
    errors = int(copy_history["ERROR_COUNT"].sum()) if "ERROR_COUNT" in copy_history.columns else 0

    c1, c2, c3, c4 = st.columns(4)
    c1.metric("Bronze tables", len(row_counts))
    c2.metric("Pipes running", f"{running}/{len(pipe_status)}")
    c3.metric("Pending files", pending)
    c4.metric("Copy errors (14d)", errors)

    render_card("Object Inventory", "对象清单", "Tables/views in the BRONZE schema.", inventory)
    cols = st.columns(4)
    with cols[0]:
        render_card("Stages", "暂存区", "Stages.", stages, height=220)
    with cols[1]:
        render_card("Pipes", "管道", "Pipes.", pipes, height=220)
    with cols[2]:
        render_card("Streams", "数据流", "Streams.", streams, height=220)
    with cols[3]:
        render_card("File Formats", "文件格式", "File formats.", file_formats, height=220)

    render_card(
        "Row Counts & Health", "行数与健康度",
        "Row counts across all 5 bronze tables.",
        row_counts,
    )

    pipe_level = PILL_OK if pending == 0 else PILL_WARN
    render_card(
        "Pipe Status & Ingestion History", "管道状态与入库历史",
        "Current pipe execution state and pending file counts.",
        pipe_status,
        status_text=f"{pending} pending" if pending else "0 pending",
        status_level=pipe_level,
    )
    err_level = PILL_OK if errors == 0 else PILL_FAIL
    render_card(
        "Copy History (14 days)", "拷贝历史（14天）",
        "Recent COPY INTO executions, rows loaded/parsed, and errors.",
        copy_history,
        status_text=f"{errors} errors" if errors else "0 errors",
        status_level=err_level,
    )
    render_card(
        "Stage File Inspection", "暂存区文件检查",
        "Files currently present in each bronze stage.",
        stage_files,
    )

    has_pending = bool(stream_state["HAS_DATA"].any()) if "HAS_DATA" in stream_state.columns else False
    render_card(
        "Stream State", "数据流状态",
        "Checks if any bronze streams have unconsumed data pending for silver.",
        stream_state,
        status_text="data pending" if has_pending else "all consumed",
        status_level=PILL_WARN if has_pending else PILL_OK,
    )


# ===========================================================================
# SILVER
# ===========================================================================
def render_silver(settings: Settings) -> None:
    render_layer_header("silver", settings)

    inventory = d.load_silver_object_inventory(settings)
    task_history = d.load_silver_task_history(settings)
    task_summary = d.load_silver_task_summary(settings)
    stream_state = d.load_silver_stream_state(settings)
    row_counts = d.load_silver_row_counts(settings)
    vs_gold = d.load_silver_vs_gold_counts(settings)

    failed = int((task_summary["STATE"] != "SUCCEEDED").sum()) if "STATE" in task_summary.columns else 0
    diff_total = int(vs_gold["DIFF"].abs().sum()) if "DIFF" in vs_gold.columns else 0
    has_pending = bool(stream_state["HAS_DATA"].any()) if "HAS_DATA" in stream_state.columns else False

    c1, c2, c3 = st.columns(3)
    c1.metric("Task states w/ failures (24h)", failed)
    c2.metric("Silver tables", len(row_counts))
    c3.metric("Silver↔Gold row diff", diff_total)

    render_card(
        "Object Inventory", "对象清单",
        "Tables, views, and tasks in the SILVER schema.",
        inventory,
    )

    task_level = PILL_OK if failed == 0 else PILL_FAIL
    render_card(
        "Task History (24h)", "任务执行历史（24小时）",
        "Per-run task execution history feeding data into silver.",
        task_history,
        status_text=f"{failed} non-success states" if failed else "all succeeded",
        status_level=task_level,
    )
    render_card(
        "Task Success/Failure Summary", "任务成功/失败汇总",
        "Run counts and average duration, grouped by task and state.",
        task_summary,
        status_text=f"{failed} non-success states" if failed else "all succeeded",
        status_level=task_level,
    )
    render_card(
        "Stream Pending Data Status", "数据流待处理状态",
        "Whether upstream bronze streams still have unconsumed data.",
        stream_state,
        status_text="data pending" if has_pending else "all consumed",
        status_level=PILL_WARN if has_pending else PILL_OK,
    )
    render_card(
        "Silver Row Counts & Freshness", "白银层行数与新鲜度",
        "Row counts, size, and LAST_ALTERED per silver table — used as a freshness proxy.",
        row_counts,
    )

    diff_level = PILL_OK if diff_total == 0 else PILL_WARN
    render_card(
        "Silver vs Gold Row Count Comparison", "白银层与黄金层行数比对",
        "Outgoing data check: row count parity between silver and the gold tables derived from it.",
        vs_gold,
        status_text="parity" if diff_total == 0 else f"diff={diff_total}",
        status_level=diff_level,
    )


# ===========================================================================
# GOLD
# ===========================================================================
def render_gold(settings: Settings) -> None:
    render_layer_header("gold", settings)

    inventory = d.load_gold_object_inventory(settings)
    freshness = d.load_gold_dt_freshness(settings)
    refresh_history = d.load_gold_refresh_history(settings)
    grain = d.load_gold_grain_validation(settings)

    behind = int((~freshness["FRESHNESS_STATUS"].astype(str).str.contains("ON TRACK")).sum()) if "FRESHNESS_STATUS" in freshness.columns else 0
    refresh_failures = int((refresh_history["REFRESH_STATE"] != "SUCCEEDED").sum()) if "REFRESH_STATE" in refresh_history.columns else 0
    grain_fail = int((grain["STATUS"] != "PASS").sum()) if "STATUS" in grain.columns else 0

    c1, c2, c3 = st.columns(3)
    c1.metric("Dynamic tables", len(inventory))
    c2.metric("Not on track", behind)
    c3.metric("Grain checks failing", grain_fail)

    render_card(
        "Object Inventory", "对象清单",
        "All 5 dynamic tables under GOLD.",
        inventory,
    )

    fresh_level = PILL_OK if behind == 0 else PILL_WARN
    render_card(
        "Dynamic Table Freshness Check", "动态表新鲜度检查",
        "Scheduling state, target lag, and actual lag per dynamic table. Note: in a simulated daily-load "
        "pipeline, tables will show BEHIND SCHEDULE between simulated loads — that's expected, not broken.",
        freshness,
        status_text=f"{behind} not on track" if behind else "all on track",
        status_level=fresh_level,
    )
    rh_level = PILL_OK if refresh_failures == 0 else PILL_FAIL
    render_card(
        "Refresh History (recent)", "刷新历史（近期）",
        "Most recent dynamic table refreshes, duration, and row deltas.",
        refresh_history,
        status_text=f"{refresh_failures} failures" if refresh_failures else "all succeeded",
        status_level=rh_level,
    )
    grain_level = PILL_OK if grain_fail == 0 else PILL_FAIL
    render_card(
        "Silver → Gold Grain Validation", "白银到黄金层粒度校验",
        "Confirms each gold table's row count matches the expected grain derived from its silver source.",
        grain,
        status_text=f"{grain_fail} mismatches" if grain_fail else "all pass",
        status_level=grain_level,
    )
