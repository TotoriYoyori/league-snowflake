"""
Offline/demo mode — reads `assets/sample_data/*.csv`, one file per check.

Every function here mirrors a function in `data.py` 1:1 by name (minus the
`load_` mismatch is intentional — these are the "mock" half of the mock/live
switch). Keeping the CSVs one-per-check, rather than one giant CSV, means
each panel can be edited/regenerated independently and the file name itself
documents which check it backs.
"""

from __future__ import annotations

import os

import pandas as pd


def _read(sample_data_dir: str, name: str) -> pd.DataFrame:
    path = os.path.join(sample_data_dir, f"{name}.csv")
    return pd.read_csv(path)


# ---------------- SEED ----------------
def seed_object_inventory(dir_: str) -> pd.DataFrame:
    return _read(dir_, "seed_object_inventory")


def seed_stages(dir_: str) -> pd.DataFrame:
    return _read(dir_, "seed_stages")


def seed_procedures(dir_: str) -> pd.DataFrame:
    return _read(dir_, "seed_procedures")


def seed_row_count_validation(dir_: str) -> pd.DataFrame:
    return _read(dir_, "seed_row_count_validation")


def seed_stage_files(dir_: str) -> pd.DataFrame:
    return _read(dir_, "seed_stage_files")


def seed_load_state(dir_: str) -> pd.DataFrame:
    return _read(dir_, "seed_load_state")


def seed_date_index(dir_: str) -> pd.DataFrame:
    return _read(dir_, "seed_date_index")


# ---------------- BRONZE ----------------
def bronze_object_inventory(dir_: str) -> pd.DataFrame:
    return _read(dir_, "bronze_object_inventory")


def bronze_stages(dir_: str) -> pd.DataFrame:
    return _read(dir_, "bronze_stages")


def bronze_pipes(dir_: str) -> pd.DataFrame:
    return _read(dir_, "bronze_pipes")


def bronze_streams(dir_: str) -> pd.DataFrame:
    return _read(dir_, "bronze_streams")


def bronze_file_formats(dir_: str) -> pd.DataFrame:
    return _read(dir_, "bronze_file_formats")


def bronze_row_counts(dir_: str) -> pd.DataFrame:
    return _read(dir_, "bronze_row_counts")


def bronze_pipe_status(dir_: str) -> pd.DataFrame:
    return _read(dir_, "bronze_pipe_status")


def bronze_copy_history(dir_: str) -> pd.DataFrame:
    return _read(dir_, "bronze_copy_history")


def bronze_stage_files(dir_: str) -> pd.DataFrame:
    return _read(dir_, "bronze_stage_files")


def bronze_stream_state(dir_: str) -> pd.DataFrame:
    return _read(dir_, "bronze_stream_state")


# ---------------- SILVER ----------------
def silver_object_inventory(dir_: str) -> pd.DataFrame:
    return _read(dir_, "silver_object_inventory")


def silver_task_history(dir_: str) -> pd.DataFrame:
    return _read(dir_, "silver_task_history")


def silver_task_summary(dir_: str) -> pd.DataFrame:
    return _read(dir_, "silver_task_summary")


def silver_stream_state(dir_: str) -> pd.DataFrame:
    return _read(dir_, "silver_stream_state")


def silver_row_counts(dir_: str) -> pd.DataFrame:
    return _read(dir_, "silver_row_counts")


def silver_vs_gold_counts(dir_: str) -> pd.DataFrame:
    return _read(dir_, "silver_vs_gold_counts")


# ---------------- GOLD ----------------
def gold_object_inventory(dir_: str) -> pd.DataFrame:
    return _read(dir_, "gold_object_inventory")


def gold_dt_freshness(dir_: str) -> pd.DataFrame:
    return _read(dir_, "gold_dt_freshness")


def gold_refresh_history(dir_: str) -> pd.DataFrame:
    return _read(dir_, "gold_refresh_history")


def gold_grain_validation(dir_: str) -> pd.DataFrame:
    return _read(dir_, "gold_grain_validation")
