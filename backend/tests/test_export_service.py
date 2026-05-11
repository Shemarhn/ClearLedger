from services.export_service import generate_csv


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
