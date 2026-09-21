# Caferio — Ingredient Stock-Out Prediction (Random Forest)

Answers one question: **"Given current stock, when will each kitchen ingredient run out?"**

```
consumption history ──► Random Forest (1 per ingredient) ──► daily forecast (next 21 days)
                                                                   │
current stock ─────────────────────────────────────────────────────┤
supplier lead time ────────────────────────────────────────────────┤
                                                                   ▼
                         run-out date/time (expected / earliest / latest)
                         status  OK · WARNING · CRITICAL
                         suggested reorder quantity
```

## Files

| File | Purpose |
|---|---|
| `generate_data.py` | Makes 12 months of **synthetic** orders + ingredient consumption (recipes × orders) |
| `features.py` | Feature engineering, shared by training and prediction |
| `train.py` | Trains, evaluates, backtests, saves `models/caferio_stock_rf.joblib` |
| `predict.py` | Recursive forecast + stock-out logic (`predict_stockout()`), CLI demo |
| `api.py` | FastAPI service exposing `/predict/stockout` |

## Run it

```bash
pip install -r requirements.txt
python generate_data.py      # 1. fake data  -> data/
python train.py              # 2. train      -> models/
python predict.py            # 3. demo output
uvicorn api:app --port 8000  # 4. API, docs at /docs
```

## What was done and why

1. **Target = daily consumption per ingredient** (grams / ml), not per dish. Kitchen stock is
   ingredients, and recipes already map dish → ingredients.
2. **One `RandomForestRegressor` per ingredient.** Quantities differ by 100× between Spices and Rice;
   separate models avoid scale problems.
3. **Features** (all use only *past* days, so no data leakage):
   day of week, weekend, month, day of month, holiday, day-before-holiday,
   consumption 1 / 7 / 14 days ago, rolling mean 7 / 14 / 28 days, rolling std 7 days.
4. **Chronological split** — oldest 80 % trains, newest 20 % tests. Random shuffling would leak the future.
5. **Tuning** with `TimeSeriesSplit` (small grid: depth, leaf size, max features).
6. **Baseline check** — model must beat "same weekday last week". It does, by ~20–30 % lower MAE.
7. **Recursive multi-day forecast** — predict tomorrow, feed it back as a lag feature, predict the day after…
8. **Stock-out logic** — cumulative predicted consumption is compared with stock; the crossing day is
   interpolated inside the day and converted to a clock time using opening hours.
9. **Uncertainty band** — ±1.28·σ·√days (σ = out-of-sample residual std) gives *earliest* / *latest* run-out.
   Status uses the earliest time, so alerts are conservative.
10. **Backtest of the real feature** — on past days, guess stock, predict run-out, compare with truth.

### Results on synthetic data (test = newest 20 %)

| Ingredient | MAE | Naive MAE | R² |
|---|---|---|---|
| Chicken | ~4.2 kg/day | ~5.3 kg | 0.70 |
| Rice | ~3.9 kg/day | ~5.2 kg | 0.56 |
| Cheese | ~0.96 kg/day | ~1.24 kg | 0.75 |
| Flour | ~1.9 kg/day | ~2.5 kg | 0.80 |

Stock-out backtest: **mean error ≈ 0.2 days**, **≈ 100 % of cases within ±1 day**, 80 % band actually
covers the truth **~70–80 %** of the time (slightly optimistic — see "Known limits").
Full numbers are in `models/metrics.json` after training.

> ⚠️ These numbers come from synthetic data with clean patterns. **Real data will score worse.**
> In your report say so explicitly: *"synthetic data was used to develop the pipeline; the system
> retrains on real operational data after deployment."*

## Move to real data (the important part)

### 1. Build the training table from your database

Use **consumption** (what the kitchen actually used), not sales. Your inventory deduction rows already give this:

```sql
create or replace view daily_ingredient_consumption as
select (t.created_at at time zone 'Asia/Kolkata')::date as date,
       i.name  as ingredient,
       i.unit  as unit,                       -- store as g / ml
       sum(abs(t.quantity)) as consumed_qty
from inventory_transactions t
join ingredients i on i.id = t.ingredient_id
where t.type = 'order_deduction'
group by 1, 2, 3;
```

Export it to `data/consumption.csv` (same 4 columns) and run `python train.py`.
For live serving, replace `load_history()` in `api.py` with a query on this view.

### 2. Keep the holiday list current
Edit `data/holidays.json`. Future holidays matter: they let the model see a demand spike coming.

### 3. Call it from the app

```
Flutter ──► your backend / Supabase Edge Function ──► POST /predict/stockout ──► JSON
```
The backend reads current stock from `inventory` and sends it. Never call the ML service straight from Flutter.

```json
POST /predict/stockout
{ "items": [ {"ingredient": "Chicken", "current_stock": 60000, "lead_time_days": 1} ],
  "horizon_days": 21 }
```
Response (per ingredient): `status`, `days_left`, `runout_expected`, `runout_earliest`,
`runout_latest`, `reorder_qty`, `forecast_daily[]`.

Dart sketch:
```dart
final res = await http.post(Uri.parse('$mlUrl/predict/stockout'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'items': items}));   // items: [{ingredient, current_stock, lead_time_days}]
final results = jsonDecode(res.body)['results'] as List;   // already sorted: CRITICAL first
```
UI ideas: red/amber/green chips from `status`, "Chicken runs out today ~7 PM" cards, reorder button
pre-filled with `reorder_qty`, line chart from `forecast_daily`.

### 4. Retrain on a schedule
- Run `python train.py` weekly (cron / GitHub Action / Supabase scheduled job), then restart the API.
- Start once you have **≥ 2–3 months** of real data. Under 28 days the model cannot predict at all.
- Compare new metrics with the old `models/metrics.json` before replacing the live model.

## Known limits (be honest about these)

- **Censored demand:** if an ingredient hits zero and dishes are unavailable, recorded consumption is
  lower than real demand. Mark such days or exclude them when possible.
- **Stock must be accurate:** predictions are only as good as `current_stock`. Do stock-takes and log wastage.
- **Band coverage:** σ is measured on 1-day-ahead errors; multi-day recursive error grows a bit faster,
  hence ~75 % coverage instead of 80 %. Widen `Z` in `predict.py` if you want safer alerts.
- **Errors compound** with horizon. Trust days 1–7 most; days 14+ are indicative.
- **New ingredients / menu changes** need ≥ 28 days of history before they get a model.
- **Unknown events** (sudden rush, festival not in `holidays.json`, weather) are invisible to the model.

## Upgrade path (later, in this order)

1. Add features: promotions/discounts, weather (rain), local events, menu changes.
2. Predict per **dish** and convert via recipes → catches menu-level shifts.
3. Try gradient boosting (LightGBM/XGBoost) or quantile forest for tighter uncertainty bands.
4. Predict per **hour** for same-day "runs out at 6 PM" alerts.
5. Auto-create purchase orders from `reorder_qty` with human approval.
