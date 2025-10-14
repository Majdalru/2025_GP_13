import 'package:flutter/material.dart';
import '../widgets/app_drawer.dart';
import 'home_page.dart';
import 'browse_page.dart';
import 'meds_summary_page.dart';
import 'location_page.dart';
import '/medmain.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  String elderlyName = 'Elderly name';

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(
        elderlyName: elderlyName,
        // This now handles the "Monthly Overview" link
        onTapArrowToMedsSummary: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const MedsSummaryPage()));
        },
        // 👇 2. Add the new required parameter for the arrow icon
        onTapArrowToMedmain: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const Medmain()));
        },
        // This is for the emergency button
        onTapEmergency: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const LocationPage()));
        },
      ),
      const BrowsePage(),
    ];

    return Scaffold(
      drawer: AppDrawer(
        elderlyName: elderlyName,
        onLogoutConfirmed: () {
          // TODO: تنفيذ تسجيل الخروج
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Logged out')));
        },
      ),
      appBar: AppBar(title: Text(_index == 0 ? elderlyName : 'Browse')),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: pages[_index],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.apps),
            selectedIcon: Icon(Icons.apps_outlined),
            label: 'Browse',
          ),
        ],
      ),
    );
  }
}
