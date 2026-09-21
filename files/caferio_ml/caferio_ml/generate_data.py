"""
Generate 12 months of SYNTHETIC Caferio data:
  data/orders.csv       date, item, orders
  data/consumption.csv  date, ingredient, unit, consumed_qty   <- ML training data
  data/holidays.json    list of holiday dates (edit for your region)

Ingredient consumption = sum(orders x recipe) with small wastage noise.
In production, consumption.csv is replaced by real rows built from
inventory_transactions (see README).

Run:  python generate_data.py
"""
import json
from pathlib import Path

import numpy as np
import pandas as pd

SEED = 42
START, END = "2025-09-01", "2026-08-31"
OUT = Path(__file__).parent / "data"

# Illustrative dates - EDIT for your region. Future dates matter: the model
# uses them to spot demand spikes in upcoming forecasts.
HOLIDAYS = [
    "2025-09-05", "2025-10-02", "2025-10-20", "2025-12-25", "2026-01-01",
    "2026-01-26", "2026-03-20", "2026-04-14", "2026-05-01", "2026-08-15",
    "2026-08-26", "2026-10-02", "2026-11-08", "2026-12-25", "2027-01-01",
]

# Quantities: grams per portion (Oil in ml).
# dow = demand multiplier Mon..Sun
MENU = {
    "Chicken Biriyani": dict(base=70, dow=[.85, .85, .85, .95, 1.15, 1.30, 1.35],
                             recipe={"Rice": 250, "Chicken": 200, "Spices": 20, "Oil": 30, "Vegetables": 60}),
    "Fried Rice":       dict(base=45, dow=[.90, .90, .95, 1.00, 1.10, 1.15, 1.10],
                             recipe={"Rice": 220, "Vegetables": 120, "Egg": 50, "Oil": 25, "Spices": 8}),
    "Burger":           dict(base=40, dow=[.80, .80, .85, .95, 1.20, 1.50, 1.40],
                             recipe={"Chicken": 120, "Flour": 90, "Cheese": 20, "Vegetables": 40, "Oil": 10}),
    "Pizza":            dict(base=30, dow=[.70, .70, .75, .90, 1.30, 1.60, 1.50],
                             recipe={"Flour": 200, "Cheese": 120, "Vegetables": 80, "Oil": 10, "Chicken": 50}),
    "Pasta":            dict(base=25, dow=[.90, .90, .95, 1.00, 1.05, 1.15, 1.10],
                             recipe={"Flour": 150, "Cheese": 40, "Vegetables": 70, "Oil": 15, "Spices": 6}),
    "Chicken Fry":      dict(base=35, dow=[.85, .85, .90, 1.00, 1.25, 1.35, 1.20],
                             recipe={"Chicken": 250, "Spices": 25, "Oil": 120, "Flour": 30}),
}
UNITS = {"Rice": "g", "Chicken": "g", "Spices": "g", "Oil": "ml",
         "Vegetables": "g", "Egg": "g", "Cheese": "g", "Flour": "g"}


def main():
    rng = np.random.default_rng(SEED)
    OUT.mkdir(exist_ok=True)
    dates = pd.date_range(START, END)
    hol = {pd.Timestamp(h) for h in HOLIDAYS}
    pre = {h - pd.Timedelta(days=1) for h in hol}

    order_rows, cons = [], {}
    for i, d in enumerate(dates):
        season = 1 + 0.10 * np.sin(2 * np.pi * (d.month - 3) / 12)
        trend = 1 + 0.0006 * i                      # business slowly grows
        boost = (1.35 if d in hol else 1.0) * (1.10 if d in pre else 1.0)
        day_cons = {k: 0.0 for k in UNITS}
        for item, cfg in MENU.items():
            mu = cfg["base"] * cfg["dow"][d.dayofweek] * season * trend * boost
            n = int(rng.poisson(mu * rng.lognormal(0, 0.07)))
            order_rows.append((d.date(), item, n))
            for ing, qty in cfg["recipe"].items():
                day_cons[ing] += n * qty * (1 + rng.normal(0.03, 0.02))  # ~3% wastage
        for ing, q in day_cons.items():
            cons[(d.date(), ing)] = round(q, 1)

    pd.DataFrame(order_rows, columns=["date", "item", "orders"]).to_csv(OUT / "orders.csv", index=False)
    pd.DataFrame(
        [(d, ing, UNITS[ing], q) for (d, ing), q in cons.items()],
        columns=["date", "ingredient", "unit", "consumed_qty"],
    ).to_csv(OUT / "consumption.csv", index=False)
    (OUT / "holidays.json").write_text(json.dumps(HOLIDAYS, indent=2))
    print(f"wrote {len(dates)} days x {len(UNITS)} ingredients -> {OUT}")


if __name__ == "__main__":
    main()
