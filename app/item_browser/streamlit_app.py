import src_data as data
import src_stats as stats
import src_ui as ui


ui.setup_page()

# --- Load (cached; live warehouse in SiS, local CSV otherwise) ---
overview = data.load_overview()
items_raw = data.load_item_stats()


# --- Controls ---
controls = ui.sidebar_controls(overview)


# --- Stats pipeline with current knobs ---
items = stats.prepare(
    items_raw, 
    k=controls["k"], 
    min_n=controls["min_n"]
)


# --- Slice to selection ---
champ = controls["champion"]
champ_items = items[items["CHAMPION"] == champ]
if controls["tiers"]:
    champ_items = champ_items[
        champ_items["ITEM_CATEGORY"].isin(controls["tiers"])
    ]
    
champ_items = champ_items.sort_values("PLAYER_PURCHASE_RATE", ascending=False)

meta = overview[overview["CHAMPION"] == champ].iloc[0]


# --- Render ---
ui.render_hero(meta)
selected = ui.render_item_table(champ_items)

if selected is not None:
    row = champ_items[champ_items["ITEM"] == selected].iloc[0]
    ui.render_recommendations(row)

ui.render_signals(champ_items)
ui.render_health(data.data_health(items_raw, overview))