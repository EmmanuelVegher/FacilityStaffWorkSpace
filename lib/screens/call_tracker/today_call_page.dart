// pages/call_tracker/today_call_page_web.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Clipboard
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/contact.dart';
import '../../services/firestore_service.dart'; // FirestoreService
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';

class TodayCallsPageWeb extends StatefulWidget {
  @override
  _TodayCallsPageWebState createState() => _TodayCallsPageWebState();
}

class _TodayCallsPageWebState extends State<TodayCallsPageWeb> {
  final FirestoreService firestoreService = FirestoreService();
  List<Contact> allTodayContacts = []; // From stream
  List<Contact> filteredContacts = [];
  bool _isInitialLoad = true;
  String searchQuery = "";
  String filterType = 'All'; // Actual/Calculated
  Set<String> duplicatePhones = {};

  // NMRS User Selection state (keep if needed)
  bool _isEditingUser = false;
  String _displayedFullName = '';
  String? _selectedFullName;
  List<Map<String, dynamic>> _users = []; // Fetch from Firestore 'Staff' if needed

  @override
  void initState() {
    super.initState();
    _loadInitialUser();
    // _fetchUsersFromMySQL(); // Replace with Firestore fetch if needed
    // Data loaded via StreamBuilder
  }

  // Load NMRS User Preference (Keep)
  Future<void> _loadInitialUser() async { /* ... */ }
  // Fetch NMRS Users (Replace with Firestore 'Staff' fetch if needed)
  // Future<void> _fetchUsersFromMySQL() async { /* ... */ }


  // --- Filtering Logic (Operates on the list from StreamBuilder) ---
  void _applyFilters(List<Contact> contactsFromStream) {
    final searchLower = searchQuery.toLowerCase();
    // Calculate duplicates
    final phoneCounts = <String, int>{};
    for (var contact in contactsFromStream) { if (contact.phoneNumber != null) phoneCounts[contact.phoneNumber!] = (phoneCounts[contact.phoneNumber] ?? 0) + 1; }
    final duplicates = phoneCounts.entries.where((e) => e.value > 1).map((e) => e.key).toSet();

    final filtered = contactsFromStream.where((contact) {
      final matchesSearch =
          (contact.name?.toLowerCase().contains(searchLower) ?? false) ||
              (contact.phoneNumber?.toLowerCase().contains(searchLower) ?? false) ||
              (contact.artStatus?.toLowerCase().contains(searchLower) ?? false) ||
              (contact.uniqueID?.toLowerCase().contains(searchLower) ?? false) ||
              (contact.state?.toLowerCase().contains(searchLower) ?? false) ||
              (contact.facilityName?.toLowerCase().contains(searchLower) ?? false);
      final matchesFilter = filterType == 'All' ||
          (filterType == 'Actual' && contact.appointmentStatus == 'Actual Next Appointment') ||
          (filterType == 'Calculated' && contact.appointmentStatus == 'Calculated Next Appointment');
      return matchesSearch && matchesFilter;
    }).toList();

    if(mounted) {
      setState(() {
        allTodayContacts = contactsFromStream;
        filteredContacts = filtered;
        duplicatePhones = duplicates;
        _isInitialLoad = false;
      });
    }
  }

  void _onSearchChanged(String query) { searchQuery = query; _applyFilters(allTodayContacts); }
  void _onFilterSelected(String selectedFilter) { filterType = selectedFilter; _applyFilters(allTodayContacts); }

  // --- Edit Dates (Uses FirestoreService) ---
  void _editDates(BuildContext context, Contact contact) {
    // ... (Dialog UI same as contact_list_web) ...
    // On Save: await firestoreService.saveContact(contact); ...
  }

  // --- REMOVED Methods for Web ---
  // _makeCall, _monitorCallLog, _updatePhoneNumberOnNMRS, _updateAddressOnNMRS, _syncPendingRecords


  // --- Build Contact Card (Same as contact_list_web) ---
  Widget _buildContactCard(Contact contact) {
    // ... Use the same _buildContactCard implementation from contact_list_web.dart ...
    return Card(/* ... */);
  }

  @override
  Widget build(BuildContext context) {
    // --- Calculate start/end Timestamps for today ---
    final now = DateTime.now();
    final startToday = Timestamp.fromDate(DateTime(now.year, now.month, now.day));
    final endToday = Timestamp.fromDate(DateTime(now.year, now.month, now.day, 23, 59, 59));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Today\'s Visits (Web)'),
        actions: [
          // ** REMOVED Sync Button **
          PopupMenuButton<String>( // Filter button
            icon: const Icon(Icons.filter_list),
            onSelected: _onFilterSelected,
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'All', child: Text('All Appointments')),
              PopupMenuItem(value: 'Actual', child: Text('Actual Next Appointment')),
              PopupMenuItem(value: 'Calculated', child: Text('Calculated Next Appointment')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // --- NMRS User Selection Row (Keep if needed) ---
          // Padding( ... ),
          // --- Search Bar ---
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(onChanged: _onSearchChanged, /* ... decoration ... */),
          ),
          // --- StreamBuilder for Today's Contacts ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('contacts') // Your contacts collection
                  .where('nextVisitDate', isGreaterThanOrEqualTo: startToday)
                  .where('nextVisitDate', isLessThanOrEqualTo: endToday)
              // Add index on nextVisitDate in Firestore
                  .orderBy('nextVisitDate')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                if (snapshot.connectionState == ConnectionState.waiting && _isInitialLoad) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData
                    //|| snapshot.docs.isEmpty
                ) {
                  _isInitialLoad = false;
                  return const Center(child: Text('No visits scheduled for today.'));
                }

                final fetchedContacts = snapshot.data!.docs.map((doc) => Contact.fromFirestore(doc.data() as Map<String, dynamic>, doc.id)).toList();

                // Filter excluded ART statuses client-side
                final excludedLower = ["transferred out", "death"];
                final contactsFromStream = fetchedContacts.where((c) => !excludedLower.contains(c.artStatus?.toLowerCase())).toList();

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if(mounted) _applyFilters(contactsFromStream);
                });

                if (_isInitialLoad) return const Center(child: CircularProgressIndicator()); // Show loader until filters applied

                if (filteredContacts.isEmpty) return const Center(child: Text('No matching visits found for today.'));

                // Display List
                return Column(
                  children: [
                    //Padding( /* ... Count display ... */),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredContacts.length,
                        itemBuilder: (context, index) => _buildContactCard(filteredContacts[index]),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}