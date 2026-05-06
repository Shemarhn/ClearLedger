"""Primary LLM provider for Google-hosted Gemma receipt and text parsing."""
import asyncio
from datetime import date
from io import BytesIO

from google import genai
from google.genai import types

from config import GEMMA_API_KEY, GEMMA_MODEL
from services.llm_json import parse_llm_json_object

RECEIPT_SYSTEM_PROMPT = """You are a financial data extraction assistant. Extract transaction details from this receipt or transaction screenshot. Return ONLY a valid JSON object with these fields:
- merchant (string): the store or business name
- amount (number): the total amount in the currency shown on the receipt
- currency (string): 3-letter currency code, default to "JMD" if unclear
- date (string): in YYYY-MM-DD format, or null if unclear
- category (string): exactly one of: Food, Transport, Utilities, Entertainment, Healthcare, Shopping, Education, Other
- line_items (array): array of objects with "name" (string) and "price" (number), or empty array if not legible
- confidence (number): 0 to 1 indicating how confident you are in the extraction

Do not include any explanation, markdown formatting, or code fences. Return ONLY the raw JSON object."""


def _get_client() -> genai.Client:
    return genai.Client(api_key=GEMMA_API_KEY)


def _generation_config() -> types.GenerateContentConfig:
    return types.GenerateContentConfig(
        temperature=0.1,
        max_output_tokens=1024,
        response_mime_type="application/json",
        media_resolution=types.MediaResolution.MEDIA_RESOLUTION_HIGH,
    )


def _generate_content(contents: list) -> str:
    client = _get_client()
    response = client.models.generate_content(
        model=GEMMA_MODEL,
        contents=contents,
        config=_generation_config(),
    )

    if not response.text:
        raise ValueError("Gemma returned an empty response.")

    return response.text


def _generate_image_content(image_bytes: bytes, mime_type: str) -> str:
    client = _get_client()
    uploaded_file = None

    try:
        image_stream = BytesIO(image_bytes)
        uploaded_file = client.files.upload(
            file=image_stream,
            config=types.UploadFileConfig(
                mime_type=mime_type,
                display_name="receipt",
            ),
        )
        response = client.models.generate_content(
            model=GEMMA_MODEL,
            contents=[uploaded_file, RECEIPT_SYSTEM_PROMPT],
            config=_generation_config(),
        )
    finally:
        if uploaded_file and uploaded_file.name:
            try:
                client.files.delete(name=uploaded_file.name)
            except Exception:
                pass

    if not response.text:
        raise ValueError("Gemma returned an empty response.")

    return response.text


TEXT_SYSTEM_PROMPT_TEMPLATE = """You are a financial transaction parser. The user will describe a transaction in natural language. Extract the transaction details and return ONLY a valid JSON object with these fields:
- merchant (string): the store or business name, or null if not mentioned
- amount (number): the transaction amount
- currency (string): 3-letter currency code, assume "JMD" if not specified
- date (string): in YYYY-MM-DD format. If the user says "today", use {today}. If they say "yesterday", use the day before {today}. If no date is mentioned, use {today}.
- category (string): exactly one of: Food, Transport, Utilities, Entertainment, Healthcare, Shopping, Education, Other
- description (string): a cleaned one-sentence summary of the transaction
- confidence (number): 0 to 1 indicating how confident you are in the parsing

Do not include any explanation, markdown formatting, or code fences. Return ONLY the raw JSON object."""


async def parse_receipt_image(image_bytes: bytes, mime_type: str = "image/jpeg") -> dict:
    """
    Send a receipt image to Gemma and extract transaction data.

    Args:
        image_bytes: Raw bytes of the receipt image.
        mime_type: MIME type of the image (image/jpeg, image/png, image/webp).

    Returns:
        Parsed transaction data as a dictionary.
    """
    response_text = await asyncio.to_thread(
        _generate_image_content,
        image_bytes,
        mime_type,
    )

    return parse_llm_json_object(response_text, "Gemma")


async def parse_text_description(user_text: str) -> dict:
    """
    Send a natural language transaction description to Gemma and extract structured data.

    Args:
        user_text: The user's natural language description of a transaction.

    Returns:
        Parsed transaction data as a dictionary.
    """
    today = date.today().isoformat()
    prompt = TEXT_SYSTEM_PROMPT_TEMPLATE.replace("{today}", today)

    response_text = await asyncio.to_thread(
        _generate_content,
        [prompt, f"User input: {user_text}"],
    )

    return parse_llm_json_object(response_text, "Gemma")
