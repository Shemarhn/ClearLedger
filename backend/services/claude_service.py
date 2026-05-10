"""Fallback LLM provider using Anthropic Claude Sonnet."""

from datetime import date
import json

import anthropic
from config import ANTHROPIC_API_KEY
from services.llm_json import parse_llm_json_object
from services.receipt_text_parser import receipt_prompt_payload

client = anthropic.Anthropic(api_key=ANTHROPIC_API_KEY)

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

Return ONLY the raw JSON object. No explanation, no markdown."""

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

Return ONLY the raw JSON object. No explanation, no markdown."""


def _clean_json_response(text: str) -> dict:
    """Strip markdown code fences and parse JSON from LLM response."""
    return parse_llm_json_object(text, "Claude")


async def parse_receipt_image_fallback(
    image_bytes: bytes,
    mime_type: str = "image/jpeg",
    ocr_text: str = "",
    candidates: dict | None = None,
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

    payload = receipt_prompt_payload(ocr_text, candidates or {}) if ocr_text else {}
    prompt = RECEIPT_SYSTEM_PROMPT
    if payload:
        prompt = (
            f"{RECEIPT_SYSTEM_PROMPT}\n\n"
            "OCR and parser candidates are supporting evidence only. The image is the source of truth. "
            "Use parser candidates for totals/dates only when they match the whole document.\n"
            f"{json.dumps(payload, ensure_ascii=False)}"
        )

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
                        "text": prompt,
                    },
                ],
            }
        ],
    )

    response_text = message.content[0].text
    if not response_text:
        raise ValueError("Claude returned an empty response for the receipt image.")

    result = _clean_json_response(response_text)
    result["source"] = "claude_vision"
    return result


async def parse_receipt_text_fallback(ocr_text: str, candidates: dict) -> dict:
    """Fallback: parse OCR receipt text with Claude."""
    payload = receipt_prompt_payload(ocr_text, candidates)
    message = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=1024,
        system=RECEIPT_TEXT_SYSTEM_PROMPT,
        messages=[
            {
                "role": "user",
                "content": (
                    "Parse this receipt OCR payload and return only JSON:\n"
                    f"{json.dumps(payload, ensure_ascii=False)}"
                ),
            }
        ],
    )

    response_text = message.content[0].text
    if not response_text:
        raise ValueError("Claude returned an empty response for receipt OCR text.")

    result = _clean_json_response(response_text)
    result["source"] = "claude_text"
    return result


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
