"""Deterministic receipt OCR parsing helpers.

These helpers do the boring work before an LLM sees receipt text: preserve line
order, find likely totals, dates, merchants, and line items, and provide a local
fallback when providers are unavailable.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime
import re
from typing import Any


MAX_OCR_TEXT_CHARS = 12000
MAX_CANDIDATES = 8

TOTAL_KEYWORDS = (
    "total",
    "grand total",
    "amount due",
    "balance due",
    "total due",
    "amount paid",
    "sale total",
    "net total",
)
NON_FINAL_AMOUNT_KEYWORDS = (
    "subtotal",
    "sub total",
    "item(s) subtotal",
    "total before tax",
    "tax",
    "gct",
    "vat",
    "change",
    "cash tender",
    "tendered",
    "discount",
    "savings",
    "points",
    "cashback",
    "balance forward",
    "shipping",
    "handling",
    "exchange rate",
    "guarantee fee",
)
MERCHANT_SKIP_KEYWORDS = (
    "receipt",
    "invoice",
    "cashier",
    "customer",
    "terminal",
    "approval",
    "auth",
    "card",
    "visa",
    "mastercard",
    "subtotal",
    "total",
    "tax",
    "change",
    "paid",
    "tel",
    "phone",
    "email",
    "www",
    "http",
    "search or ask",
    "product support",
    "buy it again",
    "track package",
    "return or replace",
    "product question",
    "product review",
    "view your item",
    "view invoice",
    "view related",
    "order summary",
    "order placed",
    "order #",
    "payment method",
    "ship to",
    "exchange rate",
)

RECEIPT_CHROME_KEYWORDS = (
    "search or ask",
    "product support",
    "buy it again",
    "track package",
    "return or replace",
    "ask product question",
    "product question",
    "write a product review",
    "product review",
    "view your item",
    "view invoice",
    "view related transactions",
)

METADATA_AMOUNT_KEYWORDS = (
    "order #",
    "order number",
    "order placed",
    "payment method",
    "mastercard ending",
    "visa ending",
    "card ending",
    "ship to",
    "sold by",
    "exchange rate",
)

CATEGORY_MERCHANT_KEYWORDS = {
    "Food": (
        "restaurant",
        "cafe",
        "coffee",
        "burger",
        "kfc",
        "starbucks",
        "island grill",
        "food",
        "jerk",
        "pizza",
        "bakery",
        "supermarket",
        "grocery",
        "market",
    ),
    "Transport": (
        "gas",
        "fuel",
        "petrol",
        "shell",
        "texaco",
        "totalenergies",
        "rubis",
        "uber",
        "taxi",
        "parking",
    ),
    "Utilities": (
        "jps",
        "nwc",
        "digicel",
        "flow",
        "internet",
        "utility",
        "electric",
        "water",
        "bill",
    ),
    "Entertainment": (
        "cinema",
        "movie",
        "theatre",
        "netflix",
        "spotify",
        "game",
        "concert",
    ),
    "Healthcare": (
        "pharmacy",
        "fontana",
        "doctor",
        "hospital",
        "clinic",
        "medical",
        "medicine",
        "health",
    ),
    "Shopping": (
        "amazon",
        "order summary",
        "sold by",
        "store",
        "shop",
        "mall",
        "hardware",
        "clothing",
        "pharmacy",
        "wholesale",
    ),
    "Education": (
        "school",
        "book",
        "tuition",
        "college",
        "university",
        "course",
    ),
}


@dataclass(frozen=True)
class AmountCandidate:
    amount: float
    line: str
    line_number: int
    score: float
    label: str


@dataclass(frozen=True)
class TextCandidate:
    value: str
    line: str
    line_number: int
    score: float


def prepare_receipt_ocr_text(ocr_text: str) -> str:
    """Normalize OCR text enough for parsing while preserving line order."""
    text = (ocr_text or "").replace("\r\n", "\n").replace("\r", "\n")
    text = text.replace("\u00a0", " ")
    lines = [_normalize_line(line) for line in text.split("\n")]
    cleaned = "\n".join(line for line in lines if line)
    return cleaned[:MAX_OCR_TEXT_CHARS]


def extract_receipt_candidates(ocr_text: str) -> dict[str, Any]:
    lines = _receipt_lines(ocr_text)
    full_text = "\n".join(lines)
    amount_candidates = _amount_candidates(lines)
    merchant_candidates = _merchant_candidates(lines)
    date_candidates = _date_candidates(lines)
    line_item_candidates = _line_item_candidates(lines)
    currency = _detect_currency(full_text)
    movement = _detect_transaction_type(lines)
    card_last4 = _detect_card_last4(full_text)
    fee_amount = _detect_fee_amount(lines)
    category_guess = _guess_category(
        " ".join(candidate.value for candidate in merchant_candidates[:2]),
        full_text,
    )

    best_amount = _best_receipt_amount(amount_candidates, line_item_candidates)
    best_merchant = merchant_candidates[0].value if merchant_candidates else None
    marketplace_merchant = _marketplace_merchant(full_text)
    if marketplace_merchant:
        best_merchant = marketplace_merchant
    best_date = date_candidates[0].value if date_candidates else None

    return {
        "merchant_candidates": [
            _text_candidate_dict(candidate) for candidate in merchant_candidates[:MAX_CANDIDATES]
        ],
        "amount_candidates": [
            _amount_candidate_dict(candidate) for candidate in amount_candidates[:MAX_CANDIDATES]
        ],
        "date_candidates": [
            _text_candidate_dict(candidate) for candidate in date_candidates[:MAX_CANDIDATES]
        ],
        "line_item_candidates": line_item_candidates[:20],
        "currency_guess": currency,
        "category_guess": category_guess,
        "best_guess": {
            "merchant": best_merchant,
            "amount": best_amount,
            "currency": currency,
            "date": best_date,
            "category": category_guess,
            "line_items": line_item_candidates[:12],
            "transaction_type": movement,
            "card_last4": card_last4,
            "fee_amount": fee_amount,
            "account_hint": "card account" if card_last4 else None,
            "destination_account_hint": _destination_hint_for_movement(movement),
        },
    }


def parse_receipt_text_basic(
    ocr_text: str,
    candidates: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Produce a usable receipt parse without an external LLM."""
    prepared_text = prepare_receipt_ocr_text(ocr_text)
    if not prepared_text:
        raise ValueError("No readable receipt text was found.")

    candidates = candidates or extract_receipt_candidates(prepared_text)
    best_guess = candidates.get("best_guess", {})
    merchant = best_guess.get("merchant")
    amount = best_guess.get("amount")
    category = best_guess.get("category") or "Other"
    line_items = best_guess.get("line_items") or []

    confidence = 0.25
    if merchant:
        confidence += 0.15
    if amount is not None:
        confidence += 0.3
    if best_guess.get("date"):
        confidence += 0.1
    if category != "Other":
        confidence += 0.1
    if line_items:
        confidence += 0.05

    description = "Receipt transaction"
    if merchant:
        description = f"Receipt transaction at {merchant}"

    return {
        "merchant": merchant,
        "amount": amount,
        "transaction_type": best_guess.get("transaction_type") or "expense",
        "currency": best_guess.get("currency") or candidates.get("currency_guess") or "JMD",
        "date": best_guess.get("date"),
        "category": category,
        "description": description,
        "line_items": line_items,
        "confidence": min(confidence, 0.85),
        "account_hint": best_guess.get("account_hint"),
        "destination_account_hint": best_guess.get("destination_account_hint"),
        "card_last4": best_guess.get("card_last4"),
        "fee_amount": best_guess.get("fee_amount"),
        "source": "receipt_text_rules",
    }


