"""
Feature engineering shared by training and prediction.
Training and prediction MUST build features the same way, so both live here.

Target: daily consumption of ONE ingredient (grams / ml).
"""
import json
from pathlib import Path

import numpy as np
import pandas as pd

DATA_DIR = Path(__file__).parent / "data"

FEATURES = [
    "dow", "is_weekend", "month", "day_of_month", "is_holiday", "is_pre_holiday",
    "lag_1", "lag_7", "lag_14",
    "roll_mean_7", "roll_mean_14", "roll_mean_28", "roll_std_7",
]
MIN_HISTORY = 28  # days of history needed before a prediction can be made


def load_holidays(path: Path = DATA_DIR / "holidays.json") -> set:
    return {pd.Timestamp(d).normalize() for d in json.loads(Path(path).read_text())}


def calendar_features(dates: pd.DatetimeIndex, holidays: set) -> pd.DataFrame:
    dates = pd.DatetimeIndex(dates).normalize()
    return pd.DataFrame({
        "dow": dates.dayofweek,
        "is_weekend": (dates.dayofweek >= 5).astype(int),
        "month": dates.month,
        "day_of_month": dates.day,
        "is_holiday": [int(d in holidays) for d in dates],
        "is_pre_holiday": [int((d + pd.Timedelta(days=1)) in holidays) for d in dates],
    }, index=dates)


def to_series(df: pd.DataFrame, ingredient: str) -> pd.Series:
    """Long table (date, ingredient, consumed_qty) -> continuous daily series.
    Missing days become 0 (closed / nothing used)."""
    g = df[df["ingredient"] == ingredient].copy()
    g["date"] = pd.to_datetime(g["date"])
    y = g.groupby("date")["consumed_qty"].sum().sort_index()
    return y.asfreq("D").fillna(0.0)


def training_frame(y: pd.Series, holidays: set) -> pd.DataFrame:
    """One row per day: calendar + lag features (using ONLY past days) + target y."""
    prev = y.shift(1)  # everything below looks strictly at yesterday and earlier
    df = calendar_features(y.index, holidays)
    df["lag_1"] = y.shift(1)
    df["lag_7"] = y.shift(7)
    df["lag_14"] = y.shift(14)
    df["roll_mean_7"] = prev.rolling(7).mean()
    df["roll_mean_14"] = prev.rolling(14).mean()
    df["roll_mean_28"] = prev.rolling(28).mean()
    df["roll_std_7"] = prev.rolling(7).std()  # ddof=1, matches next_row()
    df["y"] = y
    return df.dropna()


def next_row(hist, date: pd.Timestamp, holidays: set) -> np.ndarray:
    """Feature vector for `date`, given past values `hist` (last item = yesterday)."""
    h = np.asarray(hist[-MIN_HISTORY:], dtype=float)
    cal = calendar_features(pd.DatetimeIndex([date]), holidays).iloc[0]
    f = {
        **cal.to_dict(),
        "lag_1": h[-1], "lag_7": h[-7], "lag_14": h[-14],
        "roll_mean_7": h[-7:].mean(), "roll_mean_14": h[-14:].mean(),
        "roll_mean_28": h.mean(), "roll_std_7": h[-7:].std(ddof=1),
    }
    return np.array([f[c] for c in FEATURES], dtype=float)
