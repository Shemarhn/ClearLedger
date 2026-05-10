from io import BytesIO
import unittest

from PIL import Image

from services.image_preprocessing import prepare_image_for_llm


class ImagePreprocessingTests(unittest.TestCase):
    def test_prepares_large_dimension_image_as_jpeg(self):
        image = Image.new("RGB", (5200, 900), "white")
        buffer = BytesIO()
        image.save(buffer, format="PNG")

        prepared = prepare_image_for_llm(buffer.getvalue(), "image/png")

        self.assertEqual(prepared.mime_type, "image/jpeg")
        self.assertGreater(prepared.width, 0)
        self.assertGreater(prepared.height, 0)


if __name__ == "__main__":
    unittest.main()
