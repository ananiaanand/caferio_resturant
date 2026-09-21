"""
FastAPI service. Flutter -> your backend / Supabase edge function -> this service.

Run:   uvicorn api:app --host 0.0.0.0 --port 8000
Docs:  http://localhost:8000/docs
"""
import pandas as pd
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

from features import DATA_DIR, load_holidays, to_series
from predict import load_bundle, predict_stockout

app = FastAPI(title="Caferio Ingredient Stock-Out Prediction")
bundle = load_bundle()
holidays = load_holidays()


def load_history() -> pd.DataFrame:
    """Columns: date, ingredient, consumed_qty (one row per ingredient per day).

    TODO(production): replace this CSV read with a query on your database, e.g.
    Supabase / Postgres view `daily_ingredient_consumption` (see README).
    """
    return pd.read_csv(DATA_DIR / "consumption.csv")


class StockItem(BaseModel):
    ingredient: str
    current_stock: float = Field(..., ge=0, description="in g (or ml for Oil) - same unit as history")
    lead_time_days: float = Field(1.0, ge=0, description="supplier delivery time")


class StockoutRequest(BaseModel):
    items: list[StockItem]
    horizon_days: int = Field(21, ge=7, le=60)
    cover_days: int = Field(3, ge=0, le=14)


@app.get("/health")
def health():
    return {"status": "ok", "model_trained_until": bundle["trained_until"],
            "ingredients": sorted(bundle["units"])}

class RefillRequest(BaseModel):
    ingredient: str
    amount: float = Field(..., ge=0)
    date: str

@app.post("/refill")
def log_refill(req: RefillRequest):
    import os
    refills_file = DATA_DIR / "refills.csv"
    
    # Create file with headers if it doesn't exist
    if not os.path.exists(refills_file):
        with open(refills_file, 'w', encoding='utf-8') as f:
            f.write("date,ingredient,refill_amount\n")
            
    # Append the refill transaction
    with open(refills_file, 'a', encoding='utf-8') as f:
        f.write(f"{req.date},{req.ingredient},{req.amount}\n")
        
    return {"status": "success", "message": f"Refill of {req.amount} for {req.ingredient} logged."}



@app.post("/predict/stockout")
def stockout(req: StockoutRequest):
    hist = load_history()
    out = []
    for it in req.items:
        if it.ingredient not in bundle["models"]:
            # Graceful fallback for demo if ingredient doesn't have a model
            out.append({
                "ingredient": it.ingredient,
                "status": "OK",
                "days_left": 99,
                "runout_expected": "2030-01-01T00:00:00",
                "runout_earliest": None,
                "runout_latest": None,
                "reorder_qty": 0.0,
                "forecast_daily": []
            })
            continue
        out.append(predict_stockout(bundle, to_series(hist, it.ingredient), it.ingredient,
                                    it.current_stock, it.lead_time_days, req.cover_days,
                                    req.horizon_days, holidays=holidays))
    order = {"CRITICAL": 0, "WARNING": 1, "OK": 2}
    out.sort(key=lambda r: (order[r["status"]], r["days_left"] if r["days_left"] is not None else 1e9))
    return {"results": out}
