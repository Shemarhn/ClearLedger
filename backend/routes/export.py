"""Endpoints for generating PDF and CSV exports."""

import logging

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import Response
from supabase import create_client

from auth import get_user_id
from config import SUPABASE_SECRET_KEY, SUPABASE_URL
from models import ExportRequest
from services.export_service import generate_csv, generate_pdf

router = APIRouter(prefix="/export", tags=["Export"])
logger = logging.getLogger(__name__)


def _get_supabase():
    return create_client(SUPABASE_URL, SUPABASE_SECRET_KEY)


async def _get_transactions_for_period(user_id: str, start_date, end_date):
    supabase = _get_supabase()
    result = (
        supabase.table("transactions")
        .select("*")
        .eq("user_id", user_id)
        .gte("transaction_date", start_date.isoformat())
        .lte("transaction_date", end_date.isoformat())
        .order("transaction_date", desc=True)
        .execute()
    )
    return result.data or []


def _get_user_name(user_id: str) -> str:
    supabase = _get_supabase()
    try:
        profile = (
            supabase.table("profiles")
            .select("full_name")
            .eq("id", user_id)
            .limit(1)
            .execute()
        )
    except Exception as error:
        logger.warning("Could not load export profile name for %s: %s", user_id, error)
        return "User"

    rows = profile.data or []
    if not rows:
        return "User"

    full_name = str(rows[0].get("full_name") or "").strip()
    return full_name or "User"


@router.post("/pdf")
async def export_pdf(body: ExportRequest, user_id: str = Depends(get_user_id)):
    """
    Generate a PDF report of transactions for the given date range.
    Returns the PDF as a downloadable file.
    """
    if body.start_date > body.end_date:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="start_date must be before or equal to end_date.",
        )

    transactions = await _get_transactions_for_period(user_id, body.start_date, body.end_date)
    user_name = _get_user_name(user_id)
    pdf_bytes = generate_pdf(transactions, body.start_date, body.end_date, user_name)

    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={
            "Content-Disposition": (
                f'attachment; filename="clearledger_report_{body.start_date}_{body.end_date}.pdf"'
            )
        },
    )


@router.post("/csv")
async def export_csv(body: ExportRequest, user_id: str = Depends(get_user_id)):
    """
    Generate a CSV report of transactions for the given date range.
    Returns the CSV as a downloadable file.
    """
    if body.start_date > body.end_date:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="start_date must be before or equal to end_date.",
        )

    transactions = await _get_transactions_for_period(user_id, body.start_date, body.end_date)

    csv_content = generate_csv(transactions)

    return Response(
        content=csv_content.encode("utf-8"),
        media_type="text/csv; charset=utf-8",
        headers={
            "Content-Disposition": (
                f'attachment; filename="clearledger_export_{body.start_date}_{body.end_date}.csv"'
            )
        },
    )


@router.post("/export/pdf")
async def export_pdf_alias(body: ExportRequest, user_id: str = Depends(get_user_id)):
    return await export_pdf(body=body, user_id=user_id)


@router.post("/export/csv")
async def export_csv_alias(body: ExportRequest, user_id: str = Depends(get_user_id)):
    return await export_csv(body=body, user_id=user_id)
