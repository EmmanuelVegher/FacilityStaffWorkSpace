// pages/call_tracker/missedAndIITPage_web.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Clipboard
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/contact.dart';
import '../../services/firestore_service.dart'; // FirestoreService
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';


class MissedAndIITPageWeb extends StatefulWidget {
  @override
  _MissedAndIITPageWebState createState() => _MissedAndIITPageWebState();
}

class _MissedAndIITPageWebState extends State<MissedAndIITPageWeb> {
  final FirestoreService firestoreService = FirestoreService();
  List<Contact> allContacts = []; // Combined list from stream
  List<Contact> missedAppointments = [];
  List<Contact> iitClients = [];
  List<Contact> filteredMissed = [];
  List<Contact> filteredIIT = [];

  Set<String> duplicatePhones = {};
  bool _isInitialLoad = true; // Track initial stream load
  String searchQuery = "";
  String filterType = 'All'; // For Actual/Calculated appointment status

  // NMRS User Selection state (keep if needed)
  bool _isEditingUser = false;
  String _displayedFullName = '';
  String? _selectedFullName;


  @override
  void initState() {
    super.initState();
    _loadInitialUser();
    // Data is loaded via StreamBuilder
  }

  // Load NMRS User Preference (Keep)
  Future<void> _loadInitialUser() async {
    final prefs = await SharedPreferences.getInstance();
    if(mounted) {
      setState(() {
        _displayedFullName = prefs.getString('selected_FullName') ?? '';
      });
    }
  }

  // --- Data Processing and Filtering (Called from StreamBuilder) ---
  void _processAndFilterData(List<Contact> contactsFromStream) {
    // Segregate based on ART_Status (case-insensitive check)
    final missed = contactsFromStream.where((c) => c.artStatus?.toLowerCase() == 'missed appointment').toList();
    final iit = contactsFromStream.where((c) => c.artStatus?.toLowerCase() == 'iit').toList();

    // Calculate duplicate phones across all fetched contacts
    final phoneCounts = <String, int>{};
    for (var contact in contactsFromStream) { // Use the full list for duplicate check
      if (contact.phoneNumber != null) {
        phoneCounts[contact.phoneNumber!] = (phoneCounts[contact.phoneNumber] ?? 0) + 1;
      }
    }
    final duplicates = phoneCounts.entries.where((e) => e.value > 1).map((e) => e.key).toSet();

    // Apply search and type filters
    final searchLower = searchQuery.toLowerCase();
    final tempFilteredMissed = missed.where((c) => _matchesFilters(c, searchLower, filterType)).toList();
    final tempFilteredIIT = iit.where((c) => _matchesFilters(c, searchLower, filterType)).toList();

    // Update state
    if (mounted) {
      setState(() {
        allContacts = contactsFromStream; // Store the full list from stream
        missedAppointments = missed; // Store segregated lists
        iitClients = iit;
        filteredMissed = tempFilteredMissed;
        filteredIIT = tempFilteredIIT;
        duplicatePhones = duplicates;
        _isInitialLoad = false; // Mark initial load complete
      });
    }
  }

  // Helper for filter logic
  bool _matchesFilters(Contact contact, String searchLower, String filterType) {
    final matchesSearch =
        (contact.name?.toLowerCase().contains(searchLower) ?? false) ||
            (contact.phoneNumber?.toLowerCase().contains(searchLower) ?? false) ||
            (contact.artStatus?.toLowerCase().contains(searchLower) ?? false) || // Should match anyway, but good practice
            (contact.uniqueID?.toLowerCase().contains(searchLower) ?? false) ||
            (contact.state?.toLowerCase().contains(searchLower) ?? false) ||
            (contact.facilityName?.toLowerCase().contains(searchLower) ?? false);

    final matchesFilter = filterType == 'All' ||
        (filterType == 'Actual' && contact.appointmentStatus == 'Actual Next Appointment') ||
        (filterType == 'Calculated' && contact.appointmentStatus == 'Calculated Next Appointment');

    return matchesSearch && matchesFilter;
  }


  void _onSearchChanged(String query) {
    searchQuery = query;
    _processAndFilterData(allContacts); // Re-apply filters to the current full list
  }

  void _onFilterSelected(String selectedFilter) {
    filterType = selectedFilter;
    _processAndFilterData(allContacts); // Re-apply filters
  }

