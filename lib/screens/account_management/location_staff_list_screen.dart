import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import '../../models/staff.dart';
import 'user_form_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:html' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:excel/excel.dart';

class LocationStaffListScreen extends StatefulWidget {
  final String stateName;
  final String stateId;
  final String staffCategory;

  const LocationStaffListScreen({
    super.key,
    required this.stateName,
    required this.stateId,
    required this.staffCategory,
  });

  @override
  State<LocationStaffListScreen> createState() =>
      _LocationStaffListScreenState();
}

class _LocationStaffListScreenState extends State<LocationStaffListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSendingEmail = false;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }


  // --- ADD THIS ENTIRE NEW METHOD ---
  /// Fetches staff data, generates an Excel file, and triggers a download.
  Future<void> _downloadStaffListAsExcel() async {
    if (_isDownloading) return; // Prevent multiple calls
    setState(() => _isDownloading = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Preparing Excel file for download...')),
    );

    try {
      // 1. Fetch all staff for the current view from Firestore
      final staffSnapshot = await FirebaseFirestore.instance
          .collection('Staff')
          .where('state', isEqualTo: widget.stateName)
          .where('staffCategory', isEqualTo: widget.staffCategory)
          .where('accountStatus', isEqualTo: 'Active')
          .get();

      final List<Staff> staffList =
          staffSnapshot.docs.map((doc) => Staff.fromFirestore(doc)).toList();

      if (staffList.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No staff data available to download.'),
              backgroundColor: Colors.orange),
        );
        return; // Exit if there's nothing to download
      }

      // 2. Create an Excel workbook and sheet
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Staff List'];

      // 3. Define and style the header row
      List<String> headers = [
        'Full Name',
        'Email Address',
        'Phone Number',
        'Gender',
        'State',
        'Location',
        'Staff Category',
        'Department',
        'Designation',
        'Supervisor',
        "Supervisor's Email",
        'Attendance Record Count'
      ];
      var headerStyle = CellStyle(bold: true);
      //  sheetObject.appendRow(headers.map((e) => TextCellValue(e, cellStyle: headerStyle)).toList());

      // 4. Fetch attendance for each user and add data rows
      for (final staff in staffList) {
        // Efficiently get the count of attendance records
        final attendanceSnapshot = await FirebaseFirestore.instance
            .collection('Staff')
            .doc(staff.id)
            .collection('Record')
            .count()
            .get();

        final attendanceCount = attendanceSnapshot.count ?? 0;

        // Create a list of cell values for the current staff member
        List<CellValue> row = [
          TextCellValue(staff.fullName),
          TextCellValue(staff.emailAddress),
          TextCellValue(staff.mobile),
          TextCellValue(staff.gender),
          TextCellValue(staff.state),
          TextCellValue(staff.location),
          TextCellValue(staff.staffCategory),
          TextCellValue(staff.department),
          TextCellValue(staff.designation),
          TextCellValue(staff.supervisor),
          TextCellValue(staff.supervisorEmail),
          IntCellValue(attendanceCount)
        ];
        sheetObject.appendRow(row);
      }

      // Auto-fit columns for better readability
      // for (var i = 0; i < headers.length; i++) {
      //   sheetObject.setColAutoFit(i);
      // }

      // 5. Save the file and trigger the download (for web)
      final excelBytes = excel.save();
      if (excelBytes != null) {
        if (kIsWeb) {
          // Web platform - use blob download
          final blob = html.Blob([
            excelBytes
          ], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
          final url = html.Url.createObjectUrlFromBlob(blob);
          // Sanitize filename to remove invalid characters
          final safeCategory =
              widget.staffCategory.replaceAll(RegExp(r'[\\/*?:"<>|]'), "");
          final safeState =
              widget.stateName.replaceAll(RegExp(r'[\\/*?:"<>|]'), "");
          final anchor = html.AnchorElement(href: url)
            ..setAttribute(
                "download", "${safeState}_${safeCategory}_Staff_List.xlsx")
            ..click();
          html.Url.revokeObjectUrl(url);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Download started!'),
                backgroundColor: Colors.green),
          );
        } else {
          // Mobile platform - show message that download is not supported
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Excel download is only supported on web platform'),
                backgroundColor: Colors.orange),
          );
        }
      } else {
        throw Exception("Failed to save the Excel file.");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error creating Excel file: ${e.toString()}'),
            backgroundColor: Colors.red),
      );
    } finally {
      // Ensure the download state is reset even if an error occurs
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  // --- NEW METHOD TO FIND USERS AND LAUNCH EMAIL ---
  Future<void> _launchEmailForNonUsers() async {
    setState(() => _isSendingEmail = true);
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Finding users with zero attendance...')));

    try {
      // 1. Get all staff in the current view
      final staffSnapshot = await FirebaseFirestore.instance
          .collection('Staff')
          .where('state', isEqualTo: widget.stateName)
          .where('staffCategory', isEqualTo: widget.staffCategory)
          .where('accountStatus', isEqualTo: 'Active')
          .get();

      final List<Staff> allStaff =
          staffSnapshot.docs.map((doc) => Staff.fromFirestore(doc)).toList();
      List<String> recipientEmails = [];

      // 2. For each staff member, check their attendance count
      for (final staff in allStaff) {
        final recordCountSnapshot = await FirebaseFirestore.instance
            .collection('Staff')
            .doc(staff.id)
            .collection('Record')
            .limit(
                1) // We only need to know if it's > 0, so limit(1) is efficient
            .get();

        if (recordCountSnapshot.docs.isEmpty) {
          // If they have 0 records, add their email to the list
          if (staff.emailAddress.isNotEmpty) {
            recipientEmails.add(staff.emailAddress);
          }
        }
      }

      if (recipientEmails.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Great! Everyone in this category has attendance records.'),
            backgroundColor: Colors.green));
        setState(() => _isSendingEmail = false);
        return;
      }

      // 3. Prepare and launch the email
      final String subject =
          'Important: Action Required for Service Delivery Workspace App';

      // Refined email body
      final String body = '''
Dear Team,

This is a friendly reminder regarding the use of the Service Delivery Workspace App for attendance tracking. We've noticed that some accounts have not yet recorded any clock-ins.

**Action Required:**
Please ensure you clock in and out daily using the app. This is crucial for accurate attendance and timesheet records.

**Important Notes:**
- **Sync Your Data:** If you are already using the app, please remember to sync your records regularly to ensure they are updated on the server. If you have already done so, please disregard this message.
- **Clock-Out is Essential:** You must clock-out at the end of each workday. The system calculates hours worked based on clock-in and clock-out times. A missing clock-out will result in zero (0) hours worked for that day's timesheet.

For a detailed guide on using the app, please refer to the User Guide available within the app itself. If you encounter any issues or have questions, please reach out to your designated support contact.

Thank you,
The Service Delivery Workspace Team
''';

      final String bccRecipients = recipientEmails.join(',');

      final Uri emailLaunchUri = Uri(
        scheme: 'mailto',
        queryParameters: {
          'subject': subject,
          'body': body,
          'bcc': bccRecipients,
        },
      );

      if (await canLaunchUrl(emailLaunchUri)) {
        await launchUrl(emailLaunchUri);
      } else {
        throw 'Could not launch email client.';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red));
    } finally {
      setState(() => _isSendingEmail = false);
    }
  }

  /// --- NEW: "Copy & Go" Dialog ---
  void _showEmailDialog(List<String> recipients, String subject, String body) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Compose Reminder Email'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('The following users have zero attendance records:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(recipients.join(', ')),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy All Emails (for BCC)'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: recipients.join(',')));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Emails copied to clipboard!')));
                },
              ),
              const Divider(height: 30),
              const Text('Email Content:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SelectableText("Subject: $subject"),
              const SizedBox(height: 8),
              SelectableText(body),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('Done'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          // --- NEW: Add an "Open Email App" button as a fallback ---
          FilledButton(
            child: const Text('Try to Open Email App'),
            onPressed: () async {
              final Email email = Email(
                body: body,
                subject: subject,
                bcc: recipients,
                isHTML: false,
              );
              try {
                await FlutterEmailSender.send(email);
              } catch (error) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text(
                        'Could not open email client. Please copy the details manually.')));
              }
            },
          )
        ],
      ),
    );
  }

  /// --- UPDATED: This method now calls the dialog ---
  Future<void> _processReminderEmail() async {
    setState(() => _isSendingEmail = true);
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Finding users with zero attendance...')));

    try {
      final staffSnapshot = await FirebaseFirestore.instance
          .collection('Staff')
          .where('state', isEqualTo: widget.stateName)
          .where('staffCategory', isEqualTo: widget.staffCategory)
          .where('accountStatus', isEqualTo: 'Active')
          .get();

      final List<Staff> allStaff =
          staffSnapshot.docs.map((doc) => Staff.fromFirestore(doc)).toList();
      List<String> recipientEmails = [];

      for (final staff in allStaff) {
        final recordCountSnapshot = await FirebaseFirestore.instance
            .collection('Staff')
            .doc(staff.id)
            .collection('Record')
            .limit(1)
            .get();

        if (recordCountSnapshot.docs.isEmpty && staff.emailAddress.isNotEmpty) {
          recipientEmails.add(staff.emailAddress);
        }
      }

      if (recipientEmails.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Great! Everyone in this category has attendance records.'),
            backgroundColor: Colors.green));
        setState(() => _isSendingEmail = false);
        return;
      }

      final String subject =
          'Important: Action Required for Service Delivery Workspace App';
      final String body = '''Dear Team,

This is a friendly reminder regarding the use of the Service Delivery Workspace App for attendance tracking. We've noticed that some accounts have not yet recorded any clock-ins.

**Action Required:**
Please ensure you clock in and out daily using the app. This is crucial for accurate attendance and timesheet records.

**Important Notes:**
- **Sync Your Data:** If you are already using the app, please remember to sync your records regularly. If you have done so, please disregard this message.
- **Clock-Out is Essential:** You must clock-out at the end of each workday. A missing clock-out will result in zero (0) hours worked for that day's timesheet.

For a detailed guide, please refer to the User Guide within the app. If you have questions, please reach out for support.

Thank you,
The Service Delivery Workspace Team
''';

      // Show the new dialog instead of trying to launch mailto directly
      _showEmailDialog(recipientEmails, subject, body);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red));
    } finally {
      setState(() => _isSendingEmail = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          widget.staffCategory,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_isDownloading)
            const Padding(
              padding: EdgeInsets.only(right: 20.0),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: TextButton.icon(
                onPressed: _downloadStaffListAsExcel,
                icon: const Icon(Icons.download_for_offline_outlined, color: Colors.black),
                label: const Text(
                  'Download Excel',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.red.shade600,
              Colors.black87,
              Colors.white,
              Colors.yellow.shade600,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildSearchBar(),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('Staff')
                      .where('state', isEqualTo: widget.stateName)
                      .where('staffCategory', isEqualTo: widget.staffCategory)
                      .where('accountStatus', isEqualTo: 'Active')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Colors.white));
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                          child: Text(
                              'No staff found for ${widget.staffCategory} in ${widget.stateName}.',
                              style: const TextStyle(color: Colors.white)));
                    }

                    List<Staff> allStaff = snapshot.data!.docs
                        .map((doc) => Staff.fromFirestore(doc))
                        .toList();

                    if (_searchQuery.isNotEmpty) {
                      allStaff = allStaff
                          .where((staff) =>
                              staff.fullName
                                  .toLowerCase()
                                  .contains(_searchQuery) ||
                              staff.emailAddress
                                  .toLowerCase()
                                  .contains(_searchQuery) ||
                              staff.location
                                  .toLowerCase()
                                  .contains(_searchQuery))
                          .toList();
                    }
                    if (allStaff.isEmpty) {
                      return const Center(
                          child: Text('No users match your search.',
                              style: TextStyle(color: Colors.white)));
                    }

                    final groupedStaff = _groupStaffByLocation(allStaff);
                    final locations = groupedStaff.keys.toList()..sort();

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      itemCount: locations.length,
                      itemBuilder: (context, index) {
                        final location = locations[index];
                        final staffInLocation = groupedStaff[location]!;
                        return _LocationExpansionTile(
                          location: location,
                          staffInLocation: staffInLocation,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSendingEmail
            ? null
            : _processReminderEmail,
        backgroundColor: _isSendingEmail ? Colors.grey : Colors.blue.shade700,
        icon: _isSendingEmail
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.email_outlined, color: Colors.white),
        label: const Text('Remind Non-Users',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: Colors.grey.shade800),
        decoration: InputDecoration(
          hintText: 'Search by Name, Email, Location...',
          hintStyle: TextStyle(color: Colors.grey.shade600),
          prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
          filled: true,
          fillColor: Colors.white.withOpacity(0.9),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 14.0),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.grey.shade600),
                  onPressed: () => _searchController.clear())
              : null,
        ),
      ),
    );
  }

  Map<String, List<Staff>> _groupStaffByLocation(List<Staff> staffList) {
    final Map<String, List<Staff>> grouped = {};
    for (var staff in staffList) {
      final location =
          staff.location.isEmpty ? 'Unspecified Location' : staff.location;
      if (grouped[location] == null) {
        grouped[location] = [];
      }
      grouped[location]!.add(staff);
    }
    return grouped;
  }
}