def reconcile_receipt_result(
    result: dict[str, Any],
    candidates: dict[str, Any],
) -> dict[str, Any]:
    """
    Keep LLM output anchored to OCR-derived candidates.

    The model may categorize and clean names, but final totals should come from
    the OCR candidate set unless the model's amount is very close to one.
    """
    reconciled = dict(result)
    best_guess = candidates.get("best_guess", {})

    candidate_amounts = [
        candidate.get("amount")
        for candidate in candidates.get("amount_candidates", [])
        if isinstance(candidate.get("amount"), (int, float))
    ]
    model_amount = _coerce_float(reconciled.get("amount"))
    if model_amount is not None and candidate_amounts:
        closest = min(candidate_amounts, key=lambda amount: abs(amount - model_amount))
        if abs(closest - model_amount) <= max(0.05, closest * 0.01):
            reconciled["amount"] = closest
        elif best_guess.get("amount") is not None:
            reconciled["amount"] = best_guess["amount"]
            reconciled["confidence"] = min(_coerce_float(reconciled.get("confidence")) or 0.5, 0.65)
    elif best_guess.get("amount") is not None:
        reconciled["amount"] = best_guess["amount"]

    best_amount = _coerce_float(best_guess.get("amount"))
    line_total = _line_items_total(best_guess.get("line_items") or [])
    current_amount = _coerce_float(reconciled.get("amount"))
    if (
        best_amount is not None
        and line_total is not None
        and abs(best_amount - line_total) <= 0.01
        and (current_amount is None or current_amount < line_total - 0.01)
    ):
        reconciled["amount"] = best_amount
        reconciled["confidence"] = min(_coerce_float(reconciled.get("confidence")) or 0.5, 0.7)

    if not _clean_string(reconciled.get("merchant")) and best_guess.get("merchant"):
        reconciled["merchant"] = best_guess["merchant"]
    if not _clean_string(reconciled.get("date")) and best_guess.get("date"):
        reconciled["date"] = best_guess["date"]
    if not _clean_string(reconciled.get("currency")):
        reconciled["currency"] = best_guess.get("currency") or candidates.get("currency_guess") or "JMD"
    if not _clean_string(reconciled.get("transaction_type")):
        reconciled["transaction_type"] = best_guess.get("transaction_type") or "expense"
    if not _clean_string(reconciled.get("category")) or str(reconciled.get("category")).lower() == "other":
        reconciled["category"] = best_guess.get("category") or candidates.get("category_guess") or "Other"
    if not reconciled.get("line_items") and best_guess.get("line_items"):
        reconciled["line_items"] = best_guess["line_items"]

    if not _clean_string(reconciled.get("description")):
        merchant = _clean_string(reconciled.get("merchant"))
        reconciled["description"] = (
            f"Receipt transaction at {merchant}" if merchant else "Receipt transaction"
        )
    if not _clean_string(reconciled.get("card_last4")) and best_guess.get("card_last4"):
        reconciled["card_last4"] = best_guess["card_last4"]
    if not _clean_string(reconciled.get("account_hint")) and best_guess.get("account_hint"):
        reconciled["account_hint"] = best_guess["account_hint"]
    if (
        not _clean_string(reconciled.get("destination_account_hint"))
        and best_guess.get("destination_account_hint")
    ):
        reconciled["destination_account_hint"] = best_guess["destination_account_hint"]
    if _coerce_float(reconciled.get("fee_amount")) is None and best_guess.get("fee_amount"):
        reconciled["fee_amount"] = best_guess["fee_amount"]

    return reconciled


