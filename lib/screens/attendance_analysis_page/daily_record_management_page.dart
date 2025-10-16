import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart'; // Import for premium fonts
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data'; // For handling image data on the web


class DailyRecordManagementPage extends StatefulWidget {
  final String staffId;
  final String? recordId;
  final DateTime date;

  const DailyRecordManagementPage({
    super.key,
    required this.staffId,
    this.recordId,
    required this.date,
  });

  @override
  _DailyRecordManagementPageState createState() => _DailyRecordManagementPageState();
}

class _DailyRecordManagementPageState extends State<DailyRecordManagementPage> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final ImagePicker _picker = ImagePicker();
  Uint8List? _selectedImageData; // To hold the bytes of a newly picked image for preview
  String? _existingImageUrl;     // To hold the URL of an image already saved in Firestore
  String? _newImageUrlToSave;    // To hold the URL of a newly uploaded image before final save
  bool _isUploading = false;     // To show a progress indicator during upload

  // State variables for loading, saving, and data
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  Map<String, dynamic>? _recordData;
  String? _staffName;
  String _selectedDeduction = 'None';
  int _deductedHours = 1;
  int _approvedHours = 1;

  // Define our beautiful wine color
  static const Color wineColor = Color(0xFF722F37);

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }


  Future<void> _fetchData() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      // Always fetch the staff name
      final staffDoc = await _firestore.collection('Staff').doc(widget.staffId).get();
      _staffName = '${staffDoc.data()?['firstName'] ?? ''} ${staffDoc.data()?['lastName'] ?? ''}'.trim();

      // Check if we are in "Edit" or "Create" mode
      if (widget.recordId != null) {
        // --- EDIT MODE ---
        final recordDoc = await _firestore.collection('Staff').doc(widget.staffId).collection('Record').doc(widget.recordId!).get();
        if (!recordDoc.exists) throw Exception("Record not found.");

        _recordData = recordDoc.data();
        _selectedDeduction = _recordData?['deductionStatus'] ?? 'None';
       _notesController.text = _recordData?['recommendation']?['notes'] ?? '';
        _deductedHours = _recordData?['recommendation']?['deductedHours'] ?? 1;
        _existingImageUrl = _recordData?['evidenceImageUrl'];
        // If editing a previously approved record, set the approved hours stepper
// to the number of hours already in the record.
        if (_selectedDeduction == 'ApprovedPartial') {
          _approvedHours = (_recordData?['noOfHours'] as num? ?? 1.0).toInt();
        }
      } else {
        // Set sensible defaults for a new, approved record
        // --- CREATE MODE ---
        // Default to a Full Approval for a new, manually created record
        _recordData = {'noOfHours': 8.0};
        _selectedDeduction = 'ApprovedFull'; // <-- NEW: Default to Full Approval
        _notesController.text = '';
        _approvedHours = 8; // <-- NEW: Set approved hours to 8
        _deductedHours = 0;
      }
    } catch (e) {
      _errorMessage = "Error fetching data: $e";
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }



// Helper for the inline hour stepper, now used by both approvals and deductions
  Widget _buildHourStepper({
    required int value,
    required Color color,
    required ValueChanged<int> onChanged,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          padding: EdgeInsets.zero,
          iconSize: 28,
          icon: const Icon(Icons.remove_circle_outline),
          color: value > 1 ? color : Colors.grey,
          onPressed: value <= 1 ? null : () => onChanged(value - 1),
        ),
        Text(
          "$value hr${value > 1 ? 's' : ''}",
          style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        IconButton(
          padding: EdgeInsets.zero,
          iconSize: 28,
          icon: const Icon(Icons.add_circle_outline),
          color: value < 8 ? color : Colors.grey,
          onPressed: value >= 8 ? null : () => onChanged(value + 1),
        ),
      ],
    );
  }

