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
    movement = _detect_transaction_type(full_text)
    card_last4 = _detect_card_last4(full_text)
    fee_amount = _detect_fee_amount(lines)
    category_guess = _guess_category(
        " ".join(candidate.value for candidate in merchant_candidates[:2]),
        full_text,
    )

    best_amount = amount_candidates[0].amount if amount_candidates else None
    best_merchant = merchant_candidates[0].value if merchant_candidates else None
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
            "category": "Other" if movement != "expense" else category_guess,
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
        for raw_date in _date_strings(line):
            parsed = _parse_date_string(raw_date)
            if not parsed:
                continue

            score = 5.0
            if any(keyword in line.lower() for keyword in ("date", "trans", "purchase")):
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
        if any(keyword in lowered for keyword in TOTAL_KEYWORDS + NON_FINAL_AMOUNT_KEYWORDS):
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


def _merchant_line(line: str) -> str | None:
    lowered = line.lower()
    if len(line) < 2 or len(line) > 70:
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
    lowered = text.lower()
    if "usd" in lowered or "us$" in lowered:
        return "USD"
    return "JMD"


def _detect_transaction_type(text: str) -> str:
    lowered = text.lower()
    if any(keyword in lowered for keyword in ("withdrawal", "wdl", "cash withdrawal", "atm w/d")):
        return "withdrawal"
    if any(keyword in lowered for keyword in ("deposit", "cash deposit", "atm dep")):
        return "deposit"
    if any(keyword in lowered for keyword in ("refund", "reversal", "return")):
        return "refund"
    if any(keyword in lowered for keyword in ("salary", "payroll", "income")):
        return "income"
    if any(keyword in lowered for keyword in ("transfer", "xfer")):
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
