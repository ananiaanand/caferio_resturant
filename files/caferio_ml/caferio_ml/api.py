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


@app.post("/predict/stockout")
def stockout(req: StockoutRequest):
    hist = load_history()
    out = []
    for it in req.items:
        if it.ingredient not in bundle["models"]:
            raise HTTPException(404, f"no model for ingredient '{it.ingredient}'")
        out.append(predict_stockout(bundle, to_series(hist, it.ingredient), it.ingredient,
                                    it.current_stock, it.lead_time_days, req.cover_days,
                                    req.horizon_days, holidays=holidays))
    order = {"CRITICAL": 0, "WARNING": 1, "OK": 2}
    out.sort(key=lambda r: (order[r["status"]], r["days_left"] if r["days_left"] is not None else 1e9))
    return {"results": out}
