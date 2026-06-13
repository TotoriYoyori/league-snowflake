import streamlit as st
import os
import math
import numpy as np
import pandas as pd

# --- Connection ---
conn = st.connection("snowflake", ttl=os.getenv("SNOWFLAKE_CONNECTION_TTL"))
session = conn.session()


# --- Validation ---
def validate_minute(minute: int) -> int:
    if minute < 5 or minute > 90:
        raise ValueError(f'minute must be between 5 and 90, got {minute}')
    if minute % 5 != 0:
        raise ValueError(f'minute must be a multiple of 5, got {minute}')
    return minute


# --- Stats (replaces scipy.stats.norm.cdf) ---
def normal_cdf(x: float, mean: float, std: float) -> float:
    z = (x - mean) / std
    return 0.5 * (1.0 + math.erf(z / math.sqrt(2.0)))


# --- Data Loading ---
@st.cache_data
def load_data() -> pd.DataFrame:
    return session.sql("""
        SELECT 
            MINUTE, 
            KILLS
        FROM LEAGUE_RECORDS.L30_ID.FCT_INTERVALS
        JOIN LEAGUE_RECORDS.L30_ID.DIM_INTERVALS_KDA USING(PLAYER_INTERVAL_ID)
    """).to_pandas()


# --- Core Logic ---
def stats_at_minute(df: pd.DataFrame, minute: int) -> pd.DataFrame:
    minute = validate_minute(minute)
    return df.loc[df['MINUTE'] == minute, ['MINUTE', 'KILLS']]


def probability_of_kills_at_minute(
    df: pd.DataFrame,
    kills: int,
    minute: int,
) -> tuple[float, float, float, pd.DataFrame]:
    kills_at_min = stats_at_minute(df, minute)
    sample = kills_at_min.sample(frac=0.1)
    adjusted_sample = sample.assign(sqrt_KILLS=np.sqrt(sample['KILLS']))

    mean_val = float(np.mean(adjusted_sample['sqrt_KILLS']))
    std_val = float(np.std(adjusted_sample['sqrt_KILLS'], ddof=1))

    probability = round(normal_cdf(kills ** 0.5, mean_val, std_val) * 100, 2)

    return probability, mean_val, std_val, adjusted_sample


# --- App ---
st.title("Kill Probability Calculator")
st.write("What is the probability of a player having scored at least X kills by minute Y?")

col1, col2 = st.columns(2)
with col1:
    minute = st.select_slider("Minute", options=list(range(5, 91, 5)), value=30)
with col2:
    kills = st.slider("Target Kills", min_value=1, max_value=30, value=10)

data = load_data()

probability, mean_val, std_val, sample = probability_of_kills_at_minute(
    df=data,
    kills=kills,
    minute=minute,
)

st.metric(
    label=f"P(kills >= {kills}) at minute {minute}",
    value=f"{probability}%"
)

col_a, col_b = st.columns(2)
with col_a:
    st.metric("Sample Mean (sqrt scale)", f"{mean_val:.4f}")
with col_b:
    st.metric("Sample Std Dev (sqrt scale)", f"{std_val:.4f}")

st.bar_chart(
    sample['sqrt_KILLS'].value_counts().sort_index(),
    x_label="Sqrt Kills",
    y_label="Count",
)
