"""Receipt feedback and lightweight learning helpers.

This module stores parse outcomes and turns confirmed user saves into
per-user merchant memory. It is intentionally database-backed and auditable
instead of attempting unsafe live model retraining inside the request path.
"""

from __future__ import annotations

from datetime import datetime, timezone
import re
from typing import Any, Mapping


CORRECTION_FIELDS = (
    "merchant",
    "amount",
    "currency",
    "category",
    "transaction_type",
    "date",
    "transaction_date",
    "account_id",
    "destination_account_id",
    "card_last4",
    "original_amount",
    "original_currency",
    "exchange_rate",
)


def apply_receipt_memory(
    supabase: Any,
    user_id: str,
    result: Mapping[str, Any],
) -> dict[str, Any]:
    """Apply confirmed merchant memory to a fresh parse result."""
    learned = dict(result)
    merchant = _clean_string(learned.get("merchant"))
    merchant_key = normalize_merchant_key(merchant)
    if not merchant_key:
        return learned

    memory = _fetch_merchant_memory(supabase, user_id, merchant_key)
    if not memory:
        return learned

    preferred_category = _clean_string(memory.get("preferred_category"))
    if preferred_category and (
        not _clean_string(learned.get("category"))
        or str(learned.get("category")).lower() == "other"
        or _coerce_float(learned.get("confidence")) < 0.95
    ):
        learned["category"] = preferred_category

    preferred_type = _clean_string(memory.get("preferred_transaction_type"))
    if preferred_type and _coerce_float(learned.get("confidence")) < 0.95:
        learned["transaction_type"] = preferred_type

    preferred_currency = _clean_string(memory.get("preferred_currency"))
    if preferred_currency and not _clean_string(learned.get("currency")):
        learned["currency"] = preferred_currency

    preferred_account_id = _clean_string(memory.get("preferred_account_id"))
    if preferred_account_id:
        learned["suggested_account_id"] = preferred_account_id

    preferred_destination_account_id = _clean_string(memory.get("preferred_destination_account_id"))
    if preferred_destination_account_id:
        learned["suggested_destination_account_id"] = preferred_destination_account_id

    confidence = _coerce_float(learned.get("confidence"))
    if confidence is not None:
        learned["confidence"] = min(0.94, confidence + 0.04)

    learned["receipt_memory_applied"] = True
    return learned


def record_parse_event(
    supabase: Any,
    *,
    user_id: str,
    input_method: str,
    ocr_text: str | None,
    receipt_url: str | None,
    receipt_path: str | None,
    parser_candidates: Mapping[str, Any],
    parsed_payload: Mapping[str, Any],
    raw_llm_response: Mapping[str, Any] | None,
) -> str | None:
    """Persist a parse attempt. Fail closed so parsing still works pre-migration."""
    data = {
        "user_id": user_id,
        "input_method": input_method,
        "ocr_text": ocr_text,
        "receipt_image_url": receipt_url,
        "receipt_image_path": receipt_path,
        "parser_candidates": dict(parser_candidates),
        "parsed_payload": dict(parsed_payload),
        "raw_llm_response": dict(raw_llm_response or {}),
        "model_source": _clean_string(parsed_payload.get("source")) or "llm",
        "confidence": _coerce_float(parsed_payload.get("confidence")),
        "status": "parsed",
    }
    try:
        response = supabase.table("receipt_parse_events").insert(data).execute()
        rows = getattr(response, "data", None) or []
        if rows:
            return rows[0].get("id")
    except Exception:
        return None
    return None


def record_feedback(
    supabase: Any,
    *,
    user_id: str,
    parse_session_id: str | None,
    outcome: str,
    final_transaction_id: str | None,
    final_payload: Mapping[str, Any] | None,
    cancel_reason: str | None,
) -> dict[str, Any]:
    """Record save/correct/cancel feedback and update merchant memory."""
    initial_payload: Mapping[str, Any] = {}
    event = _fetch_parse_event(supabase, user_id, parse_session_id)
    if event:
        initial_payload = event.get("parsed_payload") or {}

    final_payload_dict = dict(final_payload or {})
    corrections = summarize_corrections(initial_payload, final_payload_dict)
    status = _feedback_status(outcome, corrections, final_payload_dict)
    update_data = {
        "status": status,
        "final_transaction_id": final_transaction_id,
        "final_payload": final_payload_dict or None,
        "correction_summary": corrections,
        "cancel_reason": cancel_reason,
        "updated_at": _utcnow_iso(),
    }

    if event:
        supabase.table("receipt_parse_events").update(update_data).eq("id", event["id"]).execute()
    else:
        insert_data = {
            "user_id": user_id,
            "input_method": _clean_string(final_payload_dict.get("input_method")) or "receipt",
            "parser_candidates": {},
            "parsed_payload": {},
            **update_data,
        }
        supabase.table("receipt_parse_events").insert(insert_data).execute()

    if status in {"saved", "corrected"} and final_payload_dict:
        update_merchant_memory(supabase, user_id, final_payload_dict, corrected=bool(corrections))

    return {
        "success": True,
        "status": status,
        "correction_summary": corrections,
    }