  // --- Edit Dates (Uses FirestoreService) ---
  void _editDates(BuildContext context, Contact contact) {
    // ... (Dialog UI remains the same as contact_list_web) ...
    // In the 'Update' button's onPressed:
    // ... (update contact object fields locally) ...
    // await firestoreService.saveContact(contact); // Save updated contact
    // Navigator.pop(context);
    // Fluttertoast.showToast(msg: 'Contact updated successfully');
    // StreamBuilder will automatically reflect the changes
  }

  // --- REMOVED Methods for Web ---
  // _makeCall, _monitorCallLog, _updatePhoneNumberOnNMRS, _updateAddressOnNMRS, _syncPendingRecords

  // --- Build Contact Card (Same as contact_list_web) ---
  Widget _buildContactCard(Contact contact) {
    // ... Use the same _buildContactCard implementation from contact_list_web.dart ...
    // (Ensure it doesn't have call/sync buttons)
    String artStatusDisplay = contact.artStatus?.trim() ?? '';
    bool hasValidPhoneNumber = contact.phoneNumber != null && contact.phoneNumber!.isNotEmpty;
    return Card(/* ... ListTile structure same as contact_list_web ... */);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Missed & IIT Contacts (Web)'),
        actions: [
          // ** REMOVED Sync Button **
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            tooltip: "Filter by Appointment Type",
            onSelected: _onFilterSelected,
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'All', child: Text('All Appointments')),
              PopupMenuItem(value: 'Actual', child: Text('Actual Next Appointment')),
              PopupMenuItem(value: 'Calculated', child: Text('Calculated Next Appointment')),
            ],
          ),
        ],
      ),
      body: Column( // Use Column to stack Search and StreamBuilder
        children: [
          // --- NMRS User Selection Row (Keep if needed) ---
          // Padding( ... NMRS user dropdown ... ),

          // --- Search Bar ---
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search within Missed/IIT lists...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(icon: Icon(Icons.clear), onPressed: () {
                  // searchController.clear(); // Assuming you add a controller
                  _onSearchChanged('');
                })
                    : null,
              ),
            ),
          ),

          // --- StreamBuilder for fetching ALL relevant contacts ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>( // Stream the whole collection, filter client-side
              stream: FirebaseFirestore.instance
                  .collection('contacts')
              // Add index in Firestore for 'artStatus'
                  .where('artStatus', whereIn: ['Missed Appointment', 'IIT', 'missed appointment', 'iit']) // Case-sensitive, include variations if needed
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting && _isInitialLoad) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData
                    //|| snapshot.docs.isEmpty
                ) {
                  _isInitialLoad = false; // Mark load complete even if empty
                  return const Center(child: Text('No Missed or IIT contacts found.'));
                }

                // Process and filter the data from the stream
                final contactsFromStream = snapshot.data!.docs.map((doc) =>
                    Contact.fromFirestore(doc.data() as Map<String, dynamic>, doc.id)).toList();

                // Schedule the processing and filtering after the build phase
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _processAndFilterData(contactsFromStream);
                  }
                });


                // Build UI based on the processed state variables (filteredMissed, filteredIIT)
                // Avoid building directly from snapshot.data here, use state variables
                if (_isInitialLoad) {
                  // Still show loading until first process/filter is done
                  return const Center(child: CircularProgressIndicator());
                }

                return SingleChildScrollView( // Allows scrolling if content overflows
                  child: Column(
                    children: [
                      ExpansionTile(
                        title: Text('Missed Appointments (${filteredMissed.length})'),
                        initiallyExpanded: true,
                        children: [
                          if (filteredMissed.isNotEmpty)
                            ...filteredMissed.map((contact) => _buildContactCard(contact)).toList()
                          else if (missedAppointments.isNotEmpty && filteredMissed.isEmpty)
                            const Padding(padding: EdgeInsets.all(16), child: Center(child: Text('No matching missed appointments found.')))
                          else
                            const Padding(padding: EdgeInsets.all(16), child: Center(child: Text('No missed appointments.'))),
                        ],
                      ),
                      const Divider(height: 20, thickness: 1),
                      ExpansionTile(
                        title: Text('Interruption-In-Treatment (IIT) (${filteredIIT.length})'),
                        initiallyExpanded: true, // Expand IIT too, or based on preference
                        children: [
                          if (filteredIIT.isNotEmpty)
                            ...filteredIIT.map((contact) => _buildContactCard(contact)).toList()
                          else if (iitClients.isNotEmpty && filteredIIT.isEmpty)
                            const Padding(padding: EdgeInsets.all(16), child: Center(child: Text('No matching IIT clients found.')))
                          else
                            const Padding(padding: EdgeInsets.all(16), child: Center(child: Text('No IIT clients.'))),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}