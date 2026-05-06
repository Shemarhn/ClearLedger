"""Utilities for turning LLM text into the JSON object the app expects."""

from __future__ import annotations

import json
import re
from collections.abc import Mapping
from typing import Any

EXPECTED_TRANSACTION_KEYS = {
    "merchant",
    "amount",
    "currency",
    "date",
    "category",
    "description",
    "line_items",
    "confidence",
}

WRAPPER_KEYS = ("transaction", "parsed_transaction", "data", "result")


def parse_llm_json_object(response: str | Mapping[str, Any], provider_name: str) -> dict:
    """Parse a JSON object from a model response that may include light wrapping."""
    if isinstance(response, Mapping):
        return _unwrap_transaction_object(dict(response))

    if not response or not response.strip():
        raise ValueError(f"{provider_name} returned an empty response.")

    cleaned = _strip_code_fence(response.strip())
    last_error: Exception | None = None

    for candidate in _json_candidates(cleaned):
        try:
            parsed = json.loads(candidate)
        except json.JSONDecodeError as error:
            last_error = error
            continue

        return _unwrap_transaction_object(_require_object(parsed, provider_name))

    error_text = f" Error: {last_error}" if last_error else ""
    raise ValueError(
        f"{provider_name} returned invalid JSON. Raw response: "
        f"{response[:500]}.{error_text}"
    )


def _strip_code_fence(text: str) -> str:
    match = re.fullmatch(r"```(?:json)?\s*(.*?)\s*```", text, re.IGNORECASE | re.DOTALL)
    if match:
        return match.group(1).strip()
    return text


def _json_candidates(text: str) -> list[str]:
    candidates = [text]
    candidates.extend(_extract_balanced_json_values(text))
    return candidates


def _extract_balanced_json_values(text: str) -> list[str]:
    values: list[str] = []
    for start, character in enumerate(text):
        if character not in "{[":
            continue

        end = _find_matching_json_end(text, start)
        if end is not None:
            values.append(text[start : end + 1])
    return values


def _find_matching_json_end(text: str, start: int) -> int | None:
    stack: list[str] = []
    in_string = False
    escaped = False

    for index in range(start, len(text)):
        character = text[index]

        if in_string:
            if escaped:
                escaped = False
            elif character == "\\":
                escaped = True
            elif character == '"':
                in_string = False
            continue

        if character == '"':
            in_string = True
        elif character in "{[":
            stack.append(character)
        elif character in "}]":
            if not stack:
                return None
            opening = stack.pop()
            if (opening, character) not in (("{", "}"), ("[", "]")):
                return None
            if not stack:
                return index

    return None


def _require_object(parsed: Any, provider_name: str) -> dict:
    if isinstance(parsed, Mapping):
        return dict(parsed)

    if isinstance(parsed, list) and parsed and isinstance(parsed[0], Mapping):
        return dict(parsed[0])

    raise ValueError(f"{provider_name} returned JSON, but not a transaction object.")


def _unwrap_transaction_object(parsed: dict) -> dict:
    if EXPECTED_TRANSACTION_KEYS.intersection(parsed.keys()):
        return parsed

    for key in WRAPPER_KEYS:
        nested = parsed.get(key)
        if isinstance(nested, Mapping):
            return dict(nested)

    return parsed
