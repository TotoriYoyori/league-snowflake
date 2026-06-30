"""Statistical core — pure pandas, no Streamlit and no Snowflake imports.

This is the only module with real logic, so it is deliberately isolated and
unit-testable on a plain DataFrame.

The method, in one line: item win rates are smoothed with empirical-Bayes
shrinkage (a Beta-binomial estimator) toward each champion's pooled win rate,
which stabilises the long tail of low-sample items. Gems and traps are then the
two interesting corners of (adjusted win rate) vs (purchase rate).
"""

from __future__ import annotations

import numpy as np
import pandas as pd

# Strength of the prior, in units of games. k games of "benefit of the doubt"
# are handed to the baseline. Median item sits near n=7 here, so k in 20-50
# corrects the noisy tail while leaving well-sampled items essentially untouched.
DEFAULT_K = 20.0


def add_effective_n(df: pd.DataFrame) -> pd.DataFrame:
    """Reconstruct the sample size behind each win rate.

    The gold table only exposes a purchase *rate*, so we recover the count:
        effective n = purchase_rate * champion games played
        wins        = win_rate * effective n
    """
    out = df.copy()
    out["EFF_N"] = (out["PLAYER_PURCHASE_RATE"] * out["GLOBAL_GAMES_PLAYED"]).round()
    out["WINS"] = (out["WIN_RATE"] * out["EFF_N"]).round()
    return out


def shrink_winrate(df: pd.DataFrame, k: float = DEFAULT_K) -> pd.DataFrame:
    """Add ADJ_WIN_RATE via empirical-Bayes shrinkage toward the champion mean.

        baseline_c = sum(wins) / sum(n)          per champion
        adjusted_i = (wins_i + k * baseline_c) / (n_i + k)

    High-n items barely move; low-n items collapse toward the champion's own
    typical win rate (not a flat 50%, so strong/weak champions are judged
    against themselves).
    """
    out = df.copy()
    grp = out.groupby("CHAMPION")
    champ_wins = grp["WINS"].transform("sum")
    champ_n = grp["EFF_N"].transform("sum")
    baseline = np.where(champ_n > 0, champ_wins / champ_n, 0.5)

    out["CHAMPION_BASELINE"] = baseline
    out["ADJ_WIN_RATE"] = (out["WINS"] + k * baseline) / (out["EFF_N"] + k)
    return out


def flag_gems_traps(
    df: pd.DataFrame,
    min_n: int = 20,
    margin: float = 0.02,
    low_q: float = 0.33,
    high_q: float = 0.66,
) -> pd.DataFrame:
    """Label each item 'gem', 'trap', or '' within its champion.

    Only items clearing `min_n` are eligible, so a flag is never just noise.

        gem  = adjusted win rate above champion median + margin,
               AND purchase rate in the champion's bottom third  (winning, ignored)
        trap = purchase rate in the champion's top third,
               AND adjusted win rate below champion median - margin (popular, losing)
    """
    out = df.copy()
    out["FLAG"] = ""
    eligible = out["EFF_N"] >= min_n

    for champ, idx in out.groupby("CHAMPION").groups.items():
        rows = out.loc[idx]
        elig = rows[eligible.loc[idx]]
        if len(elig) < 3:
            continue

        adj_median = elig["ADJ_WIN_RATE"].median()
        buy_low = elig["PLAYER_PURCHASE_RATE"].quantile(low_q)
        buy_high = elig["PLAYER_PURCHASE_RATE"].quantile(high_q)

        is_gem = (
            (elig["ADJ_WIN_RATE"] >= adj_median + margin)
            & (elig["PLAYER_PURCHASE_RATE"] <= buy_low)
        )
        is_trap = (
            (elig["PLAYER_PURCHASE_RATE"] >= buy_high)
            & (elig["ADJ_WIN_RATE"] <= adj_median - margin)
        )
        out.loc[elig.index[is_gem], "FLAG"] = "gem"
        out.loc[elig.index[is_trap], "FLAG"] = "trap"

    return out


def prepare(df: pd.DataFrame, k: float = DEFAULT_K, min_n: int = 20) -> pd.DataFrame:
    """Convenience pipeline: effective n -> shrinkage -> gem/trap flags."""
    return flag_gems_traps(shrink_winrate(add_effective_n(df), k=k), min_n=min_n)
