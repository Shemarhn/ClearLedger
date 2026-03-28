"""
ClearLedger FastAPI - Gemini Service
Handles all Google Gemini API calls for receipt parsing and text parsing.
Primary LLM provider.
"""
import json
import re
from datetime import date

import google.generativeai as genai
from config import GEMINI_API_KEY

genai.configure(api_key=GEMINI_API_KEY)

RECEIPT_SYSTEM_PROMPT = """You are a financial data extraction assistant. Extract transaction details from this receipt or transaction screenshot. Return ONLY a valid JSON object with these fields:
- merchant (string): the store or business name
- amount (number): the total amount in the currency shown on the receipt
- currency (string): 3-letter currency code, default to "JMD" if unclear
- date (string): in YYYY-MM-DD format, or null if unclear
- category (string): exactly one of: Food, Transport, Utilities, Entertainment, Healthcare, Shopping, Education, Other
- line_items (array): array of objects with "name" (string) and "price" (number), or empty array if not legible
- confidence (number): 0 to 1 indicating how confident you are in the extraction

Do not include any explanation, markdown formatting, or code fences. Return ONLY the raw JSON object."""

TEXT_SYSTEM_PROMPT_TEMPLATE = """You are a financial transaction parser. The user will describe a transaction in natural language. Extract the transaction details and return ONLY a valid JSON object with these fields:
- merchant (string): the store or business name, or null if not mentioned
- amount (number): the transaction amount
- currency (string): 3-letter currency code, assume "JMD" if not specified
- date (string): in YYYY-MM-DD format. If the user says "today", use {today}. If they say "yesterday", use the day before {today}. If no date is mentioned, use {today}.
- category (string): exactly one of: Food, Transport, Utilities, Entertainment, Healthcare, Shopping, Education, Other
- description (string): a cleaned one-sentence summary of the transaction
- confidence (number): 0 to 1 indicating how confident you are in the parsing

Do not include any explanation, markdown formatting, or code fences. Return ONLY the raw JSON object."""


def _clean_json_response(text: str) -> dict:
    """Strip markdown code fences and parse JSON from LLM response."""
    cleaned = text.strip()
    # Remove markdown code fences if present
    cleaned = re.sub(r"^```(?:json)?\s*", "", cleaned)
    cleaned = re.sub(r"\s*```$", "", cleaned)
    cleaned = cleaned.strip()

    try:
        return json.loads(cleaned)
    except json.JSONDecodeError as e:
        raise ValueError(
            f"LLM returned invalid JSON. Raw response: {text[:500]}. Error: {str(e)}"
        )


async def parse_receipt_image(image_bytes: bytes, mime_type: str = "image/jpeg") -> dict:
    """
    Send a receipt image to Gemini Vision and extract transaction data.

    Args:
        image_bytes: Raw bytes of the receipt image.
        mime_type: MIME type of the image (image/jpeg, image/png, image/webp).

    Returns:
        Parsed transaction data as a dictionary.
    """
    model = genai.GenerativeModel("gemini-2.0-flash")

    image_part = {
        "mime_type": mime_type,
        "data": image_bytes,
    }

    response = model.generate_content(
        [RECEIPT_SYSTEM_PROMPT, image_part],
        generation_config=genai.GenerationConfig(
            temperature=0.1,
            max_output_tokens=1024,
        ),
    )

    if not response.text:
        raise ValueError("Gemini returned an empty response for the receipt image.")

    return _clean_json_response(response.text)


async def parse_text_description(user_text: str) -> dict:
    """
    Send a natural language transaction description to Gemini and extract structured data.

    Args:
        user_text: The user's natural language description of a transaction.

    Returns:
        Parsed transaction data as a dictionary.
    """
    today = date.today().isoformat()
    prompt = TEXT_SYSTEM_PROMPT_TEMPLATE.replace("{today}", today)

    model = genai.GenerativeModel("gemini-2.0-flash")

    response = model.generate_content(
        [prompt, f"User input: {user_text}"],
        generation_config=genai.GenerationConfig(
            temperature=0.1,
            max_output_tokens=1024,
        ),
    )

    if not response.text:
        raise ValueError("Gemini returned an empty response for the text description.")

    return _clean_json_response(response.text)
