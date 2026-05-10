"""Endpoints for image and text transaction parsing."""

import logging
from datetime import datetime
from mimetypes import guess_type
import uuid

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from supabase import create_client

from auth import get_user_id
from config import SUPABASE_SECRET_KEY, SUPABASE_URL
from models import (
    ParseReceiptResponse,
    ParseTextResponse,
    ParsedTransaction,
    ReceiptFeedbackInput,
    ReceiptFeedbackResponse,
    TextInput,
)
from services.gemma_service import parse_receipt_text, parse_text_description
from services.claude_service import (
    parse_receipt_text_fallback,
    parse_text_description_fallback,
)
from services.image_preprocessing import (
    ImagePreparationError,
    extension_for_mime,
    normalize_mime_type,
    prepare_image_for_llm,
)
from services.receipt_text_parser import (
    extract_receipt_candidates,
    parse_receipt_text_basic,
    prepare_receipt_ocr_text,
    reconcile_receipt_result,
)
from services.receipt_intelligence import (
    apply_receipt_memory,
    record_feedback,
    record_parse_event,
)
from services.text_fallback_service import parse_text_description_basic
from services.transaction_normalizer import normalize_parsed_transaction, sanitized_llm_payload

logger = logging.getLogger(__name__)

router = APIRouter(tags=["Parse"])

MAX_UPLOAD_SIZE = 50 * 1024 * 1024  # Server memory guard; image dimensions are unrestricted.


def _get_supabase():
    return create_client(SUPABASE_URL, SUPABASE_SECRET_KEY)


async def _parse_receipt_impl(
    file: UploadFile = File(...),
    ocr_text: str = Form(""),
    user_id: str = Depends(get_user_id),
):
    """
    Accept a receipt image and OCR text, store the image, parse OCR text, and
    return structured transaction data.
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

    prepared_ocr_text = prepare_receipt_ocr_text(ocr_text)
    if len(prepared_ocr_text) < 8:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                "No readable receipt text was detected. Please retake the receipt "
                "or enter the transaction manually."
            ),
        )

    # Upload to Supabase Storage
    receipt_url = None
    receipt_path = None
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
        receipt_path = filename
    except Exception as e:
        logger.warning(f"Failed to upload receipt to storage: {e}")
        # Continue even if storage upload fails; parsing is more important

    candidates = extract_receipt_candidates(prepared_ocr_text)

    # Parse OCR text with Gemma. If providers fail, use deterministic candidates.
    try:
        result = await parse_receipt_text(prepared_ocr_text, candidates)
    except Exception as gemma_error:
        logger.warning(f"Gemma failed, trying Claude fallback: {gemma_error}")
        try:
            result = await parse_receipt_text_fallback(prepared_ocr_text, candidates)
        except Exception as claude_error:
            logger.error(
                "Both receipt text LLMs failed. "
                f"Gemma: {gemma_error}, Claude: {claude_error}. "
                "Using deterministic receipt parser."
            )
            result = parse_receipt_text_basic(prepared_ocr_text, candidates)

    result = reconcile_receipt_result(result, candidates)
    result = apply_receipt_memory(_get_supabase(), user_id, result)

    normalized = normalize_parsed_transaction(result, include_line_items=True)
    parsed = ParsedTransaction(**normalized)
    parse_session_id = record_parse_event(
        _get_supabase(),
        user_id=user_id,
        input_method="receipt",
        ocr_text=prepared_ocr_text,
        receipt_url=receipt_url,
        receipt_path=receipt_path,
        parser_candidates=candidates,
        parsed_payload=normalized,
        raw_llm_response=sanitized_llm_payload(normalized),
    )

    return ParseReceiptResponse(
        success=True,
        data=parsed,
        receipt_url=receipt_url,
        receipt_path=receipt_path,
        parse_session_id=parse_session_id,
        raw_llm_response=sanitized_llm_payload(normalized),
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

    normalized = normalize_parsed_transaction(result, include_line_items=False)
    parsed = ParsedTransaction(**normalized)

    return ParseTextResponse(
        success=True,
        data=parsed,
        raw_llm_response=sanitized_llm_payload(normalized),
    )


@router.post("/parse-receipt", response_model=ParseReceiptResponse)
async def parse_receipt(
    file: UploadFile = File(...),
    ocr_text: str = Form(""),
    user_id: str = Depends(get_user_id),
):
    return await _parse_receipt_impl(file=file, ocr_text=ocr_text, user_id=user_id)


@router.post("/parse/receipt", response_model=ParseReceiptResponse)
async def parse_receipt_alias(
    file: UploadFile = File(...),
    ocr_text: str = Form(""),
    user_id: str = Depends(get_user_id),
):
    return await _parse_receipt_impl(file=file, ocr_text=ocr_text, user_id=user_id)


@router.post("/parse-text", response_model=ParseTextResponse)
async def parse_text(body: TextInput, user_id: str = Depends(get_user_id)):
    return await _parse_text_impl(body=body, user_id=user_id)


@router.post("/parse/text", response_model=ParseTextResponse)
async def parse_text_alias(body: TextInput, user_id: str = Depends(get_user_id)):
    return await _parse_text_impl(body=body, user_id=user_id)


@router.post("/receipt-feedback", response_model=ReceiptFeedbackResponse)
async def receipt_feedback(
    body: ReceiptFeedbackInput,
    user_id: str = Depends(get_user_id),
):
    result = record_feedback(
        _get_supabase(),
        user_id=user_id,
        parse_session_id=body.parse_session_id,
        outcome=body.outcome,
        final_transaction_id=body.final_transaction_id,
        final_payload=body.final_payload,
        cancel_reason=body.cancel_reason,
    )
    return ReceiptFeedbackResponse(**result)


@router.post("/parse/receipt-feedback", response_model=ReceiptFeedbackResponse)
async def receipt_feedback_alias(
    body: ReceiptFeedbackInput,
    user_id: str = Depends(get_user_id),
):
    return await receipt_feedback(body=body, user_id=user_id)


def _declared_image_mime(file: UploadFile) -> str:
    content_type = normalize_mime_type(file.content_type)
    if content_type.startswith("image/"):
        return content_type

    guessed_type, _ = guess_type(file.filename or "")
    guessed_type = normalize_mime_type(guessed_type)
    if guessed_type.startswith("image/"):
        return guessed_type

    return ""
