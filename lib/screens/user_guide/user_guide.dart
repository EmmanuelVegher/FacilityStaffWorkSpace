import 'package:flutter/material.dart';

import '../../services/isar_service.dart';
import '../../widgets/drawer.dart';

// NEW: A dedicated widget to display an image in full screen.
// It supports zooming and can be dismissed with a tap.
// UPDATED: A dedicated widget to display an image in full screen.
// It now features an explicit close icon in the top-right corner.
class FullScreenImageViewer extends StatelessWidget {
  final String assetPath;
  final String heroTag;

  const FullScreenImageViewer({
    super.key,
    required this.assetPath,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      // Using a Stack to overlay the close button on top of the image.
      body: Stack(
        children: [
          // The main image viewer, which allows panning and zooming.
          Center(
            // Hero widget enables the smooth transition animation.
            child: Hero(
              tag: heroTag,
              child: InteractiveViewer(
                panEnabled: true,
                minScale: 1.0,
                maxScale: 4.0, // Allow zooming up to 4x
                child: Image.asset(
                  assetPath,
                  fit: BoxFit.contain,
                  // Error builder for the full-screen view as well.
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.black,
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.broken_image_outlined,
                              color: Colors.white,
                              size: 60,
                            ),
                            SizedBox(height: 16),
                            Text(
                              "Image not found",
                              style: TextStyle(color: Colors.white, fontSize: 18),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          // NEW: The close button positioned in the top-right corner.
          Positioned(
            top: 40.0, // Adjust for status bar height
            right: 20.0,
            child: CircleAvatar(
              backgroundColor: Colors.black.withOpacity(0.5),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () {
                  // Pop the screen to return to the user guide.
                  Navigator.pop(context);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class UserGuidePage extends StatelessWidget {
  const UserGuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "📘 CARITAS Nigeria Service Delivery WorkSpace User Guide",
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
        backgroundColor: const Color(0xFF722F37),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: drawer(
        context,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeader(
              "Welcome to the CARITAS Nigeria Service Delivery WorkSpace App!"),
          _buildParagraph(
              "This app helps you manage your daily tasks, attendance, timesheets, inventory, and client tracking all in one place. It's built for staff who want to stay organized, track their work, and sync everything with Firebase and NMRS."),

          _buildSection("📊 Dashboard Overview"),
          _buildParagraph(
              "The Dashboard is your central hub for an at-a-glance view of your key metrics, attendance summaries, team activities, and performance insights. It's designed to be interactive and informative."),

          _buildSubHeader("1. User Profile & Quick Stats"),
          _buildParagraph(
              "At the top, you'll find your personalized header: \n"
                  "•  **Profile Picture:** Your uploaded image.\n"
                  "•  **User Details:** Displays your Name, Designation, and Location.\n"
                  "•  **Attendance Quick View:** Shows your total clock-ins and clock-outs for the currently selected date range."),
          // MODIFIED: Pass context to _buildImage to handle navigation
          _buildImage(context, "assets/screens/dashboard_user_profile_header.png",
              "User Profile and Quick Attendance Stats."),

          _buildSubHeader("2. Date Range Filters & Report Generation"),
          _buildParagraph(
              "Control the data displayed on your dashboard:\n"
                  "•  **Start Date & End Date Pickers:** Select a specific period to view your attendance data and analytics.\n"
                  "•  **Generate Button:** Click this to refresh the dashboard and all charts with data from the selected date range."),
          _buildImage(context, "assets/screens/dashboard_date_filters.png",
              "Date Filters and Generate Button."),

          _buildSubHeader("3. PDF Export & Sharing"),
          _buildParagraph(
              "Easily document and share your dashboard summary:\n"
                  "•  **Download PDF Icon:** Generates a PDF report of the current dashboard view and saves it to your device.\n"
                  "•  **Share PDF Icon:** Generates a PDF report and allows you to share it via other apps (e.g., email, messaging)."),
          _buildImage(context, "assets/screens/dashboard_pdf_actions.png",
              "PDF Download and Share Icons. "),

          _buildSubHeader("4. Key Attendance Summary Cards"),
          _buildParagraph(
              "A grid of cards providing key attendance metrics for the selected period:\n"
                  "•  **Total Hours Worked:** Sum of all hours worked.\n"
                  "•  **Min Hours Worked:** The minimum hours worked on a single day (excluding leave/holidays).\n"
                  "•  **Max Hours Worked:** The maximum hours worked on a single day.\n"
                  "•  **Avg Hours Worked:** Average daily hours worked (excluding leave/holidays).\n"
                  "•  **Holidays Filled:** Number of days marked as holidays.\n"
                  "•  **Annual Leave Taken:** Number of annual leave days taken."),
          _buildImage(
              context,
              "assets/screens/dashboard_summary_cards_grid.png",
              "Attendance Summary Cards. "),

          _buildSubHeader("5. Facility Clock-In Live Feed (Today)"),
          _buildParagraph(
              "This card shows a real-time list of clock-ins for today from all staff within your facility. It includes:\n"
                  "•  Staff Name\n"
                  "•  Date\n"
                  "•  Clock-In Time\n"
                  "•  Status (e.g., 'Clocked-In, Yet to Clock Out', 'Clocked-In and Clocked Out')."),
          _buildImage(
              context,
              "assets/screens/dashboard_facility_live_clock_in.png",
              "Facility Clock-In Live Feed. "),

          _buildSubHeader("6. Clock-In and Clock-Out Trends Chart"),
          _buildParagraph(
              "A line chart visualizing your clock-in and clock-out times over the selected date range. Helps identify patterns in your work schedule."),
          _buildImage(context, "assets/screens/dashboard_clock_trends_chart.png",
              "Clock-In/Out Trends Chart. "),

          _buildSubHeader("7. Early/Late Clock-Ins Chart"),
          _buildParagraph(
              "A column chart showing how many minutes you clocked in early (green) or late (red) compared to the standard start time (e.g., 8:00 AM) for each day in the selected period."),
          _buildImage(context, "assets/screens/dashboard_early_late_chart.png",
              "Early/Late Clock-Ins Chart. "),

          _buildSubHeader("8. Distribution of Hours Worked Chart"),
          _buildParagraph(
              "A histogram that displays the frequency of different work durations. For example, it shows how many days you worked 8 hours, 7 hours, etc., during the selected period."),
          _buildImage(
              context,
              "assets/screens/dashboard_hours_distribution_chart.png",
              "Distribution of Hours Worked Chart. "),

          _buildSubHeader("9. Attendance by Location Chart"),
          _buildParagraph(
              "A doughnut chart showing the breakdown of your attendance records by the GPS location recorded at clock-in. Useful if you work from multiple sites."),
          _buildImage(context, "assets/screens/dashboard_location_chart.png",
              "Attendance by Location Chart. "),

          _buildSubHeader("10. Team Player of the Month (Facility Votes)"),
          _buildParagraph(
              "This section highlights the staff member recognized as the 'Team Player' based on votes from colleagues within your facility for the current month (or selected period if data spans beyond current month). It includes:\n"
                  "•  Name of the recognized team player.\n"
                  "•  Their vote count relative to the total surveys.\n"
                  "•  A bar chart showing the vote distribution among other nominated staff."),
          _buildImage(context, "assets/screens/dashboard_team_player_chart.png",
              "Team Player of the Month. "),

          _buildSection("📅 Attendance Module"),
          _buildParagraph(
              "The Attendance module allows you to manage your daily clock-ins, clock-outs, view your attendance history, and manage data synchronization. It's divided into three main tabs accessible from the bottom navigation: Calendar, Clock In/Out, and Profile."),

          _buildSubHeader("📲 Clock In/Out Tab (Check Icon)"),
          _buildParagraph(
              "This is your primary screen for daily attendance actions. It provides real-time information and action buttons:"),
          _buildBulletPoints([
            "**GPS & Location Status:** Displays your current GPS coordinates (Latitude, Longitude), accuracy, altitude, speed, and the determined location address. It also indicates if your GPS is on/off and if you are within a recognized office geofence.",
            "**User Welcome:** Greets you by name.",
            "**Today's Times:** Shows your clock-in and clock-out times for the current day if already recorded.",
            "**Clocking In:** Tap the 'Clock-In' image. This records your current time and GPS location. On specific days (e.g., the last Thursday of the month between the 20th and 30th), you may be required to complete a survey before you can clock in.",
            "**Clocking Out:** After clocking in, the 'Clock-Out' image will appear. Tap it to record your clock-out time and location. A confirmation prompt will appear.",
            "**Day Completed:** Once clocked out, the screen will show a 'You have completed this day!' message, along with your total duration worked.",
            "**Adding Comments:** After clocking out (or if the day is complete), a text field appears allowing you to add comments for that day's attendance record. Tap 'Add Comment' to save.",
            "**Out Of Office Button:** If you are not working (e.g., on leave), tap this button to navigate to the Leave Request page.",
          ]),
          _buildImage(
              context,
              "assets/screens/attendance_clock_in_out_tab.png",
              "Clock In/Out Tab."),
          _buildImage(
              context,
              "assets/screens/attendance_clock_out_state.png",
              "Clock In/Out Tab - After Clocking Out. "),

          _buildSubHeader("🗓️ Calendar Tab"),
          _buildParagraph(
              "This tab allows you to view and manage your past attendance records:"),
          _buildBulletPoints([
            "**View History:** Displays a list of your attendance records.",
            "**Filter by Month/Year:** Use the dropdowns at the top to select a specific month and year to view its records.",
            "**Record Details:** Each card in the list shows comprehensive details for a day: Date, Clock-In time, Clock-Out time, Clock-In Location, Clock-Out Location (with Lat/Long), Duration Worked (or Off-Day reason like 'Holiday'), Sync Status (Synced/Not Synced), and any Comments.",
            "**Delete Record:** Tap on an attendance card to bring up options. You can choose to delete the record (a confirmation will be required).",
            "**Manual Sync (per record):** Each record card has a refresh icon (🔄). Tapping this will attempt to sync that specific record to the server if it's not already synced and has a clock-out time.",
          ]),
          _buildImage(
              context,
              "assets/screens/attendance_calendar_tab.png",
              "Attendance Calendar/History Tab. "),

          _buildSubHeader("👤 Profile Tab (User Icon)"),
          _buildParagraph(
              "The Profile tab, accessible from the bottom navigation, is where you can view and manage your personal and work-related information:"),
          _buildBulletPoints([
            "**Profile Picture:** View your current profile picture. You can tap on it to select and upload a new image from your gallery.",
            "**Basic Information:** Displays your full name and current designation.",
            "**Editable Details:** Most of your profile information can be updated here. Tap the edit icon (✏️) next to a field to change it:",
            "  •  Gender, Marital Status",
            "  •  Staff Category",
            "  •  State (options may depend on Staff Category)",
            "  •  Office/Facility Location (options depend on selected State and Staff Category)",
            "  •  Email Address, Phone Number",
            "  •  Department (options may depend on Staff Category)",
            "  •  Designation (options depend on selected Department and Staff Category)",
            "  •  Project",
            "  •  Supervisor (selecting a supervisor also updates their email)",
            "**Signature Management:** Upload or update your digital signature. This is used in reports and timesheets. See the main 'Upload Signature' section for more details.",
            "**Sync Profile Changes:** If you make any changes to your profile, a 'Sync Updated Bio Data' button will appear. Tap this to save your changes to the server.",
          ]),
          _buildImage(
              context,
              "assets/screens/attendance_profile_tab.png",
              "Profile Tab for managing user information. "),

          _buildSubHeader("🔄 Sync, Backup & Restore (App Bar Icons)"),
          _buildParagraph(
              "On the main Attendance screen (top app bar), you'll find icons for data management:"),
          _buildBulletPoints([
            "**Upload Icon (Sync & Backup):** Tapping this opens a dialog with two options:",
            "  •  **Sync Attendance:** Uploads your completed attendance records (those with a clock-out) to the Firebase server. It also attempts to resolve any missing GPS locations and syncs your profile picture.",
            "  •  **Local Backup:** Creates a local backup of your attendance and profile data as JSON files on your device's storage.",
            "**Download Icon (Restore Data):** Tapping this opens a dialog to restore data:",
            "  •  **Local DB Restore:** Restores your attendance and profile data from the previously created local JSON backup. This will overwrite current local data.",
            "  •  **Restore from Server:** Downloads your attendance history from the Firebase server and replaces your local data. Warning: Unsynced local changes might be lost.",
          ]),
          _buildImage(
              context,
              "assets/screens/attendance_sync_backup_dialog.png",
              "Sync & Backup Options Dialog. "),
          _buildImage(
              context,
              "assets/screens/attendance_restore_dialog.png",
              "Restore Data Options Dialog. "),
          _buildParagraph(
              "**Automatic Updates:** The app periodically checks for new app versions and updates to essential data like office locations. You may be prompted if an update is required."),

          _buildSection("📝 Leave Request Module"),
          _buildParagraph(
              "This module allows you to apply for various types of leave, track your leave balances, and manage your requests. It also provides real-time GPS and location information."),
          _buildImage(context, "assets/screens/leave_request_main_view.png",
              "Leave Request Main View. "),

          _buildSubHeader("📍 Geo-Coordinates Information"),
          _buildParagraph(
              "Similar to the Attendance module, this section displays:"),
          _buildBulletPoints([
            "GPS status (On/Off).",
            "Current Latitude, Longitude, Accuracy, Altitude, Speed, and Timestamp of location data.",
            "Mock location status.",
            "Determined current State and Location (based on geofencing or reverse geocoding).",
          ]),
          _buildImage(context, "assets/screens/leave_request_gps_info.png",
              "GPS and Location Info on Leave Page. "),

          _buildSubHeader("📊 Leave Balance Summary"),
          _buildParagraph(
              "Visually track your leave balances for the current fiscal year:"),
          _buildBulletPoints([
            "**Circular Progress Indicator:** Shows the total leaves allocated for the fiscal year and the proportion used.",
            "**Textual Summary:** Details the number of 'Used' and 'Remaining' days for:",
            "  •  Annual Leave.",
            "  •  Maternity Leave (visible if applicable based on your profile's gender).",
            "**Holiday Leave Summary:** Shows the number of 'Approved' and 'Pending' holiday leave requests.",
            "Leave balances are automatically updated based on approved requests and fiscal year rollovers (around October 1st).",
          ]),
          _buildImage(
              context,
              "assets/screens/leave_request_balance_summary.png",
              "Leave Balance Summary. "),

          _buildSubHeader("📜 Leave Request History"),
          _buildParagraph(
              "View and manage your past and pending leave requests:"),
          _buildBulletPoints([
            "**Grouped by Fiscal Year:** Requests are organized into expandable sections by Fiscal Year (FY).",
            "**Request Details:** Each entry displays the leave type, date range (From DD MMMM, YYYY to DD MMMM, YYYY), and status (Pending, Approved, Rejected) with a corresponding icon and color.",
            "**Duration:** Approved leaves show the duration in days.",
            "**Actions on Pending Requests:**",
            "  •  **Edit (✏️):** Modify the leave type, date range, reason, or supervisor for pending requests. The form will pre-fill with existing details.",
            "  •  **Delete (🗑️):** Remove a pending leave request. A confirmation will be required.",
            "  •  **Sync (🔄):** Manually re-submit or sync a pending request if needed.",
            "**Rejected Requests:** An info icon (ℹ️) will appear, allowing you to view the reason for rejection.",
            "**Automatic Status Updates:** The app periodically checks for status updates from supervisors and reflects them here.",
          ]),
          _buildImage(
              context,
              "assets/screens/leave_request_history_list.png",
              "Leave Request History. "),

          _buildSubHeader("➕ Applying for Leave"),
          _buildParagraph(
              "Tap the 'Click HERE to Request Leave' floating action button to open the application form:"),
          _buildBulletPoints([
            "**Select Leave Type:** Choose from 'Annual', 'Maternity' (if applicable), or 'Holiday' using the buttons at the top.",
            "**Select Date Range:** Use the calendar to pick your start and end dates. Dates with existing attendance records or public holidays will be disabled or visually indicated.",
            "**Choose Supervisor:** Select your supervisor from a dropdown list. Their email will be automatically fetched.",
            "**Reason:** Enter a brief reason for your leave request.",
            "**Submit Request:** Upon submission:",
            "  •  The system calculates the leave duration (weekends are excluded for Annual leave).",
            "  •  It checks if the requested duration exceeds your available balance for the selected leave type.",
            "  •  An email notification is sent to your selected supervisor containing the leave details and your current leave summary.",
            "  •  The request is saved to Firebase with a 'Pending' status.",
          ]),
          _buildImage(context, "assets/screens/leave_request_apply_form.png",
              "Leave Application Form/Modal. "),
          _buildParagraph(
              "**Automatic Sync with Attendance:** Once a leave request is 'Approved' by your supervisor, the system will automatically create corresponding 'Off-Day' entries in your Attendance records for the approved dates if no attendance exists for those days."),

          _buildSection("📞 Call Tracker Module"),
          _buildParagraph(
              "The Call Tracker module helps manage client interactions. It's PIN-protected and syncs data with Firebase and NMRS. Navigation is via bottom tabs:"),
          _buildImage(
              context,
              "assets/screens/call_tracker_main_navigation.png",
              "Call Tracker Tabs. "),

          _buildSubHeader("Import Tab (File Upload Icon)"),
          _buildBulletPoints([
            "**Add Contact Manually:** Enter client details (Name, Phone, Address, Visit Dates, Appointment Type, State, Facility, Unique ID, DATIM Code, VL info) one by one.",
            "**Import from CSV:** Select a CSV file. Required columns: `patient_id`, `name`, `phone_number`. Optional: `last_visit_date`, `next_visit_date`, etc. Existing contacts are cleared before CSV import.",
            "**Import from NigeriaMRS (NMRS):** Configure MySQL settings (Host, Port, User, Password, Database, Timeout). Import contacts based on a next appointment date range or all client appointments using a specific SQL script (downloadable/shareable from this tab).",
            "**Weekly Data Wipe:** Local contacts are cleared on Mondays or if the last import was over 7 days ago to maintain data freshness.",
          ]),
          _buildImage(context, "assets/screens/call_tracker_import_tab.png",
              "Call Tracker - Import Tab. "),

          _buildSubHeader("Today's Calls Tab (Calendar Icon)"),
          _buildBulletPoints([
            "**View Today's Appointments:** Lists clients scheduled for today.",
            "**Search & Filter:** Search contacts; filter by 'Actual' or 'Calculated' appointment types.",
            "**Direct Calling & Logging:** Tap the call icon (📞) to call. After outgoing/incoming calls (from monitored numbers), the app logs details (status, duration).",
            "**Tracking Form:** For answered calls over a minimum duration, a form appears to capture interaction details (reason, outcome, verification, discontinuation). This form syncs to NMRS.",
            "**Edit Contact Info:** Modify visit dates, phone, address. Changes can be synced to NMRS if applicable (DATIM code match required for phone/address).",
            "**Data Masking & PIN:** Sensitive data (name, phone, ID) is masked. Unmask all contacts via PIN using the (👁️) icon in the app bar.",
            "**Sync:** Buttons sync local call logs to Firebase and completed tracking forms to NMRS (requires provider status & DATIM match).",
          ]),
          _buildImage(
              context,
              "assets/screens/call_tracker_today_calls_tab.png",
              "Call Tracker - Today's Calls Tab. "),
          _buildImage(
              context,
              "assets/screens/call_tracker_tracking_form.png",
              "Call Tracker - Tracking Form Dialog. "),

          _buildSubHeader("Missed & IIT Tab (Schedule Icon)"),
          _buildBulletPoints([
            "**View Missed Appointments:** Lists clients with 'Missed Appointment' ART status.",
            "**View IIT Clients:** Lists clients with 'IIT' (Interruption In Treatment) ART status.",
            "**Functionality:** Similar to 'Today's Calls' tab (search, filter, call, log, forms, edit, sync, data masking).",
            "**Automatic Call Logging:** Monitors and logs incoming calls from contacts in these lists.",
          ]),
          _buildImage(
              context,
              "assets/screens/call_tracker_missed_iit_tab.png",
              "Call Tracker - Missed & IIT Tab. "),

          _buildSubHeader("Upcoming Appointments Tab (Upcoming Icon)"),
          _buildBulletPoints([
            "**View Future Appointments:** Lists contacts with appointments scheduled after today.",
            "**Functionality:** Same as other list tabs (search, filter, call, log, forms, edit, sync, data masking).",
            "**Automatic Call Logging:** Monitors and logs incoming calls from contacts in this list.",
          ]),
          _buildImage(context, "assets/screens/call_tracker_upcoming_tab.png",
              "Call Tracker - Upcoming Appointments Tab. "),

          _buildSubHeader("Contacts Tab (Contacts Icon)"),
          _buildBulletPoints([
            "**View All Imported Contacts:** A comprehensive list of all local contacts.",
            "**Functionality:** Offers the same set of actions as other list tabs: search, filter (by appointment type), call, log calls, fill tracking forms, edit contact details, and sync information.",
            "**NMRS User Selection:** Allows selecting the current NMRS user profile for syncing data to NMRS. This is crucial for attributing actions correctly in NMRS.",
          ]),
          _buildImage(context, "assets/screens/call_tracker_contacts_tab.png",
              "Call Tracker - Contacts Tab. "),

          _buildSubHeader("Reports Tab (Assessment Icon)"),
          _buildBulletPoints([
            "**Filter by Date Range:** View reports for specific periods.",
            "**Summary Charts:** Visualizes call status distribution, ART status, average call duration trends, and monthly update trends (phone, address, next visit).",
            "**Calls per Client Summary:** Table showing total calls and status counts per client.",
            "**Detailed Logs:** Expandable table of all tracked call records, grouped by date.",
            "**Export Data:** Export the report data as CSV or PDF (data masked unless globally unmasked via PIN).",
            "**PIN Management:** Access PIN setup/change screen.",
          ]),
          _buildImage(context, "assets/screens/call_tracker_reports_tab.png",
              "Call Tracker - Reports Tab. "),

          _buildSection("🛡️ Enhance Adherence Counselling (EAC) Module"),
          _buildParagraph(
              "The EAC Tracker module facilitates the management of clients undergoing Enhanced Adherence Counselling. It helps track EAC sessions, viral load results, and adherence barriers. The module is PIN-protected."),
          _buildImage(context, "assets/screens/eac_tracker_main_tabs.png",
              "EAC Tracker Tabs Overview. "),

          _buildSubHeader("Import EAC List Tab"),
          _buildBulletPoints([
            "**Import from CSV:** Load client EAC data from a CSV file. Expected columns include `Facility_Name`, `Datim_Code`, `person_id`, `Client_Name`, `ART_ID`, `Hospital_Number`, `Phone_Number`, `Current_Age`, `ART_START_DATE`, `Sample_Collection_Date`, `VL_Result_Date`, `Date_Result_Received`, `VL_Result`, `First_EAC`, `Second_EAC`, `Third_EAC`, `Extended_EAC`, `Barriers_to_Adherence`, `Subsequent_Retest_Date`, `subsequent_vl`, `subsequent_VL_Result_Date`, `subsequent_Date_Result_Received`, and `CurrentARTStatus`.",
            "**Import from NigeriaMRS (NMRS):** Configure MySQL settings. Import EAC-eligible clients based on a VL sample collection date range or for the current fiscal year (Oct 1 - Sep 30). A specific SQL script (downloadable/shareable) is used for this.",
            "**Import from Google Sheet:** Configure target facility settings (State, Facility, DATIM Code). Import the initial EAC eligible list from a shared Google Sheet, filtering by the configured DATIM code. This is typically a one-time import for the initial list.",
            "**Note:** Only one initial list (CSV, NMRS, or Google Sheet) can be imported. Subsequent imports might be for updates or different cohorts based on app logic.",
          ]),
          _buildImage(context, "assets/screens/eac_tracker_import_tab.png",
              "EAC Tracker - Import Tab. "),

          _buildSubHeader("EAC Session Tabs (1st, 2nd, 3rd, Extended)"),
          _buildParagraph(
              "These tabs list clients due for or undergoing specific EAC sessions:"),
          _buildBulletPoints([
            "**Client Lists:** Displays clients eligible for the respective EAC session (e.g., '1st EAC' tab shows clients due for their first session).",
            "**Search & Edit:** Search for clients. Edit contact details (phone, address) which can be synced to NMRS if DATIM codes match and the selected NMRS user is an active provider.",
            "**Call & Log:** Initiate calls to clients. Call outcomes (answered, not answered) and duration are logged.",
            "**EAC Form:** After an answered call (duration > 6 seconds), an EAC form appears. Capture details like missed pickups, adherence score, barriers, interventions, referrals, follow-up dates, and comments. For 3rd/Extended EAC, also log repeat VL results and care plans.",
            "**NMRS Sync:** Filled EAC forms can be synced to NMRS. This requires the selected NMRS user to be an active provider and DATIM codes to match. Previous EAC forms for the same session date are voided on NMRS upon new submission.",
            "**Data Masking & PIN:** Similar to Call Tracker, client names and IDs are masked by default. Use the global PIN to unmask.",
            "**Duplicate Records:** The app identifies clients with multiple EAC records for the same session and provides an option to view these.",
          ]),
          _buildImage(
              context,
              "assets/screens/eac_tracker_session_tab_example.png",
              "Example of an EAC Session Tab."),
          _buildImage(context, "assets/screens/eac_tracker_form_dialog.png",
              "EAC Form Dialog. "),

          _buildSubHeader("Repeat VL Sample Tab"),
          _buildBulletPoints([
            "**Pending Results:** Lists clients whose repeat viral load sample has been collected but the result is pending.",
            "**Results Returned:** Lists clients whose repeat viral load results are available.",
            "**Functionality:** Similar to session tabs, allowing searching, editing contact info, and calling clients.",
            "**Result Display:** For clients with results, it shows the VL value, result date, and date received. Suppressed results (<50 copies/ml) are typically highlighted.",
          ]),
          _buildImage(context, "assets/screens/eac_tracker_repeat_vl_tab.png",
              "EAC Tracker - Repeat VL Sample Tab. "),

          _buildSubHeader("Report Tab"),
          _buildBulletPoints([
            "**Filter by Date Range:** View tracked EAC events for a specific period.",
            "**Summary Metrics & Charts:**",
            "  •  **EAC Completion Rate:** Percentage of unique clients who completed all required EAC sessions.",
            "  •  **Repeat Sample Collection Rate:** Percentage of EAC completers who had a repeat VL sample collected.",
            "  •  **Repeat Result Returned Rate:** Percentage of collected repeat samples for which results were returned.",
            "  •  **Repeat VL Suppression Rate:** Percentage of returned repeat VL results that are suppressed (<50 copies/ml).",
            "  Doughnut charts visualize these rates.",
            "**Detailed Logs:** A table of all EAC tracking events within the selected period, grouped by date. Shows client details, session type, outcome, call details, VL info, and tracker details.",
            "**Export Data:** Export the report as CSV or PDF (data masked unless globally unmasked via PIN). Charts can be included in the PDF.",
            "**PIN Management:** Access PIN setup/change screen.",
          ]),
          _buildImage(context, "assets/screens/eac_tracker_report_tab.png",
              "EAC Tracker - Report Tab. "),

          _buildSection("🩸 Viral Load (VL) Tracker Module"),
          _buildParagraph(
              "The VL Tracker module helps manage clients eligible for Viral Load (VL) testing, track sample collection, results, and related call interactions. It is also PIN-protected for data security."),
          _buildImage(context, "assets/screens/vl_tracker_main_tabs.png",
              "VL Tracker Tabs Overview. "),

          _buildSubHeader("Import VL List Tab"),
          _buildBulletPoints([
            "**Initial List Import:** You can import an initial list of VL eligible clients via:",
            "  •  **CSV File:** Upload a CSV with columns like `FacilityName`, `PatientUniqueID`, `ClientName`, `Sex`, `Age`, `CurrentARTStatus`, `ART Start Date`, `CurrentViralLoad(c/ml)`, `Last VL Result Date`, `Phone Number`, `Address`, etc. Only one initial list can be active.",
            "  •  **Google Sheet:** Configure target facility settings (State, Facility, DATIM Code). Import the list from a shared Google Sheet, filtered by the facility's DATIM code.",
            "  •  **NigeriaMRS (NMRS):** Configure MySQL settings. Import clients eligible for VL based on a specific fiscal quarter (Q1-Q4) for the current fiscal year. The app determines the fiscal year (Oct 1 - Sep 30) automatically.",
            "**NMRS Settings:** Save or edit connection details (Host, Port, User, Password, Database, Timeout) for NMRS import.",
            "**SQL Script:** Download or share the SQL script used for NMRS data extraction.",
            "**Clear List:** An option to clear all locally stored VL eligible records.",
          ]),
          _buildImage(context, "assets/screens/vl_tracker_import_tab.png",
              "VL Tracker - Import Tab. "),

          _buildSubHeader("Eligible Viral Load List Tab"),
          _buildBulletPoints([
            "**View Eligible Clients:** Displays clients eligible for VL testing from the imported list.",
            "**Search & Filter:** Search clients by name, ART ID, phone, etc. Filter by List Type ('Initial', 'Initial with recent updates'), Age Category, Most Recent ART Status, Sample Collection Quarter, and Sample Status (All, Sampled with No Result, Sampled with Result).",
            "**NMRS User Selection:** Select the active NMRS user profile for attributing actions correctly in NMRS when syncing lab forms.",
            "**Call Clients:** Initiate calls and log outcomes (status, duration). Incoming calls are also monitored.",
            "**Edit Contact Info:** Update client phone numbers and addresses. These changes can be synced back to NMRS (requires DATIM code match and active provider status for the selected NMRS user).",
            "**Enter Lab Form (VL Form Dialog):** For each client, open a detailed lab form to record/update VL sample collection details, results, and other clinical information (e.g., Lab Reg No, Indication for AHD, CD4, WBC, HCV, Pregnancy, TB tests, VL specifics, HIVDR info).",
            "**NMRS Sync (Forms & Contacts):**",
            "  •  **Sync Lab Form to NMRS:** Individually sync completed lab forms to NMRS (requires provider status and DATIM match). Previous lab forms for the same encounter date are voided.",
            "  •  **Sync All Pending Forms to NMRS:** Batch sync all locally saved, unsynced lab forms.",
            "  •  **Sync Contact Updates (Phone/Address) to NMRS:** Buttons appear on client cards if their phone/address has been updated locally but not yet synced.",
            "**Data Masking & PIN:** Sensitive information is masked. Use the global PIN to unmask.",
            "**Refresh from NMRS:** Options to refresh client ART status and VL data from NMRS for the displayed list, or perform a full update which re-fetches and updates client person IDs, demographics, contact info, and initial VL data from NMRS based on their ART IDs.",
          ]),
          _buildImage(
              context,
              "assets/screens/vl_tracker_eligible_list_tab.png",
              "VL Tracker - Eligible List Tab. "),
          _buildImage(
              context,
              "assets/screens/vl_tracker_lab_form_dialog.png",
              "VL Tracker - Lab Form Dialog. "),

          _buildSubHeader("VL Reports Tab"),
          _buildBulletPoints([
            "**Filter by Date Range:** View VL tracking activities and outcomes for specific periods.",
            "**Summary Metrics & Charts:**",
            "  •  **Overall Performance:** Displays the percentage of samples collected and results received from the total eligible clients in the filtered view.",
            "  •  **Quarterly VL Status & TAT:** Doughnut charts for the Current Quarter, Previous Quarter, and Older Samples, showing breakdown of Samples Collected, Results Received, Suppressed VL (<1000 c/ml), Unsuppressed VL (>=1000 c/ml), and TAT metrics.",
            "  •  **ART Status by Quarter:** Breakdown of client ART statuses (Deaths, Transferred Out, Missed Appointments, IIT, Discontinued Care) for clients whose VL samples were collected in that quarter.",
            "  •  **Call Outcomes:** Doughnut chart summarizing call outcomes (e.g., Answered, Not Answered/Failed).",
            "**Detailed Call Logs:** Table view of all call logs, grouped by date.",
            "**Export Data:** Export report summaries and detailed call logs as CSV or PDF (data masked unless globally unmasked via PIN). Charts can be included in the PDF.",
            "**PIN Management:** Access PIN setup/change screen.",
          ]),
          _buildImage(context, "assets/screens/vl_tracker_reports_tab.png",
              "VL Tracker - Reports Tab. "),

          _buildSection("📋 Task Manager"),
          _buildParagraph(
              "The Task Manager helps you log and track your daily activities, whether routine or ad-hoc. For each task, you can add a title, a detailed description, and attach relevant files (images or documents). Each task is associated with a specific date."),
          _buildSubHeader("Navigating and Adding Tasks:"),
          _buildBulletPoints([
            "**Date Selection:** Use the interactive date timeline at the top or the calendar icon to select the reporting date.",
            "**Thematic Reports:** Based on your designation (e.g., 'Tracking Assistant', 'SI Assistant', 'Pharmacy Technician'), relevant daily report indicators are displayed in expandable sections. Enter the counts for each indicator.",
            "**Other Tasks:** A separate section allows you to log free-form tasks with a title and description.",
            "**Attachments:** For both thematic report entries and 'Other Tasks', you can attach multiple files (images, PDFs, documents). Choose from gallery, take a photo, or select a document from your device. Thumbnails are shown and attachments can be changed or deleted.",
            "**AI-Powered Analysis (for Image Attachments):** If image attachments are added to 'Other Tasks', an AI (Gemini) can analyze the image and provide a summary, which is then added to the task details.",
            "**Reviewer & Supervisor:** When adding tasks or report entries, select a Reviewer from a list of facility staff and a Supervisor for approval. Supervisor emails are auto-fetched.",
            "**Saving & Editing:** Save individual report sections or tasks. Previously saved entries can be edited (values, attachments, reviewer, supervisor). Editing is possible if the report/task status is 'Pending' or 'Returned'. Approved entries are read-only unless put back into edit mode by a reviewer action (not directly done by the data entry staff).",
          ]),
          _buildImage(
              context,
              "assets/screens/task_manager_daily_view.png",
              "Task Manager - Daily Activity Reporting. "),
          _buildSubHeader("Review and Approval Workflow:"),
          _buildBulletPoints([
            "**Review List Tab:** Supervisors and designated reviewers can see reports/tasks submitted for their review. They can approve or return entries with feedback.",
            "**Status Tracking:** The status of each report/task (Pending, Approved, Returned, Rejected by Supervisor) is displayed.",
            "**Notifications:** Email notifications are sent for submissions and review actions (though not explicitly shown in UI guide, this is a common backend feature).",
          ]),
          _buildImage(context, "assets/screens/task_manager_review_list.png",
              "Task Manager - Review List for Supervisors. "),
          _buildSubHeader("Task Summary & Validation:"),
          _buildBulletPoints([
            "**Task Summary Tab:** View a monthly summary of all reported indicators and 'Other Tasks'.",
            "**Data Validation:** A 'Task Validation' button cross-checks aggregated data across different indicators for the selected month (e.g., ensuring VL results handed over match VL results entered on NMRS). Discrepancies are flagged.",
            "**PDF Report:** Generate and share a PDF report summarizing all tasks and thematic report entries for the selected month. This report includes daily entries and monthly totals.",
          ]),
          _buildImage(context, "assets/screens/task_manager_summary_tab.png",
              "Task Manager - Task Summary & Validation. "),
          _buildParagraph(
              "**Data Sync:** All tasks, reports, and attachments are synced to Firebase for backup and accessibility."),

          _buildSection("📦 Inventory Management"),
          _buildParagraph(
              "This module helps you track stock levels for Pharmacy, Laboratory, and Strategic Information (SI) tools. You can manage items, record transactions, and view reports."),
          _buildImage(context, "assets/screens/inventory_dashboard_tabs.png",
              "Inventory Dashboard with Tabs. "),

          _buildSubHeader("Importing Inventory Items"),
          _buildBulletPoints([
            "**From NigeriaMRS (NMRS):** Configure MySQL connection settings (Host, Port, User, Password, Database, Timeout). This will import Pharmacy and Laboratory item definitions from the NMRS `inv_item` table, replacing existing local Pharmacy/Lab items. Specific items like 'Tenofovir/Lamivudine/Efavirenz(30)(300/300/600mg)' are excluded, and some names like 'Darunavir/Ritonavir(30)(800mg/100mg)' are modified to 'Darunavir/Ritonavir(30)(400mg/100mg)' during import.",
            "**Add Predefined SI Items:** Click a button to add a standard list of SI tools (e.g., 'Daily HIV Testing Worksheet', 'ART Register') to your inventory. These items start with a stock count of 0.",
          ]),
          _buildImage(context, "assets/screens/inventory_import_page.png",
              "Inventory Import Page. "),

          _buildSubHeader(
              "Managing Inventory Lists (Pharmacy, Lab, SI Tools Tabs)"),
          _buildBulletPoints([
            "**View Items:** Each tab (Pharmacy, Lab, SI Tools) lists items belonging to that category.",
            "**Search:** Find items quickly using the search bar.",
            "**Item Details:** Each item card displays its Name, Description (if any), Stock on Hand (highlighted if low), Pack Size, Strength, and Last Updated timestamp.",
            "**Record Transactions:** For each item, use the menu (⋮) to:",
            "  •  **Stock In:** Record incoming stock (e.g., new supplies). Enter quantity and optional notes/source.",
            "  •  **Stock Out:** Record outgoing stock (e.g., dispensing to another unit). Enter quantity and optional notes/destination.",
            "  •  **Record Consumption:** Log items consumed (e.g., test kits used). Enter quantity and optional patient ID/reason.",
            "  •  **Stock Adjustment:** Correct stock levels. Enter the change in quantity (positive or negative) and a mandatory reason.",
            "**View History:** Access the transaction history for a specific item.",
          ]),
          _buildImage(context, "assets/screens/inventory_list_page.png",
              "Inventory List with Item Details and Actions. "),
          _buildImage(
              context,
              "assets/screens/inventory_transaction_dialog.png",
              "Inventory Transaction Dialog. "),

          _buildSubHeader("Inventory Reports (Coming Soon/Separate Section)"),
          _buildParagraph(
              "A dedicated reports section (accessible via a separate navigation item or a button within the inventory module) provides insights into inventory data:"),
          _buildBulletPoints([
            "**Filter by Date Range:** View reports for specific periods.",
            "**Summary Charts:**",
            "  •  **Low Stock Items:** Bar chart highlighting items with stock levels at or below a defined threshold (e.g., <= 5).",
            "  •  **Daily Consumption Trend:** Line chart showing the total quantity of items consumed or stocked out per day.",
            "  •  **Inventory Item Types:** Pie chart showing the distribution of items by category (Pharmacy, Lab, SI Tools).",
            "**Export Data:** (Likely feature) Ability to export reports to CSV or PDF.",
          ]),
          _buildImage(context, "assets/screens/inventory_reports_page.png",
              "Inventory Reports Page with Charts. "),

          // Updated Timesheet Section
          _buildSection("🕓 Timesheet Module"),
          _buildParagraph(
              "The Timesheet module allows you to generate, review, and manage your monthly timesheets based on your attendance records and daily tasks. It also includes a signature workflow for approvals."),
          _buildSubHeader("Generating and Viewing Your Timesheet"),
          _buildBulletPoints([
            "**Select Month & Year:** Choose the specific month and year for which you want to generate or view the timesheet.",
            "**Project Selection:** Select the relevant project for the timesheet period from a dropdown list.",
            "**Supervisor Selection:** Choose your Facility Supervisor and Caritas Supervisor from dropdown lists. Their email addresses will be automatically fetched.",
            "**Timesheet Display:** The timesheet is presented in a table format, showing days of the month. For each day:",
            "  •  Hours worked on the selected project are displayed.",
            "  •  Hours for 'Out-of-office' categories (Annual Leave, Holiday, Paternity, Maternity) are also shown.",
            "  •  Weekend days are typically marked and show '0' hours.",
            "**Totals:** The table includes total hours worked on the project, total hours for each out-of-office category, and a grand total of hours for the month. Percentage of time worked against expected hours is also calculated.",
            "**Staff Information:** Your name, department, designation, location, and state are displayed at the top.",
          ]),
          _buildImage(
              context,
              "assets/screens/timesheet_generation_view.png",
              "Timesheet Generation/View. "),

          _buildSubHeader("Signature Workflow & Submission"),
          _buildBulletPoints([
            "**Staff Signature:**",
            "  •  If your signature is not yet on the timesheet and not uploaded in your profile, you can tap to upload it directly from your gallery.",
            "  •  Once uploaded (or if already available from your profile), your signature and the current date will appear.",
            "**Supervisor Signatures:**",
            "  •  The timesheet shows placeholders for Facility Supervisor and Caritas Supervisor signatures and dates.",
            "  •  Their approval status (Pending, Approved, Rejected) and any feedback comments will be displayed once they act on the timesheet.",
            "**Submission:** After signing, click 'Submit Timesheet'. This saves the timesheet data (including your signature and selected supervisors) to Firebase and likely notifies the supervisors.",
            "**Email to Self:** Once all signatures (Staff, Facility Supervisor, Caritas Supervisor) are present and approved, an option to 'Email Signed Timesheet to Self' appears.",
            "**Include Task Summary (Optional):** A checkbox allows you to include a summary of your tasks from the Task Manager module as an appendix to the timesheet PDF.",
          ]),
          _buildImage(
              context,
              "assets/screens/timesheet_signature_section.png",
              "Timesheet Signature Section. "),

          _buildSubHeader("Download & Share"),
          _buildBulletPoints([
            "**Download PDF (💾):** Generates a PDF of the current timesheet (and optionally the task summary). The file is saved locally, and you'll be prompted to open it.",
            "**Share PDF (📤):** Generates the PDF and allows you to share it via other apps (e.g., email, messaging).",
          ]),

          _buildSection("🏅 Team Player & Staff Feedback (Weekly Survey)"),
          _buildParagraph(
              "The app includes a feature to gather weekly feedback from staff, including a nomination for the 'Best Team Player' within your facility. This is typically done through a short survey, and the results contribute to recognizing outstanding team members and understanding overall team sentiment."),
          _buildImage(
              context,
              "assets/screens/staff_feedback_survey_overview.png",
              "Staff Feedback Survey Page. "),

          _buildSubHeader("Accessing and Completing the Feedback Survey:"),
          _buildBulletPoints([
            "**Survey Prompt:** You may be prompted to complete the feedback survey at certain times, for example, before you can clock-in on a specific day of the week (e.g., the last Thursday of the month between the 20th and 30th, as mentioned in the Attendance module, or on a weekly basis as implied by 'current week' in survey questions).",
            "**Survey Page:** The survey page is titled something like 'We love to hear from you!' and presents questions grouped into sections (e.g., 'Team Spirit', 'Attitude to Work', 'Team Player Nomination').",
            "**Question Types:** Questions are typically 'tick_box' (Yes/No radio buttons) or a special 'list' type for nominating the best team player.",
            "**Answering Questions:** For Yes/No questions, select the appropriate radio button. Ensure you answer all required questions in each section.",
            "**Best Team Player Nomination (Reorderable List):**",
            "  •  One question will ask: 'For the current week, who is the best team player in your facility'.",
            "  •  You'll see an expandable section with instructions: 'Click HERE to expand the list of all staff members in your facility (Excluding yourself)... Press and Hold and Drag the cards either Upward or Downward to re-arrange the Best team player from top to bottom.'",
            "  •  The list will display staff members from your facility (excluding yourself), initially in a shuffled order.",
            "  •  Tap, hold, and drag each staff member's card to rank them. The person you rank highest (at the top) is your primary nomination.",
            "  •  **Important:** You must reorder this list if it contains more than two staff members; otherwise, the system may prompt you to complete this question.",
            "**Validation Checks:** Before submission, the app performs some validation:",
            "  •  Ensures all non-optional questions are answered.",
            "  •  May check for logical consistency between related answers (e.g., if you say 'No' to team collaboration but 'Yes' to getting support, it might ask you to review).",
            "  •  Ensures the 'Best Team Player' list has been reordered if applicable.",
            "**Submitting Your Review:** Once all questions are answered and validated, tap the 'Submit Your Review' button at the bottom of the page.",
          ]),
          _buildImage(
              context,
              "assets/screens/team_player_nomination_reorder.png",
              "Nominating Team Player by reordering list. "),

          _buildSubHeader("Data Handling and Synchronization:"),
          _buildBulletPoints([
            "**Local Storage (Isar):** Your survey responses, including your team player ranking, are first saved locally on your device in the Isar database.",
            "**Online Sync (Firebase):** If you have an internet connection, the app will attempt to sync your survey responses to Firebase Firestore. This allows for aggregation of responses from all staff.",
            "**Offline Handling:** If you submit the survey while offline, it's saved locally. The app will sync it to Firebase later when a connection is available.",
            "**One Survey Per Day:** The system typically allows only one survey submission per user per day to avoid duplicate entries.",
          ]),

          _buildSubHeader("Viewing Team Player Results:"),
          _buildParagraph(
              "The aggregated results of the 'Best Team Player' nominations are then used to highlight recognized individuals."),
          _buildBulletPoints([
            "**On the Dashboard:** The 'Team Player of the Month' section on the Dashboard (as described earlier) will display the staff member who received the most votes for the selected period. This includes their name, vote count, and a bar chart showing vote distribution among other nominees.",
            "**Dedicated 'Best Player Charts' Page:** There's also a specific page (accessible, for example, after submitting your survey if offline, or potentially from a menu) titled 'Best Player Charts'. This page might show:",
            "  •  **Your Personal Nomination:** A section like 'What your view is' displaying who you nominated as the best team player for the current week.",
            "  •  **Aggregated Facility View:** A section like 'What the view of everyone is', showing a bar chart of all nominations received from staff in your facility for the current day/week. This chart displays names and their corresponding vote counts.",
            "  •  **Recognition Card:** A card highlighting the 'Best Team Player of the Week' based on your most recent survey submission or aggregated data.",
          ]),
          _buildImage(
              context,
              "assets/screens/best_player_charts_page.png",
              "Best Player Charts Page showing individual and aggregated views. "),
          _buildParagraph(
              "This feedback mechanism is crucial for fostering a positive team environment and recognizing individual contributions."),

          _buildSection("🔐 PIN Protection for Sensitive Modules"),
          _buildParagraph(
              "Certain modules within the CARITAS Nigeria Service Delivery WorkSpace App, such as the Call Tracker, EAC Tracker, and VL Tracker, contain sensitive information and are therefore protected by a 4-digit Personal Identification Number (PIN). This ensures an additional layer of security for confidential data."),
          _buildImage(context, "assets/screens/pin_input_page.png",
              "PIN Entry Screen."),

          _buildSubHeader("First-Time Access & PIN Creation:"),
          _buildBulletPoints([
            "**Initial Prompt:** When you attempt to access a PIN-protected module (e.g., Call Tracker, EAC Tracker, VL Tracker) for the first time after PIN setup is required or if no PIN is found, you will be directed to the 'Set Your PIN' page.",
            "**Password Verification (Security Check):** Before you can set a PIN, the app requires you to verify your main CARITAS Nigeria Service Delivery WorkSpace account password. A dialog will appear asking you to 'Verify Your Password' by entering your current Firebase/Work Manager login password.",
            "  •  This step ensures that only the legitimate account holder can set or change the PIN.",
            "  •  If password verification fails, you won't be able to proceed with PIN creation.",
            "**Creating Your 4-Digit PIN:** Once your password is verified:",
            "  •  You will be on the 'Set Your PIN' screen (often titled with 'WorkSpace Arena' and 'Set Your PIN').",
            "  •  Enter your desired 4-digit numeric PIN in the provided field.",
            "  •  You can tap the visibility icon (👁️) to show or hide the PIN as you type.",
            "  •  The app will validate that the PIN is exactly 4 digits and numeric. An error message like 'Please enter a 4-digit numeric PIN' will appear if it's invalid.",
            "**Saving the PIN:** Click the 'Save PIN' button. If the PIN is valid and your password was verified, your PIN will be securely stored on your device.",
            "**Automatic Navigation:** After successfully saving the PIN, you will be automatically redirected to the module you were initially trying to access (e.g., Call Tracker).",
          ]),
          _buildImage(context, "assets/screens/pin_creation_page.png",
              "PIN Creation Screen after password verification."),
          _buildImage(
              context,
              "assets/screens/pin_password_verification_dialog.png",
              "Password Verification Dialog before PIN creation/reset. "),

          _buildSubHeader("Subsequent Access to Protected Modules:"),
          _buildBulletPoints([
            "**PIN Entry:** Every time you try to open a PIN-protected module, you will be prompted to enter your 4-digit PIN on the 'Enter Your PIN' screen.",
            "**Verification:** Enter your PIN and tap 'Verify PIN'.",
            "  •  If the PIN is correct, you will gain access to the module.",
            "  •  If the PIN is incorrect, an error message like 'Incorrect PIN. Please try again.' will be displayed, and you'll need to re-enter it.",
            "**Secure Storage:** Your PIN is stored securely on your device using `flutter_secure_storage`, meaning it's encrypted and not easily accessible.",
          ]),

          _buildSubHeader("Forgot PIN / Resetting Your PIN:"),
          _buildBulletPoints([
            "**'Forgot PIN? Reset' Option:** On the 'Enter Your PIN' screen, you'll find a 'Forgot PIN? Reset' link or button.",
            "**Password Re-Verification:** Tapping this will again require you to verify your main CARITAS Nigeria Service Delivery WorkSpace account password for security reasons, similar to the initial PIN creation process.",
            "**PIN Deletion:** If your password is successfully verified, your old PIN will be securely deleted from your device.",
            "**Prompt to Create New PIN:** You will then be redirected to the 'Set Your PIN' page to create a new 4-digit PIN, following the same steps as the first-time setup.",
            "**Message:** You'll receive a confirmation like 'PIN reset. Please create a new PIN.'",
          ]),

          _buildSubHeader("Data Masking and PIN for Unmasking:"),
          _buildBulletPoints([
            "**Sensitive Data Masking:** Within PIN-protected modules like Call Tracker, EAC Tracker, and VL Tracker, sensitive client information (e.g., names, phone numbers, IDs) is often masked by default in lists and reports to protect privacy.",
            "**Unmasking with PIN:** To view the full, unmasked details, you will typically need to use your PIN. Look for an 'unmask' icon (e.g., an eye icon 👁️) in the app bar or near the sensitive data. Tapping this will likely prompt for your PIN again or use the session's PIN verification to reveal the information.",
          ]),
          _buildParagraph(
              "This PIN system adds a crucial security layer, ensuring that only authorized users can access and view sensitive operational and client data within the app. Remember to choose a PIN that is secure and not easily guessable."),

          _buildSection("📨 Forgot Password"),
          _buildParagraph(
              "If you've forgotten your app password, the 'Forgot Password' feature allows you to initiate a password reset process via email. You can typically access this feature from the app's main drawer menu or a link on the Login page."),
          _buildSubHeader("Steps to Reset Your Password:"),
          _buildBulletPoints([
            "**Access the Page:** Navigate to the 'Forgot Password' page. You'll recognize it by its header (often with a password-related icon) and the title 'Forgot Password?'. The app bar will also display 'Forgot Password' and may include a logo (e.g., CCFN logo).",
            "**Enter Your Email:** You will see a field specifically for your email address. The page will instruct you to 'Enter the email address associated with the account for password reset.' Type your registered email address into this field.",
            "**Email Validation:** As you type, or when you attempt to submit, the app will validate that the email address is in a correct format (e.g., `user@example.com`). If it's not valid, an error message like 'Enter a valid email address' will appear.",
            "**Request Reset:** Once you've entered a valid email, tap the 'Send' button. The system uses Firebase Authentication to dispatch a password reset email to the address you provided.",
            "**Check Your Email:** After successfully submitting your email, the page will inform you, 'We will email you a verification code [or link] to reset the password.' You should then check your email inbox (and also your spam/junk folder, just in case) for an email from the CARITAS Nigeria Service Delivery WorkSpace system (or Firebase).",
            "**Follow Email Instructions:** The email you receive will contain a unique link or instructions. Clicking this link will usually take you to a secure web page where you can enter and confirm your new password. This part of the process typically happens outside the CARITAS Nigeria Service Delivery WorkSpace app, in your device's web browser.",
            "**Return to Login:** After you tap the 'Send' button in the app (and the request is processed), the app will automatically navigate you back to the Login page. Once you have successfully reset your password using the link in the email, you can return to the app and log in with your new credentials.",
            "**Remembered Password?:** If, while on the 'Forgot Password' page, you suddenly remember your password, there's a 'Login' link (often styled prominently, e.g., in red and bold). Tapping this link will take you directly back to the Login page, bypassing the password reset process.",
          ]),
          _buildImage(context, "assets/screens/forgot_password.png",
              "Forgot Password Page - Email Entry and Send Button. "),

          _buildSection("🖋️ Upload Signature (Digital Signature Management)"),
          _buildParagraph(
              "Your digital signature is used on important documents like Timesheets and other reports generated by the app. You can manage your signature from the 'Upload Signature' page, typically accessible from the app's main drawer menu or potentially linked as an action from your Profile settings."),
          _buildImage(
              context,
              "assets/screens/upload_signature_page_overview.png",
              "Upload Signature Page Overview."),

          _buildSubHeader("Key Features on the Upload Signature Page:"),
          _buildBulletPoints([
            "**Signature Preview:** A central area displays your currently saved signature. If no signature is set, it shows a placeholder prompting you to 'Tap to Upload or Draw Signature' along with an icon.",
            "**Loading Existing Signature:** When you open the page, it automatically loads and displays your previously saved signature, if any.",
            "**Single Signature Storage:** The app stores only one active signature. Adding a new signature (either by drawing or uploading) will replace the previous one.",
          ]),

          _buildSubHeader("Drawing Your Signature:"),
          _buildBulletPoints([
            "**Initiate Drawing:** Tap the 'Draw Signature' button (often styled with an icon like a pen/create) or tap directly on the signature preview area.",
            "**Signature Pad:** A dialog box will appear, presenting a dedicated signature pad (a canvas area).",
            "**Draw:** Use your finger or a stylus to draw your signature directly on the pad.",
            "**Clear:** If you make a mistake or want to start over, tap the 'Clear' button within the signature pad dialog to erase the current drawing.",
            "**Save Drawing:** Once satisfied with your drawn signature, tap the 'Save' button within the signature pad dialog. This captures the drawing as an image and updates the preview on the main Upload Signature page.",
          ]),
          _buildImage(context, "assets/screens/signature_pad_dialog.png",
              "Signature Pad for drawing. "),

          _buildSubHeader("Uploading a Signature Image:"),
          _buildBulletPoints([
            "**Initiate Upload:** Tap the 'Upload Signature' button (often styled with an icon like a file upload).",
            "**Select Image:** Your device's image gallery will open, allowing you to browse and select an image file (e.g., a scanned image of your signature).",
            "**Confirmation:** Once an image is selected, it will be processed and displayed in the signature preview area on the main Upload Signature page.",
          ]),

          _buildSubHeader("Saving and Storing Your Signature:"),
          _buildBulletPoints([
            "**Automatic Local Save (on Draw/Upload):** When you save a drawn signature from the pad or upload an image, it is typically saved locally on your device immediately, and the preview updates.",
            "**Explicit Save Button:** There is also a main 'Save Signature' button on the page. Clicking this ensures the currently displayed signature is formally saved to the local database. A confirmation message like 'Signature saved successfully!' will usually appear.",
            "**Local Storage First:** The signature image is stored locally on your device. The system might also update a reference or flag in your main profile data (e.g., in Isar database) to indicate that a new local signature is available.",
            "**Syncing to Server:** For the signature to be used in shared reports or accessible across devices (if applicable), you will likely still need to sync your overall profile data. The 'Upload Signature' page primarily handles getting the signature onto your device and preparing it. The actual upload to Firebase often happens during a general profile sync or timesheet submission process.",
          ]),
          _buildParagraph(
              "Remember, having an up-to-date signature is important for the proper generation and approval of your timesheets and other official documents within the CARITAS Nigeria Service Delivery WorkSpace app."),
          const SizedBox(height: 32),
          Center(
            child: Text(
              "Need help? Reach out to your admin or support team.",
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildHeader(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 26,
      fontWeight: FontWeight.bold,
      color: Colors.teal,
    ),
  );

  Widget _buildSubHeader(String text) => Padding(
    padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Colors.blueGrey,
      ),
    ),
  );

  Widget _buildParagraph(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12.0),
    child: Text(
      text,
      style: const TextStyle(fontSize: 16, height: 1.5),
      textAlign: TextAlign.justify,
    ),
  );

  Widget _buildSection(String title) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 8),
    child: Text(
      title,
      style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.deepPurple),
    ),
  );

  Widget _buildBulletPoints(List<String> points) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: points
            .map((point) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("  •  ",
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal)),
              Expanded(
                child: Text(
                  point,
                  style: const TextStyle(fontSize: 16, height: 1.4),
                  textAlign: TextAlign.justify,
                ),
              )
            ],
          ),
        ))
            .toList(),
      ),
    );
  }

  // MODIFIED: The _buildImage method now accepts BuildContext to handle navigation.
  // It is wrapped with a GestureDetector for tapping and a Hero for the animation.
  Widget _buildImage(BuildContext context, String assetPath, String caption) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () {
            // Navigate to the full-screen viewer page on tap
            Navigator.push(
              context,
              // Using PageRouteBuilder for a fade transition, which complements the Hero animation.
              PageRouteBuilder(
                opaque: false, // Make the route transparent
                pageBuilder: (context, animation, secondaryAnimation) =>
                    FullScreenImageViewer(
                      assetPath: assetPath,
                      // Use the asset path as a unique Hero tag
                      heroTag: assetPath,
                    ),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
              ),
            );
          },
          child: Hero(
            // The tag must be unique for each Hero widget and match the one in the destination page.
            tag: assetPath,
            child: Container(
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    )
                  ]),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Image.asset(
                  assetPath,
                  height: 220,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 220,
                      color: Colors.grey.shade200,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image,
                                color: Colors.grey.shade500, size: 40),
                            const SizedBox(height: 8),
                            Padding(
                              padding:
                              const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Text(
                                "Missing: ${assetPath.split('/').last}\n",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: Colors.grey.shade600, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            caption,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 14, color: Colors.grey, fontStyle: FontStyle.italic),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}