def receipt_prompt_payload(ocr_text: str, candidates: dict[str, Any]) -> dict[str, Any]:
    """Compact payload for LLM prompts."""
    return {
        "ocr_text": prepare_receipt_ocr_text(ocr_text),
        "parser_candidates": candidates,
    }


def _receipt_lines(ocr_text: str) -> list[str]:
    prepared = prepare_receipt_ocr_text(ocr_text)
    return [line for line in prepared.split("\n") if line]


def _normalize_line(line: str) -> str:
    line = re.sub(r"[|]+", " ", line)
    line = re.sub(r"\s+", " ", line)
    return line.strip()


def _amount_candidates(lines: list[str]) -> list[AmountCandidate]:
    candidates: list[AmountCandidate] = []
    total_lines = max(len(lines), 1)

    for index, line in enumerate(lines):
        lowered = line.lower()
        has_total_keyword = any(keyword in lowered for keyword in TOTAL_KEYWORDS)
        if _is_receipt_chrome_line(line):
            continue
        if _is_metadata_amount_line(line) and not has_total_keyword:
            continue
        if _date_strings(line) and not has_total_keyword:
            continue

        amounts = _extract_amounts(line)
        if not amounts:
            continue

        for amount in amounts:
            score = 0.0
            label = "amount"
            if any(keyword in lowered for keyword in TOTAL_KEYWORDS):
                score += 8
                label = "total"
            if re.search(r"\btotal\b", lowered):
                score += 4
                label = "total"
            if any(keyword in lowered for keyword in ("amount due", "balance due", "grand total")):
                score += 4
                label = "final_total"
            if any(keyword in lowered for keyword in NON_FINAL_AMOUNT_KEYWORDS):
                score -= 8
                label = "non_final"
            if "change" in lowered:
                score -= 8
            if "cash" in lowered and "tender" in lowered:
                score -= 6
            if "card" in lowered or "credit" in lowered or "debit" in lowered:
                score += 1
            if index / total_lines > 0.45:
                score += 1.5
            if amount <= 0:
                score -= 10

            candidates.append(
                AmountCandidate(
                    amount=amount,
                    line=line,
                    line_number=index + 1,
                    score=score,
                    label=label,
                )
            )

    return sorted(candidates, key=lambda candidate: (candidate.score, candidate.amount), reverse=True)


