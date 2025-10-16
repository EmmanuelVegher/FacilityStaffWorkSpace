// pages/call_tracker/import_contact_page_web.dart (Web Version)
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart'; // Works on web
import 'package:csv/csv.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:mysql1/mysql1.dart'; // Keep for NMRS (with caveats)
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_html/html.dart' as html; // Import for web download
import 'dart:typed_data';

// Import your FirestoreService and web-adapted models
import '../../models/contact.dart';
import '../../services/firestore_service.dart';

// *** ADD VCF Parsing library dependency in pubspec.yaml if needed ***
// Example: import 'package:simple_vcard_parser/simple_vcard_parser.dart';

class ImportContactsPageWeb extends StatefulWidget {
  const ImportContactsPageWeb({super.key});

  @override
  _ImportContactsPageWebState createState() => _ImportContactsPageWebState();
}

class _ImportContactsPageWebState extends State<ImportContactsPageWeb> {
  // ... Keep controllers (_nameController, _phoneController, etc.) ...
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  // ... other controllers for manual entry ...
  final TextEditingController _lastVisitController = TextEditingController();
  final TextEditingController _nextVisitController = TextEditingController();

  // ... Keep MySQL controllers (with security warning) ...
  final TextEditingController _mysqlHostController = TextEditingController();
  // ... other MySQL controllers ...
  final TextEditingController _nextAppointmentStartDateController = TextEditingController();
  final TextEditingController _nextAppointmentEndDateController = TextEditingController();


  String? _selectedState; // Keep state/facility for manual entry/NMRS lookup
  String? _selectedFacilityName;
  // ... other state variables for manual entry ...

  String? uploadedFileName; // Track uploaded file name
  List<int>? uploadedFileBytes; // Store bytes for parsing
  bool isImporting = false;
  bool isDatabaseImporting = false; // For NMRS date range import
  bool isDatabaseImporting1 = false; // For NMRS all import

  // Use FirestoreService
  final FirestoreService firestoreService = FirestoreService();

  // NMRS Settings state variables
  bool showMysqlDetailsInput = false;
  bool _isEditingSettings = false;
  Map<String, String> _savedSettings = {};

  final TextEditingController _uniqueIDController = TextEditingController();
  final TextEditingController _datimCodeController = TextEditingController();
  final TextEditingController _sampleCollectionDateController = TextEditingController();
  final TextEditingController _currentViralLoadController = TextEditingController();
  String? _selectedAppointmentType = "Calculated Next Appointment"; // Default?


  // NMRS Controllers

  final TextEditingController _mysqlPortController = TextEditingController(text: '3306');
  final TextEditingController _mysqlUserController = TextEditingController();
  final TextEditingController _mysqlPasswordController = TextEditingController();
  final TextEditingController _mysqlDatabaseController = TextEditingController();
  final TextEditingController _mysqlTimeoutController = TextEditingController(text: '600'); // Added




  // Location data cache (optional optimization)
  final Map<String, LocationModel?> _locationCache = {};
  List<String> _statesList = [];
  Map<String, List<String>> _facilitiesMap = {};


  @override
  void initState() {
    super.initState();
    _loadSavedSettings(); // Load NMRS settings
    _loadLocationData(); // Load states/facilities for dropdowns
  }

  @override
  void dispose() {
    // Dispose all controllers
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _lastVisitController.dispose();
    _nextVisitController.dispose();
    _uniqueIDController.dispose();
    _datimCodeController.dispose();
    _sampleCollectionDateController.dispose();
    _currentViralLoadController.dispose();
    _mysqlHostController.dispose();
    _mysqlPortController.dispose();
    _mysqlUserController.dispose();
    _mysqlPasswordController.dispose();
    _mysqlDatabaseController.dispose();
    _mysqlTimeoutController.dispose();
    _nextAppointmentStartDateController.dispose();
    _nextAppointmentEndDateController.dispose();
    super.dispose();
  }


  // --- Location Data Loading ---
  Future<void> _loadLocationData() async {
    // Replace this with fetching states/facilities from Firestore if stored there
    // Example placeholder if you don't have them in Firestore yet:
    // setState(() {
    //   _statesList = ["State A", "State B"];
    //   _facilitiesMap = {"State A": ["Facility A1", "Facility A2"], "State B": ["Facility B1"]};
    // });
    // Ideally, fetch from Firestore collection 'locations'
    try {
      // Fetch all locations from Firestore (or structure it better)
      // Example: Query distinct states, then facilities per state
      // This part depends heavily on how you store locations in Firestore
      print("Loading location data from Firestore..."); // Placeholder
      // Simulate loading
      await Future.delayed(const Duration(seconds: 1));
      setState(() {
        _statesList = ["Placeholder State 1", "Placeholder State 2"];
        _facilitiesMap = {"Placeholder State 1": ["Facility P1", "Facility P2"]};
      });

    } catch (e) {
      print("Error loading location data: $e");
    }
  }

// --- Get Datim Code (Lookup in Firestore or cache) ---
  Future<String?> _getDatimCodeByFacilityName(String? facilityName) async {
    if (facilityName == null || facilityName.isEmpty) return null;
    // Ideally, fetch from Firestore 'locations' collection
    // Example placeholder:
    if (facilityName == "Facility P1") return "DATIM_P1";
    if (facilityName == "Facility P2") return "DATIM_P2";
    return null;
    // Replace with actual Firestore lookup:
    // final location = await firestoreService.getLocationByFacilityName(facilityName);
    // return location?.datimCode;
  }

