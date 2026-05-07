import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants.dart';
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

class _AddTransactionScreenState extends State<AddTransactionScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _apiService = ApiService();
  final _ocrService = OcrService();
  final _picker = ImagePicker();
  final _textController = TextEditingController();

  bool _loadingImage = false;
  bool _loadingText = false;
  String? _imageStatus;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark ? AppConstants.darkSurface : Theme.of(context).colorScheme.surface;
    final stroke = dark ? AppConstants.darkStroke : const Color(0xFFDCE6E1);
    return Scaffold(
      body: DarkShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add movement',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            const Text(
              'Receipt, ATM slip, deposit, income, or transfer',
              style: TextStyle(color: AppConstants.darkMuted),
            ),
            const SizedBox(height: 18),
            Container(
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: stroke),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(icon: Icon(Icons.document_scanner_outlined), text: 'Photo'),
                  Tab(icon: Icon(Icons.edit_note_outlined), text: 'Text'),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _photoMode(),
                  _textMode(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoMode() {
    return ListView(
      children: [
        FinanceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.receipt_long_outlined, color: AppConstants.mint, size: 32),
              const SizedBox(height: 12),
              const Text(
                'Read a receipt or ATM slip',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                'ClearLedger runs OCR first, then classifies the movement as expense, income, deposit, withdrawal, or transfer.',
                style: TextStyle(color: AppConstants.darkMuted, height: 1.35),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _loadingImage ? null : () => _pickAndParse(ImageSource.camera),
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Take photo'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _loadingImage ? null : () => _pickAndParse(ImageSource.gallery),
                icon: const Icon(Icons.image_outlined),
                label: const Text('Choose from gallery'),
              ),
              if (_loadingImage) ...[
                const SizedBox(height: 18),
                const LinearProgressIndicator(),
                if (_imageStatus != null) ...[
                  const SizedBox(height: 10),
                  Text(_imageStatus!, style: const TextStyle(color: AppConstants.darkMuted)),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _textMode() {
    return ListView(
      children: [
        FinanceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Describe the movement',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                'Examples: Salary deposit of 85000 to Scotia. ATM withdrawal 10000 from NCB. Lunch 1500 cash.',
                style: TextStyle(color: AppConstants.darkMuted, height: 1.35),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _textController,
                maxLines: 5,
                decoration: const InputDecoration(hintText: 'Type transaction details...'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadingText ? null : _parseText,
                child: _loadingText
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Parse movement'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
