import streamlit as st
import os
import math
import numpy as np
import pandas as pd

# --- Connection ---
conn = st.connection("snowflake", ttl=os.getenv("SNOWFLAKE_CONNECTION_TTL"))
session = conn.session()


# --- Constants ---
STATS_OPTIONS = ["KILLS", "DEATHS", "ASSISTS", "KDA_RATIO"]


# --- Pure math (replaces scipy.stats.norm.cdf) ---
def normal_cdf(x: float, mean: float, std: float) -> float:
    if std == 0:
        return 1.0 if x <= mean else 0.0
    z = (x - mean) / std
    return 0.5 * (1.0 + math.erf(z / math.sqrt(2.0)))


# --- Data Loading ---
@st.cache_data
def load_data() -> pd.DataFrame:
    return session.sql("""
        SELECT 
            MINUTE, 
            KILLS, 
            DEATHS, 
            ASSISTS, 
            COALESCE(ROUND(
                (KILLS + ASSISTS) / NULLIF(DEATHS, 0)
            , 2), KILLS + ASSISTS) AS KDA_RATIO
        FROM LEAGUE_RECORDS_LEGACY.L30_ID.FCT_INTERVALS
        JOIN LEAGUE_RECORDS_LEGACY.L30_ID.DIM_INTERVALS_KDA USING(PLAYER_INTERVAL_ID)
        ORDER BY MINUTE ASC
    """).to_pandas()


# --- Core Logic ---
def prep_arr(df: pd.DataFrame, minute: int, stat: str) -> np.ndarray:
    return df.loc[df["MINUTE"] == minute, stat].to_numpy()


def sampling_distribution(
    arr: np.ndarray,
    sample_size: int,
    n_runs: int,
    seed: int = 42,
) -> np.ndarray:
    rng = np.random.default_rng(seed=seed)
    samples = rng.choice(arr, size=(n_runs, sample_size), replace=True)
    return samples.mean(axis=1)


def group_probability_of_kda(
    arr: np.ndarray,
    bounds: float,
    sample_size: int,
    n_runs: int,
) -> dict:
    """P(group of `sample_size` players averages at least `bounds`)
    using sampling distribution + normal CDF (CLT-justified).
    """
    sampling_arr = sampling_distribution(arr, sample_size, n_runs)
    sampling_mean = float(np.mean(sampling_arr))
    sampling_se = float(np.std(sampling_arr))

    prob = 1.0 - normal_cdf(bounds, sampling_mean, sampling_se)

    return {
        "probability": prob,
        "sampling_mean": sampling_mean,
        "sampling_se": sampling_se,
        "sampling_arr": sampling_arr,
    }


def single_probability_of_kda(
    arr: np.ndarray,
    bounds: float,
) -> dict:
    """P(single player achieves at least `bounds`)
    using empirical CDF — no normality assumption.
    """
    prob = float(np.mean(arr >= bounds))

    return {
        "probability": prob,
        "n_observations": len(arr),
        "mean": float(np.mean(arr)),
        "std": float(np.std(arr)),
    }


# --- App UI ---
st.title("Probability of KDA")
st.write(
    "Calculate the probability of player KDA statistics "
    "at any given match interval."
)

# --- Parameters ---
st.subheader("Parameters")

col1, col2, col3 = st.columns(3)
with col1:
    stat = st.selectbox("Stat", options=STATS_OPTIONS)
with col2:
    minute = st.select_slider("Minute Interval", options=list(range(5, 91, 5)), value=30)
with col3:
    bounds = st.slider("Bound (at least X)", min_value=0.0, max_value=30.0, value=5.0, step=0.5)

with st.expander("Sampling Parameters (Group Probability)"):
    sample_col1, sample_col2 = st.columns(2)
    with sample_col1:
        sample_size = st.slider("Sample Size", min_value=5, max_value=200, value=10, step=5)
    with sample_col2:
        n_runs = st.slider("Number of Runs", min_value=100, max_value=50000, value=10000, step=100)

# --- Load and Filter ---
data = load_data()
arr = prep_arr(data, minute, stat)

if len(arr) == 0:
    st.warning(f"No data available for {stat} at minute {minute}.")
    st.stop()

# --- Results ---
st.divider()

group_result = group_probability_of_kda(arr, bounds, sample_size, n_runs)
single_result = single_probability_of_kda(arr, bounds)

col_group, col_single = st.columns(2)

with col_group:
    st.subheader("Group Probability")
    st.caption(f"Group of {sample_size} players averaging at least {bounds} {stat}")
    st.metric(
        label="Probability",
        value=f"{group_result['probability'] * 100:.2f}%",
    )
    st.metric("Sampling Mean", f"{group_result['sampling_mean']:.4f}")
    st.metric("Standard Error", f"{group_result['sampling_se']:.4f}")

with col_single:
    st.subheader("Single Player Probability")
    st.caption(f"One player achieving at least {bounds} {stat}")
    st.metric(
        label="Probability",
        value=f"{single_result['probability'] * 100:.2f}%",
    )
    st.metric("Population Mean", f"{single_result['mean']:.4f}")
    st.metric("Population Std", f"{single_result['std']:.4f}")

# --- Distribution Chart ---
st.divider()
st.subheader("Sampling Distribution of Means")
st.caption(f"Distribution of group means (n={sample_size}, runs={n_runs})")

hist_df = pd.DataFrame({"Sample Mean": group_result["sampling_arr"]})
st.bar_chart(
    hist_df["Sample Mean"].value_counts(bins=30).sort_index(),
    x_label=f"Mean {stat}",
    y_label="Count",
)

st.caption(f"Based on {single_result['n_observations']} observations at minute {minute}.")
