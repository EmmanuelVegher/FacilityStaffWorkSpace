// A NATIONWIDE PAGE FOR REVIEWING STAFF TIMESHEETS (FINAL ADVANCED VERSION)

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:html' as html;
import 'package:flutter/services.dart' show Uint8List, rootBundle;

import '../../widgets/drawer2.dart';
import '../../widgets/drawer3.dart'; // Assuming you have a national-level drawer

// --- DATA MODELS (Unchanged) ---
// (Your TimesheetEntry, TimesheetModel, and TimesheetMetrics classes go here without any changes)
class TimesheetEntry {
  final String date;
  final String durationWorked;
  final num noOfHours;
  final bool isOffDay;
  final String projectName;

  TimesheetEntry({
    required this.date,
    required this.durationWorked,
    required this.noOfHours,
    required this.isOffDay,
    required this.projectName,
  });

  factory TimesheetEntry.fromMap(Map<String, dynamic> map) {
    return TimesheetEntry(
      date: map['date'] as String? ?? 'N/A',
      durationWorked: map['durationWorked'] as String? ?? 'N/A',
      noOfHours: map['noOfHours'] as num? ?? 0,
      isOffDay: map['offDay'] as bool? ?? false,
      projectName: map['projectName'] as String? ?? 'N/A',
    );
  }
}

class TimesheetModel {
  final String staffId;
  final String staffName;
  final String staffEmail;
  final String designation;
  final String department;
  final String location;
  final String state;
  final String? staffSignature;
  final String? staffSignatureDate;
  final String? projectName;
  final String facilitySupervisor;
  final String facilitySupervisorSignatureStatus;
  final String? facilitySupervisorSignature;
  final String? facilitySupervisorSignatureDate;
  final String caritasSupervisor;
  final String caritasSupervisorSignatureStatus;
  final String? caritasSupervisorSignature;
  final String? caritasSupervisorSignatureDate;
  final List<TimesheetEntry> entries;
  final double totalHours;

  // MODIFIED: The constructor now calls a helper method to calculate totalHours correctly.
  TimesheetModel({
    required this.staffId,
    required this.staffName,
    required this.staffEmail,
    required this.designation,
    required this.department,
    required this.location,
    required this.state,
    this.staffSignature,
    this.staffSignatureDate,
    this.projectName,
    required this.facilitySupervisor,
    required this.facilitySupervisorSignatureStatus,
    this.facilitySupervisorSignature,
    this.facilitySupervisorSignatureDate,
    required this.caritasSupervisor,
    required this.caritasSupervisorSignatureStatus,
    this.caritasSupervisorSignature,
    this.caritasSupervisorSignatureDate,
    required this.entries,
  }) : totalHours = _calculateCappedTotalHours(entries);

  // NEW: Helper method to calculate total hours with an 8-hour daily cap.
  static double _calculateCappedTotalHours(List<TimesheetEntry> entries) {
    if (entries.isEmpty) return 0.0;

    final Map<String, double> dailyHours = {};
    for (final entry in entries) {
      dailyHours.update(
        entry.date,
            (value) => value + entry.noOfHours.toDouble(),
        ifAbsent: () => entry.noOfHours.toDouble(),
      );
    }

    double cappedTotal = 0.0;
    for (final hours in dailyHours.values) {
      cappedTotal += (hours > 8.0) ? 8.0 : hours;
    }

    return cappedTotal;
  }

  factory TimesheetModel.fromMap(Map<String, dynamic> map, String id) {
    var entriesData = (map['timesheetEntries'] as List<dynamic>?)
        ?.map((e) => TimesheetEntry.fromMap(e as Map<String, dynamic>))
        .toList() ?? [];

    return TimesheetModel(
      staffId: map['staffId'] as String? ?? id,
      staffName: map['staffName'] as String? ?? 'N/A',
      staffEmail: map['staffEmail'] as String? ?? 'N/A',
      designation: map['designation'] as String? ?? 'N/A',
      department: map['department'] as String? ?? 'N/A',
      location: map['location'] as String? ?? 'N/A',
      state: map['state'] as String? ?? 'N/A',
      staffSignature: map['staffSignature'] as String?,
      staffSignatureDate: map['staffSignatureDate'] as String?,
      projectName: map['projectName'] as String?,
      facilitySupervisor: map['facilitySupervisor'] as String? ?? 'N/A',
      facilitySupervisorSignatureStatus: map['facilitySupervisorSignatureStatus'] as String? ?? 'Pending',
      facilitySupervisorSignature: map['facilitySupervisorSignature'] as String?,
      facilitySupervisorSignatureDate: map['facilitySupervisorSignatureDate'] as String?,
      caritasSupervisor: map['caritasSupervisor'] as String? ?? 'N/A',
      caritasSupervisorSignatureStatus: map['caritasSupervisorSignatureStatus'] as String? ?? 'Pending',
      caritasSupervisorSignature: map['caritasSupervisorSignature'] as String?,
      caritasSupervisorSignatureDate: map['caritasSupervisorSignatureDate'] as String?,
      entries: entriesData,
    );
  }
}

class TimesheetMetrics {
  int totalExpected = 0;
  int totalSubmitted = 0;
  int pendingFacilityApproval = 0;
  int pendingCaritasApproval = 0;
  int fullyApproved = 0;
  double totalHoursLogged = 0;
  double percentFullyApproved = 0.0;
}


