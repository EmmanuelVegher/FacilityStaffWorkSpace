// pages/call_tracker/contact_list_web.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Clipboard
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/contact.dart';
import '../../services/firestore_service.dart'; // Use FirestoreService
import 'package:shared_preferences/shared_preferences.dart';
// Remove mysql1 import if NMRS sync/edit is handled by backend
// import 'package:mysql1/mysql1.dart';
import 'package:fluttertoast/fluttertoast.dart';


class ContactListPageWeb extends StatefulWidget {
  @override
  _ContactListPageWebState createState() => _ContactListPageWebState();
}

class _ContactListPageWebState extends State<ContactListPageWeb> {
  final FirestoreService firestoreService = FirestoreService();
  TextEditingController searchController = TextEditingController();
  String searchQuery = '';
  String filterType = 'All';
  String artStatusFilter = 'All';
  Set<String> duplicatePhones = {}; // Keep for highlighting

  // State for data fetched from Firestore stream
  List<Contact> allContacts = [];
  List<Contact> filteredContacts = [];
  bool _isInitialLoad = true; // Track initial stream load

  // NMRS User Selection state variables (keep if linking display/filter)
  // bool _isFetchingUsers = false; // May not be needed if user list isn't fetched here
  bool _isEditingUser = false;
  String _displayedFullName = '';
  List<Map<String, dynamic>> _users = []; // Maybe fetch from Firestore 'Staff' collection?
  String? _selectedFullName;


