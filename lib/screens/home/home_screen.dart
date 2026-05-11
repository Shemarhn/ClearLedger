import 'package:flutter/material.dart';

import '../../widgets/dark_shell.dart';
import '../add_transaction/add_transaction_screen.dart';
import '../ai_overview/ai_overview_screen.dart';
import '../accounts/accounts_screen.dart';
import '../budgets/budget_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../ledger/ledger_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _index = 0;

  static const _screens = [
    DashboardScreen(),
    LedgerScreen(),
    AddTransactionScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _AppDrawer(onOpenPage: _openPage),
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).navigationBarTheme.backgroundColor,
          border: Border(
            top: BorderSide(
              color: Theme.of(context)
                  .colorScheme
                  .outlineVariant
                  .withValues(alpha: 0.45),
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.list_alt_outlined), label: 'Ledger'),
            NavigationDestination(icon: Icon(Icons.add_box_outlined), label: 'Add'),
            NavigationDestination(icon: Icon(Icons.tune_outlined), label: 'More'),
          ],
          onDestinationSelected: (value) {
            if (value == 3) {
              _scaffoldKey.currentState?.openDrawer();
              return;
            }
            setState(() => _index = value);
          },
        ),
      ),
    );
  }

  void _openPage(Widget page) {
    Navigator.of(context).pop();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }
}

class _AppDrawer extends StatelessWidget {
  const _AppDrawer({required this.onOpenPage});

  final void Function(Widget page) onOpenPage;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.62);
    return Drawer(
      backgroundColor: dark ? const Color(0xFF07131F) : scheme.surfaceContainerLowest,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 24, 18, 18),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 18, 8, 46),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppLogoMark(size: 54),
                  const SizedBox(height: 18),
                  Text(
                    'ClearLedger',
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 31,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tools, insights, and account rules',
                    style: TextStyle(
                      color: dark ? Colors.white.withValues(alpha: 0.84) : muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            _DrawerItem(
              glyph: AppGlyph.budget,
              title: 'Budgets',
              subtitle: 'Limits and category progress',
              onTap: () => onOpenPage(const BudgetScreen()),
            ),
            _DrawerItem(
              glyph: AppGlyph.accounts,
              title: 'Accounts',
              subtitle: 'Cash, banks, cards, and routing',
              onTap: () => onOpenPage(const AccountsScreen()),
            ),
            _DrawerItem(
              glyph: AppGlyph.insight,
              title: 'AI Overview',
              subtitle: 'Once-daily spending analysis',
              onTap: () => onOpenPage(const AiOverviewScreen()),
            ),
            const Divider(height: 34),
            _DrawerItem(
              glyph: AppGlyph.settings,
              title: 'Settings',
              subtitle: 'Theme, currency, exports, and security',
              onTap: () => onOpenPage(const SettingsScreen()),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.glyph,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final AppGlyph glyph;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: AppIconBadge(glyph: glyph, size: 42),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right),
        minLeadingWidth: 42,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        onTap: onTap,
      ),
    );
  }
}
