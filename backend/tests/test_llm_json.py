import unittest

from services.llm_json import parse_llm_json_object


class LlmJsonTests(unittest.TestCase):
    def test_parses_json_inside_code_fence(self):
        parsed = parse_llm_json_object(
            '```json\n{"merchant": "Cafe Blue", "amount": 1200}\n```',
            "Test",
        )

        self.assertEqual(parsed["merchant"], "Cafe Blue")
        self.assertEqual(parsed["amount"], 1200)

    def test_extracts_first_json_object_from_prose(self):
        parsed = parse_llm_json_object(
            'Here is the parsed receipt: {"merchant": "Shop", "amount": "1,200.50"}',
            "Test",
        )

        self.assertEqual(parsed["merchant"], "Shop")
        self.assertEqual(parsed["amount"], "1,200.50")

    def test_unwraps_nested_transaction_object(self):
        parsed = parse_llm_json_object(
            '{"data": {"merchant": "Market", "amount": 400}}',
            "Test",
        )

        self.assertEqual(parsed["merchant"], "Market")


if __name__ == "__main__":
    unittest.main()