def _merchant_candidates(lines: list[str]) -> list[TextCandidate]:
    candidates: list[TextCandidate] = []
    for index, line in enumerate(lines[:12]):
        cleaned = _merchant_line(line)
        if not cleaned:
            continue

        score = 10 - index
        if cleaned.isupper():
            score += 1.5
        if any(keyword in cleaned.lower() for keyword in ("ltd", "limited", "restaurant", "pharmacy")):
            score += 1

        candidates.append(
            TextCandidate(
                value=_title_if_shouting(cleaned),
                line=line,
                line_number=index + 1,
                score=score,
            )
        )

    return sorted(candidates, key=lambda candidate: candidate.score, reverse=True)


def _date_candidates(lines: list[str]) -> list[TextCandidate]:
    candidates: list[TextCandidate] = []
    for index, line in enumerate(lines):
        if _is_receipt_chrome_line(line):
            continue
        for raw_date in _date_strings(line):
            parsed = _parse_date_string(raw_date)
            if not parsed:
                continue

            score = 5.0
            if any(keyword in line.lower() for keyword in ("date", "trans", "purchase", "order placed")):
                score += 1
            candidates.append(
                TextCandidate(
                    value=parsed.isoformat(),
                    line=line,
                    line_number=index + 1,
                    score=score,
                )
            )

    return sorted(candidates, key=lambda candidate: candidate.score, reverse=True)


def _line_item_candidates(lines: list[str]) -> list[dict[str, Any]]:
    items: list[dict[str, Any]] = []
    for index, line in enumerate(lines):
        lowered = line.lower()
        if _is_receipt_chrome_line(line) or _is_metadata_amount_line(line):
            continue
        if any(keyword in lowered for keyword in TOTAL_KEYWORDS + NON_FINAL_AMOUNT_KEYWORDS):
            continue
        if any(
            keyword in lowered
            for keyword in ("card", "visa", "mastercard", "debit", "credit", "auth", "approval")
        ):
            continue
        if _date_strings(line):
            continue

        amounts = _extract_amounts(line)
        if not amounts:
            continue

        amount = amounts[-1]
        amount_match = list(_money_pattern().finditer(line))
        if not amount_match:
            continue

        name = line[: amount_match[-1].start()].strip(" -:.$")
        if len(name) < 2 or _line_has_noise(name):
            continue

        items.append(
            {
                "name": _title_if_shouting(name[:80]),
                "price": amount,
                "line": line,
                "line_number": index + 1,
            }
        )

    return items


def _best_receipt_amount(
    amount_candidates: list[AmountCandidate],
    line_item_candidates: list[dict[str, Any]],
) -> float | None:
    line_total = _line_items_total(line_item_candidates)
    if not amount_candidates:
        return line_total

    final_totals = [candidate for candidate in amount_candidates if candidate.label == "final_total"]
    if final_totals:
        return final_totals[0].amount

    best = amount_candidates[0]
    if best.label in {"total", "final_total"}:
        return best.amount

    if (
        line_total is not None
        and len(line_item_candidates) >= 2
        and line_total > best.amount + 0.01
    ):
        return line_total

    return best.amount


def _line_items_total(line_items: list[dict[str, Any]]) -> float | None:
    if not line_items:
        return None

    total = 0.0
    counted = 0
    for item in line_items:
        if not isinstance(item, dict):
            continue
        amount = _coerce_float(item.get("price"))
        if amount is None:
            continue
        total += amount
        counted += 1

    if counted == 0:
        return None
    return round(total, 2)


def _merchant_line(line: str) -> str | None:
    lowered = line.lower()
    if len(line) < 2 or len(line) > 70:
        return None
    if _is_receipt_chrome_line(line):
        return None
    if any(keyword in lowered for keyword in MERCHANT_SKIP_KEYWORDS):
        return None
    if _extract_amounts(line) or _date_strings(line):
        return None
    if re.search(r"\d{3}[-.\s]\d{3}[-.\s]\d{4}", line):
        return None
    if re.search(r"\b\d{1,5}\s+\w+\s+(road|rd|street|st|avenue|ave|drive|dr)\b", lowered):
        return None
    if _line_has_noise(line):
        return None
    return line.strip(" -")


