import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrException implements Exception {
  final String message;

  OcrException(this.message);

  @override
  String toString() => message;
}

class ReceiptOcrResult {
  final String text;
  final List<String> lines;

  const ReceiptOcrResult({
    required this.text,
    required this.lines,
  });
}

class OcrService {
  Future<ReceiptOcrResult> readReceipt(File image) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFile(image);
      final recognizedText = await recognizer.processImage(inputImage);
      final lines = _orderedLines(recognizedText);
      final text = lines.isNotEmpty ? lines.join('\n') : recognizedText.text.trim();

      if (text.trim().isEmpty) {
        throw OcrException('No readable receipt text was detected.');
      }

      return ReceiptOcrResult(text: text, lines: lines);
    } catch (error) {
      if (error is OcrException) rethrow;
      throw OcrException('Could not read receipt text: $error');
    } finally {
      await recognizer.close();
    }
  }

  List<String> _orderedLines(RecognizedText recognizedText) {
    final lines = <String>[];
    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final cleaned = line.text.trim().replaceAll(RegExp(r'\s+'), ' ');
        if (cleaned.isNotEmpty) {
          lines.add(cleaned);
        }
      }
    }
    return lines;
  }
}
