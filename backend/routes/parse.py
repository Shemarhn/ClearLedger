"""Endpoints for image and text transaction parsing."""

import logging
from datetime import datetime
import uuid

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from supabase import create_client

from auth import get_user_id
from config import SUPABASE_SERVICE_ROLE_KEY, SUPABASE_URL
from models import ParseReceiptResponse, ParseTextResponse, ParsedTransaction, TextInput
from services.gemini_service import parse_receipt_image, parse_text_description
from services.claude_service import (
    parse_receipt_image_fallback,
    parse_text_description_fallback,
)

logger = logging.getLogger(__name__)

router = APIRouter(tags=["Parse"])

ALLOWED_MIME_TYPES = {"image/jpeg", "image/png", "image/webp", "image/jpg"}
MAX_FILE_SIZE = 10 * 1024 * 1024  # 10 MB


def _get_supabase():
    return create_client(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)


async def _parse_receipt_impl(
    file: UploadFile = File(...),
    user_id: str = Depends(get_user_id),
):
    """
    Accept a receipt image, upload to Supabase Storage, send to Gemini Vision,
    and return structured transaction data.
    """
    # Validate file type
    if file.content_type not in ALLOWED_MIME_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Unsupported file type: {file.content_type}. Use JPEG, PNG, or WebP.",
        )

    # Read and validate file size
    image_bytes = await file.read()
    if len(image_bytes) > MAX_FILE_SIZE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File size exceeds 10 MB limit.",
        )

    # Upload to Supabase Storage
    receipt_url = None
    try:
        supabase = _get_supabase()
        filename = f"{user_id}/{datetime.utcnow().strftime('%Y%m%d_%H%M%S')}_{uuid.uuid4().hex[:8]}.jpg"
        supabase.storage.from_("receipts").upload(
            filename,
            image_bytes,
            file_options={"content-type": file.content_type or "image/jpeg"},
        )

        # Get signed URL (valid for 1 hour)
        signed = supabase.storage.from_("receipts").create_signed_url(filename, 3600)
        receipt_url = signed.get("signedURL") or signed.get("signedUrl")
    except Exception as e:
        logger.warning(f"Failed to upload receipt to storage: {e}")
        # Continue even if storage upload fails; parsing is more important

    # Parse with Gemini (try fallback on failure)
    mime = file.content_type or "image/jpeg"
    try:
        result = await parse_receipt_image(image_bytes, mime)
    except Exception as gemini_error:
        logger.warning(f"Gemini failed, trying Claude fallback: {gemini_error}")
        try:
            result = await parse_receipt_image_fallback(image_bytes, mime)
        except Exception as claude_error:
            logger.error(f"Both LLMs failed. Gemini: {gemini_error}, Claude: {claude_error}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Could not parse the receipt. Please try again or enter the transaction manually.",
            )

    parsed = ParsedTransaction(
        merchant=result.get("merchant"),
        amount=result.get("amount"),
        currency=result.get("currency", "JMD"),
        date=result.get("date"),
        category=result.get("category", "Other"),
        description=result.get("description"),
        line_items=[
            {"name": item.get("name", ""), "price": item.get("price", 0)}
            for item in result.get("line_items", [])
        ],
        confidence=result.get("confidence", 0.0),
    )

    return ParseReceiptResponse(
        success=True,
        data=parsed,
        receipt_url=receipt_url,
        raw_llm_response=result,
    )


async def _parse_text_impl(
    body: TextInput,
    user_id: str = Depends(get_user_id),
):
    """
    Accept a natural language transaction description, send to Gemini,
    and return structured transaction data.
    """
    # Parse with Gemini (try fallback on failure)
    try:
        result = await parse_text_description(body.text)
    except Exception as gemini_error:
        logger.warning(f"Gemini failed, trying Claude fallback: {gemini_error}")
        try:
            result = await parse_text_description_fallback(body.text)
        except Exception as claude_error:
            logger.error(f"Both LLMs failed. Gemini: {gemini_error}, Claude: {claude_error}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Could not parse the transaction description. Please try again.",
            )

    parsed = ParsedTransaction(
        merchant=result.get("merchant"),
        amount=result.get("amount"),
        currency=result.get("currency", "JMD"),
        date=result.get("date"),
        category=result.get("category", "Other"),
        description=result.get("description"),
        line_items=[],
        confidence=result.get("confidence", 0.0),
    )

    return ParseTextResponse(success=True, data=parsed, raw_llm_response=result)


@router.post("/parse-receipt", response_model=ParseReceiptResponse)
async def parse_receipt(file: UploadFile = File(...), user_id: str = Depends(get_user_id)):
    return await _parse_receipt_impl(file=file, user_id=user_id)


@router.post("/parse/receipt", response_model=ParseReceiptResponse)
async def parse_receipt_alias(
    file: UploadFile = File(...),
    user_id: str = Depends(get_user_id),
):
    return await _parse_receipt_impl(file=file, user_id=user_id)


@router.post("/parse-text", response_model=ParseTextResponse)
async def parse_text(body: TextInput, user_id: str = Depends(get_user_id)):
    return await _parse_text_impl(body=body, user_id=user_id)


@router.post("/parse/text", response_model=ParseTextResponse)
async def parse_text_alias(body: TextInput, user_id: str = Depends(get_user_id)):
    return await _parse_text_impl(body=body, user_id=user_id)
