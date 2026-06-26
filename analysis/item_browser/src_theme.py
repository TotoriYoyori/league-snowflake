"""Theme — one injected CSS string. Restrained on purpose: a custom font, a
custom palette, and custom layout carry the "this was designed" signal for an
internal tool; anything heavier is noise.

Palette is Genshin-leaning: warm parchment, ink text, antique gold accents,
with jade/vermilion reserved for the gem/trap semantics.

ZCOOL XiaoWei is pulled from Google Fonts here for convenience. In a locked-down
Streamlit-in-Snowflake sandbox the CDN may be blocked — bundle the .ttf into
assets/ and register it via [[theme.fontFaces]] in .streamlit/config.toml.
"""

import streamlit as st

_CSS = """
<style>

:root {
  --bg:#F7F2E7; --panel:#FBF8F0; --ink:#3D3526; --ink-soft:#6B5F49;
  --gold:#BE9A57; --gold-deep:#8C6E3A; --border:#E5DAC2;
  --jade:#5E8C6A; --jade-deep:#2F5238; --verm:#B25A48; --verm-deep:#7A3326;
}

.stApp { background:var(--bg); color:var(--ink); }
h1, h2, h3, .ie-display { font-family:'ZCOOL XiaoWei', serif; color:var(--ink); letter-spacing:.5px; }

/* Hero banner */
.ie-hero { border:1px solid var(--border); border-top:3px solid var(--gold);
  background:var(--panel); border-radius:14px; padding:18px 22px; margin-bottom:8px; }
.ie-hero .name { font-family:'ZCOOL XiaoWei', serif; font-size:34px; color:var(--ink); margin:0; }
.ie-hero .lane { color:var(--gold-deep); font-size:14px; margin:2px 0 12px; }
.ie-pills { display:flex; gap:8px; flex-wrap:wrap; }
.ie-pill { background:var(--bg); border:1px solid var(--border); border-radius:999px;
  padding:5px 13px; font-size:13px; color:var(--ink-soft); }
.ie-pill b { color:var(--ink); font-weight:600; }

/* Gem / trap panels */
.ie-card { border:1px solid var(--border); border-radius:12px; background:var(--panel);
  padding:12px 14px; height:100%; }
.ie-card.gem { border-top:3px solid var(--jade); }
.ie-card.trap { border-top:3px solid var(--verm); }
.ie-card .hd { font-family:'ZCOOL XiaoWei', serif; font-size:16px; margin-bottom:8px; }
.ie-card.gem .hd { color:var(--jade-deep); }
.ie-card.trap .hd { color:var(--verm-deep); }
.ie-row { display:flex; justify-content:space-between; font-size:13px; padding:3px 0; }
.ie-row .v { color:var(--ink-soft); }

/* Recommendation tags */
.ie-tags { display:flex; gap:8px; flex-wrap:wrap; margin-top:4px; }
.ie-tag { background:var(--bg); border:1px solid var(--gold); color:var(--gold-deep);
  border-radius:8px; padding:5px 11px; font-size:13px; }

/* Restyle native widgets just enough to match */
.stButton>button, .stSelectbox div[data-baseweb="select"]>div { border-color:var(--border); }
hr { border-color:var(--border); }
</style>
"""


def inject() -> None:
    st.markdown(_CSS, unsafe_allow_html=True)