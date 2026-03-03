import 'package:flutter/material.dart';
import 'ui/auth_gate.dart';
import 'ui/home_recording_page.dart';
import 'ui/flights_list_page.dart';
import 'ui/pilot_profile_page.dart';

/// Main application widget for ParaglidingLog.
/// 
/// Integrates authentication with flight recording and existing pilot profile functionality
/// using a modern Material 3 design and proper navigation structure.
class ParaglidingLogApp extends StatelessWidget {
  const ParaglidingLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'The Borrowed Wings',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2196F3), // Sky blue theme
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const AuthGate(), // Use AuthGate to handle authentication routing
      routes: {
        '/flights': (context) => const FlightsListPage(),
        '/pilot': (context) => const PilotProfilePage(),
      },
    );
  }
}

/// Main navigation wrapper that provides bottom navigation between key app features.
/// This is shown after successful authentication and profile completion.
class MainNavigationWrapper extends StatefulWidget {
  const MainNavigationWrapper({super.key});

  @override
  State<MainNavigationWrapper> createState() => _MainNavigationWrapperState();
}

class _MainNavigationWrapperState extends State<MainNavigationWrapper> {
  int _currentIndex = 0;
  
  final List<Widget> _pages = [
    const HomeRecordingPage(),
    const FlightsListPage(),
    const PilotProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home),
            selectedIcon: Icon(Icons.home),
            label: 'Record',
          ),
          NavigationDestination(
            icon: Icon(Icons.list),
            selectedIcon: Icon(Icons.list),
            label: 'Flights',
          ),
          NavigationDestination(
            icon: Icon(Icons.person),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}