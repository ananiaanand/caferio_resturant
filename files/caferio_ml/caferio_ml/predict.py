"""
Ingredient stock-exhaustion prediction.

  1. Random Forest predicts daily consumption for the next N days (recursive:
     each predicted day becomes a lag feature for the next day).
  2. Cumulative predicted consumption is compared with current stock
     -> "chicken runs out on <date> around <time>".
  3. Uncertainty band (from out-of-sample residuals) gives earliest / latest
     run-out, a status (OK / WARNING / CRITICAL) and a reorder quantity.

Demo:  python predict.py
"""
import math
from datetime import timedelta
from pathlib import Path

import joblib
import numpy as np
import pandas as pd

from features import DATA_DIR, MIN_HISTORY, load_holidays, next_row, to_series

MODEL_PATH = Path(__file__).parent / "models" / "caferio_stock_rf.joblib"
OPEN_HOUR, CLOSE_HOUR = 10, 22   # opening hours; used to turn "0.4 day" into a clock time
Z = 1.28                          # ~80% interval (10th / 90th percentile)


def load_bundle(path: Path = MODEL_PATH) -> dict:
    return joblib.load(path)


def recursive_forecast(model, y_hist, start: pd.Timestamp, horizon: int, holidays: set) -> np.ndarray:
    """Daily consumption forecast for start, start+1, ... start+horizon-1."""
    if len(y_hist) < MIN_HISTORY:
        raise ValueError(f"need >= {MIN_HISTORY} days of history, got {len(y_hist)}")
    hist = [float(v) for v in y_hist[-MIN_HISTORY:]]
    out = []
    for k in range(horizon):
        x = next_row(hist, start + pd.Timedelta(days=k), holidays)
        p = max(float(model.predict(x.reshape(1, -1))[0]), 0.0)
        out.append(p)
        hist = hist[1:] + [p]
    return np.array(out)


def _first_crossing(cum: np.ndarray, stock: float):
    """Fractional days (from start of day 0) at which cum >= stock, else None."""
    idx = np.flatnonzero(cum >= stock)
    if idx.size == 0:
        return None
    i = int(idx[0])
    prev = cum[i - 1] if i > 0 else 0.0
    return i + (stock - prev) / (cum[i] - prev)


def _to_datetime(start: pd.Timestamp, days: float):
    if days is None:
        return None
    whole = int(math.floor(days))
    frac = days - whole
    return (start + timedelta(days=whole)
            + timedelta(hours=OPEN_HOUR + frac * (CLOSE_HOUR - OPEN_HOUR)))


def stockout_estimate(daily_mean: np.ndarray, sigma: float, stock: float, start: pd.Timestamp) -> dict:
    """Expected / earliest / latest run-out from a daily forecast."""
    n = np.arange(1, len(daily_mean) + 1)
    cum = np.cumsum(daily_mean)
    band = Z * sigma * np.sqrt(n)               # errors of different days ~ independent
    d_exp = _first_crossing(cum, stock)
    d_early = _first_crossing(cum + band, stock)
    d_late = _first_crossing(cum - band, stock)
    return {"days_left": d_exp, "days_left_earliest": d_early, "days_left_latest": d_late,
            "runout": _to_datetime(start, d_exp),
            "runout_earliest": _to_datetime(start, d_early),
            "runout_latest": _to_datetime(start, d_late)}


def predict_stockout(bundle: dict, history: pd.Series, ingredient: str, current_stock: float,
                     lead_time_days: float = 1.0, cover_days: int = 3, horizon: int = 21,
                     start: pd.Timestamp = None, holidays: set = None) -> dict:
    """
    history        daily consumption series (index = date, last item = yesterday)
    current_stock  stock at the START of `start` (same unit as history)
    lead_time_days supplier delivery time
    cover_days     extra days of stock to keep after the delivery arrives
    """
    holidays = holidays if holidays is not None else load_holidays()
    start = pd.Timestamp(start) if start is not None else history.index[-1] + pd.Timedelta(days=1)
    model, sigma = bundle["models"][ingredient], bundle["sigma"][ingredient]

    daily = recursive_forecast(model, history.to_numpy(), start, horizon, holidays)
    est = stockout_estimate(daily, sigma, current_stock, start)

    # status: compare run-out with supplier lead time
    if current_stock <= 0 or (est["days_left"] is not None and est["days_left"] <= lead_time_days):
        status = "CRITICAL"
    elif est["days_left_earliest"] is not None and est["days_left_earliest"] <= lead_time_days:
        status = "WARNING"
    else:
        status = "OK"

    # reorder qty: cover lead time + safety days, at the pessimistic (high) demand
    tgt = min(int(math.ceil(lead_time_days + cover_days)), horizon)
    need = daily[:tgt].sum() + Z * sigma * math.sqrt(tgt)
    reorder = max(0.0, need - current_stock)

    fmt = lambda t: t.strftime("%Y-%m-%d %H:%M") if t is not None else None
    r = lambda v: round(v, 2) if v is not None else None
    return {
        "ingredient": ingredient, "unit": bundle["units"][ingredient],
        "current_stock": current_stock, "status": status,
        "days_left": r(est["days_left"]), "days_left_earliest": r(est["days_left_earliest"]),
        "days_left_latest": r(est["days_left_latest"]),
        "runout_expected": fmt(est["runout"]),
        "runout_earliest": fmt(est["runout_earliest"]),
        "runout_latest": fmt(est["runout_latest"]),
        "reorder_qty": round(reorder, 1),
        "forecast_daily": [{"date": (start + pd.Timedelta(days=i)).strftime("%Y-%m-%d"),
                            "predicted": round(float(v), 1)} for i, v in enumerate(daily)],
    }


def pretty(qty: float, unit: str) -> str:
    """1500 g -> '1.5 kg', 2500 ml -> '2.5 L'"""
    return f"{qty / 1000:.1f} {'kg' if unit == 'g' else 'L'}"


if __name__ == "__main__":
    bundle = load_bundle()
    df = pd.read_csv(DATA_DIR / "consumption.csv")
    hol = load_holidays()

    # (ingredient, current stock in g/ml, supplier lead time in days)
    demo = [("Chicken", 100_000, 1), ("Rice", 150_000, 2), ("Cheese", 7_000, 1), ("Oil", 40_000, 1)]
    print(f"model trained until {bundle['trained_until']}\n")
    for ing, stock, lead in demo:
        r = predict_stockout(bundle, to_series(df, ing), ing, stock, lead, holidays=hol)
        print(f"{ing:<8} stock {pretty(stock, r['unit']):>9}  lead {lead}d  [{r['status']}]")
        print(f"   runs out ~ {r['runout_expected']}  (earliest {r['runout_earliest']}, latest {r['runout_latest']})")
        print(f"   days left {r['days_left']}   reorder {pretty(r['reorder_qty'], r['unit'])}\n")