def _is_receipt_chrome_line(line: str) -> bool:
    lowered = line.lower()
    return any(keyword in lowered for keyword in RECEIPT_CHROME_KEYWORDS)


def _is_metadata_amount_line(line: str) -> bool:
    lowered = line.lower()
    if any(keyword in lowered for keyword in METADATA_AMOUNT_KEYWORDS):
        return True
    return bool(re.search(r"\b\d+(?:\.\d+)?\s*(?:usd|jmd)\s*=", lowered))


def _marketplace_merchant(text: str) -> str | None:
    lowered = text.lower()
    if "amazon" in lowered:
        return "Amazon"
    amazon_order_signals = (
        "order summary" in lowered
        and "payment method" in lowered
        and ("return or replace items" in lowered or "buy it again" in lowered)
    )
    if amazon_order_signals:
        return "Amazon"
    return None


def _line_has_noise(line: str) -> bool:
    alpha_count = len(re.findall(r"[A-Za-z]", line))
    digit_count = len(re.findall(r"\d", line))
    return alpha_count == 0 or digit_count > alpha_count * 2


def _extract_amounts(line: str) -> list[float]:
    amounts: list[float] = []
    for match in _money_pattern().finditer(line):
        raw = match.group(0)
        amount = _coerce_float(raw)
        if amount is None:
            continue
        if _looks_like_date_or_time(line, raw):
            continue
        amounts.append(amount)
    return amounts


def _money_pattern() -> re.Pattern[str]:
    return re.compile(
        r"(?<![A-Za-z0-9])(?:JMD|USD|US\$|JA\$|\$)?\s*-?"
        r"(?:\d{1,3}(?:,\d{3})+|\d+)(?:\.\d{1,2})?(?![A-Za-z0-9])",
        flags=re.IGNORECASE,
    )


def _looks_like_date_or_time(line: str, raw: str) -> bool:
    stripped = raw.strip()
    if re.fullmatch(r"\d{1,2}:\d{2}(?::\d{2})?", stripped):
        return True
    if re.fullmatch(r"\d{1,4}[/-]\d{1,2}[/-]\d{1,4}", stripped):
        return True
    digits = re.sub(r"\D", "", stripped)
    return len(digits) >= 7 and "." not in stripped and "," not in stripped


def _date_strings(line: str) -> list[str]:
    patterns = (
        r"\b\d{4}[/-]\d{1,2}[/-]\d{1,2}\b",
        r"\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b",
        r"\b(?:jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*"
        r"\s+\d{1,2},?\s+\d{2,4}\b",
        r"\b\d{1,2}\s+(?:jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*"
        r"\s+\d{2,4}\b",
    )
    matches: list[str] = []
    for pattern in patterns:
        matches.extend(re.findall(pattern, line, flags=re.IGNORECASE))
    return matches


def _parse_date_string(raw_date: str) -> date | None:
    raw = raw_date.strip().replace(".", "/")
    formats = (
        "%Y-%m-%d",
        "%Y/%m/%d",
        "%d/%m/%Y",
        "%d-%m-%Y",
        "%m/%d/%Y",
        "%m-%d-%Y",
        "%d/%m/%y",
        "%d-%m-%y",
        "%m/%d/%y",
        "%m-%d-%y",
        "%b %d %Y",
        "%b %d, %Y",
        "%d %b %Y",
        "%B %d %Y",
        "%B %d, %Y",
        "%d %B %Y",
    )

    for fmt in formats:
        try:
            parsed = datetime.strptime(raw, fmt).date()
        except ValueError:
            continue
        if 2000 <= parsed.year <= date.today().year + 1:
            return parsed
    return None


def _detect_currency(text: str) -> str:
    lines = _receipt_lines(text)
    total_currency = _currency_from_total_lines(lines)
    if total_currency:
        return total_currency

    lowered = text.lower()
    if "jmd" in lowered or "ja$" in lowered:
        return "JMD"
    if "usd" in lowered or "us$" in lowered:
        return "USD"
    return "JMD"


