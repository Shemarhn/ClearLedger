"""Small deterministic parser used when LLM providers are unavailable."""
import re
from datetime import date, timedelta

CATEGORY_KEYWORDS = {
    "Food": ("food", "restaurant", "lunch", "dinner", "breakfast", "coffee", "burger"),
    "Transport": ("taxi", "uber", "bus", "train", "gas", "fuel", "transport"),
    "Utilities": ("utility", "utilities", "electric", "water", "internet", "phone", "bill"),
    "Entertainment": ("movie", "cinema", "game", "concert", "entertainment"),
    "Healthcare": ("doctor", "pharmacy", "medicine", "hospital", "health"),
    "Shopping": ("shop", "shopping", "store", "mall", "clothes", "amazon"),
    "Education": ("school", "book", "tuition", "course", "education"),
}


def _parse_amount(text: str) -> tuple[float, str]:
    amount_match = re.search(
        r"(?:\$|jmd|usd|us\$)?\s*(\d+(?:\.\d{1,2})?)\s*(jmd|usd|dollars?|bucks)?",
        text,
        flags=re.IGNORECASE,
    )
    if not amount_match:
        raise ValueError("No transaction amount found.")

    currency_hint = (amount_match.group(2) or "").lower()
    currency = "USD" if currency_hint == "usd" else "JMD"
    return float(amount_match.group(1)), currency


def _parse_date(text: str) -> str:
    lowered = text.lower()
    today = date.today()
    if "yesterday" in lowered:
        return (today - timedelta(days=1)).isoformat()
    return today.isoformat()


def _parse_category(text: str) -> str:
    lowered = text.lower()
    for category, keywords in CATEGORY_KEYWORDS.items():
        if any(keyword in lowered for keyword in keywords):
            return category
    return "Other"


def _parse_transaction_type(text: str) -> str:
    lowered = text.lower()
    if any(word in lowered for word in ("withdraw", "withdrawal", "atm")):
        return "withdrawal"
    if "deposit" in lowered:
        return "deposit"
    if any(word in lowered for word in ("salary", "payroll", "paid me", "income")):
        return "income"
    if any(word in lowered for word in ("transfer", "moved", "move money")):
        return "transfer"
    if any(word in lowered for word in ("refund", "reversal", "returned")):
        return "refund"
    return "expense"


def _parse_merchant(text: str, category: str) -> str | None:
    match = re.search(
        r"\b(?:at|from|in|on|for)\s+(?:a|an|the)?\s*([A-Za-z][A-Za-z0-9&' -]{1,40})",
        text,
        flags=re.IGNORECASE,
    )
    if match:
        merchant = re.sub(
            r"\b(today|yesterday|last night|this morning|this afternoon)\b.*$",
            "",
            match.group(1),
            flags=re.IGNORECASE,
        ).strip(" .")
        if merchant:
            return merchant.title()

    if category == "Transport" and "taxi" in text.lower():
        return "Taxi"
    return None


def parse_text_description_basic(user_text: str) -> dict:
    """Parse straightforward transaction text without calling an external LLM."""
    amount, currency = _parse_amount(user_text)
    transaction_type = _parse_transaction_type(user_text)
    category = _parse_category(user_text)
    merchant = _parse_merchant(user_text, category)

    return {
        "merchant": merchant,
        "amount": amount,
        "transaction_type": transaction_type,
        "currency": currency,
        "date": _parse_date(user_text),
        "category": "Other" if transaction_type != "expense" else category,
        "description": user_text.strip(),
        "confidence": 0.45,
        "source": "local_fallback",
    }
