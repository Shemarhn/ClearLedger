"""Endpoints for image and text transaction parsing."""

import logging
from datetime import datetime
from mimetypes import guess_type
import uuid

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from supabase import create_client

from auth import get_user_id
from config import SUPABASE_SECRET_KEY, SUPABASE_URL
from models import ParseReceiptResponse, ParseTextResponse, ParsedTransaction, TextInput
from services.gemma_service import parse_receipt_image, parse_text_description
from services.claude_service import (
    parse_receipt_image_fallback,
    parse_text_description_fallback,
)
from services.image_preprocessing import (
    ImagePreparationError,
    extension_for_mime,
    normalize_mime_type,
    prepare_image_for_llm,
)
from services.text_fallback_service import parse_text_description_basic
from services.transaction_normalizer import normalize_parsed_transaction

logger = logging.getLogger(__name__)

router = APIRouter(tags=["Parse"])

MAX_UPLOAD_SIZE = 50 * 1024 * 1024  # Server memory guard; image dimensions are unrestricted.


def _get_supabase():
    return create_client(SUPABASE_URL, SUPABASE_SECRET_KEY)


async def _parse_receipt_impl(
    file: UploadFile = File(...),
    user_id: str = Depends(get_user_id),
):
    """
    Accept a receipt image, upload to Supabase Storage, send to Gemma,
    and return structured transaction data.
    """
    image_bytes = await file.read()
    if len(image_bytes) > MAX_UPLOAD_SIZE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Image file is too large to upload.",
        )

    declared_mime = _declared_image_mime(file)
    try:
        prepared_image = prepare_image_for_llm(image_bytes, declared_mime)
    except ImagePreparationError as error:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(error),
        )

    # Upload to Supabase Storage
    receipt_url = None
    try:
        supabase = _get_supabase()
        storage_mime = declared_mime or prepared_image.mime_type
        storage_bytes = image_bytes if declared_mime else prepared_image.data
        extension = extension_for_mime(storage_mime)
        filename = (
            f"{user_id}/{datetime.utcnow().strftime('%Y%m%d_%H%M%S')}_"
            f"{uuid.uuid4().hex[:8]}{extension}"
        )
        supabase.storage.from_("receipts").upload(
            filename,
            storage_bytes,
            file_options={"content-type": storage_mime or "image/jpeg"},
        )

        # Get signed URL (valid for 1 hour)
        signed = supabase.storage.from_("receipts").create_signed_url(filename, 3600)
        receipt_url = signed.get("signedURL") or signed.get("signedUrl")
    except Exception as e:
        logger.warning(f"Failed to upload receipt to storage: {e}")
        # Continue even if storage upload fails; parsing is more important

    # Parse with Gemma (try fallback on failure)
    try:
        result = await parse_receipt_image(prepared_image.data, prepared_image.mime_type)
    except Exception as gemma_error:
        logger.warning(f"Gemma failed, trying Claude fallback: {gemma_error}")
        try:
            result = await parse_receipt_image_fallback(
                prepared_image.data,
                prepared_image.mime_type,
            )
        except Exception as claude_error:
            logger.error(f"Both LLMs failed. Gemma: {gemma_error}, Claude: {claude_error}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Could not parse the receipt. Please try again or enter the transaction manually.",
            )

    parsed = ParsedTransaction(
        **normalize_parsed_transaction(result, include_line_items=True)
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
    Accept a natural language transaction description, send to Gemma,
    and return structured transaction data.
    """
    # Parse with Gemma (try fallback on failure)
    try:
        result = await parse_text_description(body.text)
    except Exception as gemma_error:
        logger.warning(f"Gemma failed, trying Claude fallback: {gemma_error}")
        try:
            result = await parse_text_description_fallback(body.text)
        except Exception as claude_error:
            logger.error(
                "Both LLMs failed for text parsing. "
                f"Gemma: {gemma_error}, Claude: {claude_error}. "
                "Trying local fallback parser."
            )
            try:
                result = parse_text_description_basic(body.text)
            except Exception as fallback_error:
                logger.error(f"Local fallback text parser failed: {fallback_error}")
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail="Could not parse the transaction description. Please try again.",
                )

    parsed = ParsedTransaction(
        **normalize_parsed_transaction(result, include_line_items=False)
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


def _declared_image_mime(file: UploadFile) -> str:
    content_type = normalize_mime_type(file.content_type)
    if content_type.startswith("image/"):
        return content_type

    guessed_type, _ = guess_type(file.filename or "")
    guessed_type = normalize_mime_type(guessed_type)
    if guessed_type.startswith("image/"):
        return guessed_type

    return ""
