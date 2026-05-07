import 'package:flutter/material.dart';

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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.list_alt_outlined), label: 'Ledger'),
          NavigationDestination(icon: Icon(Icons.add_circle_outline), label: 'Add'),
          NavigationDestination(icon: Icon(Icons.menu), label: 'Menu'),
        ],
        onDestinationSelected: (value) {
          if (value == 3) {
            _scaffoldKey.currentState?.openDrawer();
            return;
          }
          setState(() => _index = value);
        },
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
    final colorScheme = Theme.of(context).colorScheme;
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: colorScheme.primary.withValues(alpha: 0.16),
                    child: Icon(Icons.account_balance_wallet_outlined, color: colorScheme.primary),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'ClearLedger',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tools, insights, and account rules',
                    style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.62)),
                  ),
                ],
              ),
            ),
            _DrawerItem(
              icon: Icons.pie_chart_outline,
              title: 'Budgets',
              subtitle: 'Limits and category progress',
              onTap: () => onOpenPage(const BudgetScreen()),
            ),
            _DrawerItem(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Accounts',
              subtitle: 'Cash, banks, cards, and routing',
              onTap: () => onOpenPage(const AccountsScreen()),
            ),
            _DrawerItem(
              icon: Icons.auto_awesome_outlined,
              title: 'AI Overview',
              subtitle: 'Once-daily spending analysis',
              onTap: () => onOpenPage(const AiOverviewScreen()),
            ),
            const Divider(height: 28),
            _DrawerItem(
              icon: Icons.settings_outlined,
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
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onTap: onTap,
    );
  }
}
