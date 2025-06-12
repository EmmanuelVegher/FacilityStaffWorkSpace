// pages/call_tracker/today_call_page_web.dart (Example Snippet)
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Use Firestore
import '../../models/contact.dart';
import '../../services/firestore_service.dart'; // Use FirestoreService
// ... other necessary imports (shared_preferences, etc.)

class TodayCallsPageWeb extends StatefulWidget {
  const TodayCallsPageWeb({super.key});

  @override
  _TodayCallsPageWebState createState() => _TodayCallsPageWebState();
}

class _TodayCallsPageWebState extends State<TodayCallsPageWeb> {
  final FirestoreService firestoreService = FirestoreService();
  List<Contact> todayContacts = [];
  List<Contact> filteredContacts = [];
  bool isLoading = true; // Combined loading state for this page
  String searchQuery = "";
  String filterType = 'All';
  Set<String> duplicatePhones = {};

  // NMRS User Selection state variables (keep if needed)
  final List<Map<String, dynamic>> _users = [];
  String? _selectedFullName;
  final bool _isFetchingUsers = false;
  final bool _isEditingUser = false;
  final String _displayedFullName = '';


  @override
  void initState() {
    super.initState();
    // Load initial data - might need to adjust timing if dependent on NMRS user
    _loadInitialUser(); // Load NMRS user selection
    _fetchUsersFromMySQL(); // Fetch NMRS users (with security caveats)
    _loadTodayContactsFromFirestore(); // Load contacts from Firestore
  }

  // --- NMRS User selection logic (Keep as is, with security warnings) ---
  Future<void> _loadInitialUser() async { /* ... */ }
  Future<void> _fetchUsersFromMySQL() async { /* ... */ }


