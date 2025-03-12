import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'package:month_year_picker/month_year_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../widgets/drawer.dart';
import '../login_screen.dart'; // Import your login screen


class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  String? firebaseAuthId;
  String? state;
  String? project;
  String? firstName;
  String? lastName;
  String? designation;
  String? department;
  String? location;
  String? staffCategory;
  String? mobile;
  String? emailAddress;

  double screenHeight = 0;
  double screenWidth = 0;
  Color primary = const Color(0xffeef444c);
  String? _selectedMonth;
  String? _selectedYear;
  List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  List<String> _years = [];

  static const Color wineColor = Color(0xFF722F37); // Deep wine color
  static const LinearGradient appBarGradient = LinearGradient(
    colors: [wineColor, Color(0xFFB34A5A)], // Wine to lighter wine shade
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  Timer? _inactivityTimer; // Inactivity Timer

  @override
  void initState() {
    super.initState();
    _getUserDetails();
    _initializeMonthYear();
    _startInactivityTimer(); // Start inactivity timer on page load
  }

  void _startInactivityTimer() {
    _inactivityTimer?.cancel(); // Cancel any existing timer
    _inactivityTimer = Timer(const Duration(minutes: 5), _logoutUser); // Set timeout to 5 minutes
  }

  void _resetInactivityTimer() {
    _startInactivityTimer(); // Restart the timer on user activity
  }

  void _logoutUser() {
    FirebaseAuth.instance.signOut();
    // Navigate to the login screen after logout
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const LoginPage()), // Replace LoginScreen with your actual login page widget
    );
    Fluttertoast.showToast(
      msg: "Logged out due to inactivity.",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      backgroundColor: Colors.grey,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel(); // Cancel the timer when the widget is disposed
    super.dispose();
  }


  void _initializeMonthYear() {
    DateTime now = DateTime.now();
    _selectedMonth = DateFormat('MMMM').format(now);
    _selectedYear = DateFormat('yyyy').format(now);

    int currentYear = now.year;
    for (int i = currentYear - 5; i <= currentYear + 5; i++) {
      _years.add(i.toString());
    }
  }


  void _getUserDetails() async {
    SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    setState(() {
      firebaseAuthId = sharedPreferences.getString("firebaseAuthId");
      state = sharedPreferences.getString("state");
      project = sharedPreferences.getString("project");
      firstName = sharedPreferences.getString("firstName");
      lastName = sharedPreferences.getString("lastName");
      designation = sharedPreferences.getString("designation");
      department = sharedPreferences.getString("department");
      location = sharedPreferences.getString("location");
      staffCategory = sharedPreferences.getString("staffCategory");
      mobile = sharedPreferences.getString("mobile");
      emailAddress = sharedPreferences.getString("emailAddress");
    });
  }


  Stream<List<AttendanceModel>> _attendanceStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("Error: No authenticated user. Returning empty stream.");
      return Stream.value([]);
    }

    String firebaseAuthId = user.uid;
    print("User authenticated: $firebaseAuthId");

    if (_selectedMonth == null || _selectedYear == null) {
      return Stream.value([]);
    }

    String monthYearForQuery = '${_selectedMonth} ${_selectedYear}';


    return FirebaseFirestore.instance
        .collection("Staff")
        .doc(firebaseAuthId)
        .collection("Record")
        .snapshots()
        .map((snapshot) {
      final filteredDocs = snapshot.docs.where((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return data["month"] == monthYearForQuery;
      }).toList();

      print("Queried Attendance for $monthYearForQuery:");
      for (var doc in filteredDocs) {
        print("Document ID: ${doc.id}, Data: ${doc.data()}");
      }

      return filteredDocs.map((doc) => AttendanceModel.fromFirestore(doc.data() as Map<String, dynamic>, doc.id)).toList();
    });
  }


  @override
  Widget build(BuildContext context) {
    screenWidth = MediaQuery.of(context).size.width;
    screenHeight = MediaQuery.of(context).size.height;

    bool isMobile = screenWidth < 600;
    bool isTablet = screenWidth >= 600 && screenWidth < 1200;
    bool isDesktop = screenWidth >= 1200 && screenWidth < 1900;
    bool isDesktopLarge = screenWidth >= 1900;

    double titleFontSizeFactor;
    double monthPickerFontSizeFactor;
    double cardPaddingFactor;
    double cardMarginFactor;
    double fontSizeFactor;
    double iconSizeFactor;
    double sizedBoxHeightFactor;
    double containerWidthFactor;
    double cardListHeightFactor;
    double dropdownFontSizeFactor;
    double dropdownMenuMaxHeightFactor; // Added for dropdown menu height


    if (isMobile) {
      titleFontSizeFactor = 0.050;
      monthPickerFontSizeFactor = 0.050;
      cardPaddingFactor = 0.012;
      cardMarginFactor = 0.025;
      fontSizeFactor = 0.030;
      iconSizeFactor = 0.050;
      sizedBoxHeightFactor = 0.01;
      containerWidthFactor = 0.30;
      cardListHeightFactor = 1.38;
      dropdownFontSizeFactor = 0.030;
      dropdownMenuMaxHeightFactor = 0.3; // Increased for mobile
    } else if (isTablet) {
      titleFontSizeFactor = 0.015;
      monthPickerFontSizeFactor = 0.015;
      cardPaddingFactor = 0.005;
      cardMarginFactor = 0.010;
      fontSizeFactor = 0.012;
      iconSizeFactor = 0.020;
      sizedBoxHeightFactor = 0.004;
      containerWidthFactor = 0.10;
      cardListHeightFactor = 1.0;
      dropdownFontSizeFactor = 0.010;
      dropdownMenuMaxHeightFactor = 0.25; // Increased for tablet
    }else if (isDesktop) {
      titleFontSizeFactor = 0.015;
      monthPickerFontSizeFactor = 0.015;
      cardPaddingFactor = 0.0035;
      cardMarginFactor = 0.007;
      fontSizeFactor = 0.010;
      iconSizeFactor = 0.015;
      sizedBoxHeightFactor = 0.003;
      containerWidthFactor = 0.10;
      cardListHeightFactor = 0.75;
      dropdownFontSizeFactor = 0.010;
      dropdownMenuMaxHeightFactor = 0.2; // Increased for desktop
    } else {
      titleFontSizeFactor = 0.010;
      monthPickerFontSizeFactor = 0.010;
      cardPaddingFactor = 0.003;
      cardMarginFactor = 0.005;
      fontSizeFactor = 0.007;
      iconSizeFactor = 0.015;
      sizedBoxHeightFactor = 0.002;
      containerWidthFactor = 0.08;
      cardListHeightFactor = 0.75;
      dropdownFontSizeFactor = 0.008;
      dropdownMenuMaxHeightFactor = 0.15; // Increased for large desktop
    }


    return Listener( // Wrap with Listener to detect user interactions
      onPointerDown: (_) => _resetInactivityTimer(), // Reset timer on tap/click
      onPointerMove: (_) => _resetInactivityTimer(), // Reset timer on drag/move
      onPointerSignal: (_) => _resetInactivityTimer(), // Reset timer on scroll/signal
      child: Scaffold(
        appBar:AppBar(
          title: const Text('History', style: TextStyle(color: Colors.white)),
          iconTheme: IconThemeData(color: Colors.white), // Makes the drawer icon white
          flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: appBarGradient),
          ),

        ),
        drawer: drawer(
          context,
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: screenWidth * cardMarginFactor, vertical: screenHeight * cardMarginFactor),
          child: Column(
            children: [
              Container(
                alignment: Alignment.centerLeft,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                  ],
                ),
              ),
              SizedBox(
                height: screenHeight * sizedBoxHeightFactor,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Month',
                        labelStyle: TextStyle(fontSize: screenWidth * dropdownFontSizeFactor),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: screenWidth * 0.02, vertical: screenHeight * 0.01),
                      ),
                      value: _selectedMonth,
                      menuMaxHeight: screenHeight * dropdownMenuMaxHeightFactor, // Increased menu height
                      items: _months.map((month) {
                        return DropdownMenuItem<String>(
                          value: month,
                          child: Text(month, style: TextStyle(fontSize: screenWidth * dropdownFontSizeFactor)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedMonth = value;
                        });
                      },
                    ),
                  ),
                  SizedBox(width: screenWidth * 0.02),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Year',
                        labelStyle: TextStyle(fontSize: screenWidth * dropdownFontSizeFactor),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: screenWidth * 0.02, vertical: screenHeight * 0.01),
                      ),
                      value: _selectedYear,
                      menuMaxHeight: screenHeight * dropdownMenuMaxHeightFactor, // Increased menu height
                      items: _years.map((year) {
                        return DropdownMenuItem<String>(
                          value: year,
                          child: Text(year, style: TextStyle(fontSize: screenWidth * dropdownFontSizeFactor)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedYear = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: screenHeight * sizedBoxHeightFactor * 1.5,
              ),
              Padding( // Added Padding here for spacing before the first card
                padding: EdgeInsets.only(top: screenHeight * cardMarginFactor),
                child: SizedBox(
                  height: screenWidth * cardListHeightFactor,
                  width: screenWidth / 1,
                  child: StreamBuilder<List<AttendanceModel>>(
                    stream: _attendanceStream(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        final attendance = snapshot.data!;
                        if (attendance.isEmpty) {
                          return const Center(child: Text('No Attendance found for the selected month and year'));
                        }
                        return ListView.builder(
                          itemCount: attendance.length,
                          itemBuilder: (context, index) {
                            return
                              GestureDetector(
                                  onTap: () {
                                    _showAttendanceOptionsDialog(context, attendance[index].date!);
                                  },
                                  child: Container(
                                    margin: EdgeInsets.only(
                                        top: index > 0 ? screenHeight * cardMarginFactor : 0, left: screenWidth * cardMarginFactor, right: screenWidth * cardMarginFactor),
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black26,
                                          blurRadius: 10,
                                          offset: Offset(2, 2),
                                        )
                                      ],
                                      borderRadius:
                                      BorderRadius.all(Radius.circular(20)),
                                    ),
                                    child: Column(
                                        children:[
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.start,
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: [
                                              Container(
                                                margin: const EdgeInsets.only(),
                                                padding: EdgeInsets.all(screenWidth * cardPaddingFactor),
                                                width: screenWidth * containerWidthFactor,
                                                decoration: const BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      Colors.deepOrange,
                                                      Colors.deepOrange,
                                                    ],
                                                    begin: Alignment.topCenter,
                                                    end: Alignment.bottomCenter,
                                                  ),
                                                  borderRadius: BorderRadius.only(
                                                    topLeft: Radius.circular(24),
                                                    topRight: Radius.circular(24),
                                                  ),
                                                ),
                                                child: Column(
                                                    mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                    crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                    children: [
                                                      SizedBox(
                                                        height: screenHeight * sizedBoxHeightFactor,
                                                      ),
                                                      Text(
                                                        attendance[index].date.toString(),
                                                        style: TextStyle(
                                                            fontFamily: "NexaBold",
                                                            fontSize: screenWidth * fontSizeFactor * 1.0,
                                                            color: Colors.white,
                                                            fontWeight:FontWeight.bold
                                                        ),
                                                      ),
                                                      SizedBox(
                                                        height: screenHeight * sizedBoxHeightFactor,
                                                      ),
                                                      Text(
                                                        attendance[index].offDay == true
                                                            ? "DayOff: ${attendance[index].durationWorked}"
                                                            : "Hour : ${attendance[index].durationWorked}",
                                                        style: TextStyle(
                                                            fontFamily: "NexaBold",
                                                            fontSize:  screenWidth * fontSizeFactor * 0.9,
                                                            color: Colors.white,
                                                            fontWeight:FontWeight.bold
                                                        ),
                                                      ),
                                                      SizedBox(
                                                        height: screenHeight * sizedBoxHeightFactor,
                                                      ),
                                                      Text(
                                                        attendance[index]
                                                            .isSynced
                                                            .toString() ==
                                                            "true"
                                                            ? "Synced"
                                                            : "Not Synced",
                                                        style: TextStyle(
                                                          fontFamily: "NexaBold",
                                                          fontSize: screenWidth * fontSizeFactor * 1.0,
                                                          color: attendance[index]
                                                              .isSynced
                                                              .toString() ==
                                                              "true"
                                                              ? const Color.fromARGB(
                                                              255, 6, 202, 12)
                                                              : const Color.fromARGB(
                                                              255, 252, 252, 252),
                                                        ),
                                                      ),
                                                      SizedBox(height: screenHeight * sizedBoxHeightFactor),
                                                      IconButton(
                                                        icon: Icon(Icons.refresh, color: Colors.white, size: screenWidth * iconSizeFactor,),
                                                        onPressed: () {
                                                          syncCompleteData(attendance[index].date!);
                                                        },
                                                      ),

                                                    ]),
                                              ),
                                              SizedBox(
                                                width: screenWidth * 0.27,
                                                child: Column(
                                                  mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                                  crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      "Clock In",
                                                      style: TextStyle(
                                                          fontFamily: "NexaLight",
                                                          fontSize: screenWidth * fontSizeFactor * 1.0,
                                                          color: attendance[index]
                                                              .clockIn
                                                              .toString() ==
                                                              "--/--"
                                                              ? Colors.red
                                                              : Colors.black54),
                                                    ),
                                                    Text(
                                                      attendance[index]
                                                          .clockIn
                                                          .toString(),
                                                      style: TextStyle(
                                                          fontFamily: "NexaBold",
                                                          fontSize: screenWidth * fontSizeFactor * 1.0,
                                                          color: attendance[index]
                                                              .clockIn
                                                              .toString() ==
                                                              "--/--"
                                                              ? Colors.red
                                                              : Colors.black),
                                                    ),
                                                    SizedBox(
                                                      height: screenHeight * sizedBoxHeightFactor,
                                                    ),
                                                    Text(
                                                      "Lat:${attendance[index].clockInLatitude.toString()}",
                                                      style: TextStyle(
                                                          fontFamily: "NexaBold",
                                                          fontSize: screenWidth * fontSizeFactor,
                                                          color: attendance[index]
                                                              .clockInLatitude
                                                              .toString() ==
                                                              "0.0"
                                                              ? Colors.red
                                                              : Colors.black54),
                                                    ),
                                                    Text(
                                                      "Long:${attendance[index].clockInLongitude.toString()}",
                                                      style: TextStyle(
                                                          fontFamily: "NexaBold",
                                                          fontSize: screenWidth * fontSizeFactor,
                                                          color: attendance[index]
                                                              .clockInLongitude
                                                              .toString() ==
                                                              "0.0"
                                                              ? Colors.red
                                                              : Colors.black54),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              SizedBox(
                                                width: screenWidth * 0.28,
                                                child: Column(
                                                  mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                                  crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      "Clock Out",
                                                      style: TextStyle(
                                                          fontFamily: "NexaLight",
                                                          fontSize: screenWidth * fontSizeFactor * 1.0,
                                                          color: attendance[index]
                                                              .clockOut
                                                              .toString() ==
                                                              "--/--"
                                                              ? Colors.red
                                                              : Colors.black54),
                                                    ),
                                                    Text(
                                                      attendance[index]
                                                          .clockOut
                                                          .toString(),
                                                      style: TextStyle(
                                                          fontFamily: "NexaBold",
                                                          fontSize: screenWidth * fontSizeFactor * 1.0,
                                                          color: attendance[index]
                                                              .clockOut
                                                              .toString() ==
                                                              "--/--"
                                                              ? Colors.red
                                                              : Colors.black),
                                                    ),
                                                    SizedBox(
                                                      height: screenHeight * sizedBoxHeightFactor,
                                                    ),
                                                    Text(
                                                      "Lat:${attendance[index].clockOutLatitude.toString()}",
                                                      style: TextStyle(
                                                          fontFamily: "NexaBold",
                                                          fontSize: screenWidth * fontSizeFactor,
                                                          color: attendance[index]
                                                              .clockOutLatitude
                                                              .toString() ==
                                                              "0.0"
                                                              ? Colors.red
                                                              : Colors.black54),
                                                    ),
                                                    Text(
                                                      "Long:${attendance[index].clockOutLongitude.toString()}",
                                                      style: TextStyle(
                                                          fontFamily: "NexaBold",
                                                          fontSize: screenWidth * fontSizeFactor,
                                                          color: attendance[index]
                                                              .clockOutLongitude
                                                              .toString() ==
                                                              "0.0"
                                                              ? Colors.red
                                                              : Colors.black54),
                                                    )
                                                  ],
                                                ),
                                              )
                                            ],
                                          ),
                                          Container(
                                              width: screenWidth * 1,
                                              decoration: const BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    Colors.deepOrange,
                                                    Colors.black,
                                                  ],

                                                  begin: Alignment.centerRight,
                                                  end: Alignment.centerLeft,
                                                ),
                                                borderRadius: BorderRadius.only(
                                                  bottomLeft: Radius.circular(24),
                                                  bottomRight: Radius.circular(24),
                                                ),
                                              ),
                                              padding: EdgeInsets.fromLTRB(screenWidth * cardMarginFactor * 2, screenHeight * cardMarginFactor / 4, screenWidth * cardMarginFactor * 2, screenHeight * cardMarginFactor / 8),
                                              child: Column(
                                                  children:[

                                                    Text(
                                                      "Clock-In Location: ${attendance[index].clockInLocation.toString()}",
                                                      style: TextStyle(
                                                          fontFamily: "NexaBold",
                                                          fontSize:  screenWidth * fontSizeFactor,
                                                          color: Colors.white,
                                                          fontWeight:FontWeight.bold
                                                      ),
                                                    ),
                                                    SizedBox(height:screenHeight * sizedBoxHeightFactor / 2),
                                                    Text(
                                                      "Clock-Out Location: ${attendance[index].clockOutLocation.toString()}",
                                                      style: TextStyle(
                                                          fontFamily: "NexaBold",
                                                          fontSize:  screenWidth * fontSizeFactor,
                                                          color: Colors.white,
                                                          fontWeight:FontWeight.bold
                                                      ),
                                                    ),
                                                    SizedBox(height:screenHeight * sizedBoxHeightFactor / 2),
                                                    Text(
                                                      "Comments: ${attendance[index].comments.toString()}",
                                                      style: TextStyle(
                                                          fontFamily: "NexaBold",
                                                          fontSize:  screenWidth * fontSizeFactor,
                                                          color: Colors.white,
                                                          fontWeight:FontWeight.bold
                                                      ),
                                                    ),
                                                  ]
                                              )

                                          ),
                                        ]

                                    ),

                                  )
                              );
                          },
                        );
                      } else if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      } else {
                        return const Center(child: CircularProgressIndicator());
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _showAttendanceOptionsDialog(BuildContext context, String date) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Delete Attendance"),
          content: const Text("Do you want to delete this attendance?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showDeleteConfirmationDialog(context, date);
              },
              child: const Text("Delete"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("Cancel"),
            ),
          ],
        );
      },
    );
  }


  _showDeleteConfirmationDialog(BuildContext context, String date) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirm Delete"),
          content: const Text("Are you sure you want to delete this attendance? This action cannot be undone."),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                Navigator.of(context).pop();

                try {
                  await FirebaseFirestore.instance
                      .collection("Staff")
                      .doc(firebaseAuthId)
                      .collection("Record")
                      .doc(date)
                      .delete();

                  Fluttertoast.showToast(
                    msg: "Attendance Deleted",
                    toastLength: Toast.LENGTH_LONG,
                    backgroundColor: Colors.black54,
                    gravity: ToastGravity.BOTTOM,
                    timeInSecForIosWeb: 1,
                    textColor: Colors.white,
                    fontSize: 16.0,
                  );
                } catch (e) {
                  Fluttertoast.showToast(
                    msg: "Error deleting attendance: ${e.toString()}",
                    toastLength: Toast.LENGTH_LONG,
                    backgroundColor: Colors.red,
                    timeInSecForIosWeb: 1,
                    textColor: Colors.white,
                    fontSize: 16.0,
                  );
                }
              },
              child: const Text("Yes"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("No"),
            ),
          ],
        );
      },
    );
  }


  syncCompleteData(String date) async {
    if (firebaseAuthId == null) {
      Fluttertoast.showToast(
        msg: "User ID not found. Please logout and login again.",
        toastLength: Toast.LENGTH_SHORT,
        backgroundColor: Colors.red,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      return;
    }

    try {
      DocumentSnapshot staffDoc = await FirebaseFirestore.instance
          .collection("Staff")
          .doc(firebaseAuthId)
          .get();

      if (!staffDoc.exists) {
        Fluttertoast.showToast(
          msg: "Staff document not found in Firestore.",
          toastLength: Toast.LENGTH_SHORT,
          backgroundColor: Colors.red,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          textColor: Colors.white,
          fontSize: 16.0,
        );
        return;
      }

      AttendanceModel? attendanceData;
      DocumentSnapshot attendanceDoc = await FirebaseFirestore.instance
          .collection("Staff")
          .doc(firebaseAuthId)
          .collection("Record")
          .doc(date)
          .get();

      if (attendanceDoc.exists) {
        attendanceData = AttendanceModel.fromFirestore(attendanceDoc.data() as Map<String, dynamic>, attendanceDoc.id);
      } else {
        Fluttertoast.showToast(
          msg: "Attendance document not found for date: $date",
          toastLength: Toast.LENGTH_SHORT,
          backgroundColor: Colors.red,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          textColor: Colors.white,
          fontSize: 16.0,
        );
        return;
      }


      await FirebaseFirestore.instance
          .collection("Staff")
          .doc(firebaseAuthId)
          .collection("Record")
          .doc(date)
          .update({
        'isSynced': true,
      }).then((value) {
        Fluttertoast.showToast(
          msg: "Re-syncing Completed...",
          toastLength: Toast.LENGTH_SHORT,
          backgroundColor: Colors.black54,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          textColor: Colors.white,
          fontSize: 16.0,
        );
        setState(() {});
      }).catchError((error) {
        Fluttertoast.showToast(
          msg: "Re-sync Error: ${error.toString()}",
          toastLength: Toast.LENGTH_SHORT,
          backgroundColor: Colors.red,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      });

    } catch (e) {
      log("Re-sync Error: ${e.toString()}");
      Fluttertoast.showToast(
        msg: "Re-sync Error: ${e.toString()}",
        toastLength: Toast.LENGTH_SHORT,
        backgroundColor: Colors.red,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }
}


class AttendanceModel {
  String? clockIn;
  String? clockOut;
  String? clockInLocation;
  String? clockOutLocation;
  String? date;
  bool? isSynced;
  double? clockInLatitude;
  double? clockInLongitude;
  double? clockOutLatitude;
  double? clockOutLongitude;
  bool? voided;
  bool? isUpdated;
  double? noOfHours;
  String? month;
  String? durationWorked;
  bool? offDay;
  String? comments;


  AttendanceModel({
    this.clockIn,
    this.clockOut,
    this.clockInLocation,
    this.clockOutLocation,
    this.date,
    this.isSynced,
    this.clockInLatitude,
    this.clockInLongitude,
    this.clockOutLatitude,
    this.clockOutLongitude,
    this.voided,
    this.isUpdated,
    this.noOfHours,
    this.month,
    this.durationWorked,
    this.offDay,
    this.comments
  });

  factory AttendanceModel.fromFirestore(Map<String, dynamic> data, String id) {
    return AttendanceModel(
      clockIn: data['clockIn'] ?? '--/--',
      clockOut: data['clockOut'] ?? '--/--',
      clockInLocation: data['clockInLocation'] ?? 'No Location Recorded',
      clockOutLocation: data['clockOutLocation'] ?? 'No Location Recorded',
      date: id,
      isSynced: data['isSynced'] ?? false,
      clockInLatitude: (data['clockInLatitude'] ?? 0.0).toDouble(),
      clockInLongitude: (data['clockInLongitude'] ?? 0.0).toDouble(),
      clockOutLatitude: (data['clockOutLatitude'] ?? 0.0).toDouble(),
      clockOutLongitude: (data['clockOutLongitude'] ?? 0.0).toDouble(),
      voided: data['voided'] ?? false,
      isUpdated: data['isUpdated'] ?? false,
      noOfHours: (data['noOfHours'] ?? 0.0).toDouble(),
      month: data['month'] ?? '',
      durationWorked: data['durationWorked'] ?? '0 hours: 0 minutes',
      offDay: data['offDay'] ?? false,
      comments: data['comments'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'clockIn': clockIn,
      'clockOut': clockOut,
      'clockInLocation': clockInLocation,
      'clockOutLocation': clockOutLocation,
      'isSynced': isSynced,
      'clockInLatitude': clockInLatitude,
      'clockInLongitude': clockInLongitude,
      'clockOutLatitude': clockOutLatitude,
      'clockOutLongitude': clockOutLongitude,
      'voided': voided,
      'isUpdated': isUpdated,
      'noOfHours': noOfHours,
      'month': month,
      'durationWorked': durationWorked,
      'offDay': offDay,
      'comments': comments,
    };
  }
}