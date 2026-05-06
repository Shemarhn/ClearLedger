"""Image upload normalization before sending pictures to the LLM provider."""

from __future__ import annotations

from dataclasses import dataclass
from io import BytesIO
from typing import Optional

from PIL import Image, ImageOps, UnidentifiedImageError
from PIL.Image import DecompressionBombError

DIRECT_GEMINI_MIME_TYPES = {"image/heic", "image/heif"}
LLM_INLINE_IMAGE_LIMIT_BYTES = 18 * 1024 * 1024
JPEG_QUALITIES = (92, 86, 80, 72, 64)
MAX_EDGES = (None, 8192, 6144, 4096, 3072, 2048)
Image.MAX_IMAGE_PIXELS = 120_000_000


class ImagePreparationError(ValueError):
    """Raised when an upload is not a usable image."""


@dataclass(frozen=True)
class PreparedImage:
    data: bytes
    mime_type: str
    width: int | None = None
    height: int | None = None


def normalize_mime_type(mime_type: Optional[str]) -> str:
    if not mime_type:
        return ""

    normalized = mime_type.split(";", 1)[0].strip().lower()
    if normalized == "image/jpg":
        return "image/jpeg"
    return normalized


def extension_for_mime(mime_type: str) -> str:
    return {
        "image/jpeg": ".jpg",
        "image/png": ".png",
        "image/webp": ".webp",
        "image/heic": ".heic",
        "image/heif": ".heif",
    }.get(normalize_mime_type(mime_type), ".jpg")


def prepare_image_for_llm(image_bytes: bytes, declared_mime_type: Optional[str]) -> PreparedImage:
    """
    Accept any Pillow-readable image dimensions and convert to an LLM-friendly JPEG.

    Uploads are resized or recompressed only when needed to fit provider request
    limits; display dimensions are otherwise unrestricted.
    """
    if not image_bytes:
        raise ImagePreparationError("The uploaded image is empty.")

    mime_type = normalize_mime_type(declared_mime_type)

    try:
        with Image.open(BytesIO(image_bytes)) as opened:
            opened.load()
            image = ImageOps.exif_transpose(opened)
            image = _to_rgb(image)
            return _encode_jpeg_within_limit(image)
    except UnidentifiedImageError:
        if mime_type in DIRECT_GEMINI_MIME_TYPES and len(image_bytes) <= LLM_INLINE_IMAGE_LIMIT_BYTES:
            return PreparedImage(data=image_bytes, mime_type=mime_type)

        raise ImagePreparationError("Unsupported or unreadable image. Use a clear photo or screenshot.")
    except DecompressionBombError as error:
        raise ImagePreparationError("The uploaded image is too large to process safely.") from error


def _to_rgb(image: Image.Image) -> Image.Image:
    if image.mode in ("RGBA", "LA") or (image.mode == "P" and "transparency" in image.info):
        rgba = image.convert("RGBA")
        background = Image.new("RGB", rgba.size, "white")
        background.paste(rgba, mask=rgba.getchannel("A"))
        return background

    if image.mode != "RGB":
        return image.convert("RGB")

    return image.copy()


def _encode_jpeg_within_limit(image: Image.Image) -> PreparedImage:
    last_encoded: bytes | None = None
    last_size = image.size

    for max_edge in MAX_EDGES:
        candidate = _resize_to_max_edge(image, max_edge)
        last_size = candidate.size

        for quality in JPEG_QUALITIES:
            encoded = _encode_jpeg(candidate, quality)
            last_encoded = encoded
            if len(encoded) <= LLM_INLINE_IMAGE_LIMIT_BYTES:
                return PreparedImage(
                    data=encoded,
                    mime_type="image/jpeg",
                    width=candidate.width,
                    height=candidate.height,
                )

    if last_encoded is None:
        raise ImagePreparationError("The uploaded image could not be prepared for processing.")

    if len(last_encoded) > LLM_INLINE_IMAGE_LIMIT_BYTES:
        raise ImagePreparationError("The uploaded image is too large to prepare for processing.")

    return PreparedImage(
        data=last_encoded,
        mime_type="image/jpeg",
        width=last_size[0],
        height=last_size[1],
    )


def _resize_to_max_edge(image: Image.Image, max_edge: int | None) -> Image.Image:
    if max_edge is None or max(image.size) <= max_edge:
        return image.copy()

    width, height = image.size
    scale = max_edge / max(width, height)
    resized_size = (max(1, round(width * scale)), max(1, round(height * scale)))
    return image.resize(resized_size, Image.Resampling.LANCZOS)


def _encode_jpeg(image: Image.Image, quality: int) -> bytes:
    buffer = BytesIO()
    image.save(buffer, format="JPEG", quality=quality, optimize=True)
    return buffer.getvalue()
