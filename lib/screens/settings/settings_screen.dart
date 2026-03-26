import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _authService = AuthService();
  final _apiService = ApiService();

  bool _exporting = false;

  Future<void> _logout() async {
    await _authService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _export({required bool pdf}) async {
    setState(() => _exporting = true);
    try {
      final end = DateTime.now();
      final start = DateTime(end.year, end.month, 1);

      final bytes = pdf
          ? await _apiService.exportPdf(startDate: start, endDate: end)
          : await _apiService.exportCsv(startDate: start, endDate: end);

      final dir = await getTemporaryDirectory();
      final extension = pdf ? 'pdf' : 'csv';
      final file = File('${dir.path}/clearledger_export.$extension');
      await file.writeAsBytes(bytes);
      await OpenFilex.open(file.path);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export ready: ${file.path}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
              title: Text(user?.email ?? 'No email'),
              subtitle: const Text('Profile & account'),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf_outlined),
                  title: const Text('Export PDF (this month)'),
                  onTap: _exporting ? null : () => _export(pdf: true),
                ),
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.table_chart_outlined),
                  title: const Text('Export CSV (this month)'),
                  onTap: _exporting ? null : () => _export(pdf: false),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: _logout,
            ),
          ),
        ],
      ),
    );
  }
}