// Reusable "glassmorphism" ExpansionTile (No changes needed here)
class _LocationExpansionTile extends StatelessWidget {
  final String location;
  final List<Staff> staffInLocation;

  const _LocationExpansionTile(
      {required this.location, required this.staffInLocation});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: Colors.white.withOpacity(0.85),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.0),
        side: BorderSide(color: Colors.white.withOpacity(0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Text(
          '$location (${staffInLocation.length})',
          style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
              fontSize: 18),
        ),
        iconColor: Colors.red.shade700,
        collapsedIconColor: Colors.grey.shade700,
        children: staffInLocation
            .map((staff) => _StaffListTile(staff: staff))
            .toList(),
      ),
    );
  }
}

// --- NEW: Converted to a StatefulWidget to manage its own state ---
class _StaffListTile extends StatefulWidget {
  final Staff staff;
  const _StaffListTile({required this.staff});

  @override
  State<_StaffListTile> createState() => _StaffListTileState();
}

class _StaffListTileState extends State<_StaffListTile> {
  int? _attendanceCount; // Nullable to represent loading state

  @override
  void initState() {
    super.initState();
    _fetchAttendanceCount();
  }

  Future<void> _fetchAttendanceCount() async {
    // Prevents errors if the widget is disposed before the async operation completes
    if (!mounted) return;
    try {
      // Efficiently get the count of documents in the subcollection
      final snapshot = await FirebaseFirestore.instance
          .collection('Staff')
          .doc(widget.staff.id)
          .collection('Record')
          .count()
          .get();

      if (mounted) {
        setState(() {
          _attendanceCount = snapshot.count;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _attendanceCount = 0; // Default to 0 on error
        });
      }
    }
  }