  // --- NMRS Settings Logic (Keep as is, but ideally move to backend) ---
  Future<void> _loadSavedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedSettings = {
        'host': prefs.getString('mysqlHost') ?? '',
        'port': prefs.getString('mysqlPort') ?? '',
        'user': prefs.getString('mysqlUser') ?? '',
        // 'password': prefs.getString('mysqlPassword') ?? '', // Avoid storing password directly if possible
        'database': prefs.getString('mysqlDatabase') ?? '',
        'timeout': prefs.getString('mysqlTimeout') ?? '600',
      };
      _mysqlPasswordController.text = prefs.getString('mysqlPassword') ?? ''; // Load password separately
      showMysqlDetailsInput = _savedSettings['host']!.isEmpty; // Use ! after checking
    });
    _populateSettingsFields();
  }

  Future<void> _saveSettings() async {
    final host = _mysqlHostController.text;
    final port = int.tryParse(_mysqlPortController.text) ?? 3306;
    final user = _mysqlUserController.text;
    final password = _mysqlPasswordController.text;
    final database = _mysqlDatabaseController.text;
    final timeout = int.tryParse(_mysqlTimeoutController.text) ?? 600;

    if (host.isEmpty || user.isEmpty || database.isEmpty || timeout <= 0) {
      Fluttertoast.showToast(msg: 'MySQL details are required (Host, User, Database, valid Timeout).');
      return;
    }

    // ** SECURITY WARNING **
    print("WARNING: Testing MySQL connection directly from web client.");
    // *******************

    try {
      final settings = ConnectionSettings(
        host: host, port: port, user: user, password: password, db: database,
        timeout: Duration(seconds: timeout),
      );
      // Test connection (optional but recommended)
      final conn = await MySqlConnection.connect(settings);
      await conn.close(); // Close immediately after test

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('mysqlHost', host);
      await prefs.setString('mysqlPort', _mysqlPortController.text);
      await prefs.setString('mysqlUser', _mysqlUserController.text);
      await prefs.setString('mysqlPassword', _mysqlPasswordController.text); // Store password securely if possible
      await prefs.setString('mysqlDatabase', _mysqlDatabaseController.text);
      await prefs.setString('mysqlTimeout', _mysqlTimeoutController.text);
      _loadSavedSettings(); // Reload saved settings display
      setState(() { _isEditingSettings = false; showMysqlDetailsInput = false; });
      Fluttertoast.showToast(msg: 'NMRS Connection settings saved and tested successfully.');
    } on MySqlException catch (e) {
      Fluttertoast.showToast(msg: 'NMRS Connection Failed: ${e.message}', gravity: ToastGravity.CENTER, toastLength: Toast.LENGTH_LONG);
    } catch (e) {
      Fluttertoast.showToast(msg: 'An unexpected error occurred: $e', gravity: ToastGravity.CENTER, toastLength: Toast.LENGTH_LONG);
    }
  }

  void _populateSettingsFields() { /* ... Same as mobile ... */ }
  void _editSettings() { /* ... Same as mobile ... */ }
  void _cancelEditSettings() { /* ... Same as mobile ... */ }

  // --- File Picking for Web ---
  Future<void> _pickAndReadFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'vcf'], // Allow CSV and VCF
      withData: true, // Crucial for web to get bytes directly
    );

    if (result != null && result.files.single.bytes != null) {
      setState(() {
        uploadedFileName = result.files.single.name;
        uploadedFileBytes = result.files.single.bytes;
        isImporting = false; // Reset importing state
      });
      Fluttertoast.showToast(msg: "File selected: $uploadedFileName");
    } else {
      setState(() {
        uploadedFileName = null;
        uploadedFileBytes = null;
      });
      Fluttertoast.showToast(msg: "No file selected or failed to read file.");
    }
  }

  // --- Contact Importing Logic (Web) ---

  Future<void> _processUploadedFile() async {
    if (uploadedFileBytes == null || uploadedFileName == null) {
      Fluttertoast.showToast(msg: "Please select a file first.");
      return;
    }

    setState(() => isImporting = true);
    int importedCount = 0;

    try {
      // if (uploadedFileName!.toLowerCase().endsWith('.csv')) {
      //   importedCount = await _importContactsFromCsv(uploadedFileBytes!);
      // } else if (uploadedFileName!.toLowerCase().endsWith('.vcf')) {
      //   importedCount = await _importContactsFromVcf(uploadedFileBytes!);
      // } else {
      //   Fluttertoast.showToast(msg: "Unsupported file type. Please use .csv or .vcf");
      // }

      if (importedCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully imported $importedCount contacts.')),
        );
      } else {
        // Handle case where parsing might have failed or file was empty
        Fluttertoast.showToast(msg: "No contacts were imported. Check file format or content.");
      }
    } catch (e) {
      print("Error processing file: $e");
      Fluttertoast.showToast(msg: "Error importing contacts: ${e.toString()}");
    } finally {
      setState(() {
        isImporting = false;
        // Optionally clear file selection after import
        // uploadedFileName = null;
        // uploadedFileBytes = null;
      });
    }
  }


  // // --- CSV Parsing (Adapt to use FirestoreService) ---
  // Future<int> _importContactsFromCsv1(List<int> fileBytes) async {
  //   // ... (CSV parsing logic is similar to mobile) ...
  //   final csvString = utf8.decode(fileBytes); // Use utf8.decode
  //   final csvTable = const CsvToListConverter().convert(csvString);
  //   final header = csvTable.isNotEmpty ? csvTable[0].map((e) => e.toString().trim().toLowerCase()).toList() : []; // Normalize header
  //   final rows = csvTable.skip(1).toList();
  //
  //   // Find indices (case-insensitive)
  //   int nameIndex = header.indexOf('name');
  //   int phoneIndex = header.indexOf('phone_number');
  //   // ... find other indices ...
  //   int addressIndex = header.indexOf('address');
  //   int lastVisitDateIndex = header.indexOf('last_visit_date');
  //   int nextVisitDateIndex = header.indexOf('next_visit_date');
  //   int stateIndex = header.indexOf('state');
  //   int facilityNameIndex = header.indexOf('facilityname'); // Check common variations
  //   int uniqueIDIndex = header.indexOf('uniqueid');
  //   int datimCodeIndex = header.indexOf('datimcode');
  //   int artStatusIndex = header.indexOf('art_status');
  //   int appointmentStatusIndex = header.indexOf('appointmentstatus');
  //   // ... add other fields as needed
  //
  //   // Basic validation
  //   if (nameIndex == -1 || phoneIndex == -1 ) { // Add other mandatory fields if needed
  //     throw Exception("CSV must contain 'name' and 'phone_number' columns.");
  //   }
  //
  //   List<Contact> contactsToSave = [];
  //   int count = 0;
  //
  //   for (var row in rows) {
  //     // Ensure row has enough columns for expected indices
  //     if (row.length <= nameIndex || row.length <= phoneIndex) continue; // Skip malformed rows
  //
  //     String? phoneNumber = row[phoneIndex]?.toString().trim();
  //     // Basic phone number cleaning (example)
  //     if (phoneNumber != null) {
  //       phoneNumber = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), ''); // Keep digits and '+'
  //       if (phoneNumber.isEmpty) phoneNumber = null;
  //     }
  //
  //     // Skip if essential data is missing
  //     if (row[nameIndex]?.toString().trim().isEmpty ?? true) continue;
  //     if (phoneNumber == null) continue;
  //
  //
  //     final contact = Contact(
  //       name: row[nameIndex]?.toString().trim(),
  //       phoneNumber: phoneNumber,
  //       // Safely parse dates and other fields
  //       address: (addressIndex != -1 && row.length > addressIndex) ? row[addressIndex]?.toString().trim() : null,
  //       lastVisitDate: (lastVisitDateIndex != -1 && row.length > lastVisitDateIndex && row[lastVisitDateIndex].toString().isNotEmpty)
  //           ? DateTime.tryParse(row[lastVisitDateIndex].toString())
  //           : null,
  //       nextVisitDate: (nextVisitDateIndex != -1 && row.length > nextVisitDateIndex && row[nextVisitDateIndex].toString().isNotEmpty)
  //           ? DateTime.tryParse(row[nextVisitDateIndex].toString())
  //           : null,
  //       state: (stateIndex != -1 && row.length > stateIndex) ? row[stateIndex]?.toString().trim() : null,
  //       facilityName: (facilityNameIndex != -1 && row.length > facilityNameIndex) ? row[facilityNameIndex]?.toString().trim() : null,
  //       uniqueID: (uniqueIDIndex != -1 && row.length > uniqueIDIndex) ? row[uniqueIDIndex]?.toString().trim() : null,
  //       datimCode: (datimCodeIndex != -1 && row.length > datimCodeIndex) ? row[datimCodeIndex]?.toString().trim() : null,
  //       artStatus: (artStatusIndex != -1 && row.length > artStatusIndex) ? row[artStatusIndex]?.toString().trim() : null,
  //       appointmentStatus: (appointmentStatusIndex != -1 && row.length > appointmentStatusIndex) ? row[appointmentStatusIndex]?.toString().trim() : 'Calculated Next Appointment', // Default if missing?
  //
  //       // ... add other fields ...
  //     );
  //     contactsToSave.add(contact);
  //     count++;
  //   }
  //
  //   if (contactsToSave.isNotEmpty) {
  //     // Use FirestoreService to save
  //     await firestoreService.saveAllContacts(contactsToSave);
  //   }
  //   return count;
  // }

  // --- VCF Parsing (Requires a library or manual implementation) ---
