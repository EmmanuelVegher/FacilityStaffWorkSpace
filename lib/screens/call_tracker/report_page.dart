import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Use Firestore
import 'package:firebase_auth/firebase_auth.dart'; // Use Firebase Auth
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../models/contact_tracked.dart';


class ReportsPageWeb extends StatefulWidget {
  @override
  _ReportsPageWebState createState() => _ReportsPageWebState();
}

class _ReportsPageWebState extends State<ReportsPageWeb> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<ContactTracked> trackedContacts = [];
  DateTime? startDate;
  DateTime? endDate;
  bool isLoading = true; // Start loading initially
  bool _isUserBioLoading = true;
  String? _errorMessage;

  // User Bio Details (fetched from Firestore)
  String? currentUserAuthId;
  String? userFirstName;
  String? userLastName;
  String? userDesignation;
  String? userLocation; // Tracker's Facility Location
  String? userState; // Tracker's State
  String? userSupervisor;
  String? userSupervisorEmail;


  // Chart Data Holders (same as mobile)
  List<MapEntry<String, int>> callStatusChartData = [];
  List<_ChartDataPoint> callDurationTrendData = [];
  List<_UpdateChartData> updateMetricsData = [];
  List<MapEntry<String, int>> artStatusChartData = [];

  @override
  void initState() {
    super.initState();
    _initializePage();
  }

  Future<void> _initializePage() async {
    await _loadCurrentUserBio();
    // Load initial data for a default range (e.g., last 7 days) or require selection
    // Setting a default range:
    final now = DateTime.now();
    startDate = DateTime(now.year, now.month, now.day - 6); // Last 7 days start
    endDate = DateTime(now.year, now.month, now.day);     // Today end
    _loadContacts(start: startDate, end: endDate);
  }

  Future<void> _loadCurrentUserBio() async {
    setState(() {
      _isUserBioLoading = true;
      _errorMessage = null;
    });
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception("User not logged in.");
      }
      currentUserAuthId = user.uid;

      final docSnapshot = await _firestore.collection('Staff').doc(currentUserAuthId).get();

      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data()!;
        setState(() {
          userFirstName = data['firstName'] as String?;
          userLastName = data['lastName'] as String?;
          userDesignation = data['designation'] as String?;
          userLocation = data['location'] as String?; // Facility name
          userState = data['state'] as String?;
          userSupervisor = data['supervisor'] as String?;
          userSupervisorEmail = data['supervisorEmail'] as String?;
          _isUserBioLoading = false;
        });
        print("User Bio Loaded: State=$userState, Location=$userLocation, AuthId=$currentUserAuthId");
      } else {
        throw Exception("User bio data not found in Firestore 'Staff' collection.");
      }
    } catch (e) {
      print("Error loading user bio: $e");
      if (mounted) {
        setState(() {
          _errorMessage = "Error loading user details: $e";
          _isUserBioLoading = false;
          isLoading = false; // Stop main loading if user bio fails
        });
      }
    }
  }


  // Fetch contacts from Firestore based on the complex path structure
  Future<void> _loadContacts({DateTime? start, DateTime? end}) async {
    // Ensure user bio (needed for path) is loaded and available
    if (_isUserBioLoading || currentUserAuthId == null || userState == null || userLocation == null) {
      print("User bio not ready, delaying contact load.");
      // Optionally set isLoading = false and show a message asking to wait/retry
      if (!_isUserBioLoading && mounted) { // If bio loading finished but failed
        setState(() {
          isLoading = false;
          _errorMessage = _errorMessage ?? "Cannot load reports: User details (State/Facility) missing.";
          trackedContacts = []; // Clear previous results
          _prepareChartData(); // Clear charts
        });
      } else if (mounted) {
        setState(() { isLoading = true; }); // Keep loading if bio is still loading
      }
      return;
    }
    // Require a date range for Web fetching due to path complexity
    if (start == null || end == null) {
      if (mounted) {
        setState(() {
          isLoading = false;
          trackedContacts = [];
          _prepareChartData();
          _errorMessage = "Please select a date range to load reports.";
        });
      }
      return;
    }

    setState(() {
      isLoading = true;
      _errorMessage = null; // Clear previous errors
      trackedContacts = []; // Clear previous results before loading
    });

    print("Loading contacts for State: $userState, Facility: $userLocation, User: $currentUserAuthId");
    print("Date Range: ${DateFormat('yyyy-MM-dd').format(start)} to ${DateFormat('yyyy-MM-dd').format(end)}");

    List<ContactTracked> fetchedContacts = [];
    DateTime currentDate = start;
    final DateFormat pathDateFormat = DateFormat('dd-MMM-yyyy'); // Format used in the path

    try {
      while (currentDate.isBefore(end.add(Duration(days: 1)))) { // Loop through each day in the range
        String formattedDate = pathDateFormat.format(currentDate);
        // Construct the path to the *collection* containing the UUID documents for that day/user
        String dailyUserCollectionPath = '/Reports/$userState/CallTracker/$userLocation/$formattedDate/$currentUserAuthId/$currentUserAuthId';

        print("Querying path: $dailyUserCollectionPath");

        try {
          QuerySnapshot dailySnapshot = await _firestore.collection(dailyUserCollectionPath).get();
          print("Found ${dailySnapshot.docs.length} records for $formattedDate");

          for (var doc in dailySnapshot.docs) {
            if (doc.exists && doc.data() != null) {
              try {
                // Use the document ID (which should be the UUID) when parsing
                fetchedContacts.add(ContactTracked.fromFirestore(doc.data() as Map<String, dynamic>, doc.id));
              } catch (parseError) {
                print("Error parsing document ${doc.id} from $formattedDate: $parseError");
                // Optionally skip this doc or handle error
              }
            }
          }
        } catch (dailyError) {
          // Log error for specific day, but continue trying other days
          print("Error fetching data for path $dailyUserCollectionPath: $dailyError");
          // If the path doesn't exist, Firestore throws an error, which is expected if no calls were made that day.
          // We can ignore specific types of errors if needed (e.g., permission denied vs. not found)
          // For simplicity here, we just print and continue.
        }

        currentDate = currentDate.add(Duration(days: 1)); // Move to the next day
      } // End of date loop

      if (mounted) {
        setState(() {
          trackedContacts = fetchedContacts;
          _prepareChartData(); // Prepare chart data after loading/filtering
          isLoading = false;
        });
        print("Finished loading ${trackedContacts.length} contacts.");
      }

    } catch (e) {
      print('Error loading contacts from Firestore: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          _errorMessage = "Error loading reports: $e";
          trackedContacts = [];
          _prepareChartData();
        });
      }
    }
  }


  // --- Chart Data Preparation Functions ---
  // (These functions remain IDENTICAL to the mobile version as they operate on the List<ContactTracked>)
  void _prepareChartData() {
    callStatusChartData = _getCallStatusData();
    callDurationTrendData = _getCallDurationTrendData();
    updateMetricsData = _getUpdateMetricsData();
    artStatusChartData = _getArtStatusData();
  }

  List<MapEntry<String, int>> _getCallStatusData() {
    Map<String, int> statusCounts = {};
    for (var contact in trackedContacts) {
      String status = contact.callStatus?.trim() ?? 'N/A';
      if (status.isEmpty) status = 'N/A';
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;
    }
    return statusCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }

  List<_ChartDataPoint> _getCallDurationTrendData() {
    Map<String, List<int>> dailyDurations = {};
    final DateFormat dateKeyFormat = DateFormat('yyyy-MM-dd');
    for (var contact in trackedContacts) {
      if (contact.dateTracked != null && contact.callDuration != null && contact.callDuration! > 0) {
        String dateKey = dateKeyFormat.format(contact.dateTracked!);
        dailyDurations.putIfAbsent(dateKey, () => []).add(contact.callDuration!);
      }
    }
    List<_ChartDataPoint> chartData = [];
    dailyDurations.forEach((date, durations) {
      double averageDuration = durations.reduce((a, b) => a + b) / durations.length;
      chartData.add(_ChartDataPoint(date, averageDuration));
    });
    chartData.sort((a, b) => a.x.compareTo(b.x));
    return chartData;
  }

  List<_UpdateChartData> _getUpdateMetricsData() {
    Map<String, int> phoneUpdates = {};
    Map<String, int> addressUpdates = {};
    Map<String, int> nextVisitUpdates = {};
    final DateFormat monthKeyFormat = DateFormat('yyyy-MM');
    for (var contact in trackedContacts) {
      // Ensure these fields exist in the Firestore data or handle nulls
      if (contact.datePhoneNumberUpdated != null) {
        String monthKey = monthKeyFormat.format(contact.datePhoneNumberUpdated!);
        phoneUpdates[monthKey] = (phoneUpdates[monthKey] ?? 0) + 1;
      }
      if (contact.dateAddressChanged != null) {
        String monthKey = monthKeyFormat.format(contact.dateAddressChanged!);
        addressUpdates[monthKey] = (addressUpdates[monthKey] ?? 0) + 1;
      }
      if (contact.dateNextVisitChanged != null) {
        String monthKey = monthKeyFormat.format(contact.dateNextVisitChanged!);
        nextVisitUpdates[monthKey] = (nextVisitUpdates[monthKey] ?? 0) + 1;
      }
    }
    Set<String> allMonths = {...phoneUpdates.keys, ...addressUpdates.keys, ...nextVisitUpdates.keys};
    List<String> sortedMonths = allMonths.toList()..sort();
    List<_UpdateChartData> chartData = [];
    for (String month in sortedMonths) {
      chartData.add(_UpdateChartData(month, phoneUpdates[month] ?? 0, addressUpdates[month] ?? 0, nextVisitUpdates[month] ?? 0));
    }
    return chartData;
  }

  List<MapEntry<String, int>> _getArtStatusData() {
    Map<String, int> statusCounts = {};
    for (var contact in trackedContacts) {
      String status = contact.artStatus?.trim() ?? 'Unknown';
      if (status.isEmpty) status = 'Unknown';
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;
    }
    return statusCounts.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
  }

  // --- Helper Functions ---
  // (These functions remain IDENTICAL to the mobile version)
  String formatDuration(int totalSeconds) {
    if (totalSeconds < 0) return 'N/A';
    if (totalSeconds == 0) return '0 Seconds';
    final int minutes = totalSeconds ~/ 60;
    final int remainingSeconds = totalSeconds % 60;
    String minuteString = minutes > 0 ? '$minutes minute${minutes > 1 ? 's' : ''}' : '';
    String secondString = remainingSeconds > 0 ? '$remainingSeconds second${remainingSeconds > 1 ? 's' : ''}' : '';
    if (minuteString.isNotEmpty && secondString.isNotEmpty) return '$minuteString $secondString';
    return minuteString.isNotEmpty ? minuteString : secondString;
  }

  Color _getStatusColor(String status) {
    String lowerStatus = status.toLowerCase();
    switch (lowerStatus) {
      case 'answered': // Map common statuses
      case 'completed': return Colors.green.shade700;
      case 'missed': // Map common statuses
      case 'missed call': case 'not answered': case 'call failed': case 'call dropped': return Colors.red.shade700;
      case 'call busy': return Colors.orange.shade700;
      case 'unknown (no log detail)': // Specific status from mobile code
      case 'n/a': case 'unknown': return Colors.grey.shade600;
      default: return Colors.blue.shade700;
    }
  }

  Map<String, List<ContactTracked>> _groupContactsByDate() {
    final Map<String, List<ContactTracked>> dailyReports = {};
    final DateFormat dateKeyFormat = DateFormat('yyyy-MM-dd');
    final DateFormat displayFormat = DateFormat('EEEE, MMMM d, yyyy');
    for (var contact in trackedContacts) {
      final dateKey = contact.dateTracked != null ? dateKeyFormat.format(contact.dateTracked!) : 'Unknown Date';
      dailyReports.putIfAbsent(dateKey, () => []).add(contact);
    }
    final sortedKeys = dailyReports.keys.toList()
      ..sort((a, b) {
        if (a == 'Unknown Date') return 1;
        if (b == 'Unknown Date') return -1;
        return b.compareTo(a);
      });
    final sortedMap = { for (var k in sortedKeys) k : dailyReports[k]! };
    final displayMap = <String, List<ContactTracked>>{};
    sortedMap.forEach((key, value) {
      final displayKey = key == 'Unknown Date' ? 'Unknown Tracking Date' : displayFormat.format(dateKeyFormat.parse(key));
      value.sort((c1, c2) => (c1.name ?? '').toLowerCase().compareTo((c2.name ?? '').toLowerCase()));
      displayMap[displayKey] = value;
    });
    return displayMap;
  }


  // --- Date Range Picker ---
  // (This function remains IDENTICAL to the mobile version)
  void _showDateRangePicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select Date Range'),
        content: SizedBox(
          width: 400, // Constrain width for web dialog
          height: 450,
          child: SfDateRangePicker(
            selectionMode: DateRangePickerSelectionMode.range,
            initialSelectedRange: (startDate != null && endDate != null)
                ? PickerDateRange(startDate!, endDate!)
                : null,
            showActionButtons: true,
            cancelText: 'Cancel',
            confirmText: 'Apply',
            onSubmit: (Object? value) {
              if (value is PickerDateRange && value.startDate != null && value.endDate != null) {
                setState(() {
                  startDate = value.startDate;
                  endDate = value.endDate;
                });
                Navigator.pop(context);
                _loadContacts(start: startDate, end: endDate); // Reload with filter
              } else {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please select both a start and end date.')),
                );
              }
            },
            onCancel: () {
              Navigator.pop(context);
            },
          ),
        ),
      ),
    );
  }


  // --- Build Method ---
  @override
  Widget build(BuildContext context) {
    final Map<String, List<ContactTracked>> dailyGroupedReports = (isLoading || _isUserBioLoading) ? {} : _groupContactsByDate();

    // Determine overall state
    Widget bodyContent;
    if (_isUserBioLoading) {
      bodyContent = Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [CircularProgressIndicator(), SizedBox(height: 10), Text("Loading user details...")],
      ));
    } else if (isLoading) {
      bodyContent = Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [CircularProgressIndicator(), SizedBox(height: 10), Text("Loading reports...")],
      ));
    } else if (_errorMessage != null) {
      bodyContent = Center(child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text('Error: $_errorMessage', style: TextStyle(color: Colors.red), textAlign: TextAlign.center,),
      ));
    } else if (trackedContacts.isEmpty) {
      bodyContent = Center(
          child: Text(
            startDate == null
                ? 'Please select a date range to view reports.' // Prompt if no range selected
                : 'No tracked contacts found for the selected period.',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          )
      );
    } else {
      // Main content (charts and table) - Same structure as mobile
      bodyContent = SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Date Range Display ---
              if (startDate != null && endDate != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    'Displaying data for ${userFirstName ?? ''} ${userLastName ?? ''} (${userLocation ?? 'N/A Facility'}) from ${DateFormat.yMd().format(startDate!)} to ${DateFormat.yMd().format(endDate!)}',
                    style: Theme.of(context).textTheme.titleSmall,
                    textAlign: TextAlign.center,
                  ),
                ),

              // --- Performance Warning (Optional but recommended) ---
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Card(
                  color: Colors.orange.shade100,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      "Note: Loading reports may be slow due to the current data structure in Firestore. Consider optimizing the data structure for better performance.",
                      style: TextStyle(color: Colors.orange.shade900),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),


              // --- Charts Section ---
              Text('Summary Charts', style: Theme.of(context).textTheme.headlineSmall),
              SizedBox(height: 16),

              // Wrap charts for responsiveness on web if needed
              Wrap(
                spacing: 20.0, // Horizontal space between charts
                runSpacing: 20.0, // Vertical space between rows of charts
                alignment: WrapAlignment.start,
                children: [
                  if (callStatusChartData.isNotEmpty)
                    ConstrainedBox( // Give charts a max width on web
                      constraints: BoxConstraints(maxWidth: 400),
                      child: _buildChartCard(
                        title: 'Call Status Distribution',
                        chart: SfCircularChart( /* ... same as mobile ... */
                            legend: Legend(isVisible: true, position: LegendPosition.bottom, overflowMode: LegendItemOverflowMode.wrap),
                            series: <CircularSeries>[ PieSeries<MapEntry<String, int>, String>( /* ... */
                              dataSource: callStatusChartData, xValueMapper: (d,_) => d.key, yValueMapper: (d,_) => d.value,
                              dataLabelSettings: DataLabelSettings(isVisible: true, labelPosition: ChartDataLabelPosition.outside, connectorLineSettings: ConnectorLineSettings(type: ConnectorType.curve, length: '10%')),
                              radius: '80%',
                            )]
                        ),
                      ),
                    ),

                  if (artStatusChartData.isNotEmpty)
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 400),
                      child: _buildChartCard(
                        title: 'ART Status Distribution',
                        chart: SfCircularChart( /* ... same as mobile ... */
                            legend: Legend(isVisible: true, position: LegendPosition.bottom, overflowMode: LegendItemOverflowMode.wrap),
                            series: <CircularSeries>[ PieSeries<MapEntry<String, int>, String>( /* ... */
                              dataSource: artStatusChartData, xValueMapper: (d,_) => d.key, yValueMapper: (d,_) => d.value,
                              dataLabelSettings: DataLabelSettings(isVisible: true, labelPosition: ChartDataLabelPosition.outside, connectorLineSettings: ConnectorLineSettings(type: ConnectorType.curve, length: '10%')),
                              radius: '80%',
                            )]
                        ),
                      ),
                    ),

                  if (callDurationTrendData.isNotEmpty)
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 600), // Line charts can be wider
                      child: _buildChartCard(
                        title: 'Average Call Duration Trend (Daily)',
                        chart: SfCartesianChart( /* ... same as mobile ... */
                            primaryXAxis: CategoryAxis(labelRotation: -45, title: AxisTitle(text: 'Date Tracked'), majorGridLines: MajorGridLines(width: 0)),
                            primaryYAxis: NumericAxis(title: AxisTitle(text: 'Avg. Duration (Seconds)'), numberFormat: NumberFormat.compact()),
                            tooltipBehavior: TooltipBehavior(enable: true),
                            series: <CartesianSeries<dynamic, dynamic>>[ LineSeries<_ChartDataPoint, String>( /* ... */
                              dataSource: callDurationTrendData,
                              xValueMapper: (data, _) => DateFormat('MMM d').format(DateFormat('yyyy-MM-dd').parse(data.x)),
                              yValueMapper: (data, _) => data.y,
                              name: 'Avg Duration', markerSettings: MarkerSettings(isVisible: true),
                            )]
                        ),
                      ),
                    ),

                  if (updateMetricsData.isNotEmpty)
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 600),
                      child: _buildChartCard(
                        title: 'Monthly Update Trends',
                        chart: SfCartesianChart( /* ... same as mobile ... */
                            primaryXAxis: CategoryAxis(labelRotation: -45, title: AxisTitle(text: 'Month'), majorGridLines: MajorGridLines(width: 0)),
                            primaryYAxis: NumericAxis(title: AxisTitle(text: 'Number of Updates'), majorTickLines: MajorTickLines(size: 0)),
                            legend: Legend(isVisible: true, position: LegendPosition.top, overflowMode: LegendItemOverflowMode.wrap),
                            tooltipBehavior: TooltipBehavior(enable: true, shared: true),
                            series: <CartesianSeries<dynamic, dynamic>>[
                              LineSeries<_UpdateChartData, String>(dataSource: updateMetricsData, xValueMapper: (d,_) => DateFormat('MMM yyyy').format(DateFormat('yyyy-MM').parse(d.month)), yValueMapper: (d,_) => d.phoneUpdates, name: 'Phone Updates', markerSettings: MarkerSettings(isVisible: true)),
                              LineSeries<_UpdateChartData, String>(dataSource: updateMetricsData, xValueMapper: (d,_) => DateFormat('MMM yyyy').format(DateFormat('yyyy-MM').parse(d.month)), yValueMapper: (d,_) => d.addressUpdates, name: 'Address Updates', markerSettings: MarkerSettings(isVisible: true)),
                              LineSeries<_UpdateChartData, String>(dataSource: updateMetricsData, xValueMapper: (d,_) => DateFormat('MMM yyyy').format(DateFormat('yyyy-MM').parse(d.month)), yValueMapper: (d,_) => d.nextVisitUpdates, name: 'Next Visit Updates', markerSettings: MarkerSettings(isVisible: true)),
                            ]
                        ),
                      ),
                    ),
                ],
              ),


              SizedBox(height: 30),

              // --- Data Table Section ---
              Text('Detailed Logs', style: Theme.of(context).textTheme.headlineSmall),
              SizedBox(height: 10),
              if (dailyGroupedReports.isEmpty && !(isLoading || _isUserBioLoading))
                Center(child: Text('No detailed logs found for the selected period.'))
              else if (!isLoading && !_isUserBioLoading) // Only build list if not loading
                ListView.builder(
                  shrinkWrap: true, // Important inside SingleChildScrollView
                  physics: NeverScrollableScrollPhysics(), // Disable listview scrolling
                  itemCount: dailyGroupedReports.keys.length,
                  itemBuilder: (context, index) {
                    final displayDateKey = dailyGroupedReports.keys.elementAt(index);
                    final dailyContactList = dailyGroupedReports[displayDateKey]!;

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      clipBehavior: Clip.antiAlias,
                      child: ExpansionTile(
                        title: Text(displayDateKey, style: TextStyle(fontWeight: FontWeight.bold)),
                        initiallyExpanded: index == 0,
                        children: <Widget>[
                          SingleChildScrollView( // Make table horizontally scrollable
                            scrollDirection: Axis.horizontal,
                            child: Padding( // Add padding around the DataTable
                              padding: const EdgeInsets.all(8.0),
                              child: DataTable(
                                // DataTable properties remain the same
                                columnSpacing: 15.0,
                                headingRowColor: MaterialStateProperty.all(Colors.grey.shade200),
                                columns: const [
                                  // Keep the same columns as the mobile version
                                  DataColumn(label: Text('Client Name')),
                                  DataColumn(label: Text('Client PhoneNo')),
                                  DataColumn(label: Text('Client ART Status')),
                                  DataColumn(label: Text("Client's Facility")),
                                  DataColumn(label: Text('Client State')),
                                  DataColumn(label: Text('Client ART ID')),
                                  DataColumn(label: Text('DatimCode')),
                                  DataColumn(label: Text('Time Tracking Done')),
                                  DataColumn(label: Text('Call Status')),
                                  DataColumn(label: Text('Duration of Call')),
                                  DataColumn(label: Text('Tracked By')),
                                  DataColumn(label: Text("Tracker's Designation")),
                                  DataColumn(label: Text("Tracker's Facility")),
                                  DataColumn(label: Text("Tracker's Supervisor")),
                                  DataColumn(label: Text("Tracker's Supervisor Email")),
                                ],
                                // Rows generation remains the same, using the loaded Firestore data
                                rows: dailyContactList.map((contact) {
                                  return DataRow(cells: [
                                    DataCell(Text(contact.name ?? 'N/A')),
                                    DataCell(Text(contact.phoneNumber?? 'N/A')),
                                    DataCell(Text(contact.artStatus ?? 'N/A')),
                                    DataCell(Text(contact.facilityName ?? 'N/A')),
                                    DataCell(Text(contact.state ?? 'N/A')),
                                    DataCell(Text(contact.uniqueID ?? 'N/A')),
                                    DataCell(Text(contact.datimCode ?? 'N/A')),
                                    DataCell(Text(contact.dateTracked != null ? DateFormat('HH:mm').format(contact.dateTracked!) : 'N/A')),
                                    DataCell(Container(
                                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                          color: contact.callStatus != null ? _getStatusColor(contact.callStatus!).withOpacity(0.2) : Colors.transparent,
                                          borderRadius: BorderRadius.circular(4)
                                      ),
                                      child: Text(contact.callStatus ?? 'N/A', style: TextStyle(
                                          color: contact.callStatus != null ? _getStatusColor(contact.callStatus!) : Colors.black87,
                                          fontWeight: FontWeight.w500
                                      )),
                                    )),
                                    DataCell(Text(contact.callDuration != null ? formatDuration(contact.callDuration!) : 'N/A')),
                                    DataCell(Text(contact.trackedBy ?? 'N/A')),
                                    DataCell(Text(contact.designation ?? 'N/A')),
                                    DataCell(Text(contact.trackerFacilityLocation ?? 'N/A')),
                                    DataCell(Text(contact.supervisorName ?? 'N/A')),
                                    DataCell(Text(contact.supervisorEmail ?? 'N/A')),
                                  ]);
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      );
    }

    // --- Scaffold ---
    return Scaffold(
      appBar: AppBar(
        title: Text('Tracking Reports'),
        actions: [
          IconButton(
            tooltip: 'Filter by Date Range',
            icon: Icon(Icons.filter_list),
            // Disable filter button while loading
            onPressed: (isLoading || _isUserBioLoading) ? null : () => _showDateRangePicker(context),
          ),
          IconButton(
            tooltip: 'Refresh Data',
            icon: Icon(Icons.refresh),
            // Disable refresh button while loading
            onPressed: (isLoading || _isUserBioLoading) ? null : () => _loadContacts(start: startDate, end: endDate),
          ),
        ],
      ),
      body: bodyContent, // Use the determined body content
    );
  }

  // Helper widget to build chart cards consistently (IDENTICAL to mobile)
  Widget _buildChartCard({required String title, required Widget chart}) {
    return Card(
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            SizedBox(height: 10),
            // Adjust height based on chart type or make it flexible
            Container(
              height: 250, // Keep fixed height for consistency or use LayoutBuilder
              child: chart,
            ),
          ],
        ),
      ),
    );
  }
}

// --- Helper Chart Data Classes ---
// (Keep these IDENTICAL to the mobile version)
class _ChartDataPoint {
  final String x;
  final double y;
  _ChartDataPoint(this.x, this.y);
}

class _UpdateChartData {
  final String month;
  final int phoneUpdates;
  final int addressUpdates;
  final int nextVisitUpdates;
  _UpdateChartData(this.month, this.phoneUpdates, this.addressUpdates, this.nextVisitUpdates);
}