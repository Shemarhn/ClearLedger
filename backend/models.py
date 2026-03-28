"""
ClearLedger FastAPI - Pydantic Models
Request/response models for all endpoints.
"""
from pydantic import BaseModel, Field
from typing import Optional
from datetime import date


class LineItem(BaseModel):
    name: str
    price: float


class ParsedTransaction(BaseModel):
    merchant: Optional[str] = None
    amount: Optional[float] = None
    currency: str = "JMD"
    date: Optional[str] = None
    category: str = "Other"
    description: Optional[str] = None
    line_items: list[LineItem] = Field(default_factory=list)
    confidence: float = 0.0


class ParseReceiptResponse(BaseModel):
    success: bool
    data: ParsedTransaction
    receipt_url: Optional[str] = None
    raw_llm_response: Optional[dict] = None


class TextInput(BaseModel):
    text: str = Field(..., min_length=5, max_length=1000)


class ParseTextResponse(BaseModel):
    success: bool
    data: ParsedTransaction
    raw_llm_response: Optional[dict] = None


class ExportRequest(BaseModel):
    start_date: date
    end_date: date


class BudgetCheckResult(BaseModel):
    category: str
    monthly_limit: float
    total_spent: float
    percentage: float
    over_budget: bool