// --- VCF Parsing ---

  // --- CSV Parsing (Adapt to use FirestoreService) ---
  Future<int> _importContactsFromCsv(Uint8List fileBytes) async {
    final csvString = utf8.decode(fileBytes);
    final List<List<dynamic>> csvTable = const CsvToListConverter(eol: '\n', fieldDelimiter: ',').convert(csvString); // Handle different line endings/delimiters if needed

    if (csvTable.isEmpty) return 0;

    final header = csvTable[0].map((e) => e.toString().trim().toLowerCase()).toList();
    final rows = csvTable.skip(1).toList();

    int nameIndex = header.indexOf('name');
    int phoneIndex = header.indexOf('phone_number');
    int patientIdIndex = header.indexOf('patient_id'); // Make optional? Decide based on needs
    int addressIndex = header.indexOf('address');
    int lastVisitDateIndex = header.indexOf('last_visit_date');
    int nextVisitDateIndex = header.indexOf('next_visit_date');
    int stateIndex = header.indexOf('state');
    int facilityNameIndex = header.indexOf('facilityname');
    int uniqueIDIndex = header.indexOf('uniqueid');
    int datimCodeIndex = header.indexOf('datimcode');
    int artStatusIndex = header.indexOf('art_status');
    int appointmentStatusIndex = header.indexOf('appointmentstatus');
    int sampleCollectionDateIndex = header.indexOf('sample_collection_date');
    int currentViralLoadIndex = header.indexOf('currentviralload');

    if (nameIndex == -1 || phoneIndex == -1) {
      throw Exception("CSV must contain 'name' and 'phone_number' columns.");
    }

    List<Contact> contactsToSave = [];
    int count = 0;

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      // Basic row validation
      if (row.length < header.length) {
        print("Skipping row ${i + 2}: Incorrect number of columns.");
        continue;
      }
      String? name = row[nameIndex]?.toString().trim();
      String? phone = row[phoneIndex]?.toString().trim().replaceAll(RegExp(r'[^0-9+]'), '');

      if (name == null || name.isEmpty || phone == null || phone.isEmpty) {
        print("Skipping row ${i + 2}: Missing name or phone number.");
        continue;
      }

      // Safely get other fields
      int? patientId = (patientIdIndex != -1 && row[patientIdIndex] != null) ? int.tryParse(row[patientIdIndex].toString()) : null;
      String? address = (addressIndex != -1) ? row[addressIndex]?.toString().trim() : null;
      DateTime? lastVisit = (lastVisitDateIndex != -1 && row[lastVisitDateIndex].toString().isNotEmpty) ? DateTime.tryParse(row[lastVisitDateIndex].toString()) : null;
      DateTime? nextVisit = (nextVisitDateIndex != -1 && row[nextVisitDateIndex].toString().isNotEmpty) ? DateTime.tryParse(row[nextVisitDateIndex].toString()) : null;
      String? state = (stateIndex != -1) ? row[stateIndex]?.toString().trim() : null;
      String? facilityName = (facilityNameIndex != -1) ? row[facilityNameIndex]?.toString().trim() : null;
      String? uniqueID = (uniqueIDIndex != -1) ? row[uniqueIDIndex]?.toString().trim() : null;
      String? datimCode = (datimCodeIndex != -1) ? row[datimCodeIndex]?.toString().trim() : null;
      String? artStatus = (artStatusIndex != -1) ? row[artStatusIndex]?.toString().trim() : null;
      String? apptStatus = (appointmentStatusIndex != -1) ? row[appointmentStatusIndex]?.toString().trim() : 'Calculated Next Appointment';
      DateTime? sampleDate = (sampleCollectionDateIndex != -1 && row[sampleCollectionDateIndex].toString().isNotEmpty) ? DateTime.tryParse(row[sampleCollectionDateIndex].toString()) : null;
      String? viralLoad = (currentViralLoadIndex != -1) ? row[currentViralLoadIndex]?.toString().trim() : null;


      // Add contact
      contactsToSave.add(Contact(
        name: name, phoneNumber: phone, patientId: patientId, address: address,
        lastVisitDate: lastVisit, nextVisitDate: nextVisit, state: state,
        facilityName: facilityName, uniqueID: uniqueID, datimCode: datimCode,
        artStatus: artStatus, appointmentStatus: apptStatus,
        sampleCollectionDate: sampleDate, currentViralLoad: viralLoad,
      ));
      count++;
    }

    if (contactsToSave.isNotEmpty) {
      await firestoreService.saveAllContacts(contactsToSave);
    }
    return count;
  }

  // Future<int> _importContactsFromVcf(Uint8List fileBytes) async {
  //   final vcfString = utf8.decode(fileBytes);
  //   List<Contact> contactsToSave = [];
  //   int count = 0;
  //
  //   try {
  //     final parser = VCardParser(vcfString);
  //     final vcards = await parser.parse(); // Parse the VCF data
  //
  //     for (final vcard in vcards) {
  //       String? name = vcard.formattedName?.value ??
  //           vcard.structuredName?.buildName() ??
  //           vcard.nickname?.values.firstOrNull;
  //       // Get multiple phone numbers if available
  //       List<String> phones = (vcard.telephone ?? [])
  //           .map((tel) => tel.value?.replaceAll(RegExp(r'[^0-9+]'), '') ?? '')
  //           .where((p) => p.isNotEmpty)
  //           .toList();
  //
  //       if (name != null && name.isNotEmpty && phones.isNotEmpty) {
  //         // For simplicity, just take the first valid phone number
  //         String primaryPhone = phones.first;
  //
  //         // Extract address (example - might need refinement based on VCF structure)
  //         String? address;
  //         if (vcard.address != null && vcard.address!.isNotEmpty) {
  //           address = vcard.address!.first.buildAddress(); // simple_vcard_parser helper
  //         }
  //
  //         contactsToSave.add(Contact(
  //           name: name.trim(),
  //           phoneNumber: primaryPhone,
  //           address: address?.trim(),
  //           // VCF usually doesn't contain visit dates, ART status, etc.
  //           // These would need to be added manually later or from other sources.
  //         ));
  //         count++;
  //       } else {
  //         print("Skipping VCard: Missing name or phone. Name: $name, Phones: $phones");
  //       }
  //     }
  //   } catch (e) {
  //     print("VCF Parsing Error: $e");
  //     throw Exception("Failed to parse VCF file. Ensure it's valid.");
  //   }
  //
  //   if (contactsToSave.isNotEmpty) {
  //     await firestoreService.saveAllContacts(contactsToSave);
  //   }
  //   return count;
  // }



