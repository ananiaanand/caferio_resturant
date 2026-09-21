"""
Train one Random Forest per ingredient, evaluate it honestly, save the bundle.

Steps
  1. load consumption.csv -> daily series per ingredient
  2. features (calendar + lags + rolling means)
  3. CHRONOLOGICAL split: oldest 80% train, newest 20% test (no shuffling!)
  4. small grid search with TimeSeriesSplit
  5. metrics vs naive baseline ("same weekday last week")
  6. backtest of the real product feature: stock-out date prediction
  7. refit on ALL data and save models/caferio_stock_rf.joblib

Run:  python train.py
"""
import json
from datetime import datetime
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
from sklearn.base import clone
from sklearn.ensemble import RandomForestRegressor
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score
from sklearn.model_selection import GridSearchCV, TimeSeriesSplit

from features import DATA_DIR, FEATURES, load_holidays, to_series, training_frame
from predict import MODEL_PATH, _first_crossing, recursive_forecast, stockout_estimate

HORIZON = 14
GRID = {"max_depth": [None, 10], "min_samples_leaf": [1, 3], "max_features": [0.6, 1.0]}


def backtest_stockout(model, sigma, y: pd.Series, test_start, holidays, rng) -> dict:
    """Pretend to be the app on many past days: guess stock, predict run-out, compare to truth."""
    err, hit, cover, wk_err = [], 0, 0, []
    starts = [d for d in y.index if d >= test_start and d + pd.Timedelta(days=HORIZON) <= y.index[-1]][::2]
    for s in starts:
        hist = y[y.index < s].to_numpy()
        future = y[(y.index >= s)].to_numpy()[:HORIZON]
        stock = hist[-28:].mean() * rng.uniform(1.5, 7.0)       # random stock = 1.5..7 days of usage
        true_days = _first_crossing(np.cumsum(future), stock)
        daily = recursive_forecast(model, hist, s, HORIZON, holidays)
        est = stockout_estimate(daily, sigma, stock, s)
        wk_err.append(abs(daily[:7].sum() - future[:7].sum()) / future[:7].sum())
        if true_days is None or est["days_left"] is None:
            continue
        err.append(abs(est["days_left"] - true_days))
        hit += abs(est["days_left"] - true_days) <= 1.0
        lo, hi = est["days_left_earliest"], est["days_left_latest"]
        cover += (lo is not None and lo - 1e-9 <= true_days) and (hi is None or true_days <= hi + 1e-9)
    n = len(err)
    return {"cases": n, "stockout_mae_days": round(float(np.mean(err)), 2),
            "within_1_day_pct": round(100 * hit / n, 1),
            "interval_coverage_pct": round(100 * cover / n, 1),
            "next7d_total_mape_pct": round(100 * float(np.mean(wk_err)), 1)}


def main():
    df = pd.read_csv(DATA_DIR / "consumption.csv")
    holidays = load_holidays()
    units = df.drop_duplicates("ingredient").set_index("ingredient")["unit"].to_dict()
    rng = np.random.default_rng(0)
    bundle = {"models": {}, "sigma": {}, "units": units, "metrics": {}, "backtest": {},
              "features": FEATURES}

    for ing in sorted(units):
        y = to_series(df, ing)
        frame = training_frame(y, holidays)
        split = int(len(frame) * 0.8)
        train, test = frame.iloc[:split], frame.iloc[split:]
        Xtr, ytr = train[FEATURES].to_numpy(), train["y"].to_numpy()
        Xte, yte = test[FEATURES].to_numpy(), test["y"].to_numpy()

        gs = GridSearchCV(RandomForestRegressor(n_estimators=300, random_state=42, n_jobs=-1),
                          GRID, cv=TimeSeriesSplit(3), scoring="neg_mean_absolute_error")
        gs.fit(Xtr, ytr)
        rf = gs.best_estimator_
        rf.set_params(n_jobs=1)   # single-row predict is much faster without thread spawn

        pred = rf.predict(Xte)
        sigma = float(np.std(yte - pred, ddof=1))              # out-of-sample error size
        naive_mae = mean_absolute_error(yte, test["lag_7"])    # baseline
        m = {"mae": round(mean_absolute_error(yte, pred), 1),
             "rmse": round(float(np.sqrt(mean_squared_error(yte, pred))), 1),
             "r2": round(r2_score(yte, pred), 3),
             "mape_pct": round(100 * float(np.mean(np.abs(yte - pred) / np.maximum(yte, 1))), 1),
             "baseline_mae_lag7": round(naive_mae, 1), "best_params": gs.best_params_}
        bt = backtest_stockout(rf, sigma, y, test.index[0], holidays, rng)
        bundle["metrics"][ing], bundle["backtest"][ing], bundle["sigma"][ing] = m, bt, sigma

        # production model: same settings, trained on ALL data
        final = clone(rf).fit(frame[FEATURES].to_numpy(), frame["y"].to_numpy())
        final.set_params(n_jobs=1)
        bundle["models"][ing] = final
        print(f"{ing:<11} MAE {m['mae']:>7} {units[ing]} | naive {m['baseline_mae_lag7']:>7} | R2 {m['r2']:.3f} "
              f"| stock-out MAE {bt['stockout_mae_days']} d | within 1d {bt['within_1_day_pct']}% "
              f"| band coverage {bt['interval_coverage_pct']}%")

    bundle["trained_until"] = str(to_series(df, next(iter(units))).index[-1].date())
    bundle["trained_at"] = datetime.now().isoformat(timespec="seconds")
    MODEL_PATH.parent.mkdir(exist_ok=True)
    joblib.dump(bundle, MODEL_PATH, compress=3)
    Path(MODEL_PATH.parent / "metrics.json").write_text(json.dumps(
        {"metrics": bundle["metrics"], "backtest": bundle["backtest"]}, indent=2, default=str))
    print(f"\nsaved {MODEL_PATH}")


if __name__ == "__main__":
    main()
