import 'package:flutter/material.dart';
import 'screens/customer_machines_screen.dart';
import 'screens/customer_pass_screen.dart';
import 'screens/customer_pt_diet_screen.dart';
import 'screens/customer_store_screen.dart';

class CustomerAppRoot extends StatefulWidget {
  const CustomerAppRoot({super.key});

  @override
  State<CustomerAppRoot> createState() => _CustomerAppRootState();
}

class _CustomerAppRootState extends State<CustomerAppRoot> {
  int _tabIndex = 0;

  static const _screens = [
    CustomerPassScreen(),
    CustomerMachinesScreen(),
    CustomerPtDietScreen(),
    CustomerStoreScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SmartGym Club (Customer App)'),
      ),
      body: _screens[_tabIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner_rounded),
            label: 'Club Pass',
          ),
          NavigationDestination(
            icon: Icon(Icons.play_circle_outline_rounded),
            label: 'Floor QR',
          ),
          NavigationDestination(
            icon: Icon(Icons.restaurant_menu_rounded),
            label: 'PT & Diet',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_fire_department_rounded),
            label: 'Fuel & PR',
          ),
        ],
      ),
    );
  }
}
