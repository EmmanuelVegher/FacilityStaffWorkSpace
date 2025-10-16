// pages/call_tracker/contact_list_web.dart
import 'package:call_log/call_log.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Clipboard
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:intl/intl.dart';
import 'package:mysql1/mysql1.dart';
import 'package:uuid/uuid.dart';
import '../../models/contact.dart';
import '../../models/contact_tracked.dart';
import '../../services/firestore_service.dart'; // Use FirestoreService
import 'package:shared_preferences/shared_preferences.dart';
// Remove mysql1 import if NMRS sync/edit is handled by backend
// import 'package:mysql1/mysql1.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'package:flutter/foundation.dart' show kIsWeb; // To check if running on web
import 'package:universal_html/html.dart' as html; // For web platform detection
import 'package:url_launcher/url_launcher.dart'; // For web tel: links

// For Clipboard


class ContactListPageWeb extends StatefulWidget {
  const ContactListPageWeb({super.key});

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
  final bool _isEditingUser = false;
  String _displayedFullName = '';
  List<Map<String, dynamic>> _users = []; // Maybe fetch from Firestore 'Staff' collection?
  bool _isMySQLConnected = false;
  bool _isFetchingUsers = false;

  String? _selectedFullName;
  String? trackedBy;
  String? designation;
  String? trackerFacilityLocation;
  String? firebaseAuthId;
  String? supervisor;
  String? supervisorEmail;

  String? trackerState;


  @override
  void initState() {
    super.initState();
    _loadInitialUser(); // Load saved NMRS user pref
    // Don't fetch MySQL users here unless absolutely necessary for filtering display
     _fetchUsersFromMySQL();
    // Data is loaded via StreamBuilder now
  }

