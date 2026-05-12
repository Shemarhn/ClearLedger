from datetime import date
from decimal import Decimal

from services.export_service import generate_csv, generate_pdf


def test_generate_csv_sanitizes_multiline_cells_and_adds_excel_bom():
    csv_content = generate_csv(
        [
            {
                "transaction_date": "2026-05-10",
                "merchant": "A,B Store",
                "category": "Food",
                "transaction_type": "expense",
                "description": "first line\nsecond line",
                "amount": 12.5,
                "currency": "JMD",
                "input_method": "receipt",
            }
        ]
    )

    assert csv_content.startswith("\ufeffDate,Merchant")
    assert "first line second line" in csv_content
    assert '"A,B Store"' in csv_content


def test_generate_pdf_handles_nulls_and_non_string_values():
    pdf_bytes = generate_pdf(
        [
            {
                "transaction_date": date(2026, 5, 10),
                "merchant": None,
                "category": None,
                "transaction_type": None,
                "description": "first line\nsecond line",
                "amount": Decimal("12.50"),
                "currency": None,
                "input_method": None,
            },
            {
                "transaction_date": "2026-05-11",
                "merchant": "A&B Store",
                "category": "Food",
                "transaction_type": "expense",
                "amount": "bad amount",
                "currency": "JMD",
                "input_method": "receipt",
            },
        ],
        date(2026, 5, 1),
        date(2026, 5, 12),
        "A&B User",
    )

    assert pdf_bytes.startswith(b"%PDF")
    assert len(pdf_bytes) > 1000
