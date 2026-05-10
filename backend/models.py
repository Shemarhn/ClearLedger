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
    transaction_type: str = "expense"
    currency: str = "JMD"
    date: Optional[str] = None
    category: str = "Other"
    description: Optional[str] = None
    line_items: list[LineItem] = Field(default_factory=list)
    confidence: float = 0.0
    account_hint: Optional[str] = None
    destination_account_hint: Optional[str] = None
    suggested_account_id: Optional[str] = None
    suggested_destination_account_id: Optional[str] = None
    card_last4: Optional[str] = None
    fee_amount: Optional[float] = None


class ParseReceiptResponse(BaseModel):
    success: bool
    data: ParsedTransaction
    receipt_url: Optional[str] = None
    receipt_path: Optional[str] = None
    parse_session_id: Optional[str] = None
    raw_llm_response: Optional[dict] = None


class TextInput(BaseModel):
    text: str = Field(..., min_length=5, max_length=1000)


class ParseTextResponse(BaseModel):
    success: bool
    data: ParsedTransaction
    raw_llm_response: Optional[dict] = None


class ReceiptFeedbackInput(BaseModel):
    parse_session_id: Optional[str] = None
    outcome: str = Field(..., pattern="^(saved|corrected|cancelled|accepted|confirmed)$")
    final_transaction_id: Optional[str] = None
    final_payload: Optional[dict] = None
    cancel_reason: Optional[str] = None


class ReceiptFeedbackResponse(BaseModel):
    success: bool
    status: str
    correction_summary: dict = Field(default_factory=dict)


class ExportRequest(BaseModel):
    start_date: date
    end_date: date


class BudgetCheckResult(BaseModel):
    category: str
    monthly_limit: float
    total_spent: float
    percentage: float
    over_budget: bool


class DailyOverviewResponse(BaseModel):
    success: bool
    generated_for: str
    summary: str
    insights: list[str] = Field(default_factory=list)
    suggestions: list[str] = Field(default_factory=list)
    totals: dict = Field(default_factory=dict)
    raw_llm_response: Optional[dict] = None
