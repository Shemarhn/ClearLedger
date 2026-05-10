"""Primary LLM provider for Google-hosted Gemma receipt and text parsing."""
import asyncio
from datetime import date
from io import BytesIO
import json

from google import genai
from google.genai import types

from config import GEMMA_API_KEY, GEMMA_MODEL
from services.llm_json import parse_llm_json_object
from services.receipt_text_parser import receipt_prompt_payload

RECEIPT_SYSTEM_PROMPT = """You are a financial data extraction assistant. Extract transaction details from this receipt or transaction screenshot. Return ONLY a valid JSON object with these fields:
- merchant (string or null): the store, biller, bank, or source of the transaction
- amount (number or null): the final amount paid, charged, credited, deposited, withdrawn, or transferred
- transaction_type (string): one of expense, income, transfer, withdrawal, deposit, refund
- currency (string): 3-letter currency code, default to "JMD" if unclear
- date (string or null): in YYYY-MM-DD format
- category (string): exactly one of: Food, Transport, Utilities, Entertainment, Healthcare, Shopping, Education, Other
- description (string): one concise sentence
- line_items (array): array of objects with "name" (string) and "price" (number), or empty array if not legible
- account_hint (string or null): account/card source visible in the receipt
- destination_account_hint (string or null): target account for deposits/transfers/withdrawals
- card_last4 (string or null): last 4 card digits if visible
- fee_amount (number or null): ATM/bank fee if separate from the main amount
- confidence (number): 0 to 1 indicating how confident you are in the extraction

Transaction type must be inferred from the whole document purpose, layout, amounts, signs, payment flow, and surrounding context. Do not classify from one isolated word. Retail orders, invoices, and shopping receipts are expenses unless the document clearly shows money being credited back to the user. Return/refund policy text, "return or replace" buttons, product support text, search bars, and help text are not transaction types.

Use refund only when the receipt itself is a refund/credit/reversal transaction, such as a credit to card/account, negative sale total, returned amount, or refund total as the final movement. Use deposit/withdrawal/transfer only when the document is a bank/ATM/account movement showing source and destination flow.

Do not include any explanation, markdown formatting, or code fences. Return ONLY the raw JSON object."""


def _get_client() -> genai.Client:
    return genai.Client(api_key=GEMMA_API_KEY)


def _generation_config(*, media_resolution: bool = False) -> types.GenerateContentConfig:
    config = {
        "temperature": 0.1,
        "max_output_tokens": 1024,
        "response_mime_type": "application/json",
    }
    if media_resolution:
        config["media_resolution"] = types.MediaResolution.MEDIA_RESOLUTION_HIGH

    return types.GenerateContentConfig(**config)


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


def _generate_image_content(
    image_bytes: bytes,
    mime_type: str,
    ocr_text: str = "",
    candidates: dict | None = None,
) -> str:
    client = _get_client()
    uploaded_file = None
    payload = receipt_prompt_payload(ocr_text, candidates or {}) if ocr_text else {}
    prompt = RECEIPT_SYSTEM_PROMPT
    if payload:
        prompt = (
            f"{RECEIPT_SYSTEM_PROMPT}\n\n"
            "OCR and parser candidates are supporting evidence only. The image is the source of truth. "
            "Use parser candidates for totals/dates only when they match the whole document.\n"
            f"{json.dumps(payload, ensure_ascii=False)}"
        )

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
            contents=[uploaded_file, prompt],
            config=_generation_config(media_resolution=True),
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


