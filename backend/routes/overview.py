"""Daily AI overview endpoint."""

from __future__ import annotations

from collections import defaultdict
from datetime import date, timedelta
import logging
from typing import Any

from fastapi import APIRouter, Depends
from supabase import create_client

from auth import get_user_id
from config import SUPABASE_SECRET_KEY, SUPABASE_URL
from models import DailyOverviewResponse
from services.gemma_service import generate_daily_overview, generate_daily_overview_gemma

logger = logging.getLogger(__name__)
router = APIRouter(tags=["Overview"])


@router.post("/overview/daily", response_model=DailyOverviewResponse)
async def daily_overview(user_id: str = Depends(get_user_id)):
    supabase = create_client(SUPABASE_URL, SUPABASE_SECRET_KEY)
    start = date.today() - timedelta(days=60)

    response = (
        supabase.table("transactions")
        .select("*")
        .eq("user_id", user_id)
        .gte("transaction_date", start.isoformat())
        .order("transaction_date", desc=True)
        .limit(250)
        .execute()
    )
    transactions = response.data or []
    profile_response = (
        supabase.table("profiles")
        .select("currency")
        .eq("id", user_id)
        .limit(1)
        .execute()
    )
    profile_rows = profile_response.data or []
    currency = (
        str(profile_rows[0].get("currency") or "JMD").upper()
        if profile_rows
        else "JMD"
    )
    payload = _overview_payload(transactions, currency)

    try:
        llm = await generate_daily_overview(payload)
    except Exception as gemini_error:
        logger.warning("Daily overview Gemini Flash failed, trying Gemma: %s", gemini_error)
        try:
            llm = await generate_daily_overview_gemma(payload)
        except Exception as gemma_error:
            logger.warning(
                "Daily overview Gemma failed, using deterministic overview: %s",
                gemma_error,
            )
            llm = None

    if llm:
        summary = str(llm.get("summary") or payload["summary"])
        insights = _string_list(llm.get("insights")) or payload["insights"]
        suggestions = _string_list(llm.get("suggestions")) or payload["suggestions"]
        raw = {
            "summary": summary,
            "insights": insights,
            "suggestions": suggestions,
        }
    else:
        summary = payload["summary"]
        insights = payload["insights"]
        suggestions = payload["suggestions"]
        raw = None

    return DailyOverviewResponse(
        success=True,
        generated_for=date.today().isoformat(),
        summary=summary,
        insights=insights,
        suggestions=suggestions,
        totals=payload["totals"],
        raw_llm_response=raw,
    )


def _overview_payload(transactions: list[dict[str, Any]], currency: str) -> dict[str, Any]:
    totals = defaultdict(float)
    category_totals = defaultdict(float)
    transfers = 0
    card_routed = 0

    compact = []
    for tx in transactions:
        tx_type = tx.get("transaction_type") or "expense"
        amount = float(tx.get("amount") or 0)
        totals[tx_type] += amount
        if tx_type == "expense":
            category_totals[tx.get("category") or "Other"] += amount
        if tx_type in {"transfer", "withdrawal", "deposit"}:
            transfers += 1
        if tx.get("card_last4"):
            card_routed += 1
        compact.append(
            {
                "date": tx.get("transaction_date"),
                "type": tx_type,
                "amount": amount,
                "category": tx.get("category"),
                "merchant": tx.get("merchant"),
                "description": tx.get("description"),
                "card_last4": tx.get("card_last4"),
                "fee_amount": tx.get("fee_amount"),
            }
        )

    income = totals["income"] + totals["refund"]
    spent = totals["expense"]
    net = income - spent
    top_category = max(category_totals.items(), key=lambda item: item[1], default=("None", 0))

    insights = []
    if transactions:
        insights.append(f"Your recorded net for this period is {currency} {net:,.0f}.")
        if top_category[1] > 0:
            insights.append(f"{top_category[0]} is the largest spending category.")
        if transfers:
            insights.append(f"{transfers} recent entries are transfers, deposits, or withdrawals.")
        if card_routed:
            insights.append(f"{card_routed} receipts included card digits for account routing.")
    else:
        insights.append("No recent transactions were available for analysis.")

    suggestions = [
        "Link card last-4 digits for accounts you use often.",
        "Use transfers for ATM withdrawals and deposits so balances stay accurate.",
    ]
    if spent > income and income > 0:
        suggestions.append("Review flexible spending because outflows are above recorded inflows.")
    elif top_category[1] > 0:
        suggestions.append(f"Set or review the budget for {top_category[0]}.")

    return {
        "transactions": compact,
        "currency": currency,
        "totals": {
            "income": income,
            "expense": spent,
            "transfer": totals["transfer"],
            "withdrawal": totals["withdrawal"],
            "deposit": totals["deposit"],
            "refund": totals["refund"],
            "net": net,
        },
        "summary": (
            f"Recent net is {currency} {net:,.0f}, with {currency} {income:,.0f} "
            f"in inflows and {currency} {spent:,.0f} in expenses."
        ),
        "insights": insights,
        "suggestions": suggestions,
    }


def _string_list(value: Any) -> list[str]:
    if not isinstance(value, list):
        return []
    return [str(item).strip() for item in value if str(item).strip()]