// New widget for the "Partial Approval" option
  Widget _buildPartialApprovalCard() {
    final bool isSelected = _selectedDeduction == 'ApprovedPartial';
    return Card(
      elevation: isSelected ? 4.0 : 1.0,
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isSelected ? Colors.blue : Colors.transparent, width: 2.0),
      ),
      child: InkWell(
        onTap: () => setState(() => _selectedDeduction = 'ApprovedPartial'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
          child: Row(
            children: [
              Radio<String>(
                value: 'ApprovedPartial',
                groupValue: _selectedDeduction,
                onChanged: (v) => setState(() => _selectedDeduction = v!),
                activeColor: Colors.blue,
              ),
              Icon(Icons.thumb_up_alt_outlined, color: isSelected ? Colors.blue : Colors.grey.shade600, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Partial Approval', style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: isSelected ? Colors.blue : Colors.black87)),
                    Text('Approve a specific number of hours.', style: GoogleFonts.sourceSans3(color: Colors.grey.shade700, fontSize: 14)),
                  ],
                ),
              ),
              if (isSelected)
                _buildHourStepper(
                  value: _approvedHours,
                  color: Colors.blue.shade700,
                  onChanged: (newValue) => setState(() => _approvedHours = newValue),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, String> _calculateClockOutDetails({
    required String startTime,
    required double hoursToAdd,
  }) {
    try {
      // Use a base date, as we only care about the time part
      final now = DateTime.now();
      final baseDate = DateTime(now.year, now.month, now.day);

      // Parse the start time string (e.g., "08:41 AM")
      final DateFormat timeFormat = DateFormat("hh:mm a");
      final DateTime parsedStartTime = timeFormat.parse(startTime);

      // Combine with the base date to create a full DateTime object for calculation
      final DateTime startDateTime = baseDate.add(Duration(
        hours: parsedStartTime.hour,
        minutes: parsedStartTime.minute,
      ));

      // Calculate the duration to add from the decimal hours
      final Duration durationToAdd = Duration(
        microseconds: (hoursToAdd * 3600 * 1000000).round(),
      );

      // Calculate the final end time
      final DateTime endDateTime = startDateTime.add(durationToAdd);

      // Format the end time back into a "hh:mm a" string
      final String clockOutString = timeFormat.format(endDateTime);

      // Format the duration into a "X hours Y minutes" string
      final int totalMinutes = durationToAdd.inMinutes;
      final int hours = totalMinutes ~/ 60;
      final int minutes = totalMinutes % 60;
      final String durationString = "$hours hour${hours == 1 ? '' : 's'} $minutes minute${minutes == 1 ? '' : 's'}";

      return {
        'clockOut': clockOutString,
        'durationWorked': durationString,
      };
    } catch (e) {
      // Fallback in case of a parsing error
      print("Error calculating time: $e");
      return {
        'clockOut': "--/--",
        'durationWorked': "0 hours 0 minutes",
      };
    }
  }

  Future<void> _saveChanges() async {
    // 1. Validate the form to ensure a comment is provided for any action
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isSaving = true);

    try {
      // 2. Get the current supervisor's details for attribution
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Authentication Error: You are not logged in.");

      final recommenderDoc = await _firestore.collection('Staff').doc(user.uid).get();
      if (!recommenderDoc.exists) throw Exception("Action Failed: Your staff profile could not be found.");
      final recommenderData = recommenderDoc.data()!;

      final recommenderName = '${recommenderData['firstName']} ${recommenderData['lastName']}'.trim();
      final recommenderDesignation = recommenderData['designation'] ?? 'N/A';

      // 3. Determine deducted hours and build the detailed recommendation note
      final supervisorNotes = _notesController.text.trim();
      int deductedHoursForMap = 0;
      String deductionSummaryString = ""; // This will hold the new summary text

      if (_selectedDeduction == 'Partial') {
        deductedHoursForMap = _deductedHours;
      } else if (_selectedDeduction == 'Full') {
        deductedHoursForMap = 8;
      }

      // --- NEW: Construct the detailed deduction summary string ---
      if (deductedHoursForMap > 0) {
        final double percentage = (deductedHoursForMap / 8.0) * 100;
        deductionSummaryString = "\n\nSystem Note: $deductedHoursForMap/8 hours recommended for deduction (${percentage.toStringAsFixed(0)}% of daily pay).";
      }

      final attributionString = "\n\n- Action by: $recommenderName ($recommenderDesignation)";
      // Combine all parts: Supervisor's notes + System's summary + Supervisor's attribution
      final finalNotesWithAttribution = supervisorNotes + deductionSummaryString + attributionString;

      // Determine final image URL to be saved
      String? finalImageUrl = _newImageUrlToSave ?? _existingImageUrl;
      if (_selectedDeduction == 'None') {
        finalImageUrl = null;
      }

      // 4. Check if we are UPDATING an existing record or CREATING a new one
      if (widget.recordId != null) {
        // --- UPDATE PATH ---

        double? finalEffectiveHours;
        Map<String, String>? timeDetails;

        // Only calculate new hours/times if it's an approval action
        if (_selectedDeduction == 'ApprovedPartial' || _selectedDeduction == 'ApprovedFull') {
          final originalClockIn = _recordData?['clockIn'] as String? ?? "08:00 AM";
          finalEffectiveHours = (_selectedDeduction == 'ApprovedPartial')
              ? _approvedHours.toDouble()
              : 8.0;

          timeDetails = _calculateClockOutDetails(
            startTime: originalClockIn,
            hoursToAdd: finalEffectiveHours,
          );
        }

        // Build the recommendation map with all necessary details
        final recommendationMap = {
          'notes': finalNotesWithAttribution,
          'recommenderId': user.uid,
          'recommenderName': recommenderName,
          'recommenderDesignation': recommenderDesignation,
          'recommenderCategory': recommenderData['staffCategory'] ?? 'N/A',
          'timestamp': FieldValue.serverTimestamp(),
          'deductedHours': deductedHoursForMap,
        };

        // Prepare the data payload for the update operation
        final Map<String, dynamic> updateData = {
          'deductionStatus': _selectedDeduction,
          'isUpdated': true,
          'comments': null,
          'recommendation': _selectedDeduction == 'None' ? FieldValue.delete() : recommendationMap,
          'evidenceImageUrl': finalImageUrl,
        };

        // Conditionally add fields for approval actions
        if (finalEffectiveHours != null && timeDetails != null) {
          updateData['noOfHours'] = finalEffectiveHours;
          updateData['clockOut'] = timeDetails['clockOut'];
          updateData['durationWorked'] = timeDetails['durationWorked'];
        }

        // Handle deletion of the image field if the URL is null
        if (finalImageUrl == null) {
          updateData['evidenceImageUrl'] = FieldValue.delete();
        }

        // Perform the Firestore update
        await _firestore
            .collection('Staff')
            .doc(widget.staffId)
            .collection('Record')
            .doc(widget.recordId!)
            .update(updateData);

      } else {
        // --- CREATE PATH ---

        double finalEffectiveHours = (_selectedDeduction == 'ApprovedPartial')
            ? _approvedHours.toDouble()
            : 8.0;

        final timeDetails = _calculateClockOutDetails(
          startTime: "08:00 AM",
          hoursToAdd: finalEffectiveHours,
        );

        // Fetch the staff's last known location data
        final recordsQuery = await _firestore.collection('Staff').doc(widget.staffId).collection('Record').orderBy('timestamp', descending: true).limit(1).get();

        double clockInLat = 0.0;
        double clockInLon = 0.0;
        String clockInLocationName = "N/A (Manually Created)";
        double clockOutLat = 0.0;
        double clockOutLon = 0.0;
        String clockOutLocationName = "";

        if (recordsQuery.docs.isNotEmpty) {
          final lastRecord = recordsQuery.docs.first.data();
          if (lastRecord['clockInLatitude'] != null && (lastRecord['clockInLatitude'] as num) != 0) {
            clockInLat = (lastRecord['clockInLatitude'] as num).toDouble();
            clockInLon = (lastRecord['clockInLongitude'] as num).toDouble();
            clockInLocationName = lastRecord['clockInLocation'] as String? ?? clockInLocationName;
          }
          if (lastRecord['clockOutLatitude'] != null && (lastRecord['clockOutLatitude'] as num) != 0) {
            clockOutLat = (lastRecord['clockOutLatitude'] as num).toDouble();
            clockOutLon = (lastRecord['clockOutLongitude'] as num).toDouble();
            clockOutLocationName = lastRecord['clockOutLocation'] as String? ?? "";
          } else if (clockInLat != 0.0) {
            clockOutLat = clockInLat;
            clockOutLon = clockInLon;
            clockOutLocationName = clockInLocationName;
          }
        }

        // Build the recommendation map for the new record
        final recommendationMap = {
          'notes': finalNotesWithAttribution,
          'recommenderId': user.uid,
          'recommenderName': recommenderName,
          'recommenderDesignation': recommenderDesignation,
          'recommenderCategory': recommenderData['staffCategory'] ?? 'N/A',
          'timestamp': FieldValue.serverTimestamp(),
          'deductedHours': 0, // No deduction on a new, approved record
        };

        final String formattedDate = DateFormat('dd-MMMM-yyyy').format(widget.date);
        final String formattedMonth = DateFormat('MMMM yyyy').format(widget.date);

        // Build the full data payload for the new record
        final Map<String, dynamic> newRecordData = {
          'Offline_DB_id': DateTime.now().millisecondsSinceEpoch,
          'clockIn': "08:00 AM",
          'clockInLatitude': clockInLat,
          'clockInLocation': clockInLocationName,
          'clockInLongitude': clockInLon,
          'clockOut': timeDetails['clockOut'],
          'clockOutLatitude': clockOutLat,
          'clockOutLocation': clockOutLocationName,
          'clockOutLongitude': clockOutLon,
          'comments': null,
          'date': formattedDate,
          'deductionStatus': _selectedDeduction,
          'durationWorked': timeDetails['durationWorked'],
          'isSynced': true,
          'isUpdated': false,
          'month': formattedMonth,
          'noOfHours': finalEffectiveHours,
          'offDay': false,
          'recommendation': recommendationMap,
          'timestamp': Timestamp.fromDate(widget.date),
          'evidenceImageUrl': finalImageUrl,
          'voided': false,
        };

        // Create the document using the formatted date as the ID
        await _firestore
            .collection('Staff')
            .doc(widget.staffId)
            .collection('Record')
            .doc(formattedDate)
            .set(newRecordData);
      }

      // 7. Provide success feedback and close the page
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Changes saved successfully!'), backgroundColor: Colors.green),
      );
      Navigator.of(context).pop(true);

    } catch (e) {
      // 8. Handle any errors during the process
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving changes: $e'), backgroundColor: Colors.red),
      );
    } finally {
      // 9. Ensure the saving indicator is turned off
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // A light background color to make the cards pop
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          "Manage Attendance Record",
          style: GoogleFonts.lato(fontWeight: FontWeight.bold),
        ),
        backgroundColor: wineColor,
        foregroundColor: Colors.white, // Ensures back button and title are white
        elevation: 4.0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: wineColor))
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
          : AnimatedOpacity(
        duration: const Duration(milliseconds: 500),
        opacity: _isLoading ? 0.0 : 1.0,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeaderCard(),
                const SizedBox(height: 24),
                _buildDeductionOptions(),
                const SizedBox(height: 24),
                _buildNotesField(),
                const SizedBox(height: 24),
                _buildImageUploadSection(),
                const SizedBox(height: 32),
                _buildSaveButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Helper Widgets for a Clean Build Method ---

  Widget _buildHeaderCard() {
    return Card(
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildHeaderInfoRow(
              icon: Icons.person_outline,
              label: 'Staff Member',
              value: _staffName ?? 'Loading...',
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildHeaderInfoRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'Date',
                    value: DateFormat.yMMMEd().format(widget.date),
                    crossAxisAlignment: CrossAxisAlignment.start,
                  ),
                ),
                Expanded(
                  child: _buildHeaderInfoRow(
                    icon: Icons.timer_outlined,
                    label: 'Hours Logged',
                    value: _recordData?['noOfHours']?.toStringAsFixed(2) ?? 'N/A',
                    crossAxisAlignment: CrossAxisAlignment.start,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

// CORRECTED VERSION
  Widget _buildHeaderInfoRow({
    required IconData icon,
    required String label,
    required String value,
    // The parameter name is now correctly in camelCase.
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
  }) {
    return Row(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Icon(icon, color: Colors.grey.shade600, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.sourceSans3(color: Colors.grey.shade600, fontSize: 14),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDeductionOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
          child: Text(
            "Recommendation", // Renamed for clarity
            style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
        ),
        // --- NEUTRAL OPTION ---
        _buildSimpleDeductionCard(
          title: 'No Action',
          subtitle: 'Leave attendance as originally logged.',
          value: 'None',
          icon: Icons.check_circle_outline,
          color: Colors.green,
        ),

        // --- APPROVAL OPTIONS ---
        _buildPartialApprovalCard(), // The new card with the stepper
        _buildSimpleDeductionCard( // Re-using simple card for Full Approval
          title: 'Full Approval',
          subtitle: 'Approve a full 8-hour day.',
          value: 'ApprovedFull',
          icon: Icons.verified_user_outlined,
          color: Colors.indigo,
        ),

        // --- DEDUCTION OPTIONS ---
        _buildPartialDeductionCard(),
        _buildFullDeductionCard(),
      ],
    );
  }

  // 3. Add this new helper widget specifically for the Partial Deduction layout.
  Widget _buildPartialDeductionCard() {
    final bool isSelected = _selectedDeduction == 'Partial';
    return Card(
      elevation: isSelected ? 4.0 : 1.0,
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? Colors.orange : Colors.transparent,
          width: 2.0,
        ),
      ),
      child: InkWell(
        onTap: () => setState(() {
          _selectedDeduction = 'Partial';
        }),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
          child: Row(
            children: [
              Radio<String>(
                value: 'Partial',
                groupValue: _selectedDeduction,
                onChanged: (v) => setState(() => _selectedDeduction = v!),
                activeColor: Colors.orange,
              ),
              Icon(Icons.warning_amber_rounded, color: isSelected ? Colors.orange : Colors.grey.shade600, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Partial Deduction', style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: isSelected ? Colors.orange : Colors.black87)),
                    Text('For lateness or leaving early.', style: GoogleFonts.sourceSans3(color: Colors.grey.shade700, fontSize: 14)),
                  ],
                ),
              ),
              // The stepper is now here, and only visible when this option is selected
              if (isSelected)
                _buildHourStepper( // <-- Use the new generic stepper
                  value: _deductedHours,
                  color: Colors.orange.shade700,
                  onChanged: (newValue) => setState(() => _deductedHours = newValue),
                ),
            ],
          ),
        ),
      ),
    );
  }