def _currency_from_total_lines(lines: list[str]) -> str | None:
    currency_by_priority: list[str] = []
    for line in lines:
        lowered = line.lower()
        if _is_metadata_amount_line(line) and "grand total" not in lowered:
            continue
        if not any(keyword in lowered for keyword in TOTAL_KEYWORDS):
            continue

        currencies = _currencies_in_line(line)
        if not currencies:
            continue
        if "grand total" in lowered or "amount due" in lowered or "balance due" in lowered:
            return currencies[-1]
        if not any(keyword in lowered for keyword in NON_FINAL_AMOUNT_KEYWORDS):
            currency_by_priority.append(currencies[-1])

    return currency_by_priority[-1] if currency_by_priority else None


def _currencies_in_line(line: str) -> list[str]:
    currencies: list[str] = []
    for match in re.finditer(r"\bJMD\b|JA\$|\bUSD\b|US\$|\$", line, flags=re.IGNORECASE):
        token = match.group(0).upper()
        currencies.append("JMD" if token in {"JMD", "JA$"} else "USD")
    return currencies


def _detect_transaction_type(lines: list[str]) -> str:
    """
    Conservative fallback only.

    The LLM is responsible for transaction-type inference. The deterministic
    parser must not turn isolated policy/help words into a movement type. When
    providers are unavailable, default to expense unless the document has a
    bank/ATM shape with source/destination movement evidence.
    """
    compact_text = " ".join(line.lower() for line in lines)
    bank_surface = any(
        marker in compact_text
        for marker in ("atm", "account", "available balance", "ledger balance", "branch")
    )
    cash_surface = "cash" in compact_text
    if bank_surface and cash_surface and any(
        marker in compact_text for marker in ("withdrawal", "cash withdrawal", "atm w/d")
    ):
        return "withdrawal"
    if bank_surface and cash_surface and any(
        marker in compact_text for marker in ("deposit", "cash deposit")
    ):
        return "deposit"
    if bank_surface and any(marker in compact_text for marker in ("from account", "to account")):
        return "transfer"
    return "expense"


def _destination_hint_for_movement(movement: str) -> str | None:
    if movement == "withdrawal":
        return "cash"
    if movement == "deposit":
        return "bank account"
    return None


def _detect_card_last4(text: str) -> str | None:
    patterns = (
        r"(?:card|acct|account|pan|visa|mastercard)[^\n\r\d]{0,12}(?:x+|\*+|#+)?\s*(\d{4})\b",
        r"(?:x{2,}|\*{2,}|#{2,})\s*(\d{4})\b",
    )
    for pattern in patterns:
        match = re.search(pattern, text, flags=re.IGNORECASE)
        if match:
            return match.group(1)
    return None


def _detect_fee_amount(lines: list[str]) -> float | None:
    for line in lines:
        lowered = line.lower()
        if not any(keyword in lowered for keyword in ("fee", "charge", "service")):
            continue
        amounts = _extract_amounts(line)
        if amounts:
            return amounts[-1]
    return None


def _guess_category(merchant_text: str, full_text: str) -> str:
    haystack = f"{merchant_text}\n{full_text}".lower()
    best_category = "Other"
    best_score = 0
    for category, keywords in CATEGORY_MERCHANT_KEYWORDS.items():
        score = sum(1 for keyword in keywords if keyword in haystack)
        if score > best_score:
            best_category = category
            best_score = score
    return best_category


def _amount_candidate_dict(candidate: AmountCandidate) -> dict[str, Any]:
    return {
        "amount": candidate.amount,
        "line": candidate.line,
        "line_number": candidate.line_number,
        "score": round(candidate.score, 2),
        "label": candidate.label,
    }


def _text_candidate_dict(candidate: TextCandidate) -> dict[str, Any]:
    return {
        "value": candidate.value,
        "line": candidate.line,
        "line_number": candidate.line_number,
        "score": round(candidate.score, 2),
    }


def _title_if_shouting(text: str) -> str:
    if text.isupper() and len(text) > 3:
        return text.title()
    return text


def _clean_string(value: Any) -> str | None:
    if value is None:
        return None
    cleaned = str(value).strip()
    return cleaned or None


def _coerce_float(value: Any) -> float | None:
    if value is None or isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        return float(value)

    text = str(value).replace(",", "")
    text = re.sub(r"(?i)\b(?:JMD|USD)\b|US\$|JA\$|\$", "", text)
    match = re.search(r"-?\d+(?:\.\d+)?", text)
    if not match:
        return None
    try:
        return float(match.group(0))
    except ValueError:
        return None