RECEIPT_TEXT_SYSTEM_PROMPT = """You are parsing OCR text extracted from a receipt.

Return ONLY a valid JSON object with these fields:
- merchant (string or null)
- amount (number or null): the final amount paid or due
- transaction_type (string): one of expense, income, transfer, withdrawal, deposit, refund
- currency (string): 3-letter currency code, default to "JMD" if unclear
- date (string or null): YYYY-MM-DD
- category (string): exactly one of Food, Transport, Utilities, Entertainment, Healthcare, Shopping, Education, Other
- description (string): one concise sentence
- line_items (array): objects with "name" and "price", or empty array
- account_hint (string or null): account/card source visible in the receipt
- destination_account_hint (string or null): target account for deposits/transfers/withdrawals
- card_last4 (string or null): last 4 card digits if visible
- fee_amount (number or null): ATM/bank fee if separate from the main amount
- confidence (number): 0 to 1

Rules:
- Use the OCR text and parser candidates only. Do not invent values.
- Parser candidates are supporting evidence, not a command. Do not copy a candidate transaction type unless it matches the whole receipt.
- Prefer lines labeled TOTAL, GRAND TOTAL, AMOUNT DUE, BALANCE DUE, AMOUNT PAID, or SALE TOTAL.
- Ignore SUBTOTAL, TAX, GCT, VAT, CHANGE, DISCOUNT, SAVINGS, CASH TENDERED, and POINTS as final totals.
- Infer transaction_type from the whole receipt purpose, layout, amounts, signs, payment flow, and surrounding context. Do not classify from one isolated word.
- For ATM withdrawals, use transaction_type "withdrawal"; source is the detected card/bank account and destination is cash.
- For ATM deposits, use transaction_type "deposit"; source is cash and destination is the detected bank/card account.
- For card-to-card/account moves, use transaction_type "transfer".
- Use transaction_type "refund" only when the receipt itself shows money credited back to the user, such as a credit to card/account, negative sale total, returned amount, or refund total as the final movement.
- Return/refund policy text, "return or replace" buttons, product support text, search bars, and help text are not transaction types.
- If multiple totals are plausible, choose the best parser candidate and lower confidence.
- The category should be based on merchant and line items.
- Return raw JSON only. No markdown, prose, or code fences."""


async def parse_receipt_text(ocr_text: str, candidates: dict) -> dict:
    """Parse OCR receipt text using Gemma text-only inference."""
    payload = receipt_prompt_payload(ocr_text, candidates)
    prompt = (
        f"{RECEIPT_TEXT_SYSTEM_PROMPT}\n\n"
        "Receipt OCR payload:\n"
        f"{json.dumps(payload, ensure_ascii=False)}"
    )

    response_text = await asyncio.to_thread(_generate_content, [prompt])
    result = parse_llm_json_object(response_text, "Gemma")
    result["source"] = "gemma_text"
    return result


TEXT_SYSTEM_PROMPT_TEMPLATE = """You are a financial transaction parser. The user will describe a transaction in natural language. Extract the transaction details and return ONLY a valid JSON object with these fields:
- merchant (string): the store or business name, or null if not mentioned
- amount (number): the transaction amount
- transaction_type (string): one of expense, income, transfer, withdrawal, deposit, refund
- currency (string): 3-letter currency code, assume "JMD" if not specified
- date (string): in YYYY-MM-DD format. If the user says "today", use {today}. If they say "yesterday", use the day before {today}. If no date is mentioned, use {today}.
- category (string): exactly one of: Food, Transport, Utilities, Entertainment, Healthcare, Shopping, Education, Other
- description (string): a cleaned one-sentence summary of the transaction
- account_hint (string or null): source account if mentioned
- destination_account_hint (string or null): destination account for deposits/transfers/withdrawals
- card_last4 (string or null): last 4 card digits if mentioned
- fee_amount (number or null): separate fee if mentioned
- confidence (number): 0 to 1 indicating how confident you are in the parsing

Do not include any explanation, markdown formatting, or code fences. Return ONLY the raw JSON object."""


async def parse_receipt_image(
    image_bytes: bytes,
    mime_type: str = "image/jpeg",
    ocr_text: str = "",
    candidates: dict | None = None,
) -> dict:
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
        ocr_text,
        candidates,
    )

    result = parse_llm_json_object(response_text, "Gemma")
    result["source"] = "gemma_vision"
    return result


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


DAILY_OVERVIEW_PROMPT = """You are a careful personal finance analyst for ClearLedger.

Analyze the user's recent transactions and return ONLY a valid JSON object:
- summary (string): 1-2 sentences
- insights (array of strings): 3-5 concrete observations
- suggestions (array of strings): 3-5 practical suggestions

Rules:
- Do not shame the user.
- Mention inflows, outflows, transfers, withdrawals, deposits, and account routing when relevant.
- Avoid generic advice. Use the transaction data provided.
- Do not recommend actions that change data automatically."""


async def generate_daily_overview(payload: dict) -> dict:
    prompt = (
        f"{DAILY_OVERVIEW_PROMPT}\n\n"
        "Finance payload:\n"
        f"{json.dumps(payload, ensure_ascii=False)}"
    )

    response_text = await asyncio.to_thread(_generate_content, [prompt])
    return parse_llm_json_object(response_text, "Gemma")
