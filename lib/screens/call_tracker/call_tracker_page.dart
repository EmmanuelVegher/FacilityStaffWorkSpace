// pages/call_tracker/call_tracker_page_web.dart (Web Version)
import 'package:service_delivery_workspace/screens/call_tracker/report_page.dart';
import 'package:service_delivery_workspace/screens/call_tracker/today_call_page.dart';
import 'package:service_delivery_workspace/screens/call_tracker/upcoming_appointment.dart';
import 'package:flutter/material.dart';

import 'contact_list.dart';
import 'import_contact_page.dart';
import 'missedAndIITPage.dart';
// Import WEB versions of your pages


class CallTrackerPageWeb extends StatefulWidget {
  const CallTrackerPageWeb({super.key});

  @override
  _CallTrackerPageWebState createState() => _CallTrackerPageWebState();
}

class _CallTrackerPageWebState extends State<CallTrackerPageWeb> {
  int _selectedIndex = 0;

  // List of WEB screens
  final List<Widget> _screens = [
    const ReportsPageWeb(), // Use the web reports page
    const TodayCallsPageWeb(),
    const MissedAndIITPageWeb(),
    const UpcomingAppointmentsPageWeb(),
    const ContactListPageWeb(),
    const ImportContactsPageWeb(),

  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Use Row for NavigationRail layout
      body: Row(
        children: <Widget>[
          // Conditionally show NavigationRail for wider screens
          LayoutBuilder(
            builder: (context, constraint) {
              // Example breakpoint, adjust as needed
              if (constraint.maxWidth > 600) {
                return NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (int index) {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                  labelType: NavigationRailLabelType.selected, // Or .all / .none
                  destinations: const <NavigationRailDestination>[

                    NavigationRailDestination(icon: Icon(Icons.assessment_outlined), selectedIcon: Icon(Icons.assessment), label: Text('Reports')),
                    NavigationRailDestination(icon: Icon(Icons.today_outlined), selectedIcon: Icon(Icons.today), label: Text('Today')),
                    NavigationRailDestination(icon: Icon(Icons.schedule_outlined), selectedIcon: Icon(Icons.schedule_rounded), label: Text('Missed')),
                    NavigationRailDestination(icon: Icon(Icons.upcoming_outlined), selectedIcon: Icon(Icons.upcoming), label: Text('Upcoming')),
                    NavigationRailDestination(icon: Icon(Icons.contacts_outlined), selectedIcon: Icon(Icons.contacts), label: Text('Contacts')),
                    NavigationRailDestination(icon: Icon(Icons.upload_file_outlined), selectedIcon: Icon(Icons.upload_file), label: Text('Import')),
                  ],
                );
              } else {
                // Return an empty container or handle differently for narrow screens
                return Container(); // Or potentially use BottomNavigationBar here if needed
              }
            },
          ),
          const VerticalDivider(thickness: 1, width: 1),
          // Main content area
          Expanded(
            child: _screens[_selectedIndex],
          ),
        ],
      ),
      // Optionally add BottomNavigationBar for narrow screens
      bottomNavigationBar: MediaQuery.of(context).size.width < 600
          ? BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.today), label: 'Today'),
          BottomNavigationBarItem(icon: Icon(Icons.schedule_rounded), label: 'Missed'),
          BottomNavigationBarItem(icon: Icon(Icons.upcoming), label: 'Upcoming'),
          BottomNavigationBarItem(icon: Icon(Icons.contacts), label: 'Contacts'),
          BottomNavigationBarItem(icon: Icon(Icons.upload_file), label: 'Import'),
          BottomNavigationBarItem(icon: Icon(Icons.assessment), label: 'Reports'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey, // Important for fixed type
        onTap: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed, // Ensures all items are visible
      )
          : null, // No bottom bar on wider screens
    );
  }
}