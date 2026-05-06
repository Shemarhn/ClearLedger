"""Normalize LLM output before it reaches Pydantic response models."""

from __future__ import annotations

import re
from collections.abc import Mapping
from typing import Any

ALLOWED_CATEGORIES = {
    "Food",
    "Transport",
    "Utilities",
    "Entertainment",
    "Healthcare",
    "Shopping",
    "Education",
    "Other",
}


def normalize_parsed_transaction(result: Mapping[str, Any], include_line_items: bool) -> dict:
    return {
        "merchant": _clean_string(result.get("merchant")),
        "amount": _coerce_float(result.get("amount")),
        "currency": _coerce_currency(result.get("currency")),
        "date": _clean_string(result.get("date")),
        "category": _coerce_category(result.get("category")),
        "description": _clean_string(result.get("description")),
        "line_items": _coerce_line_items(result.get("line_items")) if include_line_items else [],
        "confidence": _coerce_confidence(result.get("confidence")),
    }


def sanitized_llm_payload(normalized: Mapping[str, Any]) -> dict:
    """Keep only fields the app uses instead of storing arbitrary provider output."""
    payload = {
        "merchant": normalized.get("merchant"),
        "amount": normalized.get("amount"),
        "currency": normalized.get("currency"),
        "date": normalized.get("date"),
        "category": normalized.get("category"),
        "description": normalized.get("description"),
        "line_items": normalized.get("line_items") or [],
        "confidence": normalized.get("confidence"),
    }

    return {key: value for key, value in payload.items() if value is not None}


def _clean_string(value: Any) -> str | None:
    if value is None:
        return None

    cleaned = str(value).strip()
    if not cleaned or cleaned.lower() in {"null", "none", "unknown", "n/a"}:
        return None
    return cleaned


def _coerce_currency(value: Any) -> str:
    cleaned = _clean_string(value)
    if cleaned is None:
        return "JMD"

    match = re.search(r"\b[A-Za-z]{3}\b", cleaned)
    if not match:
        return "JMD"

    return match.group(0).upper()


def _coerce_category(value: Any) -> str:
    cleaned = _clean_string(value)
    if cleaned is None:
        return "Other"

    for category in ALLOWED_CATEGORIES:
        if cleaned.lower() == category.lower():
            return category

    return "Other"


def _coerce_line_items(value: Any) -> list[dict]:
    if not isinstance(value, list):
        return []

    items: list[dict] = []
    for item in value:
        if not isinstance(item, Mapping):
            continue

        name = _clean_string(item.get("name") or item.get("description") or item.get("item"))
        price = _coerce_float(item.get("price") or item.get("amount") or item.get("total"))

        if name is None and price is None:
            continue

        items.append({"name": name or "Item", "price": price or 0.0})

    return items


def _coerce_confidence(value: Any) -> float:
    confidence = _coerce_float(value)
    if confidence is None:
        return 0.0

    if confidence > 1:
        confidence = confidence / 100

    return min(1.0, max(0.0, confidence))


def _coerce_float(value: Any) -> float | None:
    if value is None:
        return None

    if isinstance(value, bool):
        return None

    if isinstance(value, (int, float)):
        return float(value)

    text = str(value).strip()
    if not text:
        return None

    match = re.search(r"-?\d+(?:,\d{3})*(?:\.\d+)?|-?\d+(?:\.\d+)?", text)
    if not match:
        return None

    try:
        return float(match.group(0).replace(",", ""))
    except ValueError:
        return None