  @override
  void initState() {
    super.initState();
    _loadInitialUser(); // Load saved NMRS user pref
    // Don't fetch MySQL users here unless absolutely necessary for filtering display
    // _fetchUsersFromMySQL();
    // Data is loaded via StreamBuilder now
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

  // NMRS User Fetching (Remove or adapt to fetch from Firestore 'Staff')
  // Future<void> _fetchUsersFromMySQL() async { ... } // Remove this

  // --- Filtering Logic (Operates on the list from StreamBuilder) ---
  void _applyFilters(List<Contact> contactsFromStream) {
    final searchLower = searchQuery.toLowerCase();
    // Calculate duplicates based on the current list from the stream
    final phoneCounts = <String, int>{};
    for (var contact in contactsFromStream) {
      if (contact.phoneNumber != null) {
        phoneCounts[contact.phoneNumber!] = (phoneCounts[contact.phoneNumber] ?? 0) + 1;
      }
    }
    final duplicates = phoneCounts.entries.where((e) => e.value > 1).map((e) => e.key).toSet();

    final filtered = contactsFromStream.where((contact) {
      final matchesSearch =
          (contact.name?.toLowerCase().contains(searchLower) ?? false) ||
              (contact.phoneNumber?.toLowerCase().contains(searchLower) ?? false) ||
              (contact.artStatus?.toLowerCase().contains(searchLower) ?? false) ||
              (contact.uniqueID?.toLowerCase().contains(searchLower) ?? false) ||
              (contact.state?.toLowerCase().contains(searchLower) ?? false) ||
              (contact.facilityName?.toLowerCase().contains(searchLower) ?? false);

      final matchesApptFilter = filterType == 'All' ||
          (filterType == 'Actual' && contact.appointmentStatus == 'Actual Next Appointment') ||
          (filterType == 'Calculated' && contact.appointmentStatus == 'Calculated Next Appointment');

      String artStatusDisplay = contact.artStatus ?? '';
      final matchesArtStatusFilter = artStatusFilter == 'All' || artStatusDisplay == artStatusFilter;

      return matchesSearch && matchesApptFilter && matchesArtStatusFilter;
    }).toList();

    // Update state after filtering
    if(mounted) { // Check if widget is still in the tree
      setState(() {
        allContacts = contactsFromStream; // Update the base list
        filteredContacts = filtered;
        duplicatePhones = duplicates;
        _isInitialLoad = false; // Mark initial load complete
      });
    }
  }

  void _onSearchChanged(String query) {
    searchQuery = query;
    _applyFilters(allContacts); // Re-apply filters to the current full list
  }

  void _onFilterSelected(String selectedFilter) {
    if (selectedFilter == 'Actual' || selectedFilter == 'Calculated' || selectedFilter == 'All Appointment') {
      filterType = selectedFilter == 'All Appointment' ? 'All' : selectedFilter;
      artStatusFilter = 'All';
    } else { // Assumes it's an ART status filter
      filterType = 'All';
      artStatusFilter = selectedFilter;
    }
    _applyFilters(allContacts); // Re-apply filters
  }


  // --- Edit Contact (Uses FirestoreService) ---
  void _editDates(BuildContext context, Contact contact) {
    DateTime? originalLastVisitDate = contact.lastVisitDate;
    DateTime? originalNextVisitDate = contact.nextVisitDate;
    String originalPhoneNumber = contact.phoneNumber ?? '';
    String originalAddress = contact.address ?? '';

    DateTime? selectedLastVisitDate = originalLastVisitDate;
    DateTime? selectedNextVisitDate = originalNextVisitDate;
    TextEditingController phoneNumberController = TextEditingController(text: originalPhoneNumber);
    TextEditingController addressController = TextEditingController(text: originalAddress);
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder( // Use StatefulBuilder for dialog state
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Contact Info'),
              content: SingleChildScrollView( /* ... Dialog content fields ... */ ),
              actions: [
                TextButton(child: const Text('Cancel'), onPressed: () => Navigator.pop(context)),
                ElevatedButton(
                  child: isSaving ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Update'),
                  onPressed: isSaving ? null : () async {
                    setDialogState(() => isSaving = true);
                    try {
                      final newPhone = phoneNumberController.text.trim().replaceAll(RegExp(r'[^0-9+]'), '');
                      final newAddress = addressController.text.trim();

                      // Update contact object fields
                      // ... (set flags like isPhoneNumberUpdated if needed for logic/display) ...
                      if (newPhone != originalPhoneNumber) contact.phoneNumber = newPhone;
                      if (newAddress != originalAddress) contact.address = newAddress;
                      contact.lastVisitDate = selectedLastVisitDate;
                      contact.nextVisitDate = selectedNextVisitDate;
                      // ... (update appointmentStatus, etc.) ...

                      await firestoreService.saveContact(contact); // Save updated contact
                      Navigator.pop(context);
                      Fluttertoast.showToast(msg: 'Contact updated successfully');
                      // StreamBuilder will automatically reflect the changes, no manual reload needed
                    } catch (e) {
                      Fluttertoast.showToast(msg: 'Error updating contact: $e');
                    } finally {
                      if(mounted) { // Check mount status before calling setDialogState
                        setDialogState(() => isSaving = false);
                      }
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- REMOVED Methods for Web ---
  // _makeCall, _monitorCallLog, _updatePhoneNumberOnNMRS, _updateAddressOnNMRS, _syncPendingRecords


  // --- Build Contact Card (Remove call/sync elements) ---
  Widget _buildContactCard(Contact contact) {
    String artStatusDisplay = contact.artStatus?.trim() ?? '';
    bool hasValidPhoneNumber = contact.phoneNumber != null && contact.phoneNumber!.isNotEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        title: Text(contact.name ?? 'N/A'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              contact.phoneNumber ?? 'N/A',
              style: TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.bold,
                  color: duplicatePhones.contains(contact.phoneNumber) ? Colors.red : Colors.black),
            ),
            if (contact.nextVisitDate != null) Text('Scheduled: ${DateFormat('MMM dd, yyyy').format(contact.nextVisitDate!)}', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 14, fontWeight: FontWeight.bold)),
            // ** Removed Call Status Display **
            const SizedBox(height: 6),
            const Divider(),
            Text('Address: ${contact.address ?? 'N/A'}', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),
            Text('Appointment Status: ${contact.appointmentStatus ?? 'N/A'}', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),
            Text('State: ${contact.state ?? 'N/A'}', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),
            Text('Facility: ${contact.facilityName ?? 'N/A'}', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),
            Text('Unique ID: ${contact.uniqueID ?? 'N/A'}', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),
            Text('DATIM Code: ${contact.datimCode ?? 'N/A'}', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),
            Text('ART Status: ${artStatusDisplay.isNotEmpty ? artStatusDisplay : 'N/A'}', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),
            if (artStatusDisplay.toLowerCase() != 'active' && contact.dateOfTermination != null) Text('Termination Date: ${DateFormat('MMM dd, yyyy').format(contact.dateOfTermination!)}', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),
            // ... Display Sample Date / VL ...
            Text('Sample Date: ${contact.sampleCollectionDate != null ? DateFormat('MMM dd, yyyy').format(contact.sampleCollectionDate!) : 'N/A'}', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),
            Text('Last VL: ${contact.currentViralLoad ?? 'N/A'}', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),

            // ** REMOVED NMRS Update Buttons **
          ],
        ),
        trailing: Wrap(
          spacing: 8,
          children: [
            IconButton( // Keep Edit
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () => _editDates(context, contact),
            ),
            // ** REMOVED Call Button **
            if (hasValidPhoneNumber) // Optional: Add Copy button
              IconButton(
                icon: Icon(Icons.content_copy, size: 18, color: Colors.grey),
                tooltip: 'Copy Phone Number',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: contact.phoneNumber!));
                  Fluttertoast.showToast(msg: 'Phone number copied');
                },
              ),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    // NMRS User selection dropdown (Keep if filtering/display depends on it)
    // final List<Map<String, dynamic>> usersForDropdown = _users.where((user) => user['FullName'] != _displayedFullName).toList();

    // --- Define ART Status Filters (Example) ---
    // You might want to fetch these dynamically or define them statically
    const List<String> artStatuses = ['All', 'Active', 'Missed Appointment', 'IIT', 'Transferred Out', 'Death', 'Discontinued Care'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Contacts (Web)'),
        actions: [
          // ** REMOVED Sync Button **
          // Filter Button
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            tooltip: "Filter List",
            onSelected: _onFilterSelected,
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'All Appointment', child: Text('All Appointments')),
              const PopupMenuItem(value: 'Actual', child: Text('Actual Next Appointment')),
              const PopupMenuItem(value: 'Calculated', child: Text('Calculated Next Appointment')),
              const PopupMenuDivider(),
              const PopupMenuItem(enabled: false, child: Text("Filter by ART Status:", style: TextStyle(fontWeight: FontWeight.bold))),
              ...artStatuses.map((status) => PopupMenuItem(value: status, child: Text(status))).toList(),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // --- NMRS User Selection Row (Keep if needed) ---
          // Padding(
          //    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          //    child: Row( /* ... NMRS User Dropdown and Edit Button ... */ ),
          // ),
          // --- Search Bar ---
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search by name, phone, ART Status, Unique ID, state, facility...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(icon: Icon(Icons.clear), onPressed: () {
                  searchController.clear();
                  _onSearchChanged('');
                })
                    : null,
              ),
            ),
          ),
          // --- StreamBuilder for Contact List ---
          Expanded(
            child: StreamBuilder<List<Contact>>(
              stream: firestoreService.streamAllContacts(), // Use the stream
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error loading contacts: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting && _isInitialLoad) {
                  // Show loader only on the very first load
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No contacts found.'));
                }

                // Data is available, apply filters
                // Important: Call _applyFilters only when the stream data changes
                // We can compare snapshot.data with allContacts, but for simplicity,
                // we re-apply filters whenever the stream updates.
                // Avoid calling setState directly inside build. Schedule it.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) { // Ensure widget is still mounted
                    _applyFilters(snapshot.data!);
                  }
                });


                // Display based on filteredContacts state variable
                if (filteredContacts.isEmpty && !_isInitialLoad) {
                  return const Center(child: Text("No matching records found."));
                }

                return Column( // Wrap ListView in Column to add count header
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Showing ${filteredContacts.length} of ${allContacts.length} contacts',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    // Update Counts (Calculate from filtered list or all list)
                    // Text("Next Appt Updated: ${filteredContacts.where((c) => c.dateNextVisitChanged != null).length}"),
                    // Text("Phone Updated: ${filteredContacts.where((c) => c.datePhoneNumberUpdated != null).length}"),
                    // Text("Address Updated: ${filteredContacts.where((c) => c.dateAddressChanged != null).length}"),

                    Expanded( // Make ListView take remaining space
                      child: ListView.builder(
                        itemCount: filteredContacts.length,
                        itemBuilder: (context, index) {
                          return _buildContactCard(filteredContacts[index]);
                        },
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