// --- Manual Add (Uses FirestoreService) ---
  Future<void> _addManualContact() async {
    final name = _nameController.text.trim();
    final phoneNumber = _phoneController.text.trim().replaceAll(RegExp(r'[^0-9+]'), '');
    final address = _addressController.text.trim();
    final uniqueID = _uniqueIDController.text.trim();
    // final datimCode = _datimCodeController.text.trim(); // Already set by facility dropdown

    if (name.isEmpty || phoneNumber.isEmpty) {
      Fluttertoast.showToast(msg: 'Name and Phone Number are required');
      return;
    }
    try {
      final contact = Contact(
        name: name,
        phoneNumber: phoneNumber,
        lastVisitDate: _lastVisitController.text.isNotEmpty ? DateTime.tryParse(_lastVisitController.text) : null,
        nextVisitDate: _nextVisitController.text.isNotEmpty ? DateTime.tryParse(_nextVisitController.text) : null,
        state: _selectedState,
        facilityName: _selectedFacilityName,
        uniqueID: uniqueID.isNotEmpty ? uniqueID : null,
        datimCode: _datimCodeController.text.isNotEmpty ? _datimCodeController.text : null, // Use controller value
        address: address.isNotEmpty ? address : null,
        appointmentStatus: _selectedAppointmentType,
        sampleCollectionDate: _sampleCollectionDateController.text.isNotEmpty ? DateTime.tryParse(_sampleCollectionDateController.text) : null,
        currentViralLoad: _currentViralLoadController.text.isNotEmpty ? _currentViralLoadController.text : null,
        // ART Status would likely be set elsewhere or default
      );
      await firestoreService.saveContact(contact);

      // Clear form
      _nameController.clear();
      _phoneController.clear();
      _lastVisitController.clear();
      _nextVisitController.clear();
      _addressController.clear();
      _uniqueIDController.clear();
      _sampleCollectionDateController.clear();
      _currentViralLoadController.clear();
      setState(() {
        _selectedState = null;
        _selectedFacilityName = null;
        _datimCodeController.clear();
        _selectedAppointmentType = "Calculated Next Appointment";
      });

      Fluttertoast.showToast(msg: 'Contact added successfully');
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error adding contact: $e');
    }
  }

  // --- NMRS Import (Keep logic, use FirestoreService, add warning) ---
  Future<void> _importContactsFromDatabase() async {
    setState(() => isDatabaseImporting = true);
    // ... (Get MySQL connection details) ...
    final host = _mysqlHostController.text;
    final port = int.tryParse(_mysqlPortController.text) ?? 3306;
    // ... etc ...
    final startDate = _nextAppointmentStartDateController.text;
    final endDate = _nextAppointmentEndDateController.text;

    // *** Add a check and warning for web ***
    print("WARNING: Connecting directly to MySQL from web client is insecure.");
    // ****************************************

    MySqlConnection? conn;
    try {
      final host = _mysqlHostController.text;
      // ... get other settings ...
      final startDate = _nextAppointmentStartDateController.text;
      final endDate = _nextAppointmentEndDateController.text;
      final timeout = int.tryParse(_mysqlTimeoutController.text) ?? 600;


      if (host.isEmpty || /*...*/ startDate.isEmpty || endDate.isEmpty) {
        Fluttertoast.showToast(msg: 'MySQL details, Host and Date Range are required.');
        setState(() => isDatabaseImporting = false); return;
      }

      DateTime parsedStartDate = DateTime.parse(startDate); // Add error handling
      DateTime parsedEndDate = DateTime.parse(endDate);     // Add error handling
      final formattedStartDate = DateFormat('yyyy-MM-dd 00:00:00').format(parsedStartDate);
      final formattedEndDate = DateFormat('yyyy-MM-dd 23:59:59').format(parsedEndDate);

      final settings = ConnectionSettings(/* ... */ timeout: Duration(seconds: timeout));
      conn = await MySqlConnection.connect(settings);

      // ... (Parse dates - same as mobile) ...
      // ... (Format dates - same as mobile) ...

      // ... (Execute MySQL query - same as mobile) ...
      // Note: Your complex query with function creation might need adjustments
      // or might fail depending on MySQL server permissions from the web host.
      // Consider simplifying or moving to a backend.
      const queryFunction = ''' DROP FUNCTION IF EXISTS get_concept_name; ''';
      const query = ''' CREATE FUNCTION get_concept_name... '''; // Shortened
      const queryy1 = ''' SET SESSION optimizer_switch='block_nested_loop=off'; ''';
      const query2 = ''' SELECT DISTINCT patient.patient_id AS patient_id, ... WHERE Extracted_Data.NextAppointmentDate between ? and ?; '''; // Shortened

      await conn.query(queryFunction);
      await conn.query(query);
      await conn.query(queryy1);
      var results1 = await conn.query(query2, [/* formattedStartDate, formattedEndDate */]);


      int importedDbCount = 0;
      List<Contact> contactList = [];

      // Clear existing contacts before import? Decide on strategy.
      // await firestoreService.cleanContactCollection(); // Use with caution!

      for (final row in results1) {
        String datimCode = row['Datim_Code']?.toString() ?? '';
        // Fetch location info (implement in FirestoreService or use cache)
        // LocationModel? location = _locationCache[datimCode] ?? await firestoreService.getLocationByDatimCode(datimCode);
        // _locationCache[datimCode] = location; // Update cache

        String facilityName = row['Facility_Name']?.toString() ?? '';
        // String state = location?.state ?? ''; // Get state from location if found
        // if (location != null && location.locationName != null) {
        //   facilityName = location.locationName!;
        // }

        final contact = Contact(
          patientId: row['patient_id'],
          datimCode: datimCode,
          facilityName: facilityName,
          // state: state,
          lastVisitDate: row['LastPickupDate'] != null ? DateTime.tryParse(row['LastPickupDate'].toString()) : null,
          nextVisitDate: row['NextAppointmentDate'] != null ? DateTime.tryParse(row['NextAppointmentDate'].toString()) : null,
          appointmentStatus: row['AppointmentStatus']?.toString(),
          name: row['FullName']?.toString(),
          address: row['Address']?.toString(),
          uniqueID: row['identifier']?.toString(),
          phoneNumber: row['value']?.toString().replaceAll(RegExp(r'[^0-9+]'), ''),
          artStatus: row['ART_Status']?.toString(),
          dateOfTermination: row['DateOfTermination'] != null ? DateTime.tryParse(row['DateOfTermination'].toString()) : null,
          sampleCollectionDate: row['sample_collection_date'] != null ? DateTime.tryParse(row['sample_collection_date'].toString()) : null,
          currentViralLoad: row['CurrentViralLoad']?.toString(),
        );

        // Simple validation
        if(contact.name != null && contact.name!.isNotEmpty && contact.phoneNumber != null && contact.phoneNumber!.isNotEmpty) {
          contactList.add(contact);
          importedDbCount++;
        } else {
          print("Skipping NMRS record: Missing name or phone for patient ID ${contact.patientId}");
        }
      }

      if (contactList.isNotEmpty) {
        await firestoreService.saveAllContacts(contactList); // Save to Firestore
      }

      Fluttertoast.showToast(msg: "Import finished. Imported $importedDbCount contacts from NMRS.");

    } on MySqlException catch (e) {
      print("NMRS MySQL Exception: $e");
      Fluttertoast.showToast(msg: 'NMRS Import Failed (DB): ${e.message}', toastLength: Toast.LENGTH_LONG);
    } catch (e) {
      print("Error importing contacts from database: $e");
      Fluttertoast.showToast(msg: 'NMRS Import Failed: $e', toastLength: Toast.LENGTH_LONG);
    } finally {
      await conn?.close();
      setState(() => isDatabaseImporting = false);
    }
  }

  Future<void> _importAllContactsFromDatabase() async {
    setState(() => isDatabaseImporting1 = true);
    print("WARNING: Connecting directly to MySQL from web client is insecure.");
    // ... Similar logic to _importContactsFromDatabase, but remove date filtering from query2 ...
    MySqlConnection? conn;
    try {
      // ... Connect ...
      // ... Execute Functions ...
      const String query2All = """ SELECT ... FROM ... """; // Your query WITHOUT the WHERE clause for NextAppointmentDate
      var results = await conn?.query(query2All);
      // ... Process results and save to Firestore (same loop as above) ...
      // ... Show success/error toast ...
    } catch(e) {
      // ... Error handling ...
    } finally {
      await conn?.close();
      setState(() => isDatabaseImporting1 = false);
    }
  }

  // --- SQL Script Download (Web version using universal_html) ---
  Future<void> _downloadSqlScript() async {
    String sqlQuery = r"""
-- =============================================
-- Author: VEGHER EMMANUEL
-- Modified date: 21/04/2025
-- Description: Query to Generate Contact List
-- =============================================

-- =====================================================
-- Create function for concept_id
-- ===============================================    

DELIMITER $$

DROP FUNCTION IF EXISTS get_concept_name$$

CREATE FUNCTION get_concept_name(conceptid INT) RETURNS VARCHAR(255)
DETERMINISTIC
READS SQL DATA
BEGIN
  DECLARE result VARCHAR(255);
  SELECT NAME INTO result
  FROM concept_name
  WHERE concept_id = conceptid
    AND locale = 'en'
    AND locale_preferred = 1
  LIMIT 1;
  RETURN result;
END$$

DELIMITER ;

-- Generate Contact List
SELECT DISTINCT patient.patient_id AS patient_id,
(SELECT property_value FROM global_property WHERE property = 'facility_datim_code' LIMIT 1) AS Datim_Code,
(SELECT property_value FROM global_property WHERE property = 'Facility_Name' LIMIT 1) AS Facility_Name,

-- Determine the most recent pickup/appointment date
    CASE
        WHEN Pharmacy.Pharm_VisitLastDate = visit.encounter_datetime THEN visit.encounter_datetime
        WHEN Pharmacy.Pharm_VisitLastDate >  visit.encounter_datetime THEN Pharmacy.Pharm_VisitLastDate
        ELSE Pharmacy.Pharm_VisitLastDate
    END AS LastPickupDate,

    -- Compute next appointment date based on which is the most recent
    CASE
        WHEN Pharmacy.Pharm_VisitLastDate = visit.encounter_datetime THEN visit.Clinic_NxtApptDate
        WHEN Pharmacy.Pharm_VisitLastDate > visit.encounter_datetime THEN Pharmacy.CalculatedNextAppointment
        ELSE Pharmacy.CalculatedNextAppointment
    END AS NextAppointmentDate,

     -- Status of appointment computation
    CASE
        WHEN Pharmacy.Pharm_VisitLastDate = visit.encounter_datetime THEN 'Actual Next Appointment'
        WHEN Pharmacy.Pharm_VisitLastDate > visit.encounter_datetime THEN 'Calculated Next Appointment'
        ELSE 'Calculated Next Appointment'
    END AS AppointmentStatus,
    FullName.FullName,
    Address.Address,
    PatientUniqueID.identifier,
    PhoneNo.value,

    CASE
WHEN pharmacy.CurrentARTStatus28Days_Pharmacy = 'Active' AND ClientTrackingForm.OutcomeOfTracking LIKE 'Transf%' AND ClientTrackingForm.Date_Of_Termination_OR_ReturnedToCare < pharmacy.`Pharm_VisitLastDate` THEN 'Active'
WHEN pharmacy.CurrentARTStatus28Days_Pharmacy = 'Active' AND ClientTrackingForm.OutcomeOfTracking LIKE 'Transf%' AND ClientTrackingForm.Date_Of_Termination_OR_ReturnedToCare >= pharmacy.`Pharm_VisitLastDate` THEN 'Transferred Out'
WHEN pharmacy.CurrentARTStatus28Days_Pharmacy = 'Inactive' AND ClientTrackingForm.OutcomeOfTracking LIKE 'Transf%'  THEN 'Transferred Out'
WHEN pharmacy.CurrentARTStatus28Days_Pharmacy = 'Active' AND ClientTrackingForm.OutcomeOfTracking LIKE 'Transf%' AND (ClientTrackingForm.Date_Of_Termination_OR_ReturnedToCare = '' OR ClientTrackingForm.Date_Of_Termination_OR_ReturnedToCare IS NULL) THEN 'Transferred-Out'
WHEN pharmacy.CurrentARTStatus28Days_Pharmacy = 'Active' AND ClientTrackingForm.OutcomeOfTracking LIKE 'Discont%' AND ClientTrackingForm.Date_Of_Termination_OR_ReturnedToCare < pharmacy.`Pharm_VisitLastDate`THEN 'Active'
WHEN pharmacy.CurrentARTStatus28Days_Pharmacy = 'Active' AND ClientTrackingForm.OutcomeOfTracking LIKE 'Discont%' AND (ClientTrackingForm.Date_Of_Termination_OR_ReturnedToCare = '' OR ClientTrackingForm.Date_Of_Termination_OR_ReturnedToCare IS NULL) THEN 'Discontinued Care'
WHEN pharmacy.CurrentARTStatus28Days_Pharmacy = 'Active' AND ClientTrackingForm.OutcomeOfTracking LIKE 'Discont%' AND ClientTrackingForm.Date_Of_Termination_OR_ReturnedToCare >= pharmacy.`Pharm_VisitLastDate`THEN 'Discontinued Care'
WHEN pharmacy.CurrentARTStatus28Days_Pharmacy = 'Inactive' AND ClientTrackingForm.OutcomeOfTracking LIKE 'Discont%' THEN 'Discontinued Care'
WHEN pharmacy.CurrentARTStatus28Days_Pharmacy = 'Active' AND ClientTrackingForm.OutcomeOfTracking LIKE 'Dea%' THEN 'Death'
WHEN pharmacy.CurrentARTStatus28Days_Pharmacy = 'Inactive' AND pharmacy.CurrentARTStatus90Days_Pharmacy = 'Active' THEN 'Missed Appointment'
WHEN pharmacy.CurrentARTStatus28Days_Pharmacy = 'inactive' AND ClientTrackingForm.OutcomeOfTracking LIKE 'Dea%' THEN 'Death'
WHEN pharmacy.CurrentARTStatus28Days_Pharmacy = 'Active' AND ClientTrackingForm.OutcomeOfTracking = 'Returned_To_Care'  THEN 'Active'
WHEN pharmacy.CurrentARTStatus28Days_Pharmacy = 'Active' AND (ClientTrackingForm.OutcomeOfTracking = '' OR ClientTrackingForm.OutcomeOfTracking IS NULL)  THEN 'Active'
ELSE 'IIT' END AS 'ART_Status',

    ClientTrackingForm.DateOfTermination,
    Tb1.sample_collection_date,
    Tb1.CurrentViralLoad


FROM `patient` AS patient
-- ===============================
-- Personal History (Biographical) Information
-- =================================

LEFT JOIN
(SELECT DISTINCT patient_id, identifier FROM patient_identifier WHERE identifier_type = 4 AND voided = 0) AS PatientUniqueID
ON patient.patient_id = PatientUniqueID.patient_id
LEFT JOIN
(SELECT  person_id, CONCAT(given_name, ' ', family_name) AS FullName FROM person_name WHERE voided = 0  GROUP BY person_id) AS FullName
ON patient.patient_id = FullName.person_id

LEFT JOIN
(SELECT  person_id, VALUE FROM `person_attribute` WHERE person_attribute_type_id = 8 AND voided = 0  GROUP BY person_id) AS PhoneNo
ON patient.patient_id = PhoneNo.person_id
LEFT JOIN
(SELECT a.person_id, CONCAT(a.address1, ' ,', a.address2, ' ,', a.city_village, ' ,', a.state_province) AS 'Address' FROM `person_address` AS a WHERE  voided = 0 GROUP BY a.person_id ) AS Address
ON patient.patient_id = Address.person_id


-- Pharmacy Form Details - To Calculate ACTIVE Status as AT Today
INNER JOIN (
  SELECT
    p.patient_id,
    p.encounter_datetime AS Pharm_VisitLastDate,
    p.value_numeric,
    p.value_numeric1,
    DATE_ADD(p.encounter_datetime, INTERVAL p.value_numeric DAY) AS CalculatedNextAppointment,
    IF(DATE_ADD(DATE_ADD(p.encounter_datetime, INTERVAL p.value_numeric DAY), INTERVAL 28 DAY) >= NOW(), 'Active', 'Inactive') AS CurrentARTStatus28Days_Pharmacy,
    IF(DATE_ADD(DATE_ADD(p.encounter_datetime, INTERVAL p.value_numeric DAY), INTERVAL 90 DAY) >= NOW(), 'Active', 'Inactive') AS CurrentARTStatus90Days_Pharmacy
  FROM (
    SELECT
      Lpickup.patient_id,
      Lpickup.encounter_datetime,
      MedDuration.value_numeric,
      (MedDuration.value_numeric + 29) AS value_numeric1
    FROM (
      SELECT
        A.patient_id,
        A.encounter_datetime,
        A.encounter_id
      FROM encounter A
      JOIN patient_identifier B ON A.patient_id = B.patient_id
      WHERE A.encounter_type = 13
        AND A.voided = 0
        AND B.voided = 0
        AND B.identifier_type = 4
    ) AS Lpickup
    JOIN (
      SELECT
        B.person_id,
        B.encounter_id,
        B.value_numeric
      FROM obs A
      JOIN obs B ON A.obs_id = B.obs_group_id AND A.encounter_id = B.encounter_id
      WHERE A.concept_id = 162240
        AND B.concept_id = 159368
        AND A.voided = 0
        AND B.voided = 0
        AND B.value_numeric IS NOT NULL
    ) AS MedDuration
    ON Lpickup.patient_id = MedDuration.person_id
    AND Lpickup.encounter_id = MedDuration.encounter_id
  ) p
  JOIN (
    SELECT patient_id, MAX(encounter_datetime) AS max_date
    FROM encounter
    WHERE encounter_type = 13 AND voided = 0
    GROUP BY patient_id
  ) latest ON p.patient_id = latest.patient_id AND p.encounter_datetime = latest.max_date
) AS Pharmacy
ON patient.patient_id = Pharmacy.patient_id


-- ============================================
-- Care Card Details
-- =========================================
LEFT JOIN (
  SELECT
    e.patient_id,
    e.encounter_datetime,
    o.value_datetime AS Clinic_NxtApptDate
  FROM encounter e
  JOIN obs o ON e.encounter_id = o.encounter_id
  JOIN (
    SELECT patient_id, MAX(encounter_datetime) AS max_date
    FROM encounter
    WHERE encounter_type = 12 AND voided = 0
    GROUP BY patient_id
  ) latest ON e.patient_id = latest.patient_id AND e.encounter_datetime = latest.max_date
  WHERE e.encounter_type = 12
    AND o.concept_id = 5096
    AND e.voided = 0
    AND o.voided = 0
) AS visit
ON patient.patient_id = visit.patient_id



-- =======================
-- Client Tracking Details
-- =========================
LEFT JOIN (
  SELECT
    ct.patient_id,
    MAX(ct.encounter_id) AS encounter_id,
    MAX(ct.encounter_datetime) AS encounter_datetime,
    MAX(rft.ReasonForTracking) AS ReasonForTracking,
    MAX(dot.DateOfTermination) AS DateOfTermination,
    MAX(rot.ReasonForTermination) AS ReasonForTermination,
    MAX(dt.DateOfTracking) AS DateOfTracking,
    MAX(ltf.LTFU) AS LTFU,
    MAX(dol.value_datetime) AS DateOfLTFU,
    MAX(pcf.PatientCareInFacilityTerminated) AS PatientCareInFacilityTerminated,
    CASE
      WHEN MAX(pcf.PatientCareInFacilityTerminated) = 'Yes' THEN MAX(rot.ReasonForTermination)
      WHEN MAX(pcf.PatientCareInFacilityTerminated) = 'No' THEN 'Returned_To_Care'
      ELSE NULL
    END AS OutcomeOfTracking,
    CASE
      WHEN MAX(pcf.PatientCareInFacilityTerminated) = 'Yes' THEN MAX(dot.DateOfTermination)
      WHEN MAX(pcf.PatientCareInFacilityTerminated) = 'No' THEN MAX(drc.value_datetime)
      ELSE NULL
    END AS Date_Of_Termination_OR_ReturnedToCare
  FROM (
    SELECT patient_id, encounter_id, encounter_datetime
    FROM encounter
    WHERE encounter_type = 15
      AND encounter_datetime <= CURDATE() + INTERVAL 1 DAY
      AND voided = 0
  ) ct
  LEFT JOIN (
    SELECT person_id, encounter_id, get_concept_name(value_coded) AS ReasonForTracking
    FROM obs
    WHERE concept_id = 165460 AND voided = 0
  ) rft ON ct.patient_id = rft.person_id AND ct.encounter_id = rft.encounter_id

  LEFT JOIN (
    SELECT person_id, encounter_id, obs_datetime AS DateOfTracking
    FROM obs
    WHERE concept_id = 165460 AND voided = 0
  ) dt ON ct.patient_id = dt.person_id AND ct.encounter_id = dt.encounter_id

  LEFT JOIN (
    SELECT person_id, encounter_id, value_datetime AS DateOfTermination
    FROM obs
    WHERE concept_id = 165469 AND voided = 0
  ) dot ON ct.patient_id = dot.person_id AND ct.encounter_id = dot.encounter_id

  LEFT JOIN (
    SELECT person_id, encounter_id, get_concept_name(value_coded) AS ReasonForTermination
    FROM obs
    WHERE concept_id = 165470 AND voided = 0
  ) rot ON ct.patient_id = rot.person_id AND ct.encounter_id = rot.encounter_id

  LEFT JOIN (
    SELECT
      A.person_id, A.encounter_id,
      CONCAT(
        CASE WHEN A.concept_id = 5240 AND A.value_coded = 1 THEN get_concept_name(A.concept_id) END,
        '(',
        CASE WHEN B.concept_id = 166157 THEN get_concept_name(B.value_coded) END,
        ')'
      ) AS LTFU
    FROM obs A
    JOIN obs B ON A.encounter_id = B.encounter_id
               AND A.person_id = B.person_id
    WHERE A.concept_id = 5240 AND B.concept_id = 166157 AND A.voided = 0 AND B.voided = 0
  ) ltf ON ct.patient_id = ltf.person_id AND ct.encounter_id = ltf.encounter_id

  LEFT JOIN (
    SELECT person_id, encounter_id, value_datetime
    FROM obs
    WHERE concept_id = 166152 AND voided = 0
  ) dol ON ct.patient_id = dol.person_id AND ct.encounter_id = dol.encounter_id

  LEFT JOIN (
    SELECT person_id, encounter_id, get_concept_name(value_coded) AS PatientCareInFacilityTerminated
    FROM obs
    WHERE concept_id = 165586 AND voided = 0
  ) pcf ON ct.patient_id = pcf.person_id AND ct.encounter_id = pcf.encounter_id

  LEFT JOIN (
    SELECT person_id, encounter_id, value_datetime
    FROM obs
    WHERE concept_id = 165775 AND voided = 0
  ) drc ON ct.patient_id = drc.person_id AND ct.encounter_id = drc.encounter_id

  GROUP BY ct.patient_id
) AS ClientTrackingForm
ON ClientTrackingForm.patient_id = patient.patient_id


-- Viral Load Result
LEFT JOIN (
  SELECT
    vl.patient_id,    vl.encounter_id,
    vl.encounter_datetime,
    sample_col.sample_collection_date,
    COALESCE(vl_result.value_numeric, vl_result2.vl_text_result) AS CurrentViralLoad
  FROM (
    -- Get latest VL encounter per patient
    SELECT
      e.patient_id,
      e.encounter_id,
      e.encounter_datetime
    FROM encounter e
    WHERE e.encounter_type = 11
      AND e.encounter_datetime <= DATE_FORMAT(NOW(),'%Y-%m-%d 23:59:59')
      AND e.voided = 0
      AND e.encounter_datetime = (
        SELECT MAX(encounter_datetime)
        FROM encounter
        WHERE patient_id = e.patient_id
          AND encounter_type = 11
          AND voided = 0
          AND encounter_datetime <= DATE_FORMAT(NOW(),'%Y-%m-%d 23:59:59')
      )
  ) vl

  LEFT JOIN (
    -- Numeric VL result
    SELECT
      o.person_id,
      o.encounter_id,
      o.value_numeric
    FROM obs o
    WHERE o.concept_id = 856
      AND o.value_numeric IS NOT NULL
      AND o.voided = 0
  ) vl_result
    ON vl.patient_id = vl_result.person_id AND vl.encounter_id = vl_result.encounter_id

  LEFT JOIN (
    -- Sample collection date
    SELECT
      o.person_id,
      o.encounter_id,
      o.value_datetime AS sample_collection_date
    FROM obs o
    WHERE o.concept_id = 159951
      AND o.value_datetime IS NOT NULL
      AND o.voided = 0
  ) sample_col
    ON vl.patient_id = sample_col.person_id AND vl.encounter_id = sample_col.encounter_id

  LEFT JOIN (
    -- Coded VL result (as text)
    SELECT
      o.person_id,
      o.encounter_id,
      get_concept_name(o.value_coded) AS vl_text_result
    FROM obs o
    WHERE o.concept_id = 166422
      AND o.value_coded NOT IN (166426)
      AND o.voided = 0
  ) vl_result2
    ON vl.patient_id = vl_result2.person_id AND vl.encounter_id = vl_result2.encounter_id

  WHERE sample_col.sample_collection_date IS NOT NULL
    AND (
      vl_result.value_numeric IS NOT NULL
      OR vl_result2.vl_text_result IS NOT NULL
    )
) AS Tb1
ON Tb1.patient_id = patient.patient_id

""";
    String fileName = 'contact_tracking_list_query.sql';

    // Use universal_html for web download
    final bytes = utf8.encode(sqlQuery);
    final blob = html.Blob([bytes], 'text/plain', 'native'); // Specify MIME type
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.document.createElement('a') as html.AnchorElement
      ..href = url
      ..style.display = 'none'
      ..download = fileName;
    html.document.body!.children.add(anchor);
    anchor.click(); // Trigger download
    html.document.body!.children.remove(anchor);
    html.Url.revokeObjectUrl(url); // Clean up

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('SQL script download initiated.')),
    );
  }

  // --- SQL Script Share (Not directly possible on Web) ---
  Future<void> _downloadAndShareSqlScript() async {
    // Sharing files directly from web like mobile is not possible.
    // Best approach is to download it first, then user can share manually.
    Fluttertoast.showToast(msg: "Sharing not directly supported on web. Downloading file instead.");
    await _downloadSqlScript(); // Just trigger the download
  }





  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      controller.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }


  // --- Build Method (Web Adaptation) ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import Contacts')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Manual Entry Card (Keep structure, uses FirestoreService now) ---
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Add Contact Manually', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 16),
                      TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Name *', border: OutlineInputBorder())),
                      const SizedBox(height: 12),
                      TextField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Phone Number *', border: OutlineInputBorder()), keyboardType: TextInputType.phone),
                      const SizedBox(height: 12),
                      TextField(controller: _addressController, decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder())),
                      const SizedBox(height: 12),
                      Row(children: [ // Date Fields
                        Expanded(child: TextField(controller: _lastVisitController, decoration: InputDecoration(labelText: 'Last Visit', suffixIcon: IconButton(icon: const Icon(Icons.calendar_today), onPressed: () => _selectDate(context, _lastVisitController))), readOnly: true)),
                        const SizedBox(width: 12),
                        Expanded(child: TextField(controller: _nextVisitController, decoration: InputDecoration(labelText: 'Next Visit', suffixIcon: IconButton(icon: const Icon(Icons.calendar_today), onPressed: () => _selectDate(context, _nextVisitController))), readOnly: true)),
                      ]),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>( // Appointment Type
                        decoration: const InputDecoration(labelText: 'Appointment Type', border: OutlineInputBorder()),
                        initialValue: _selectedAppointmentType,
                        items: ["Actual Next Appointment", "Calculated Next Appointment"].map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                        onChanged: (v) => setState(() => _selectedAppointmentType = v),
                      ),
                      const SizedBox(height: 12),
                      // State Dropdown (using fetched _statesList)
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'State', border: OutlineInputBorder()),
                        initialValue: _selectedState,
                        items: _statesList.map((state) => DropdownMenuItem(value: state, child: Text(state))).toList(),
                        onChanged: (newValue) {
                          setState(() {
                            _selectedState = newValue;
                            _selectedFacilityName = null; // Reset facility
                            _datimCodeController.clear();
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      // Facility Dropdown (filtered by state)
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Facility Name', border: OutlineInputBorder()),
                        initialValue: _selectedFacilityName,
                        // Use facilities from _facilitiesMap based on selected state
                        items: (_selectedState != null && _facilitiesMap.containsKey(_selectedState))
                            ? _facilitiesMap[_selectedState]!.map((facility) => DropdownMenuItem(value: facility, child: Text(facility))).toList()
                            : [], // Empty list if no state or no facilities for state
                        onChanged: (newValue) async {
                          setState(() { _selectedFacilityName = newValue; _datimCodeController.text = 'Loading...'; });
                          final datimCode = await _getDatimCodeByFacilityName(newValue);
                          setState(() { _datimCodeController.text = datimCode ?? ''; });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(controller: _uniqueIDController, decoration: const InputDecoration(labelText: 'Unique ID (Client ART ID)', border: OutlineInputBorder())),
                      const SizedBox(height: 12),
                      TextField(controller: _datimCodeController, decoration: const InputDecoration(labelText: 'Datim Code', border: OutlineInputBorder()), readOnly: true),
                      const SizedBox(height: 12),
                      Row(children: [ // Sample Date / VL
                        Expanded(child: TextField(controller: _sampleCollectionDateController, decoration: InputDecoration(labelText: 'Sample Date', suffixIcon: IconButton(icon: const Icon(Icons.calendar_today), onPressed: () => _selectDate(context, _sampleCollectionDateController))), readOnly: true)),
                        const SizedBox(width: 12),
                        Expanded(child: TextField(controller: _currentViralLoadController, decoration: const InputDecoration(labelText: 'Viral Load'), keyboardType: TextInputType.text)), // Allow text like <50
                      ]),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _addManualContact, style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)), child: const Text('Add Contact')),
                    ]
                ),
              ),
            ),
            const SizedBox(height: 24),

            // --- File Import Card (Web Specific) ---
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Import from File (CSV or VCF)', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _pickAndReadFile, // Use combined picker
                      child: const Text('Select Contacts File (.csv or .vcf)'),
                    ),
                    const SizedBox(height: 10),
                    if (uploadedFileName != null)
                      Center(child: Text('Selected: $uploadedFileName', style: const TextStyle(fontStyle: FontStyle.italic))),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      // Disable if no file selected or already importing
                      onPressed: (uploadedFileBytes == null || isImporting) ? null : _processUploadedFile,
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: isImporting ? const CircularProgressIndicator(color: Colors.white,) : const Text('Import Contacts from Selected File'),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Note: For large files, import may take some time. "
                          "Ensure your CSV has columns like 'name', 'phone_number'. "
                          "VCF import is experimental.",
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // --- NMRS Import Card (Keep structure, add warnings) ---
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Import from NigeriaMRS (NMRS)', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 10),
                    // *** SECURITY WARNING ***
                    Container(
                      padding: const EdgeInsets.all(8),
                      color: Colors.orange.shade100,
                      child: Text(
                        'Security Warning: Connecting directly to the NMRS database from the web browser is NOT recommended for production environments due to security risks. Consider using a secure backend API.',
                        style: TextStyle(color: Colors.orange.shade900),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // ... NMRS Settings UI (same as mobile) ...
                    // ... Date Range Pickers (same as mobile) ...
                    ElevatedButton(
                      onPressed: (isDatabaseImporting || _savedSettings.isEmpty) ? null : _importContactsFromDatabase, // Uses FirestoreService
                      child: isDatabaseImporting ? const CircularProgressIndicator(color: Colors.white,) : const Text('Import Scheduled Appointments Between Dates'),
                    ),
                    // ... Divider and 'OR' ...
                    ElevatedButton(
                      onPressed: (isDatabaseImporting1 || _savedSettings.isEmpty) ? null : _importAllContactsFromDatabase, // Uses FirestoreService
                      child: isDatabaseImporting1 ? const CircularProgressIndicator(color: Colors.white,) : const Text('Import All Client Appointments'),
                    ),
                    const SizedBox(height: 16),
                    // ... Download/Share Buttons (use web download) ...
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _downloadSqlScript, // Uses web download
                          icon: const Icon(Icons.download, color: Colors.white),
                          label: const Text('Download SQL Script', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF800020)),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: _downloadAndShareSqlScript, // Shows message + downloads
                          icon: const Icon(Icons.share, color: Colors.white),
                          label: const Text('Share SQL Script', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF800020)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}