def update_merchant_memory(
    supabase: Any,
    user_id: str,
    final_payload: Mapping[str, Any],
    *,
    corrected: bool,
) -> None:
    merchant = _clean_string(final_payload.get("merchant"))
    merchant_key = normalize_merchant_key(merchant)
    if not merchant_key:
        return

    existing = _fetch_merchant_memory(supabase, user_id, merchant_key)
    usage_count = int(existing.get("usage_count", 0)) + 1 if existing else 1
    corrected_count = int(existing.get("corrected_count", 0)) + (1 if corrected else 0) if existing else (1 if corrected else 0)
    confirmed_count = int(existing.get("confirmed_count", 0)) + 1 if existing else 1
    data = {
        "user_id": user_id,
        "merchant_key": merchant_key,
        "merchant_display": merchant,
        "preferred_category": _clean_string(final_payload.get("category")),
        "preferred_transaction_type": _clean_string(final_payload.get("transaction_type")),
        "preferred_currency": _clean_string(final_payload.get("currency")),
        "preferred_account_id": _clean_string(final_payload.get("account_id")),
        "preferred_destination_account_id": _clean_string(
            final_payload.get("destination_account_id")
        ),
        "last_card_last4": _clean_string(final_payload.get("card_last4")),
        "usage_count": usage_count,
        "confirmed_count": confirmed_count,
        "corrected_count": corrected_count,
        "last_seen_at": _utcnow_iso(),
        "updated_at": _utcnow_iso(),
    }

    if existing:
        supabase.table("receipt_merchant_memory").update(data).eq("id", existing["id"]).execute()
    else:
        supabase.table("receipt_merchant_memory").insert(data).execute()


def summarize_corrections(
    initial_payload: Mapping[str, Any],
    final_payload: Mapping[str, Any],
) -> dict[str, dict[str, Any]]:
    corrections: dict[str, dict[str, Any]] = {}
    for field in CORRECTION_FIELDS:
        before = _comparable(initial_payload.get(field))
        after = _comparable(final_payload.get(field))
        if before == after:
            continue
        if before in {None, ""} and after in {None, ""}:
            continue
        corrections[field] = {
            "from": initial_payload.get(field),
            "to": final_payload.get(field),
        }
    return corrections


def normalize_merchant_key(value: str | None) -> str | None:
    cleaned = _clean_string(value)
    if not cleaned:
        return None
    cleaned = cleaned.lower()
    cleaned = re.sub(r"\b(ltd|limited|inc|llc|co|company)\b\.?", "", cleaned)
    cleaned = re.sub(r"[^a-z0-9]+", " ", cleaned)
    cleaned = re.sub(r"\s+", " ", cleaned).strip()
    return cleaned or None


def _fetch_parse_event(
    supabase: Any,
    user_id: str,
    parse_session_id: str | None,
) -> dict[str, Any] | None:
    if not parse_session_id:
        return None
    response = (
        supabase.table("receipt_parse_events")
        .select("*")
        .eq("id", parse_session_id)
        .eq("user_id", user_id)
        .limit(1)
        .execute()
    )
    rows = getattr(response, "data", None) or []
    return rows[0] if rows else None


def _fetch_merchant_memory(
    supabase: Any,
    user_id: str,
    merchant_key: str | None,
) -> dict[str, Any] | None:
    if not merchant_key:
        return None
    try:
        response = (
            supabase.table("receipt_merchant_memory")
            .select("*")
            .eq("user_id", user_id)
            .eq("merchant_key", merchant_key)
            .limit(1)
            .execute()
        )
    except Exception:
        return None
    rows = getattr(response, "data", None) or []
    return rows[0] if rows else None


def _feedback_status(
    outcome: str,
    corrections: Mapping[str, Any],
    final_payload: Mapping[str, Any],
) -> str:
    normalized = (outcome or "").strip().lower()
    if normalized == "cancelled":
        return "cancelled"
    if final_payload and corrections:
        return "corrected"
    if normalized in {"saved", "accepted", "confirmed"}:
        return "saved"
    return "parsed"


def _comparable(value: Any) -> Any:
    if value is None:
        return None
    if isinstance(value, float):
        return round(value, 2)
    if isinstance(value, int):
        return float(value)
    text = str(value).strip()
    numeric = _coerce_float(text)
    if numeric is not None and re.fullmatch(r"[-+]?[\d,.]+(?:\.\d+)?", text):
        return round(numeric, 2)
    return text.lower()


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
    match = re.search(r"-?\d+(?:\.\d+)?", text)
    if not match:
        return None
    try:
        return float(match.group(0))
    except ValueError:
        return None


def _utcnow_iso() -> str:
    return datetime.now(timezone.utc).isoformat()