// 4. And another new helper widget for the Full Deduction layout.
  Widget _buildFullDeductionCard() {
    final bool isSelected = _selectedDeduction == 'Full';
    return Card(
      elevation: isSelected ? 4.0 : 1.0,
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? Colors.red : Colors.transparent,
          width: 2.0,
        ),
      ),
      child: InkWell(
        onTap: () => setState(() {
          _selectedDeduction = 'Full';
          _deductedHours = 8; // Silently set the hours to 8
        }),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
          child: Row(
            children: [
              Radio<String>(
                value: 'Full',
                groupValue: _selectedDeduction,
                onChanged: (v) => setState(() {
                  _selectedDeduction = v!;
                  _deductedHours = 8;
                }),
                activeColor: Colors.red,
              ),
              Icon(Icons.cancel_outlined, color: isSelected ? Colors.red : Colors.grey.shade600, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Full Deduction', style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: isSelected ? Colors.red : Colors.black87)),
                    Text('For truancy or unapproved absence.', style: GoogleFonts.sourceSans3(color: Colors.grey.shade700, fontSize: 14)),
                  ],
                ),
              ),
              // Display a static "8 hrs" text when selected
              if (isSelected)
                Text(
                  "8 hrs",
                  style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red.shade700),
                )
            ],
          ),
        ),
      ),
    );
  }




  Widget _buildSimpleDeductionCard({
    required String title,
    required String subtitle,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final bool isSelected = _selectedDeduction == value;
    return Card(
      elevation: isSelected ? 4.0 : 1.0,
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? color : Colors.transparent,
          width: 2.0,
        ),
      ),
      child: InkWell(
        onTap: () => setState(() => _selectedDeduction = value),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
          child: Row(
            children: [
              Radio<String>(
                value: value,
                groupValue: _selectedDeduction,
                onChanged: (newValue) => setState(() => _selectedDeduction = newValue!),
                activeColor: color,
              ),
              Icon(icon, color: isSelected ? color : Colors.grey.shade600, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.lato(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? color : Colors.black87,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.sourceSans3(color: Colors.grey.shade700, fontSize: 14),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotesField() {
    return TextFormField(
      controller: _notesController,
      decoration: InputDecoration(
        labelText: 'Reason / Supervisor Notes',
        labelStyle: GoogleFonts.sourceSans3(color: Colors.grey.shade700),
        hintText: 'e.g., Left facility after clock-in, arrived 3 hours late, Approve due to technical issues,Full Approval due to illness etc.',
        hintStyle: GoogleFonts.sourceSans3(),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: wineColor, width: 2.0),
        ),
        prefixIcon: const Icon(Icons.notes_rounded),
      ),
      maxLines: 4,
      validator: (value) {
        // A reason is required for any action other than "None".
        if (_selectedDeduction != 'None' && (value == null || value.trim().isEmpty)) {
          return 'A reason is required when making a recommendation.';
        }
        return null;
      },
    );
  }

  // New method to handle picking and uploading the image
  Future<void> _pickAndUploadImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return; // User cancelled the picker

    setState(() {
      _isUploading = true;
    });

    try {
      final imageData = await image.readAsBytes();
      // Create a unique file name
      final String fileName = 'evidence/${widget.staffId}-${widget.date.toIso8601String()}-${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Get a reference to the storage location
      final Reference storageRef = FirebaseStorage.instance.ref().child(fileName);

      // Upload the file
      final UploadTask uploadTask = storageRef.putData(imageData);
      final TaskSnapshot snapshot = await uploadTask;

      // Get the download URL
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      setState(() {
        _selectedImageData = imageData; // Show the new preview
        _newImageUrlToSave = downloadUrl; // Store URL for the final save
        _isUploading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image uploaded successfully! Ready to save.'), backgroundColor: Colors.green),
      );

    } catch (e) {
      setState(() { _isUploading = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading image: $e'), backgroundColor: Colors.red),
      );
    }
  }

// New widget for the entire upload section
  Widget _buildImageUploadSection() {
    return Card(
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Evidence (Optional)",
              style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // --- IMAGE DISPLAY AREA ---
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Center(
                child: _isUploading
                    ? const CircularProgressIndicator(color: Color(0xFF722F37))
                    : _selectedImageData != null
                // Show the newly picked image preview
                    ? Image.memory(_selectedImageData!, fit: BoxFit.contain)
                    : _existingImageUrl != null
                // Show the image from Firestore
                    ? Image.network(_existingImageUrl!, fit: BoxFit.contain, loadingBuilder: (context, child, progress) {
                  return progress == null ? child : const Center(child: CircularProgressIndicator());
                })
                // Placeholder if no image exists
                    : Icon(Icons.photo_library_outlined, size: 60, color: Colors.grey.shade400),
              ),
            ),
            const SizedBox(height: 16),
            // --- UPLOAD BUTTON ---
            OutlinedButton.icon(
              onPressed: _isUploading ? null : _pickAndUploadImage,
              icon: const Icon(Icons.upload_file),
              label: Text(_existingImageUrl != null || _selectedImageData != null ? 'Replace Image' : 'Upload Image'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      height: 50,
      child: ElevatedButton.icon(
        onPressed: _isSaving ? null : _saveChanges,
        icon: _isSaving
            ? Container() // Hide icon when loading
            : const Icon(Icons.save_alt_rounded, color: Colors.white),
        label: _isSaving
            ? const SizedBox(
          height: 24,
          width: 24,
          child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
        )
            : Text(
          'Save Changes',
          style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: wineColor,
          disabledBackgroundColor: wineColor.withOpacity(0.7),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 4.0,
        ),
      ),
    );
  }
}