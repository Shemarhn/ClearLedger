import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/api_service.dart';
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
  final _picker = ImagePicker();
  final _textController = TextEditingController();

  bool _loadingImage = false;
  bool _loadingText = false;

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
    setState(() => _loadingImage = true);
    try {
      final image = await _picker.pickImage(source: source, imageQuality: 80);
      if (image == null) return;

      final parsed = await _apiService.processReceiptImage(File(image.path));
      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ReviewTransactionScreen(
            parsed: parsed.copyWith(description: parsed.description ?? 'Receipt transaction'),
            inputMethod: 'receipt',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Receipt parsing failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingImage = false);
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
      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ReviewTransactionScreen(
            parsed: parsed,
            inputMethod: 'text',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Text parsing failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingText = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Transaction'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Photo'),
            Tab(text: 'Text'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Upload receipt or transaction screenshot',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _loadingImage ? null : () => _pickAndParse(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Take Photo'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _loadingImage ? null : () => _pickAndParse(ImageSource.gallery),
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Choose from Gallery'),
                ),
                if (_loadingImage) ...[
                  const SizedBox(height: 20),
                  const Center(child: CircularProgressIndicator()),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Describe your transaction',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text('Example: Spent 1500 at Burger King yesterday'),
                const SizedBox(height: 16),
                TextField(
                  controller: _textController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: 'Type transaction details...',
                  ),
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
                      : const Text('Parse Transaction'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
