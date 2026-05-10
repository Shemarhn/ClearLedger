import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/parsed_transaction.dart';
import '../../services/api_service.dart';
import '../../services/ocr_service.dart';
import '../../widgets/dark_shell.dart';
import 'review_transaction_screen.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _apiService = ApiService();
  final _ocrService = OcrService();
  final _picker = ImagePicker();
  final _textController = TextEditingController();

  bool _loadingImage = false;
  bool _loadingText = false;
  String? _imageStatus;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickAndParse(ImageSource source) async {
    setState(() {
      _loadingImage = true;
      _imageStatus = null;
    });
    try {
      final image = await _picker.pickImage(
        source: source,
        imageQuality: 78,
        maxWidth: 1800,
        maxHeight: 1800,
      );
      if (image == null) return;

      final imageFile = File(image.path);
      if (mounted) setState(() => _imageStatus = 'Reading receipt text...');
      final ocrResult = await _ocrService.readReceipt(imageFile);
      if (mounted) setState(() => _imageStatus = 'Classifying money movement...');
      final parsed = await _apiService.processReceiptImage(
        imageFile,
        ocrText: ocrResult.text,
      );
      await _review(parsed.copyWith(description: parsed.description ?? 'Receipt transaction'), 'receipt');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Receipt parsing failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingImage = false;
          _imageStatus = null;
        });
      }
    }
  }

  Future<void> _parseText() async {
    if (_textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a transaction description first.')),
      );
      return;
    }

    setState(() => _loadingText = true);
    try {
      final parsed = await _apiService.processTextDescription(_textController.text.trim());
      await _review(parsed, 'text');
      if (mounted) _textController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Text parsing failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingText = false);
    }
  }

  Future<void> _review(ParsedTransaction parsed, String method) async {
    if (!mounted) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ReviewTransactionScreen(parsed: parsed, inputMethod: method),
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction saved successfully.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DarkShell(
        child: ListView(
          children: [
            const ScreenHeader(
              title: 'Add movement',
              subtitle: 'Scan a receipt or describe the movement',
              glyph: AppGlyph.scan,
            ),
            const SizedBox(height: 18),
            _photoMode(),
            const SizedBox(height: 18),
            _textMode(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _photoMode() {
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62);
    return FinanceCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppIconBadge(glyph: AppGlyph.receipt, size: 50),
          const SizedBox(height: 18),
          const Text(
            'Read a receipt or ATM slip',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            'Receipts, ATM slips, card purchases, and cash movements stay in one place.',
            style: TextStyle(color: muted, height: 1.35, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 22),
          ElevatedButton.icon(
            onPressed: _loadingImage ? null : () => _pickAndParse(ImageSource.camera),
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('Take photo'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _loadingImage ? null : () => _pickAndParse(ImageSource.gallery),
            icon: const Icon(Icons.image_outlined),
            label: const Text('Open gallery'),
          ),
          if (_loadingImage) ...[
            const SizedBox(height: 18),
            const LinearProgressIndicator(),
            if (_imageStatus != null) ...[
              const SizedBox(height: 10),
              Text(_imageStatus!, style: TextStyle(color: muted, fontWeight: FontWeight.w700)),
            ],
          ],
        ],
      ),
    );
  }

  Widget _textMode() {
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62);
    return FinanceCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppIconBadge(glyph: AppGlyph.document, size: 50),
          const SizedBox(height: 18),
          const Text(
            'Insert text',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            'For salary deposits, withdrawals, cash lunches, and quick corrections.',
            style: TextStyle(color: muted, height: 1.35, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _textController,
            maxLines: 5,
            decoration: const InputDecoration(hintText: 'Type movement details...'),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: _loadingText ? null : _parseText,
            icon: const Icon(Icons.auto_awesome_outlined),
            label: _loadingText
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Parse movement'),
          ),
        ],
      ),
    );
  }
}
