"""Custom CSS injected once at app start. Light mode, fixed palette."""

from __future__ import annotations

CSS = """
<style>
:root {
    --red: #cc1f1f;
    --dark-red: #a81818;
    --amber: #e08a1e;
    --green: #2f9e63;
    --page-bg: #f1f1f1;
    --card-bg: #ffffff;
    --card-border: #e6e6e6;
    --subtle-border: #f1f1f1;
    --thead-bg: #fafafa;
    --ink: #1a1a1a;
    --ink-soft: #888888;
    --ink-faint: #aaaaaa;
    --font-main: "Noto Sans SC", system-ui, sans-serif;
}

html, body, [class*="css"] {
    font-family: var(--font-main);
    color: var(--ink);
}

.stApp {
    background-color: var(--page-bg);
}

[data-testid="stHeader"] {
    background-color: transparent;
}

/* ---------- App header ---------- */
.pm-header {
    display: flex;
    flex-direction: column;
    gap: 2px;
    margin-bottom: 1.25rem;
}
.pm-header .pm-title {
    font-size: 4rem;
    font-weight: 700;
    color: var(--dark-red);
}
.pm-header .pm-subtitle-en {
    font-size: 1.5rem;
    color: var(--ink-soft);
}
.pm-header .pm-subtitle-zh {
    font-size: 1rem;
    color: var(--ink-faint);
}

/* ---------- Layer section header ---------- */
.pm-layer-header {
    display: flex;
    align-items: baseline;
    gap: 0.6rem;
    margin: 1.6rem 0 0.6rem 0;
    padding-bottom: 0.4rem;
    border-bottom: 2px solid var(--card-border);
}
.pm-layer-header .pm-layer-en {
    font-size: 1.2rem;
    font-weight: 700;
    color: var(--ink);
}
.pm-layer-header .pm-layer-zh {
    font-size: 0.85rem;
    color: var(--ink-faint);
}

/* ---------- Check card ---------- */
div[data-testid="stVerticalBlockBorderWrapper"]:has(> div > div[data-testid="stVerticalBlock"] .pm-card-title) {
    background-color: var(--card-bg);
    border: 1px solid var(--card-border) !important;
    border-radius: 10px !important;
    padding: 0.9rem 1rem;
    margin-bottom: 0.9rem;
}

.pm-card-title {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 0.4rem;
}

.pm-card-title .pm-card-name {
    font-size: 1.2rem;
    font-weight: 600;
    color: var(--ink);
}

.pm-card-title .pm-card-desc {
    font-size: 1rem;
    color: var(--ink-soft);
    margin-top: 1px;
}

/* ---------- Status pill ---------- */
.pm-pill {
    display: inline-flex;
    align-items: center;
    gap: 0.3rem;
    font-size: 0.72rem;
    font-weight: 600;
    padding: 2px 10px;
    border-radius: 999px;
    white-space: nowrap;
}
.pm-pill-ok { background-color: rgba(47, 158, 99, 0.12); color: var(--green); }
.pm-pill-warn { background-color: rgba(224, 138, 30, 0.14); color: var(--amber); }
.pm-pill-fail { background-color: rgba(204, 31, 31, 0.12); color: var(--red); }
.pm-pill-neutral { background-color: var(--thead-bg); color: var(--ink-soft); }

/* ---------- Dataframe tweaks ---------- */
[data-testid="stDataFrame"] {
    border: 1px solid var(--subtle-border);
    border-radius: 8px;
    overflow: hidden;
    background-color: var(--page-bg);
}

/* ---------- Metric tweaks ---------- */
[data-testid="stMetric"] {
    background-color: var(--card-bg);
    border: 1px solid var(--card-border);
    border-radius: 10px;
    padding: 0.6rem 0.9rem;
}

[data-testid="stMetric"] p {
    color: var(--dark-red);
}

[data-testid="stMetricLabel"] { 
    color: var(--ink-soft); 
}

/* ---------- Sidebar ---------- */
[data-testid="stSidebar"] {
    background-color: var(--dark-red);
    border-right: 1px solid var(--card-border);
    color: var(--card-bg);
}

[data-testid="stSidebar"] p {
    color: var(--card-bg);
}

</style>
"""


def inject(st_module) -> None:
    st_module.markdown(CSS, unsafe_allow_html=True)
