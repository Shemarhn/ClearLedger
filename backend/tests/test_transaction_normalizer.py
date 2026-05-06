import unittest

from services.transaction_normalizer import normalize_parsed_transaction, sanitized_llm_payload


class TransactionNormalizerTests(unittest.TestCase):
    def test_coerces_model_output_into_response_safe_values(self):
        normalized = normalize_parsed_transaction(
            {
                "merchant": "  ShopMart ",
                "amount": "JMD 1,234.50",
                "currency": "jamaican dollar",
                "category": "food",
                "confidence": "85%",
                "line_items": [
                    {"item": "Bread", "amount": "$250"},
                    "not an item",
                ],
            },
            include_line_items=True,
        )

        self.assertEqual(normalized["merchant"], "ShopMart")
        self.assertEqual(normalized["amount"], 1234.50)
        self.assertEqual(normalized["currency"], "JMD")
        self.assertEqual(normalized["category"], "Food")
        self.assertEqual(normalized["confidence"], 0.85)
        self.assertEqual(normalized["line_items"], [{"name": "Bread", "price": 250.0}])

    def test_omits_line_items_for_text_parsing(self):
        normalized = normalize_parsed_transaction(
            {"line_items": [{"name": "Bread", "price": 250}]},
            include_line_items=False,
        )

        self.assertEqual(normalized["line_items"], [])

    def test_sanitized_payload_drops_unknown_fields(self):
        normalized = normalize_parsed_transaction(
            {
                "merchant": "Shop",
                "amount": 500,
                "provider_trace": "do not store this",
            },
            include_line_items=True,
        )

        payload = sanitized_llm_payload(normalized)

        self.assertEqual(payload["merchant"], "Shop")
        self.assertNotIn("provider_trace", payload)


if __name__ == "__main__":
    unittest.main()
