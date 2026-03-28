"""
ClearLedger FastAPI - Claude Service
Fallback LLM provider using Anthropic Claude Sonnet.
Used when Gemini is unavailable or returns errors.
"""
import json
import re
from datetime import date

import anthropic
from config import ANTHROPIC_API_KEY

client = anthropic.Anthropic(api_key=ANTHROPIC_API_KEY)

RECEIPT_SYSTEM_PROMPT = """You are a financial data extraction assistant. Extract transaction details from this receipt or transaction screenshot. Return ONLY a valid JSON object with these fields:
- merchant (string): the store or business name
- amount (number): the total amount in the currency shown on the receipt
- currency (string): 3-letter currency code, default to "JMD" if unclear
- date (string): in YYYY-MM-DD format, or null if unclear
- category (string): exactly one of: Food, Transport, Utilities, Entertainment, Healthcare, Shopping, Education, Other
- line_items (array): array of objects with "name" (string) and "price" (number), or empty array if not legible
- confidence (number): 0 to 1 indicating how confident you are in the extraction

Return ONLY the raw JSON object. No explanation, no markdown."""

TEXT_SYSTEM_PROMPT_TEMPLATE = """You are a financial transaction parser. The user will describe a transaction in natural language. Extract the transaction details and return ONLY a valid JSON object with these fields:
- merchant (string): the store or business name, or null if not mentioned
- amount (number): the transaction amount
- currency (string): 3-letter currency code, assume "JMD" if not specified
- date (string): in YYYY-MM-DD format. If the user says "today", use {today}. If they say "yesterday", use the day before {today}. If no date is mentioned, use {today}.
- category (string): exactly one of: Food, Transport, Utilities, Entertainment, Healthcare, Shopping, Education, Other
- description (string): a cleaned one-sentence summary of the transaction
- confidence (number): 0 to 1 indicating how confident you are in the parsing

Return ONLY the raw JSON object. No explanation, no markdown."""


def _clean_json_response(text: str) -> dict:
    """Strip markdown code fences and parse JSON from LLM response."""
    cleaned = text.strip()
    cleaned = re.sub(r"^```(?:json)?\s*", "", cleaned)
    cleaned = re.sub(r"\s*```$", "", cleaned)
    cleaned = cleaned.strip()

    try:
        return json.loads(cleaned)
    except json.JSONDecodeError as e:
        raise ValueError(
            f"Claude returned invalid JSON. Raw response: {text[:500]}. Error: {str(e)}"
        )


async def parse_receipt_image_fallback(
    image_bytes: bytes, mime_type: str = "image/jpeg"
) -> dict:
    """
    Fallback: Send a receipt image to Claude Vision and extract transaction data.
    """
    import base64

    image_b64 = base64.b64encode(image_bytes).decode("utf-8")

    # Map common MIME types
    media_type = mime_type
    if media_type == "image/jpg":
        media_type = "image/jpeg"

    message = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=1024,
        messages=[
            {
                "role": "user",
                "content": [
                    {
                        "type": "image",
                        "source": {
                            "type": "base64",
                            "media_type": media_type,
                            "data": image_b64,
                        },
                    },
                    {
                        "type": "text",
                        "text": RECEIPT_SYSTEM_PROMPT,
                    },
                ],
            }
        ],
    )

    response_text = message.content[0].text
    if not response_text:
        raise ValueError("Claude returned an empty response for the receipt image.")

    return _clean_json_response(response_text)


async def parse_text_description_fallback(user_text: str) -> dict:
    """
    Fallback: Send a natural language transaction description to Claude.
    """
    today = date.today().isoformat()
    system_prompt = TEXT_SYSTEM_PROMPT_TEMPLATE.replace("{today}", today)

    message = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=1024,
        system=system_prompt,
        messages=[
            {
                "role": "user",
                "content": f"Parse this transaction: {user_text}",
            }
        ],
    )

    response_text = message.content[0].text
    if not response_text:
        raise ValueError("Claude returned an empty response for the text description.")

    return _clean_json_response(response_text)