  // --- Load Contacts from Firestore ---
  Future<void> _loadTodayContactsFromFirestore() async {
    setState(() => isLoading = true);
    try {
      // Fetch all contacts from Firestore (adjust query as needed)
      // For "Today", you might query based on a 'nextVisitDate' field
      // This requires 'nextVisitDate' to be properly indexed in Firestore
      final now = DateTime.now();
      final todayStart = Timestamp.fromDate(DateTime(now.year, now.month, now.day));
      final todayEnd = Timestamp.fromDate(DateTime(now.year, now.month, now.day, 23, 59, 59));

      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('contacts') // Use your contacts collection path
          .where('nextVisitDate', isGreaterThanOrEqualTo: todayStart)
          .where('nextVisitDate', isLessThanOrEqualTo: todayEnd)
      // Add additional filters like ART status if needed and indexed
      // .where('artStatus', whereNotIn: ['Transferred Out', 'Death']) // Case-sensitive
          .orderBy('nextVisitDate')
          .get();

      List<Contact> fetchedContacts = snapshot.docs.map((doc) =>
          Contact.fromFirestore(doc.data() as Map<String, dynamic>, doc.id)
      ).toList();

      // Filter out excluded statuses client-side if necessary (Firestore 'not-in' has limits)
      final excludedArtStatusesLower = ["transferred out", "death"];
      final contacts = fetchedContacts.where((contact) {
        final artStatus = contact.artStatus?.toLowerCase();
        return !excludedArtStatusesLower.contains(artStatus);
      }).toList();


      // Calculate duplicates (same logic as mobile)
      final phoneCounts = <String, int>{};
      for (var contact in contacts) {
        if (contact.phoneNumber != null) {
          phoneCounts[contact.phoneNumber!] = (phoneCounts[contact.phoneNumber] ?? 0) + 1;
        }
      }
      final duplicates = phoneCounts.entries.where((e) => e.value > 1).map((e) => e.key).toSet();

      setState(() {
        todayContacts = contacts;
        duplicatePhones = duplicates;
        isLoading = false; // Set loading false before applying filters
      });
      _applyFilters(); // Apply filters after data is loaded
    } catch (e) {
      print("Error loading today's contacts from Firestore: $e");
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading contacts: $e')),
      );
    }
  }

  // --- Filtering Logic (operates on the list, no change needed) ---
  void _applyFilters() {
    setState(() {
      filteredContacts = todayContacts.where((contact) {
        // ... same search/filterType logic as mobile ...
        return true; // placeholder
      }).toList();
    });
  }
  void _onSearchChanged(String query) { /* ... */ _applyFilters();}
  void _onFilterSelected(String selectedFilter) { /* ... */ _applyFilters();}


  // --- Edit Dates (Saves to Firestore) ---
  void _editDates(BuildContext context, Contact contact) {
    // ... (Dialog UI remains the same) ...
    // In the 'Update' button's onPressed:
    // ... (update contact object fields locally) ...
    // await firestoreService.saveContact(contact); // Save updated contact
    // Navigator.pop(context);
    // _loadTodayContactsFromFirestore(); // Reload data
    // ... (show snackbar) ...
  }

  // --- REMOVED Methods for Web ---
  // _makeCall
  // _monitorCallLog
  // _updatePhoneNumberOnNMRS (unless using backend API)
  // _updateAddressOnNMRS (unless using backend API)
  // _syncPendingRecords (sync logic is different with Firestore)

  // --- Build Contact Card (Remove call button/status) ---
  Widget _buildContactCard(Contact contact) {
    // ... (Get artStatusDisplay, check for valid phone - maybe just for display) ...
    bool hasValidPhoneNumber = contact.phoneNumber != null && contact.phoneNumber!.isNotEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        title: Text(contact.name ?? 'N/A'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(contact.phoneNumber ?? 'N/A'),
            // ... Display other details (dates, address, NMRS sync status etc.) ...
            Text('ART_Status: ${contact.artStatus ?? 'N/A'}'),
            // ... display termination date, VL, sample date ...

            // ** REMOVED NMRS Update buttons (or conditionally show if using backend) **

          ],
        ),
        trailing: Wrap( // Keep Wrap for potential future actions
          spacing: 8,
          children: [
            IconButton( // Keep Edit button
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () => _editDates(context, contact),
            ),
            // ** REMOVED Call Button **
            // Optionally show phone icon that copies number:
            if (hasValidPhoneNumber)
              IconButton(
                icon: const Icon(Icons.content_copy, size: 18, color: Colors.grey),
                tooltip: 'Copy Phone Number',
                onPressed: () {
                  // Clipboard.setData(ClipboardData(text: contact.phoneNumber!));
                  // Fluttertoast.showToast(msg: 'Phone number copied');
                  // Requires flutter/services import and clipboard handling
                },
              ),
          ],
        ),
      ),
    );
  }


  // --- Build Method ---
  @override
  Widget build(BuildContext context) {
    // ... (NMRS user selection dropdown logic - keep if needed) ...

    return Scaffold(
      appBar: AppBar(
        title: const Text('Today\'s Visits (Web)'), // Changed title
        // actions: [
        //   // ** REMOVED Sync Button (Isar specific) **
        //   PopupMenuButton<String>(itemBuilder: (BuildContext context) {  }, /* ... Filter options ... */ ),
        // ],
      ),
      body: isLoading // Use the combined loading state
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: Column(
          children: [
            // ... (NMRS User Dropdown Row - Keep if using NMRS sync) ...
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField( // Search Bar
                onChanged: _onSearchChanged,
                // ... decoration ...
              ),
            ),
            if (!isLoading && todayContacts.isNotEmpty)
              const Padding( // Filter summary
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ... Text showing counts (filtered/total) ...
                    // ... Text showing update counts ...
                  ],
                ),
              ),
            Expanded( // List View
              child: filteredContacts.isEmpty
                  ? const Center(child: Text('No matching records'))
                  : ListView.builder(
                itemCount: filteredContacts.length,
                itemBuilder: (context, index) {
                  return _buildContactCard(filteredContacts[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}