  void _showDeleteConfirmation(BuildContext context, Staff staff) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Account Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_off, color: Colors.orange),
              title: const Text('Resigned'),
              onTap: () async {
                await FirebaseFirestore.instance
                    .collection('Staff')
                    .doc(staff.id)
                    .update({'accountStatus': 'Resigned'});
                if (context.mounted) {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Account status updated to Resigned'),
                        backgroundColor: Colors.green),
                  );
                }
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.cancel_schedule_send, color: Colors.red),
              title: const Text('Terminated'),
              onTap: () async {
                await FirebaseFirestore.instance
                    .collection('Staff')
                    .doc(staff.id)
                    .update({'accountStatus': 'Terminated'});
                if (context.mounted) {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Account status updated to Terminated'),
                        backgroundColor: Colors.green),
                  );
                }
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.pause_circle_filled, color: Colors.blueGrey),
              title: const Text('Inactive'),
              onTap: () async {
                await FirebaseFirestore.instance
                    .collection('Staff')
                    .doc(staff.id)
                    .update({'accountStatus': 'Inactive'});
                if (context.mounted) {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Account status updated to Inactive'),
                        backgroundColor: Colors.green),
                  );
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(ctx).pop()),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Helper function to build subtitle text lines to avoid repetition
    Widget buildSubtitleLine(String label, String value) {
      return Text(
        '$label: ${value.isNotEmpty ? value : "N/A"}',
        style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
        overflow: TextOverflow.ellipsis,
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Material(
        color: Colors.grey.shade50.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
        child: ListTile(
          leading: CircleAvatar(
            radius: 28,
            backgroundColor: Colors.grey.shade300,
            backgroundImage: widget.staff.photoUrl.isNotEmpty
                ? NetworkImage(widget.staff.photoUrl)
                : null,
            child: widget.staff.photoUrl.isEmpty
                ? const Icon(Icons.person, color: Colors.white, size: 30)
                : null,
          ),
          title: Text(widget.staff.fullName,
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: Colors.grey.shade900)),
          // --- NEW: Rebuilt subtitle with more information ---
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              buildSubtitleLine('Sex', widget.staff.gender),
              buildSubtitleLine('Email Address', widget.staff.emailAddress),
              buildSubtitleLine('Phone Number', widget.staff.mobile),
              buildSubtitleLine('Department', widget.staff.department),
              buildSubtitleLine('Designation', widget.staff.designation),
              buildSubtitleLine('Bank', widget.staff.bankName),
              buildSubtitleLine('Account Number', widget.staff.accountNumber),
              buildSubtitleLine('Name of Supervisor', widget.staff.supervisor),
              buildSubtitleLine(
                  "Supervisor's Email Address", widget.staff.supervisorEmail),
              buildSubtitleLine("Program Manager", widget.staff.programManager),
              buildSubtitleLine("Program Manager's Email Address",
                  widget.staff.programManagerEmail),
              if (_attendanceCount == null)
                Text('Attendance: Loading...',
                    style: TextStyle(
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                        fontSize: 12))
              else
                Text('Attendance: $_attendanceCount records',
                    style:
                        TextStyle(color: Colors.grey.shade700, fontSize: 12)),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.edit_outlined, color: Colors.blue.shade700),
                tooltip: 'Edit User',
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => UserFormScreen(staff: widget.staff),
                )),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'Update Account Status',
                onPressed: () => _showDeleteConfirmation(context, widget.staff),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