  Future<void> _loadLoggedInUserInfo() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      final DocumentSnapshot<Map<String, dynamic>> snapshot =
      await FirebaseFirestore.instance.collection('Staff').doc(userId).get();
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data()!;
        final firstName = data['firstName'] as String? ?? '';
        final lastName = data['lastName'] as String? ?? '';
        setState(() {
          trackedBy = '$firstName $lastName';
          firebaseAuthId = userId;
          designation = data['designation'] as String? ?? '';
          trackerFacilityLocation = data['location'] as String? ?? '';
          supervisor = data['supervisor'] as String? ?? '';
          supervisorEmail = data['supervisorEmail'] as String? ?? '';
          trackerState = data['state'] as String? ?? '';
        });
      }
    }
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
  Future<void> _fetchUsersFromMySQL() async {
    setState(() {
      _isFetchingUsers = true;
      _isMySQLConnected = false; // Reset connection status at the start
    });
    final prefs = await SharedPreferences.getInstance();
    final host = prefs.getString('mysqlHost') ?? '';
    final port = int.tryParse(prefs.getString('mysqlPort') ?? '3306') ?? 3306;
    final user = prefs.getString('mysqlUser') ?? '';
    final password = prefs.getString('mysqlPassword') ?? '';
    final database = prefs.getString('mysqlDatabase') ?? '';

    if (host.isEmpty || user.isEmpty || database.isEmpty) {
      setState(() {
        _isFetchingUsers = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'MySQL settings are not configured. Please configure them in Import Contacts page.')),
      );
      return;
    }

    MySqlConnection? conn;
    try {
      final settings = ConnectionSettings(
        host: host,
        port: port,
        user: user,
        password: password,
        db: database,
      );
      conn = await MySqlConnection.connect(settings);
      setState(() {
        _isMySQLConnected = true;
      });
      var results = await conn.query(
          '''
          select userInfo.person_id,userInfo.FullName,userInfo.user_id ,providerInfo.provider_id from
(select A.person_id,concat(A.given_name," ",A.family_name) as FullName,B.user_id
from person_name as A,users AS B
where B.person_id = A.person_id and B.retired = 0) as userInfo
left join
(select provider_id,person_id from provider where retired = 0) as providerInfo
on userInfo.person_id = providerInfo.person_id
          ''');
      List<Map<String, dynamic>> usersData = [];
      Set<String> uniqueFullNames = {};
      for (var row in results) {
        String fullName = row['FullName'];
        if (!uniqueFullNames.contains(fullName)) {
          uniqueFullNames.add(fullName);
          usersData.add({
            'person_id': row['person_id'],
            'FullName': fullName,
            'user_id': row['user_id'],
            'provider_id': row['provider_id'],
          });
        }
      }
      print("usersData==$usersData");
      setState(() {
        _users = usersData;
      });
    } on MySqlException catch (e) {
      setState(() {
        _isMySQLConnected = false;
        _isFetchingUsers = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('MySQL Connection Failed: ${e.message}')),
      );
    } catch (e) {
      setState(() {
        _isMySQLConnected = false;
        _isFetchingUsers = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching users: $e')),
      );
    } finally {
      setState(() {
        _isFetchingUsers = false;
      });
      await conn?.close();
    }
  }



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
              content: const SingleChildScrollView( /* ... Dialog content fields ... */ ),
              actions: [
                TextButton(child: const Text('Cancel'), onPressed: () => Navigator.pop(context)),
                ElevatedButton(
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
                  child: isSaving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }


  Future<void> _updatePhoneNumberOnNMRS(Contact contact) async {
    final prefs = await SharedPreferences.getInstance();
    final host = prefs.getString('mysqlHost') ?? '';
    final port = int.tryParse(prefs.getString('mysqlPort') ?? '3306') ?? 3306;
    final user = prefs.getString('mysqlUser') ?? '';
    final password = prefs.getString('mysqlPassword') ?? '';
    final database = prefs.getString('mysqlDatabase') ?? '';
    final providerId = prefs.getInt('selected_provider_id'); // Get provider_id from shared preferences
    final userId = prefs.getInt('selected_user_id');


    if (host.isEmpty || user.isEmpty || database.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'NMRS connection settings are not configured. Please configure them in Import Contacts page.')),
      );
      return;
    }

    MySqlConnection? conn; // Declare conn outside try block for wider scope
    try {
      final settings = ConnectionSettings(
        host: host,
        port: port,
        user: user,
        password: password,
        db: database,
      );
      conn = await MySqlConnection.connect(settings); // Assign connection

      // Fetch Datim Code from NMRS
      const datimCodeQuery =
          'SELECT property_value FROM global_property WHERE property = "facility_datim_code" LIMIT 1';
      final datimCodeResult = await conn.query(datimCodeQuery);
      final nmrsDatimCode = datimCodeResult.isNotEmpty &&
          datimCodeResult.first.isNotEmpty
          ? datimCodeResult.first.first.toString()
          : null;

      final contactDatimCode = contact.datimCode;

      if (nmrsDatimCode == null ||
          contactDatimCode == null ||
          nmrsDatimCode != contactDatimCode) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Datim Code mismatch. Cannot update phone number on NMRS for this contact.')),
        );
        return; // Stop further execution if Datim codes don't match
      }

      final patientId = contact.patientId;
      final phoneNumber = contact.phoneNumber;
      final dateChanged = DateTime.now().toUtc();

      if (patientId == null || phoneNumber == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Could not update phone number on NMRS. Patient ID or Phone number is missing.')),
        );
        return;
      }

      const query =
          'UPDATE person_attribute SET value = ?, changed_by = ?, date_changed = ? WHERE person_id = ?'; // Assuming 9 is person_attribute_type_id for phone_number. You may need to verify this in your DB.
      await conn.query(query, [phoneNumber, userId,dateChanged, patientId]); // Added providerId to the query


      setState(() {}); // To rebuild the widget and reflect changes immediately

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Phone number updated on NMRS successfully')),
      );
    } on MySqlException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Failed to update phone number on NMRS. MySQL Exception: ${e.message}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Failed to update phone number on NMRS. Error: $e')),
      );
    } finally {
      conn?.close(); // Close connection in finally block to ensure it always runs
    }
  }

  Future<void> _updateAddressOnNMRS(Contact contact) async {
    final prefs = await SharedPreferences.getInstance();
    final host = prefs.getString('mysqlHost') ?? '';
    final port = int.tryParse(prefs.getString('mysqlPort') ?? '3306') ?? 3306;
    final user = prefs.getString('mysqlUser') ?? '';
    final password = prefs.getString('mysqlPassword') ?? '';
    final database = prefs.getString('mysqlDatabase') ?? '';
    final providerId = prefs.getInt('selected_provider_id'); // Get provider_id from shared preferences
    final userId = prefs.getInt('selected_user_id'); // Get provider_id from shared preferences


    if (host.isEmpty || user.isEmpty || database.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'NMRS connection settings are not configured. Please configure them in Import Contacts page.')),
      );
      return;
    }

    MySqlConnection? conn; // Declare conn outside try block for wider scope
    try {
      final settings = ConnectionSettings(
        host: host,
        port: port,
        user: user,
        password: password,
        db: database,
      );
      conn = await MySqlConnection.connect(settings); // Assign connection

      // Fetch Datim Code from NMRS
      const datimCodeQuery =
          'SELECT property_value FROM global_property WHERE property = "facility_datim_code" LIMIT 1';
      final datimCodeResult = await conn.query(datimCodeQuery);
      final nmrsDatimCode = datimCodeResult.isNotEmpty &&
          datimCodeResult.first.isNotEmpty
          ? datimCodeResult.first.first.toString()
          : null;

      final contactDatimCode = contact.datimCode;

      if (nmrsDatimCode == null ||
          contactDatimCode == null ||
          nmrsDatimCode != contactDatimCode) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Datim Code mismatch. Cannot update address on NMRS for this contact.')),
        );
        return; // Stop further execution if Datim codes don't match
      }

      final patientId = contact.patientId;
      final address = contact.address;
      final dateChanged = DateTime.now().toUtc();

      if (patientId == null || address == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Could not update address on NMRS. Patient ID or Address is missing.')),
        );
        return;
      }

      const query =
          'UPDATE person_address SET address2 = ?, changed_by = ? , date_changed = ? WHERE person_id = ?'; // Assuming 9 is person_attribute_type_id for phone_number. You may need to verify this in your DB.
      await conn.query(query, [address, userId,dateChanged, patientId]); // Added providerId to the query

      // contact.isAddressSyncedToNMRS = true;
      // await IsarService().updateContact(contact);

      setState(() {}); // To rebuild the widget and reflect changes immediately

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Address updated on NMRS successfully')),
      );
    } on MySqlException catch (e) {
      print('Failed to update phone number on NMRS. MySQL Exception: ${e.message}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
            Text('Failed to update phone number on NMRS. MySQL Exception: ${e.message}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Failed to update phone number on NMRS. Error: $e')),
      );
    } finally {
      conn?.close(); // Close connection in finally block to ensure it always runs
    }
  }


  Future<void> _makeCall(String phoneNumber, Contact contact) async { // Pass Contact object

    if (kIsWeb) {
      // --- Web Platform ---
      // Use url_launcher to open 'tel:' link
      final Uri telUri = Uri(scheme: 'tel', path: phoneNumber);
      try {
        if (await canLaunchUrl(telUri)) {
          await launchUrl(telUri);
          // NOTE: We CANNOT track call duration or status reliably on web
          // You might manually update the contact's callStatus here if needed,
          // but it won't reflect the actual call outcome.
          // Example:
          // contact.callStatus = "Call Initiated (Web)";
          // await firestoreService.saveContact(contact); // Update Firestore if desired
        } else {
          Fluttertoast.showToast(msg: 'Could not launch phone dialer.');
        }
      } catch (e) {
        Fluttertoast.showToast(msg: 'Failed to launch dialer: $e');
      }

    } else {
      // --- Native Mobile Platform (Android/iOS) ---
      // Keep your original logic using flutter_phone_direct_caller
      // Important: Ensure permission_handler and flutter_phone_direct_caller
      // are correctly handled (e.g., using conditional imports/logic if sharing code)

      // Example placeholder for native logic (replace with your actual mobile code)

      if (await Permission.phone.request().isGranted) {
        try {
          bool? callInitiated = await FlutterPhoneDirectCaller.callNumber(phoneNumber);
          if (callInitiated == true) {
             print("Native call initiated for $phoneNumber");
             _monitorCallLog(phoneNumber, contact); // Call log monitoring ONLY on native
          } else {
             Fluttertoast.showToast(msg: 'Failed to initiate native call.');
          }
        } catch (e) {
          Fluttertoast.showToast(msg: 'Failed to make native call: $e');
        }
      } else {
        Fluttertoast.showToast(msg: 'Phone permission denied');
      }

      Fluttertoast.showToast(msg: 'Direct calling not configured for this platform.'); // Fallback if native code not present
    }

  }


  Future<Iterable<CallLogEntry>> getCalllogs(){
    return CallLog.get();
  }

  CircleAvatar getAvator(CallType callType){
    switch(callType){
      case CallType.outgoing:
        return const CircleAvatar(maxRadius: 30,foregroundColor: Colors.green,backgroundColor: Colors.greenAccent);
      case CallType.missed:
        return CircleAvatar(maxRadius: 30,foregroundColor: Colors.red[400],backgroundColor: Colors.red[400]);
      default:
        return CircleAvatar(maxRadius: 30,foregroundColor: Colors.indigo[700],backgroundColor: Colors.indigo[700]);
    }
  }

  String formatDare(DateTime dt){
    return DateFormat('d-MM-y H:m:s').format(dt);
  }

  Text getTitle(CallLogEntry entry){
    if(entry.name == null) {
      return Text(entry.number!);
    }
    if(entry.name!.isEmpty) {
      return Text(entry.number!);
    } else {
      return Text(entry.name!);
    }
  }

  String getTime(int duration){
    Duration d1 = Duration(seconds:duration);
    String formattedDuration = "";
    if(d1.inHours > 0){
      formattedDuration += "${d1.inHours}h ";
    }

    if(d1.inMinutes > 0){
      formattedDuration += "${d1.inMinutes}m ";
    }

    if(d1.inSeconds > 0){
      formattedDuration += "${d1.inSeconds}s ";
    }
    if(formattedDuration.isEmpty) {
      return "0s";
    }
    return formattedDuration;
  }

  Future<void> _monitorCallLog(String phoneNumber, Contact originalContact) async {
    print("_monitorCallLog started for $phoneNumber");


    if (await Permission.phone.isGranted) {
      DateTime callStartTime = DateTime.now();
      CallLogEntry? latestCallEntry;
      int maxAttempts = 500;
      int attempts = 0;
      bool callLogged = false;

      while (attempts < maxAttempts && !callLogged) {
        attempts++;
        print("Attempt $attempts to query call log for $phoneNumber");
        try {
          final DateTime now = DateTime.now();
          final int from = callStartTime.subtract(const Duration(minutes: 1)).millisecondsSinceEpoch;
          final int to = now.millisecondsSinceEpoch;

          Iterable<CallLogEntry> entries = await CallLog.query(
            dateFrom: from,
            dateTo: to,
            number: phoneNumber,
          );

          print("Call log entries found in this attempt: ${entries.length}");

          latestCallEntry = entries.firstOrNull;

          if (latestCallEntry != null && latestCallEntry.callType == CallType.outgoing) {
            print("Relevant outgoing call log found for $phoneNumber.");
            callLogged = true;
            break;
          } else {
            print("No relevant outgoing call log found yet for $phoneNumber, waiting...");
            await Future.delayed(const Duration(seconds: 3));
          }
        } catch (e) {
          _showSnackBar('Error reading call log: $e');
          print('Error reading call log: $e');
          return;
        }
      }

      // --- Prepare ContactTracked Data ---
      ContactTracked contactTracked;

      if (callLogged && latestCallEntry != null) {
        int totalDurationSeconds = latestCallEntry.duration ?? 0;
        String callStatus = _getCallStatus(latestCallEntry);
        print("Call details - Duration: $totalDurationSeconds Seconds, Status: $callStatus");

        contactTracked = ContactTracked(
          // UUID is generated by the constructor now
          name: originalContact.name ?? 'N/A',
          phoneNumber: originalContact.phoneNumber ?? 'N/A',
          // Use the actual call timestamp if available, otherwise now
          lastVisitDate: latestCallEntry.timestamp != null
              ? DateTime.fromMillisecondsSinceEpoch(latestCallEntry.timestamp!)
              : DateTime.now(),
          callDuration: totalDurationSeconds,
          callStatus: callStatus,
          state: originalContact.state,
          facilityName: originalContact.facilityName,
          uniqueID: originalContact.uniqueID,
          datimCode: originalContact.datimCode,
          trackedBy: trackedBy,
          designation: designation,
          firebaseAuthId: firebaseAuthId, // Ensure this is populated
          supervisorName: supervisor,
          supervisorEmail: supervisorEmail,
          trackerFacilityLocation: trackerFacilityLocation,
          dateTracked: DateTime.now(), // When the tracking record is created
          patientId: originalContact.patientId,
          dateNextVisitChanged: originalContact.dateNextVisitChanged,
          datePhoneNumberUpdated: originalContact.datePhoneNumberUpdated,
          dateAddressChanged: originalContact.dateAddressChanged,
          artStatus: originalContact.artStatus,
          dateOfTermination: originalContact.dateOfTermination,
          sampleCollectionDate: originalContact.sampleCollectionDate,
          currentViralLoad: originalContact.currentViralLoad,
          // isUpdated and isSynced default to false
        );

        // Update the original contact's status in Isar as well
        originalContact.callStatus = callStatus;
       // await IsarService().updateContact(originalContact); // Save original contact update

        _showSnackBar('Call logged - Duration: $totalDurationSeconds Seconds - Status: $callStatus');

      } else {
        // Case where no detailed call log was found after attempts
        print("No outgoing call log found for $phoneNumber after multiple attempts or within timeout.");
        contactTracked = ContactTracked(
          name: originalContact.name ?? 'N/A',
          phoneNumber: originalContact.phoneNumber ?? 'N/A',
          lastVisitDate: callStartTime, // Use the time call was initiated
          callStatus: "Unknown (No Log Detail)", // Indicate lack of detail
          state: originalContact.state,
          facilityName: originalContact.facilityName,
          uniqueID: originalContact.uniqueID,
          datimCode: originalContact.datimCode,
          trackedBy: trackedBy,
          designation: designation,
          firebaseAuthId: firebaseAuthId,
          supervisorName: supervisor,
          supervisorEmail: supervisorEmail,
          trackerFacilityLocation: trackerFacilityLocation,
          dateTracked: DateTime.now(),
          patientId: originalContact.patientId,
          dateNextVisitChanged: originalContact.dateNextVisitChanged,
          datePhoneNumberUpdated: originalContact.datePhoneNumberUpdated,
          dateAddressChanged: originalContact.dateAddressChanged,
          artStatus: originalContact.artStatus,
          dateOfTermination: originalContact.dateOfTermination,
          sampleCollectionDate: originalContact.sampleCollectionDate,
          currentViralLoad: originalContact.currentViralLoad,
          // isUpdated and isSynced default to false
        );

        // Update original contact status
        originalContact.callStatus = "Unknown (No Log Detail)";
       // await IsarService().updateContact(originalContact);

        _showSnackBar('No call log details found for $phoneNumber.');
      }
      // --- End Prepare ContactTracked Data ---


      // --- Save to Isar Initially ---
      // Save with isUpdated = false, isSynced = false initially
    //  await IsarService().saveContactTracked(contactTracked);
//      print("ContactTracked saved initially to Isar with ID: ${contactTracked.id}, UUID: ${contactTracked.uuid}");
      // --- End Save to Isar Initially ---


      try {
        // Validate necessary fields for the path
        final state = contactTracked.state;
        final facilityName = contactTracked.facilityName;
        final userId = contactTracked.firebaseAuthId; // Use the stored Firebase Auth ID
        // final uuid = contactTracked.uuid;

        if (state != null && facilityName != null && userId != null && userId.isNotEmpty) {
          final formattedDate = DateFormat('dd-MMM-yyyy').format(contactTracked.dateTracked ?? DateTime.now());
          final uuid2 = const Uuid().v4();
          final firestorePath = '/Reports/$trackerState/CallTracker/$trackerFacilityLocation/$formattedDate/$firebaseAuthId/$firebaseAuthId/$uuid2';

          print("Firestore Path: $firestorePath");

          // Set flags before attempting sync in case of immediate failure below this point
          contactTracked.isUpdated = true;
          contactTracked.isSynced = false; // Assume failure until success

          // Convert to JSON (Map)
          final data = contactTracked.toJson();

          // Perform the Firestore set operation
          await FirebaseFirestore.instance.doc(firestorePath).set(data);

          // ** SUCCESS ** Update flags in the local object
          contactTracked.isSynced = true; // Mark as synced
          print("Firestore sync successful for UUID: $uuid2");

          // ** IMPORTANT: Update the record in Isar AGAIN with the new flags **
         // await IsarService().saveContactTracked(contactTracked);
          print("ContactTracked updated in Isar with sync status for UUID: $uuid2");

          _showSnackBar('Call record synced to cloud.');

        } else {
          print("Firestore sync skipped: Missing required fields for path (state, facilityName, or userId).");
          _showSnackBar('Sync skipped: Missing required data.');
          // Keep isUpdated/isSynced as false (already saved like this)
        }

      } catch (e) {
        print("Firestore sync failed: $e");
        _showSnackBar('Firestore sync failed: $e');
        // Sync failed, isUpdated is true (attempt was made), isSynced remains false
        // We already saved contactTracked with isUpdated=true, isSynced=false before the try block
        // Optionally, update Isar again to ensure isSynced is false if you didn't set it before try
        // contactTracked.isSynced = false; // Explicitly set again on error
        // await IsarService().saveContactTracked(contactTracked);
        // Note: The current logic saves with isUpdated=true/isSynced=false before the 'try',
        // so no extra save is needed here unless you change that initial setting.
      }


      // Refresh the UI list
    //  _loadContacts();
    } else {
      _showSnackBar('Phone permission not granted.');
    }
  }




  String _getCallStatus(CallLogEntry call) {
    if (call.callType == CallType.outgoing) {
      if (call.duration != null && call.duration! > 0) {
        return "Answered";
      } else {
        return "Missed"; // Consider it missed if outgoing and no duration or 0
      }
    }
    switch (call.callType) {
      case CallType.incoming:
        return "Incoming";
      case CallType.missed:
        return "Missed";
      case CallType.rejected:
        return "Rejected";
      case CallType.blocked:
        return "Blocked";
      default:
        return "Unknown";
    }
  }


  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'missed call':
      case 'not answered':
      case 'call failed':
      case 'call dropped':
        return Colors.red;
      case 'call busy':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }



  // --- Build Contact Card (Remove call/sync elements) ---
  Widget _buildContactCard(Contact contact) {
    String artStatusDisplay = contact.artStatus?.trim() ?? '';
    bool hasValidPhoneNumber = contact.phoneNumber != null && contact.phoneNumber!.isNotEmpty;

    // --- Platform Check for Call Button ---
    bool showCallButton = false;
    if (kIsWeb) {
      // On Web, check if the underlying OS is likely mobile
      try {
        final userAgent = html.window.navigator.userAgent.toLowerCase();
        showCallButton = userAgent.contains('android') ||
            userAgent.contains('iphone') ||
            userAgent.contains('ipad');
      } catch (e) {
        // Fallback if userAgent access fails (less common)
        print("Could not detect platform from user agent: $e");
        showCallButton = false;
      }
    } else {
      // On native mobile, assume we can always try to show the call button
      // (Permission checks happen inside _makeCall)
      showCallButton = true;
    }
    // --- End Platform Check ---

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
            if (contact.callStatus != null)
              Text(
                'Last status: ${contact.callStatus}',
                style: TextStyle(
                  color: _getStatusColor(
                      contact.callStatus!),
                  fontWeight: FontWeight.bold,
                ),
              ),
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

            contact.isPhoneNumberUpdated == true &&
                contact.isSyncedToNMRS == false
                ? Padding(
              padding: const EdgeInsets.only(
                  top: 8.0),
              child: ElevatedButton.icon(
                onPressed: () =>
                    _updatePhoneNumberOnNMRS(
                        contact),
                icon: const Icon(
                    Icons.info_outline),
                label: const Text(
                    'Update PhoneNumber on NMRS',style: TextStyle(color: Colors.white)),
                style:
                ElevatedButton.styleFrom(
                  backgroundColor:
                  Colors.blueAccent,
                ),
              ),
            )
                : const SizedBox.shrink(),
            contact.isAddressUpdated == true &&
                contact.isAddressSyncedToNMRS == false
                ? Padding(
              padding: const EdgeInsets.only(
                  top: 8.0),
              child: ElevatedButton.icon(
                onPressed: () =>
                    _updateAddressOnNMRS(
                        contact),
                icon: const Icon(
                    Icons.info_outline),
                label: const Text(
                    'Update Address on NMRS',style: TextStyle(color: Colors.white)),
                style:
                ElevatedButton.styleFrom(
                  backgroundColor:
                  Colors.blueAccent,
                ),
              ),
            )
                : const SizedBox.shrink(),
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
                icon: const Icon(Icons.content_copy, size: 18, color: Colors.grey),
                tooltip: 'Copy Phone Number',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: contact.phoneNumber!));
                  Fluttertoast.showToast(msg: 'Phone number copied');
                },
              ),
            // *** Conditionally show the Call button ***
            if (showCallButton && hasValidPhoneNumber)
              IconButton(
                icon: const Icon(Icons.call, color: Colors.green),
                tooltip: 'Call ${contact.phoneNumber}', // Add tooltip
                // Use the updated _makeCall function
                onPressed: () => _makeCall(contact.phoneNumber!, contact),
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
              ...artStatuses.map((status) => PopupMenuItem(value: status, child: Text(status))),
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
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: () {
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