// --- MAIN WIDGET ---
class TimesheetReviewPageHq extends StatefulWidget {
  const TimesheetReviewPageHq({super.key});

  @override
  _TimesheetReviewPageHqState createState() => _TimesheetReviewPageHqState();
}

class _TimesheetReviewPageHqState extends State<TimesheetReviewPageHq> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isFilterLoading = true;
  bool _isLoading = false;
  bool _isExporting = false;
  String? _errorMessage;

  List<String> _availableStates = [];
  List<String> _availableFacilities = [];
  List<String> _selectedStates = [];
  List<String> _selectedFacilities = [];

  late int _selectedYear;
  late int _selectedMonth;
  List<TimesheetModel> _staffListForFilter = [];
  List<String> _selectedStaffIds = [];

  List<TimesheetModel> _allTimesheetsMaster = [];
  List<TimesheetModel> _displayedTimesheets = [];
  TimesheetMetrics _metrics = TimesheetMetrics();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
    _initializeFilters();
  }

  Future<void> _initializeFilters() async {
    // Use the main loading indicator for the entire startup process.
    setState(() => _isLoading = true);
    try {
      final snapshot = await _firestore.collection('Location').get();
      final states = snapshot.docs.map((doc) => doc.id).where((id) => id.isNotEmpty).toList();

      if (mounted) {
        // 1. Set the available states and the default selection.
        setState(() {
          _availableStates = ['All States', ...states..sort()];
          _selectedStates = ['All States'];
        });

        // 2. Await the population of the dependent facility filter.
        await _onStateSelectionChange(_selectedStates);

        if (!mounted) return;

        // 3. With filters now initialized with defaults, load the timesheet data.
        await _loadTimesheets();
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = "Error initializing page: $e");
    } finally {
      // 4. Turn off the main loading indicator when all startup tasks are complete.
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isFilterLoading = false; // Also ensure the filter-specific loader is off.
        });
      }
    }
  }

  Future<void> _onStateSelectionChange(List<String> selected) async {
    setState(() {
      _selectedStates = selected;
      _isFilterLoading = true;
      _selectedFacilities = ['All Facilities'];
      _availableFacilities = ['All Facilities'];
      _allTimesheetsMaster.clear();
      _applyFiltersAndCalculateMetrics();
    });

    List<String> statesToQuery = _selectedStates.contains('All States')
        ? _availableStates.where((s) => s != 'All States').toList()
        : _selectedStates;

    if (statesToQuery.isNotEmpty) {
      try {
        final Set<String> facilityNames = {};
        for (var i = 0; i < statesToQuery.length; i += 30) {
          final chunk = statesToQuery.sublist(i, min(i + 30, statesToQuery.length));
          final locationDocs = await _firestore.collection('Location').where(FieldPath.documentId, whereIn: chunk).get();
          for (final doc in locationDocs.docs) {
            final facilitiesSnapshot = await doc.reference.collection(doc.id).get();
            for (final facilityDoc in facilitiesSnapshot.docs) {
              final locationName = facilityDoc.data()['LocationName'] as String?;
              if (locationName != null && locationName.isNotEmpty) {
                facilityNames.add(locationName);
              }
            }
          }
        }
        if (mounted) {
          setState(() {
            _availableFacilities.addAll(facilityNames.toList()..sort());
          });
        }
      } catch (e) {
        if (mounted) setState(() => _errorMessage = "Error updating facility filter: $e");
      }
    }
    if (mounted) setState(() => _isFilterLoading = false);
  }

  // MODIFIED: Rewritten to get accurate 'Expected' count and use correct 'whereIn' logic.
  Future<void> _loadTimesheets() async {
    if (_selectedStates.isEmpty || (_selectedStates.contains('All States') && _availableStates.length <= 1)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select at least one state.")));
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _allTimesheetsMaster = [];
      _staffListForFilter = [];
      _selectedStaffIds.clear();
    });

    try {
      List<String> statesToQuery = _selectedStates.contains('All States')
          ? _availableStates.where((s) => s != 'All States').toList()
          : _selectedStates;

      List<String> facilitiesToQuery = _selectedFacilities.contains('All Facilities')
          ? _availableFacilities.where((f) => f != 'All Facilities').toList()
          : _selectedFacilities;

      // --- Step 1: Get the ACCURATE count of expected staff for metrics ---
      int expectedCount = 0;
      Query staffCountQuery = _firestore.collection('Staff')
          .where('staffCategory', isEqualTo: 'Facility Staff')
          .where('state', whereIn: statesToQuery);

      // Only add the location filter if a specific set of facilities is chosen
      if (facilitiesToQuery.isNotEmpty && !_selectedFacilities.contains('All Facilities')) {
        staffCountQuery = staffCountQuery.where('location', whereIn: facilitiesToQuery);
      }

      // Use .count() for an efficient way to get the number of documents
      final aggregateQuerySnapshot = await staffCountQuery.count().get();
      expectedCount = aggregateQuerySnapshot.count ?? 0;

      // --- Step 2: Perform the main collection group query for submitted timesheets ---
      Query timesheetQuery = _firestore.collectionGroup('TimeSheets')
          .where('state', whereIn: statesToQuery);

      if (facilitiesToQuery.isNotEmpty && !_selectedFacilities.contains('All Facilities')) {
        timesheetQuery = timesheetQuery.where('location', whereIn: facilitiesToQuery);
      }

      final timesheetSnapshot = await timesheetQuery.get();

      // --- Step 3: Filter results by the correct month/year document ID ---
      final monthName = DateFormat('MMMM').format(DateTime(_selectedYear, _selectedMonth));
      final timesheetDocId = '${monthName}_$_selectedYear';

      final List<TimesheetModel> fetchedTimesheets = [];
      for (final doc in timesheetSnapshot.docs) {
        if (doc.id == timesheetDocId) {
          final data = doc.data();
          if (data is Map<String, dynamic>) {
            final staffId = data['staffId'] as String? ?? doc.reference.parent.parent!.id;
            fetchedTimesheets.add(TimesheetModel.fromMap(data, staffId));
          }
        }
      }

      _allTimesheetsMaster = fetchedTimesheets..sort((a, b) => a.staffName.compareTo(b.staffName));
      _staffListForFilter = List.from(_allTimesheetsMaster);
      // Pass the accurate expectedCount to the metrics calculation
      _applyFiltersAndCalculateMetrics(expectedCount);

    } catch (e, stack) {
      debugPrint('Error loading timesheets: $e\n$stack');
      if (mounted) {
        if (e is FirebaseException && e.code == 'failed-precondition') {
          _errorMessage = 'Firestore Index Required: Please check your debug console for a link to create the necessary index.';
        } else {
          _errorMessage = 'Failed to load timesheets: $e';
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // MODIFIED: Ensures metrics cascade from the correct 'expected' count.
  void _applyFiltersAndCalculateMetrics([int? expectedCount]) {
    List<TimesheetModel> filteredList = _allTimesheetsMaster;

    if (_selectedStaffIds.isNotEmpty) {
      final selectionSet = _selectedStaffIds.toSet();
      filteredList = _allTimesheetsMaster.where((ts) => selectionSet.contains(ts.staffId)).toList();
    }

    final newMetrics = TimesheetMetrics();

    // Use the passed-in expectedCount, or default to the existing one if just sub-filtering.
    newMetrics.totalExpected = expectedCount ?? _metrics.totalExpected;
    newMetrics.totalSubmitted = _allTimesheetsMaster.length;

    newMetrics.fullyApproved = filteredList.where((ts) => ts.facilitySupervisorSignatureStatus == 'Approved' && ts.caritasSupervisorSignatureStatus == 'Approved').length;
    newMetrics.pendingCaritasApproval = filteredList.where((ts) => ts.facilitySupervisorSignatureStatus == 'Approved' && ts.caritasSupervisorSignatureStatus != 'Approved').length;
    newMetrics.pendingFacilityApproval = filteredList.where((ts) => ts.facilitySupervisorSignatureStatus != 'Approved').length;
    newMetrics.totalHoursLogged = filteredList.fold(0.0, (sum, item) => sum + item.totalHours);

    if (newMetrics.totalExpected > 0) {
      // % Approved should be based on the master list for the current filter, not the sub-filtered staff list
      final masterFullyApproved = _allTimesheetsMaster.where((ts) => ts.facilitySupervisorSignatureStatus == 'Approved' && ts.caritasSupervisorSignatureStatus == 'Approved').length;
      newMetrics.percentFullyApproved = (masterFullyApproved / newMetrics.totalExpected) * 100;
    } else {
      newMetrics.percentFullyApproved = 0.0;
    }

    setState(() {
      _displayedTimesheets = filteredList;
      _metrics = newMetrics;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Nationwide Timesheet Review", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF722F37),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if(_isExporting)
            const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: Colors.white))
          else
            PopupMenuButton<String>(
              icon: const Icon(Icons.download_outlined),
              tooltip: "Download Options",
              onSelected: (value) {
                if(value == 'bulk') _downloadBulkPdf();
              },
              enabled: !_isLoading && _displayedTimesheets.isNotEmpty,
              itemBuilder: (context) => [
                const PopupMenuItem(
                    value: 'bulk',
                    child: ListTile(leading: Icon(Icons.picture_as_pdf), title: Text("Download All (PDF)"))
                )
              ],
            )
        ],
      ),
      drawer: drawer3(context),
      body: Column(
        children: [
          _buildFilterBar(),
          if (_errorMessage != null) Center(child: Padding(padding: const EdgeInsets.all(8.0), child: Text(_errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center))),
          _buildMetricsDashboard(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _allTimesheetsMaster.isEmpty && !_isLoading
                ? Center(child: Padding(padding: const EdgeInsets.all(24.0), child: Text("Please select filters and click 'Apply' to see timesheets.", style: TextStyle(color: Colors.grey.shade600))))
                : _buildTimesheetList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final years = List.generate(5, (index) => DateTime.now().year - index);
    final months = List.generate(12, (index) => index + 1);

    return Card(
      margin: const EdgeInsets.all(8.0),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Wrap(
          spacing: 16, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.center,
          children: [
            if (_isFilterLoading) const Text("Loading filters...") else ...[
              _buildMultiSelectStateDropdown(),
              _buildMultiSelectFacilityDropdown(),
            ],
            DropdownButtonFormField<int>(
              value: _selectedMonth,
              decoration: const InputDecoration(labelText: 'Month', border: OutlineInputBorder(), constraints: BoxConstraints(maxWidth: 150)),
              items: months.map((m) => DropdownMenuItem(value: m, child: Text(DateFormat('MMMM').format(DateTime(0, m))))).toList(),
              onChanged: (value) => setState(() => _selectedMonth = value!),
            ),
            DropdownButtonFormField<int>(
              value: _selectedYear,
              decoration: const InputDecoration(labelText: 'Year', border: OutlineInputBorder(), constraints: BoxConstraints(maxWidth: 120)),
              items: years.map((y) => DropdownMenuItem(value: y, child: Text(y.toString()))).toList(),
              onChanged: (value) => setState(() => _selectedYear = value!),
            ),
            _buildMultiSelectStaffDropdown(),
            ElevatedButton.icon(
              icon: const Icon(Icons.filter_list),
              label: const Text('Apply Filter'),
              onPressed: _isLoading || _isFilterLoading ? null : _loadTimesheets,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
            ),
          ],
        ),
      ),
    );
  }

  // MODIFIED: Simplified "All" logic for State dropdown.
  void _showMultiSelectStateDialog() async {
    List<String> tempSelected = List.from(_selectedStates);
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            bool isAllSelected = tempSelected.length == _availableStates.length -1 || tempSelected.contains('All States');
            return AlertDialog(
              title: const Text('Select States'),
              content: SizedBox(
                width: 350,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CheckboxListTile(
                      title: const Text('All States', style: TextStyle(fontWeight: FontWeight.bold)),
                      value: isAllSelected,
                      onChanged: (bool? value) {
                        setDialogState(() {
                          tempSelected.clear();
                          if (value == true) {
                            tempSelected.add('All States');
                          }
                        });
                      },
                    ),
                    const Divider(),
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _availableStates.where((s) => s != 'All States').length,
                        itemBuilder: (context, index) {
                          final option = _availableStates.where((s) => s != 'All States').toList()[index];
                          return CheckboxListTile(
                            title: Text(option),
                            value: tempSelected.contains(option),
                            onChanged: (bool? value) {
                              setDialogState(() {
                                tempSelected.remove('All States');
                                if (value == true) {
                                  tempSelected.add(option);
                                } else {
                                  tempSelected.remove(option);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    if (tempSelected.isEmpty) tempSelected.add('All States');
                    _onStateSelectionChange(tempSelected);
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ... (The rest of the code is largely the same, paste from previous response) ...
  // ... (All other build methods, PDF logic, etc. are correct) ...
  Widget _buildMultiSelectStateDropdown() {
    String getButtonText() {
      if (_selectedStates.isEmpty) return 'Select State';
      if (_selectedStates.contains('All States')) return 'All States';
      if (_selectedStates.length == 1) return _selectedStates.first;
      return '${_selectedStates.length} States Selected';
    }

    return InkWell(
      onTap: _showMultiSelectStateDialog,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'State',
          border: OutlineInputBorder(),
          constraints: BoxConstraints(maxWidth: 300),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Expanded(child: Text(getButtonText(), overflow: TextOverflow.ellipsis)),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiSelectFacilityDropdown() {
    String getButtonText() {
      if (_selectedFacilities.isEmpty) return 'Select Facility';
      if (_selectedFacilities.contains('All Facilities')) return 'All Facilities';
      if (_selectedFacilities.length == 1) return _selectedFacilities.first;
      return '${_selectedFacilities.length} Facilities Selected';
    }

    return InkWell(
      onTap: _availableFacilities.length <= 1 ? null : _showMultiSelectFacilityDialog,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Facility',
          border: const OutlineInputBorder(),
          constraints: const BoxConstraints(maxWidth: 300),
          filled: _availableFacilities.length <= 1,
          fillColor: Colors.grey.shade200,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Expanded(child: Text(getButtonText(), overflow: TextOverflow.ellipsis)),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  void _showMultiSelectFacilityDialog() async {
    List<String> tempSelected = List.from(_selectedFacilities);
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isAllSelected = tempSelected.contains('All Facilities') || tempSelected.length == _availableFacilities.length - 1;
            return AlertDialog(
              title: const Text('Select Facilities'),
              content: SizedBox(
                width: 350,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CheckboxListTile(
                      title: const Text('All Facilities', style: TextStyle(fontWeight: FontWeight.bold)),
                      value: isAllSelected,
                      onChanged: (bool? value) {
                        setDialogState(() {
                          tempSelected.clear();
                          if (value == true) {
                            tempSelected.add('All Facilities');
                          }
                        });
                      },
                    ),
                    const Divider(),
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _availableFacilities.where((f) => f != 'All Facilities').length,
                        itemBuilder: (context, index) {
                          final option = _availableFacilities.where((f) => f != 'All Facilities').toList()[index];
                          return CheckboxListTile(
                            title: Text(option),
                            value: tempSelected.contains(option),
                            onChanged: (bool? value) {
                              setDialogState(() {
                                tempSelected.remove('All Facilities');
                                if (value == true) {
                                  tempSelected.add(option);
                                } else {
                                  tempSelected.remove(option);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
                ElevatedButton(
                  onPressed: () {
                    if (tempSelected.isEmpty) tempSelected.add('All Facilities');
                    setState(() => _selectedFacilities = tempSelected);
                    Navigator.pop(context);
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMultiSelectStaffDropdown() {
    String getButtonText() {
      if (_selectedStaffIds.isEmpty) return 'All Staff';
      if (_selectedStaffIds.length == 1) {
        final staffMember = _staffListForFilter.firstWhere((s) => s.staffId == _selectedStaffIds.first, orElse: () => TimesheetModel.fromMap({}, ''));
        return staffMember.staffName;
      }
      return '${_selectedStaffIds.length} Staff Selected';
    }

    return InkWell(
      onTap: _staffListForFilter.isEmpty ? null : _showMultiSelectStaffDialog,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Staff Member',
          border: const OutlineInputBorder(),
          constraints: const BoxConstraints(maxWidth: 250),
          filled: _staffListForFilter.isEmpty,
          fillColor: Colors.grey.shade200,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Expanded(child: Text(getButtonText(), overflow: TextOverflow.ellipsis)),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  void _showMultiSelectStaffDialog() async {
    List<String> tempSelectedIds = List.from(_selectedStaffIds);
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            bool isAllSelected = tempSelectedIds.length == _staffListForFilter.length;
            return AlertDialog(
              title: const Text('Select Staff'),
              content: SizedBox(
                width: 350,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CheckboxListTile(
                      title: const Text('All Staff', style: TextStyle(fontWeight: FontWeight.bold)),
                      value: isAllSelected,
                      onChanged: (bool? value) {
                        setDialogState(() {
                          tempSelectedIds.clear();
                          if (value == true) {
                            tempSelectedIds.addAll(_staffListForFilter.map((s) => s.staffId));
                          }
                        });
                      },
                    ),
                    const Divider(),
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _staffListForFilter.length,
                        itemBuilder: (context, index) {
                          final staff = _staffListForFilter[index];
                          return CheckboxListTile(
                            title: Text(staff.staffName),
                            value: tempSelectedIds.contains(staff.staffId),
                            onChanged: (bool? value) {
                              setDialogState(() {
                                if (value == true) {
                                  tempSelectedIds.add(staff.staffId);
                                } else {
                                  tempSelectedIds.remove(staff.staffId);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
                ElevatedButton(
                  onPressed: () {
                    // MODIFIED: If all are selected, treat as "All Staff" by clearing the list
                    if (tempSelectedIds.length == _staffListForFilter.length) {
                      _selectedStaffIds.clear();
                    } else {
                      _selectedStaffIds = tempSelectedIds;
                    }
                    _applyFiltersAndCalculateMetrics();
                    Navigator.of(context).pop();
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMetricsDashboard() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Wrap(
        spacing: 16, runSpacing: 16, alignment: WrapAlignment.center,
        children: [
          _buildKpiCard("Expected Timesheets", _metrics.totalExpected.toString(), Icons.people_alt_rounded, Colors.indigo),
          _buildKpiCard("Total Submitted", _metrics.totalSubmitted.toString(), Icons.file_present_rounded, Colors.blueGrey),
          _buildKpiCard("Awaiting Facility Approval", _metrics.pendingFacilityApproval.toString(), Icons.hourglass_top_rounded, Colors.orange),
          _buildKpiCard("Awaiting CARITAS Approval", _metrics.pendingCaritasApproval.toString(), Icons.hourglass_bottom_rounded, Colors.deepPurple),
          _buildKpiCard("Fully Approved", _metrics.fullyApproved.toString(), Icons.check_circle_rounded, Colors.green),
          _buildKpiCard("% Fully Approved", "${_metrics.percentFullyApproved.toStringAsFixed(1)}%", Icons.pie_chart, Colors.pink),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Container(
        padding: const EdgeInsets.all(16),
        width: 240,
        child: Row(
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
                  const SizedBox(height: 4),
                  Text(title, style: TextStyle(fontSize: 14, color: Colors.grey.shade700), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimesheetList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: _displayedTimesheets.length,
      itemBuilder: (context, index) {
        final timesheet = _displayedTimesheets[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: ExpansionTile(
            title: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(timesheet.staffName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('${timesheet.location} - ${timesheet.state}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                _buildStatusChip(timesheet.facilitySupervisorSignatureStatus, timesheet.caritasSupervisorSignatureStatus),
                const SizedBox(width: 8),
                Text("${timesheet.totalHours.toStringAsFixed(2)} hrs", style: const TextStyle(fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                  tooltip: "Download PDF",
                  onPressed: () => _downloadSinglePdf(timesheet.staffId),
                )
              ],
            ),
            children: [_buildExpansionDetails(timesheet)],
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(String facilityStatus, String caritasStatus) {
    String text; Color color;
    if (facilityStatus == 'Approved' && caritasStatus == 'Approved') {
      text = 'Fully Approved'; color = Colors.green;
    } else if (facilityStatus == 'Approved' && caritasStatus == 'Pending') {
      text = 'CARITAS Pending'; color = Colors.deepPurple;
    } else {
      text = 'Facility Pending'; color = Colors.orange;
    }
    return Chip(
      label: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildExpansionDetails(TimesheetModel timesheet) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildSupervisorInfo("Facility Supervisor", timesheet.facilitySupervisor, timesheet.facilitySupervisorSignatureStatus, timesheet.facilitySupervisorSignatureDate, timesheet.facilitySupervisorSignature)),
              Expanded(child: _buildSupervisorInfo("CARITAS Supervisor", timesheet.caritasSupervisor, timesheet.caritasSupervisorSignatureStatus, timesheet.caritasSupervisorSignatureDate, timesheet.caritasSupervisorSignature)),
            ],
          ),
          const Divider(height: 24),
          Text("Daily Entries", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _buildEntriesTable(timesheet.entries),
        ],
      ),
    );
  }

  Widget _buildSupervisorInfo(String title, String name, String status, String? date, String? signatureUrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), Text(name),
        Text("Status: $status"),
        if (date != null) Text("Date: $date"),
        if (signatureUrl != null && signatureUrl.isNotEmpty) ...[
          const SizedBox(height: 8),
          Image.network(signatureUrl, height: 40, errorBuilder: (c, e, s) => const Icon(Icons.error, color: Colors.red)),
        ]
      ],
    );
  }

  Widget _buildEntriesTable(List<TimesheetEntry> entries) {
    // 1. Aggregate entries to get a summary for each day.
    final Map<String, Map<String, dynamic>> dailySummary = {};
    for (final entry in entries) {
      dailySummary.update(
        entry.date,
            (value) {
          value['hours'] = value['hours']! + entry.noOfHours.toDouble();
          if (entry.isOffDay) value['isOffDay'] = true;
          return value;
        },
        ifAbsent: () => {
          'hours': entry.noOfHours.toDouble(),
          'isOffDay': entry.isOffDay,
        },
      );
    }

    // 2. Sort the daily entries by date for consistent display.
    final sortedDates = dailySummary.keys.toList()..sort();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        // MODIFIED: Columns are simplified for a daily summary view.
        columns: const [
          DataColumn(label: Text("Date")),
          DataColumn(label: Text("Total Hours"), numeric: true)
        ],
        rows: sortedDates.map((date) {
          final summary = dailySummary[date]!;
          final double dailyHours = summary['hours']!;
          // 3. Apply the 8-hour cap for display, matching the total calculation.
          final double cappedHours = dailyHours > 8.0 ? 8.0 : dailyHours;
          final bool isOffDay = summary['isOffDay']!;

          return DataRow(
              color: WidgetStateProperty.resolveWith<Color?>(
                      (s) => isOffDay ? Colors.blue.withOpacity(0.05) : null),
              cells: [
                DataCell(Text(date)),
                DataCell(Text(cappedHours.toStringAsFixed(2))),
              ]
          );
        }).toList(),
      ),
    );
  }

  Future<TimesheetModel?> _fetchTimesheetFromFirestore(String staffId, String timesheetDocId) async {
    try {
      final querySnapshot = await _firestore.collectionGroup('TimeSheets').where('staffId', isEqualTo: staffId).get();
      final docs = querySnapshot.docs.where((doc) => doc.id == timesheetDocId).toList();
      if (docs.isNotEmpty) {
        final doc = docs.first;
        final data = doc.data();
        if (data is Map<String, dynamic>) {
          return TimesheetModel.fromMap(data, staffId);
        }
      }
      return null;
    } catch (e) {
      debugPrint("Error fetching single timesheet for PDF: $e");
      return null;
    }
  }

  Future<void> _downloadSinglePdf(String staffId) async {
    setState(() => _isExporting = true);
    final monthName = DateFormat('MMMM').format(DateTime(_selectedYear, _selectedMonth));
    final timesheetDocId = '${monthName}_$_selectedYear';
    final timesheet = await _fetchTimesheetFromFirestore(staffId, timesheetDocId);
    if (timesheet == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not find the latest timesheet for staff ID ${staffId} to download.')));
      setState(() => _isExporting = false);
      return;
    }
    final pdf = pw.Document();
    final font = await rootBundle.load("assets/fonts/OpenSans-Regular.ttf");
    final boldFont = await rootBundle.load("assets/fonts/OpenSans-Bold.ttf");
    final ttf = pw.Font.ttf(font);
    final ttfBold = pw.Font.ttf(boldFont);
    final logoImage = pw.MemoryImage((await rootBundle.load('assets/image/ccfn_logo.png')).buffer.asUint8List());
    pdf.addPage(await _createSingleTimesheetPage(timesheet, logoImage, ttf, ttfBold));
    final pdfBytes = await pdf.save();
    _triggerDownload(pdfBytes, 'Timesheet_${timesheet.staffName.replaceAll(' ','_')}_${_selectedMonth}_${_selectedYear}.pdf');
    setState(() => _isExporting = false);
  }

  Future<void> _downloadBulkPdf() async {
    setState(() => _isExporting = true);
    try {
      List<String> statesToQuery = _selectedStates.contains('All States')
          ? _availableStates.where((s) => s != 'All States').toList()
          : _selectedStates;

      Query timesheetQuery = _firestore.collectionGroup('TimeSheets').where('state', whereIn: statesToQuery);

      List<String> facilitiesToQuery = _selectedFacilities.contains('All Facilities')
          ? _availableFacilities.where((f) => f != 'All Facilities').toList()
          : _selectedFacilities;

      if (facilitiesToQuery.isNotEmpty && !_selectedFacilities.contains('All Facilities')) {
        timesheetQuery = timesheetQuery.where('location', whereIn: facilitiesToQuery);
      }
      final timesheetSnapshot = await timesheetQuery.get();

      final monthName = DateFormat('MMMM').format(DateTime(_selectedYear, _selectedMonth));
      final timesheetDocId = '${monthName}_$_selectedYear';
      final staffIdFilterSet = _selectedStaffIds.toSet();
      final List<TimesheetModel> timesheetsToPrint = [];

      for (final doc in timesheetSnapshot.docs) {
        if (doc.id == timesheetDocId) {
          final data = doc.data();
          if (data is Map<String, dynamic>) {
            final staffId = data['staffId'] as String?;
            if (staffId == null) continue;
            if (staffIdFilterSet.isNotEmpty && !staffIdFilterSet.contains(staffId)) continue;
            timesheetsToPrint.add(TimesheetModel.fromMap(data, staffId));
          }
        }
      }

      if (timesheetsToPrint.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No matching timesheets found to generate a bulk PDF.')));
        setState(() => _isExporting = false);
        return;
      }
      timesheetsToPrint.sort((a,b) => a.staffName.compareTo(b.staffName));

      final pdf = pw.Document();
      final font = await rootBundle.load("assets/fonts/OpenSans-Regular.ttf");
      final boldFont = await rootBundle.load("assets/fonts/OpenSans-Bold.ttf");
      final ttf = pw.Font.ttf(font);
      final ttfBold = pw.Font.ttf(boldFont);
      final logoImage = pw.MemoryImage((await rootBundle.load('assets/image/ccfn_logo.png')).buffer.asUint8List());
      for(final timesheet in timesheetsToPrint) {
        pdf.addPage(await _createSingleTimesheetPage(timesheet, logoImage, ttf, ttfBold));
      }

      final pdfBytes = await pdf.save();
      String selectionName = 'Nationwide';
      if (!_selectedStates.contains('All States')) {
        selectionName = _selectedStates.join('_').replaceAll(' ', '_');
      }
      _triggerDownload(pdfBytes, 'Bulk_Timesheets_${selectionName}_${_selectedMonth}_${_selectedYear}.pdf');

    } catch (e, stack) {
      debugPrint("Error generating bulk PDF: $e\n$stack");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('An error occurred while generating the bulk PDF: $e')));
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<Uint8List?> _networkImageToByte(String? imageUrl) async {
    if (imageUrl == null || imageUrl.isEmpty || imageUrl == 'null') return null;
    try {
      final response = await Dio().get<List<int>>(imageUrl, options: Options(responseType: ResponseType.bytes));
      if (response.statusCode == 200 && response.data != null && response.data!.isNotEmpty) {
        return Uint8List.fromList(response.data!);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching image for PDF: $e');
      return null;
    }
  }

  void _triggerDownload(Uint8List data, String filename) {
    final blob = html.Blob([data], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.document.createElement('a') as html.AnchorElement
      ..href = url
      ..style.display = 'none'
      ..download = filename;
    html.document.body!.children.add(anchor);
    anchor.click();
    html.document.body!.children.remove(anchor);
    html.Url.revokeObjectUrl(url);
  }


  Future<pw.Page> _createSingleTimesheetPage(TimesheetModel timesheet, pw.ImageProvider logoImage, pw.Font ttf, pw.Font ttfBold) async {
    final monthName = DateFormat('MMMM, yyyy').format(DateTime(_selectedYear, _selectedMonth));

    // *** MODIFIED: Date range is now 20th of previous month to 19th of current month. ***
    final startDate = DateTime(_selectedYear, _selectedMonth - 1, 20);
    final endDate = DateTime(_selectedYear, _selectedMonth, 19);

    final daysInRange = List.generate(endDate.difference(startDate).inDays + 1, (i) => startDate.add(Duration(days: i)));
    final tableHeaders = ['Project Name', ...daysInRange.map((date) => DateFormat('dd').format(date)), 'Total Hours', '%'];

    final mainProjectName = timesheet.projectName ?? "Access Project";
    final List<String> categories = [
      mainProjectName,
      'Annual leave',
      'Holiday',
      'Maternity',
    ];

    Map<String, List<double>> dailyHoursByCategory = {
      for (var category in categories) category: List.filled(daysInRange.length, 0.0)
    };

    // Populate hours from entries, capping each day's work at 8 hours.
    for (int i = 0; i < daysInRange.length; i++) {
      final date = daysInRange[i];
      final dateString = DateFormat('yyyy-MM-dd').format(date);
      double dailyTotalForCap = 0; // Track total hours for a single day to cap at 8

      for (final entry in timesheet.entries) {
        if (entry.date == dateString) {
          double hours = entry.noOfHours.toDouble();
          if (dailyTotalForCap + hours > 8.0) {
            hours = 8.0 - dailyTotalForCap; // Only add the remaining hours up to the cap
          }
          if (hours < 0) hours = 0;
          dailyTotalForCap += hours;

          if (entry.isOffDay) {
            if (dailyHoursByCategory.containsKey(entry.durationWorked)) {
              dailyHoursByCategory[entry.durationWorked]![i] += hours;
            }
          } else {
            dailyHoursByCategory[mainProjectName]![i] += hours;
          }
        }
      }
    }

    final int workingDays = daysInRange.where((d) => d.weekday != DateTime.saturday && d.weekday != DateTime.sunday).length;
    final double maxHours = (workingDays * 8.0);

    List<List<String>> tableBodyRows = [];

    for (var category in categories) {
      final hours = dailyHoursByCategory[category]!;
      final totalCategoryHours = hours.reduce((a, b) => a + b);
      final percentCategory = maxHours > 0 ? (totalCategoryHours / maxHours * 100) : 0;
      tableBodyRows.add([
        category,
        ...hours.map((h) => h.round().toString()),
        totalCategoryHours.round().toString(),
        '${percentCategory.round()}%'
      ]);
    }

    List<String> totalRowStrings = ['Total'];
    for (int i = 0; i < daysInRange.length; i++) {
      double dayTotal = 0;
      for (var category in categories) {
        dayTotal += dailyHoursByCategory[category]![i];
      }
      totalRowStrings.add(dayTotal.round().toString());
    }

    final double grandTotalHours = totalRowStrings.sublist(1).fold(0.0, (sum, item) => sum + (double.tryParse(item) ?? 0.0));
    final double grandPercent = maxHours > 0 ? (grandTotalHours / maxHours * 100) : 0.0;

    totalRowStrings.add(grandTotalHours.round().toString());
    totalRowStrings.add('${grandPercent.round()}%');
    tableBodyRows.add(totalRowStrings);

    final staffSigBytes = await _networkImageToByte(timesheet.staffSignature);
    final facilitySigBytes = await _networkImageToByte(timesheet.facilitySupervisorSignature);
    final caritasSigBytes = await _networkImageToByte(timesheet.caritasSupervisorSignature);

    return pw.Page(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(30),
      theme: pw.ThemeData.withFont(base: ttf, bold: ttfBold),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Name: ${timesheet.staffName}', style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('Department: ${timesheet.department}', style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('Designation: ${timesheet.designation}', style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('Location: ${timesheet.location}', style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('State: ${timesheet.state}', style: const pw.TextStyle(fontSize: 10)),
                    ]),
                pw.Column(children: [
                  pw.Text("CARITAS NIGERIA", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 20)),
                  pw.SizedBox(height: 5),
                  pw.Text("Monthly Time Report ($monthName)", style: const pw.TextStyle(fontSize: 14))
                ]),
                pw.Image(logoImage, width: 70, height: 70),
              ],
            ),
            pw.SizedBox(height: 15),
            pw.Table(
              border: pw.TableBorder.all(),
              columnWidths: {
                0: const pw.FlexColumnWidth(2.5),
                for (int i = 1; i <= daysInRange.length; i++) i: const pw.FlexColumnWidth(0.8),
                daysInRange.length + 1: const pw.FlexColumnWidth(1.2),
                daysInRange.length + 2: const pw.FlexColumnWidth(0.8),
              },
              children: [
                pw.TableRow(
                  children: tableHeaders.asMap().entries.map((entry) {
                    final i = entry.key;
                    final headerText = entry.value;
                    bool isWeekendHeader = i > 0 && i <= daysInRange.length && (daysInRange[i - 1].weekday == 6 || daysInRange[i - 1].weekday == 7);
                    return pw.Container(
                        color: isWeekendHeader ? PdfColors.black : PdfColors.grey300,
                        alignment: pw.Alignment.center,
                        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                        child: pw.Text(headerText, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: isWeekendHeader ? PdfColors.white : PdfColors.black)));
                  }).toList(),
                ),
                ...tableBodyRows.map((row) {
                  final isTotalRow = row.first == 'Total';
                  final style = isTotalRow
                      ? pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)
                      : const pw.TextStyle(fontSize: 8);

                  return pw.TableRow(
                    decoration: isTotalRow ? const pw.BoxDecoration(color: PdfColors.grey300) : null,
                    children: row.asMap().entries.map((entry) {
                      final i = entry.key;
                      final data = entry.value;
                      final isWeekend = i > 0 && i <= daysInRange.length && (daysInRange[i - 1].weekday == 6 || daysInRange[i - 1].weekday == 7);

                      return pw.Container(
                        color: isWeekend ? PdfColors.black : null,
                        alignment: pw.Alignment.center,
                        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                        child: pw.Text(
                          isWeekend ? '' : data,
                          style: style,
                        ),
                      );
                    }).toList(),
                  );
                }),
              ],
            ),
            pw.Spacer(),
            pw.Text('Signature & Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
            pw.Divider(height: 1),
            pw.SizedBox(height: 5),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                _buildPdfSignatureColumn('Name of Staff', timesheet.staffName, staffSigBytes, timesheet.staffSignatureDate),
                _buildPdfSignatureColumn('Name of Project Coordinator', timesheet.facilitySupervisor, facilitySigBytes, timesheet.facilitySupervisorSignatureDate),
                _buildPdfSignatureColumn('Name of Caritas Supervisor', timesheet.caritasSupervisor, caritasSigBytes, timesheet.caritasSupervisorSignatureDate),
              ],
            ),
          ],
        );
      },
    );
  }

  pw.Widget _buildPdfSignatureColumn(String title, String name, Uint8List? imageBytes, String? date) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
        pw.SizedBox(height: 2),
        pw.Text(name.toUpperCase(), style: const pw.TextStyle(fontSize: 10)),
        pw.SizedBox(height: 2),
        pw.Container(
            height: 35, width: 100,
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 0.5)),
            child: imageBytes != null && imageBytes.isNotEmpty
                ? pw.Image(pw.MemoryImage(imageBytes))
                : pw.Center(child: pw.Text('Signature', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)))
        ),
        pw.SizedBox(height: 2),
        pw.Text("Date: ${date ?? 'N/A'}", style: const pw.TextStyle(fontSize: 10)),
      ],
    );
  }
}
