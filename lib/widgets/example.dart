// // import 'dart:math';
// //
// // import 'package:action_slider/action_slider.dart';
// // import 'package:flutter/material.dart';
// //
// // class MyExampleSliderPage extends StatefulWidget {
// //   const MyExampleSliderPage({Key? key, required this.title}) : super(key: key);
// //
// //   final String title;
// //
// //   @override
// //   State<MyExampleSliderPage> createState() => _MyExampleSliderPageState();
// // }
// //
// // class _MyExampleSliderPageState extends State<MyExampleSliderPage> {
// //   final _controller = ActionSliderController();
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     final theme = Theme.of(context);
// //
// //     return Scaffold(
// //       appBar: AppBar(
// //         title: Text(widget.title),
// //       ),
// //       body: Center(
// //         child: Column(
// //           mainAxisAlignment: MainAxisAlignment.center,
// //           children: <Widget>[
// //             DefaultTextStyle.merge(
// //               style: const TextStyle(color: Colors.white),
// //               child: ActionSlider.dual(
// //                 backgroundBorderRadius: BorderRadius.circular(10.0),
// //                 foregroundBorderRadius: BorderRadius.circular(10.0),
// //                 width: 300.0,
// //                 backgroundColor: Colors.black,
// //                 startChild: const Text('Start'),
// //                 endChild: const Text('End'),
// //                 icon: Padding(
// //                   padding: const EdgeInsets.only(right: 2.0),
// //                   child: Transform.rotate(
// //                       angle: 0.5 * pi,
// //                       child: const Icon(Icons.unfold_more_rounded, size: 28.0)),
// //                 ),
// //                 startAction: (controller) async {
// //                   controller.loading(); //starts loading animation
// //                   await Future.delayed(const Duration(seconds: 3));
// //                   controller.success(); //starts success animation
// //                   await Future.delayed(const Duration(seconds: 1));
// //                   controller.reset(); //resets the slider
// //                 },
// //                 endAction: (controller) async {
// //                   controller.loading(); //starts loading animation
// //                   await Future.delayed(const Duration(seconds: 3));
// //                   controller.success(); //starts success animation
// //                   await Future.delayed(const Duration(seconds: 1));
// //                   controller.reset(); //resets the slider
// //                 },
// //               ),
// //             ),
// //             const SizedBox(height: 24.0),
// //             ActionSlider.standard(
// //               sliderBehavior: SliderBehavior.stretch,
// //               width: 300.0,
// //               backgroundColor: Colors.white,
// //               toggleColor: Colors.lightGreenAccent,
// //               action: (controller) async {
// //                 controller.loading(); //starts loading animation
// //                 await Future.delayed(const Duration(seconds: 3));
// //                 controller.success(); //starts success animation
// //                 await Future.delayed(const Duration(seconds: 1));
// //                 controller.reset(); //resets the slider
// //               },
// //               child: const Text('Slide to confirm'),
// //             ),
// //             const SizedBox(height: 24.0),
// //             ActionSlider.standard(
// //               width: 300.0,
// //               action: (controller) async {
// //                 controller.loading(); //starts loading animation
// //                 await Future.delayed(const Duration(seconds: 3));
// //                 controller.success(); //starts success animation
// //                 await Future.delayed(const Duration(seconds: 1));
// //                 controller.reset(); //resets the slider
// //               },
// //               direction: TextDirection.rtl,
// //               child: const Text('Slide to confirm'),
// //             ),
// //             const SizedBox(height: 24.0),
// //             ActionSlider.standard(
// //               rolling: true,
// //               width: 300.0,
// //               backgroundColor: Colors.black,
// //               reverseSlideAnimationCurve: Curves.easeInOut,
// //               reverseSlideAnimationDuration: const Duration(milliseconds: 500),
// //               toggleColor: Colors.purpleAccent,
// //               icon: const Icon(Icons.add),
// //               action: (controller) async {
// //                 controller.loading(); //starts loading animation
// //                 await Future.delayed(const Duration(seconds: 3));
// //                 controller.success(); //starts success animation
// //                 await Future.delayed(const Duration(seconds: 1));
// //                 controller.reset(); //resets the slider
// //               },
// //               child: const Text('Rolling slider',
// //                   style: TextStyle(color: Colors.white)),
// //             ),
// //             const SizedBox(height: 24.0),
// //             ActionSlider.standard(
// //               sliderBehavior: SliderBehavior.stretch,
// //               rolling: true,
// //               width: 300.0,
// //               backgroundColor: Colors.white,
// //               toggleColor: Colors.amber,
// //               iconAlignment: Alignment.centerRight,
// //               loadingIcon: SizedBox(
// //                   width: 55,
// //                   child: Center(
// //                       child: SizedBox(
// //                         width: 24.0,
// //                         height: 24.0,
// //                         child: CircularProgressIndicator(
// //                             strokeWidth: 2.0, color: theme.iconTheme.color),
// //                       ))),
// //               successIcon: const SizedBox(
// //                   width: 55, child: Center(child: Icon(Icons.check_rounded))),
// //               icon: const SizedBox(
// //                   width: 55, child: Center(child: Icon(Icons.refresh_rounded))),
// //               action: (controller) async {
// //                 controller.loading(); //starts loading animation
// //                 await Future.delayed(const Duration(seconds: 3));
// //                 controller.success(); //starts success animation
// //                 await Future.delayed(const Duration(seconds: 1));
// //                 controller.reset(); //resets the slider
// //               },
// //               child: const Text('Swipe right'),
// //             ),
// //             const SizedBox(height: 24.0),
// //             ActionSlider.custom(
// //               sliderBehavior: SliderBehavior.stretch,
// //               width: 300.0,
// //               controller: _controller,
// //               height: 60.0,
// //               toggleWidth: 60.0,
// //               toggleMargin: EdgeInsets.zero,
// //               backgroundColor: Colors.green,
// //               foregroundChild: DecoratedBox(
// //                   decoration: BoxDecoration(
// //                       color: Colors.black,
// //                       borderRadius: BorderRadius.circular(5)),
// //                   child: const Icon(Icons.check_rounded, color: Colors.white)),
// //               foregroundBuilder: (context, state, child) => child!,
// //               outerBackgroundBuilder: (context, state, child) => Card(
// //                 margin: EdgeInsets.zero,
// //                 color: Color.lerp(Colors.red, Colors.green, state.position),
// //                 child: Center(
// //                     child: Text(state.position.toStringAsFixed(2),
// //                         style: theme.textTheme.titleMedium)),
// //               ),
// //               backgroundBorderRadius: BorderRadius.circular(5.0),
// //               action: (controller) async {
// //                 controller.loading(); //starts loading animation
// //                 await Future.delayed(const Duration(seconds: 3));
// //                 controller.success(); //starts success animation
// //                 await Future.delayed(const Duration(seconds: 1));
// //                 controller.reset(); //resets the slider
// //               },
// //             ),
// //             const SizedBox(height: 24.0),
// //             ActionSlider.custom(
// //               toggleMargin: EdgeInsets.zero,
// //               width: 300.0,
// //               controller: _controller,
// //               toggleWidth: 60.0,
// //               height: 60.0,
// //               backgroundColor: Colors.green,
// //               foregroundChild: Container(
// //                   decoration: const BoxDecoration(
// //                     color: Colors.black,
// //                     borderRadius: BorderRadius.all(Radius.circular(30.0)),
// //                   ),
// //                   child: const Icon(Icons.check_rounded, color: Colors.white)),
// //               foregroundBuilder: (context, state, child) => child!,
// //               backgroundChild: Center(
// //                 child: Text('Highly Customizable :)',
// //                     style: theme.textTheme.titleMedium),
// //               ),
// //               backgroundBuilder: (context, state, child) => ClipRect(
// //                   child: OverflowBox(
// //                       maxWidth: state.standardSize.width,
// //                       maxHeight: state.toggleSize.height,
// //                       minWidth: state.standardSize.width,
// //                       minHeight: state.toggleSize.height,
// //                       child: child!)),
// //               backgroundBorderRadius: BorderRadius.circular(5.0),
// //               action: (controller) async {
// //                 controller.loading(); //starts loading animation
// //                 await Future.delayed(const Duration(seconds: 3));
// //                 controller.success(); //starts success animation
// //                 await Future.delayed(const Duration(seconds: 1));
// //                 controller.reset(); //resets the slider
// //               },
// //             ),
// //           ],
// //         ),
// //       ),
// //     );
// //   }
// // }
//
// import 'dart:developer';
//
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
//
// import '../../model/attendancemodel.dart';
// import '../../services/isar_service.dart';
//
// class TimesheetScreen extends StatefulWidget {
//   const TimesheetScreen({super.key});
//
//   @override
//   _TimesheetScreenState createState() => _TimesheetScreenState();
// }
//
// class _TimesheetScreenState extends State<TimesheetScreen> {
//   late DateTime startDate;
//   late DateTime endDate;
//   List<DateTime> daysInRange = [];
//   TextEditingController facilitySupervisorController = TextEditingController();
//   TextEditingController caritasSupervisorController = TextEditingController();
//   late int selectedMonth;
//   String formattedDate = DateFormat('MMMM dd, yyyy').format(DateTime.now());
//   List<AttendanceModel> attendanceData = [];
//
//   List<String?> projectNames = [];
//   String? selectedProjectName;
//
//   List<String> outOfOfficeCategories = [
//     'Absent', 'Annual leave', 'Holiday', 'Other Leaves', 'Security Crisis',
//     'Sick leave', 'Remote working', 'Sit at home', 'Trainings', 'Travel'
//   ];
//
//   @override
//   void initState() {
//     super.initState();
//     selectedMonth = DateTime.now().month - 1;
//     initializeDateRange(selectedMonth);
//     _loadProjectNames();
//     _loadAttendanceData();
//   }
//
//   Future<void> _loadAttendanceData() async {
//     attendanceData = await IsarService().getAllAttendance();
//     setState(() {});
//   }
//
//   String _getDurationForDate(DateTime date) {
//     final dateAttendances = attendanceData.where((attendance) {
//       DateTime? attendanceDate;
//       try {
//         attendanceDate = DateTime.parse(attendance.date ?? '');
//       } catch (e) {
//         log("Error parsing date: $e");
//         return false;
//       }
//
//       return attendanceDate.year == date.year &&
//           attendanceDate.month == date.month &&
//           attendanceDate.day == date.day ;
//       // &&
//       // attendance.projectName == selectedProjectName;
//     }).toList();
//
//     if (dateAttendances.isNotEmpty) {
//       final totalHours = dateAttendances.fold<double>(0.0, (prev, attendance) =>
//       prev + (double.tryParse(attendance.noOfHours?.toString() ?? '') ?? 0.0));
//       return '${totalHours.toStringAsFixed(1)} hrs';
//     }
//     return '0 hrs';
//   }
//
//   String _getOutOfOfficeData(DateTime date, String category) {
//     // Implement your logic to fetch out-of-office data from Isar based on date and category
//     // This is a placeholder, replace with your actual Isar query:
//     final outOfOfficeData = attendanceData.where((attendance) {
//       DateTime? attendanceDate;
//       try {
//         attendanceDate = DateTime.parse(attendance.date ?? '');
//       }
//       catch (e)
//       {
//         log("Error parsing date");
//         return false;
//       }
//       return attendance.durationWorked == category &&
//           attendanceDate.year == date.year &&
//           attendanceDate.month == date.month &&
//           attendanceDate.day == date.day
//       //&&
//       // attendance.projectName == selectedProjectName
//           ;
//     }).toList();
//
//     if (outOfOfficeData.isNotEmpty)
//     {
//       return outOfOfficeData[0].noOfHours?.toString() ?? '0 hrs';
//     }
//     return "0 hrs";  //  Placeholder – replace with your logic
//   }
//
//
//
//   double _calculateTotalOutOfOfficeHours(String category) {    //takes category as argument
//     double totalHours = 0.0;
//     for (var date in daysInRange) {
//       // Add logic to calculate total hours. Ensure to check if this is out-of-office
//       totalHours += double.tryParse(_getOutOfOfficeData(date, category)) ?? 0.0; //add out of office type as an argument.
//     }
//     return totalHours;
//   }
//   double calculatePercentageOutOfOffice(String category)
//   {
//     double totalHoursCategory = _calculateTotalOutOfOfficeHours(category); // Calculate the total out of office hours for a category
//     double workingDays = daysInRange.where((date) => !isWeekend(date)).length.toDouble();
//     double maxHours = workingDays * 8;
//
//     return totalHoursCategory > 0 && maxHours > 0 ?  (totalHoursCategory / maxHours * 100): 0.0; // Calculate percentage
//
//   }
//
//
//   Future<void> _loadProjectNames() async {
//     projectNames = await IsarService().getProjectFromIsar();
//     if (projectNames.isNotEmpty) {
//       setState(() {
//         selectedProjectName = projectNames[0];
//       });
//     }
//   }
//
//   void initializeDateRange(int month) {
//     DateTime now = DateTime.now();
//     DateTime selectedMonthDate = DateTime(now.year, month + 1);
//     startDate = DateTime(selectedMonthDate.year, selectedMonthDate.month - 1, 19);
//     endDate = DateTime(selectedMonthDate.year, selectedMonthDate.month, 20);
//
//
//     daysInRange = [];
//     for (var date = startDate; date.isBefore(endDate) || date.isAtSameMomentAs(endDate); date = date.add(const Duration(days: 1))) {
//       daysInRange.add(date);
//     }
//   }
//
//   List<String> facilitySupervisors = ['Supervisor A', 'Supervisor B', 'Supervisor C'];
//   List<String> caritasSupervisors = ['Caritas A', 'Caritas B', 'Caritas C'];
//
//   bool isWeekend(DateTime date) => date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
//
//   int calculateTotalHours() => daysInRange.where(isWeekend).length * 8;
//
//
//
//   double calculatePercentageWorked() {
//     int workingDays = daysInRange.where((date) => !isWeekend(date)).length;
//     return (calculateTotalHours() / (workingDays * 8)) * 100;
//   }
//
//   Widget _buildDataRow({
//     required String label,
//     required Widget Function(DateTime date) cellBuilder,
//     required double totalHours, // Add totalHours parameter
//     required double percentage, // Add percentage parameter
//   }) {
//     return Row(
//       children: [
//         Container(
//           width: 150,
//           alignment: Alignment.center,
//           padding: const EdgeInsets.all(8.0),
//           color: Colors.white,
//           child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
//         ),
//         ...daysInRange.map((date) {
//           return cellBuilder(date); // Use the cellBuilder to create cells
//         }).toList(),
//         //Total hours Container
//         Container(
//           width: 100,
//           alignment: Alignment.center,
//           padding: const EdgeInsets.all(8.0),
//           color: Colors.white,
//           child: Text('$totalHours hrs',
//               style:
//               const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
//         ),
//         //Percentage Container
//         Container(
//           width: 100,
//           alignment: Alignment.center,
//           padding: const EdgeInsets.all(8.0),
//           color: Colors.white,
//           child: Text('${percentage.toStringAsFixed(2)}%',
//               style:
//               const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
//         ),
//       ],
//     );
//   }
//
//
//
//   Widget _buildDateCell(DateTime date, String text) {
//     bool weekend = isWeekend(date);
//     return Container(
//       width: 100,
//       decoration: BoxDecoration(
//         color: weekend ? Colors.grey.shade300 : Colors.white,
//         border: Border.all(color: Colors.black12),
//       ),
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           if (!weekend) Text(text, style: const TextStyle(color: Colors.blueAccent)),
//         ],
//       ),
//     );
//   }
//
//
//   @override
//   Widget build(BuildContext context) {
//     int totalWorkHours = calculateTotalHours();
//     double percentageWorked = calculatePercentageWorked();
//
//     return Scaffold(
//       appBar: AppBar(title: const Text('Timesheet')),
//       body: SingleChildScrollView(
//         child: Column(children: [
//           Padding(
//             padding: const EdgeInsets.all(8.0),
//             child: Row(children: [
//               const Text('Select Month:',
//                   style: TextStyle(fontWeight: FontWeight.bold)),
//               const SizedBox(width: 10),
//               DropdownButton<int>(
//                   value: selectedMonth,
//                   items: List.generate(12, (index) {
//                     DateTime monthDate = DateTime(2024, index + 1);
//                     return DropdownMenuItem<int>(
//                         value: index,
//                         child: Text(DateFormat.MMMM().format(monthDate)));
//                   }),
//                   onChanged: (int? newValue) {
//                     if (newValue != null) {
//                       setState(() {
//                         selectedMonth = newValue;
//                         initializeDateRange(selectedMonth);
//                       });
//                     }
//                   })
//             ]),
//           ),
//           SingleChildScrollView(
//             scrollDirection: Axis.horizontal,
//             child: Column(children: [
//               // Project row (header)
//               _buildDataRow(
//                   label: "Project name",
//                   cellBuilder: (date) => _buildDateCell(date, DateFormat("dd MMM").format(date)),
//                   totalHours: calculateTotalHours().toDouble(),
//                   percentage: calculatePercentageWorked()
//
//               ),
//               const Divider(),
//
//
//
//               // Project row (data) with project selection
//               Row(
//                 children: [
//                   Container(
//                     width: 150, // Keep the fixed width if you need it
//                     alignment: Alignment.center,
//                     padding: const EdgeInsets.all(8.0),
//                     color: Colors.white,
//                     child: projectNames.isEmpty
//                         ? const Text('No projects found')
//                         : DropdownButton<String>(
//                       value: selectedProjectName,
//                       isExpanded: true, // This will expand the dropdown to the Container's width
//                       items: projectNames.map((projectName) {
//                         return DropdownMenuItem<String>(
//                           value: projectName,
//                           child: FittedBox( // Use FittedBox to wrap the Text
//                             fit: BoxFit.scaleDown, // Scales down text to fit
//                             alignment: Alignment.centerLeft, // Align text to the left
//                             child: Text(projectName ?? 'No Project Name'),
//                           ),
//                         );
//                       }).toList(),
//                       onChanged: (String? newValue) {
//                         setState(() {
//                           selectedProjectName = newValue;
//                           _loadAttendanceData();
//                         });
//                       },
//                       hint: const Text('Select Project'),
//                     ),
//                   ),
//
//
//
//                   ...daysInRange.map((date) {
//                     return _buildDateCell(date, _getDurationForDate(date));
//                   }).toList(),
//                   Container(
//                     width: 100,
//                     alignment: Alignment.center,
//                     padding: const EdgeInsets.all(8.0),
//                     color: Colors.white,
//                     child: Text('$totalWorkHours hrs',
//                         style: const TextStyle(
//                             color: Colors.green, fontWeight: FontWeight.bold)),
//                   ),
//                   Container(
//                     width: 100,
//                     alignment: Alignment.center,
//                     padding: const EdgeInsets.all(8.0),
//                     color: Colors.white,
//                     child: Text('${percentageWorked.toStringAsFixed(2)}%',
//                         style: const TextStyle(
//                             color: Colors.green, fontWeight: FontWeight.bold)),
//                   ),
//
//                 ],
//               ),
//
//               const Divider(),
//
//
//               // Out-of-office rows (using the _buildDataRow function)
//               ...outOfOfficeCategories.map((category) {
//                 double totalOutOfOfficeHours = _calculateTotalOutOfOfficeHours(category); // Pass category here
//                 return _buildDataRow(
//                   label: category,
//                   cellBuilder: (date) => _buildDateCell(date, _getOutOfOfficeData(date, category)),
//                   totalHours: totalOutOfOfficeHours,
//                   percentage: calculatePercentageOutOfOffice(category),
//
//                 );
//               }).toList(),
//               // ... (Rest of the UI elements - Signature, supervisor info, etc.)
//
//               //Name of staff section
//               Row(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Container(
//                     width: 300,
//                     alignment: Alignment.center,
//                     padding: const EdgeInsets.all(8.0),
//                     color: Colors.grey.shade200,
//                     child: const Column(children: [
//                       Text('Name of Staff',
//                           style: TextStyle(fontWeight: FontWeight.bold)),
//                       SizedBox(height: 20.0),
//                       Text('Emmanuel Vegher',
//                           style: TextStyle(fontWeight: FontWeight.bold))
//                     ]),
//                   ),
//                   const SizedBox(width: 20.0),
//                   Container(
//                     width: 300,
//                     padding: const EdgeInsets.all(8.0),
//                     child: const Column(children: [
//                       Text('Facility Supervisor Name',
//                           style: TextStyle(fontWeight: FontWeight.bold)),
//                       SizedBox(height: 20.0),
//                       Image(
//                           image: AssetImage('assets/signature.png'),
//                           height: 50)
//                     ]),
//                   ),
//                   Container(
//                     width: 300,
//                     padding: const EdgeInsets.all(8.0),
//                     child: Column(children: [
//                       const Text('Date',
//                           style: TextStyle(fontWeight: FontWeight.bold)),
//                       const SizedBox(height: 20.0),
//                       Text(formattedDate,
//                           style: const TextStyle(fontWeight: FontWeight.bold))
//                     ]),
//                   )
//                 ],
//               ),
//               const SizedBox(height: 20.0),
//               //User name section
//               Row(children: [
//                 Container(
//                     width: 150,
//                     alignment: Alignment.center,
//                     padding: const EdgeInsets.all(8.0),
//                     color: Colors.grey.shade200,
//                     child: const Column(children: [
//                       Text('User Name',
//                           style: TextStyle(fontWeight: FontWeight.bold)),
//                       SizedBox(height: 8.0),
//                       Image(
//                           image: AssetImage('assets/signature.png'),
//                           height: 50)
//                     ])),
//                 Container(
//                     width: 150,
//                     padding: const EdgeInsets.all(8.0),
//                     child: Column(children: [
//                       const Text('Facility Supervisor',
//                           style: TextStyle(fontWeight: FontWeight.bold)),
//                       TextField(
//                           controller: facilitySupervisorController,
//                           decoration: const InputDecoration(
//                               border: OutlineInputBorder(),
//                               hintText: 'Enter name')),
//                       DropdownButton<String>(
//                           items: facilitySupervisors
//                               .map((String supervisor) =>
//                               DropdownMenuItem<String>(
//                                   value: supervisor, child: Text(supervisor)))
//                               .toList(),
//                           onChanged: (String? newValue) {
//                             setState(() {
//                               facilitySupervisorController.text = newValue ?? '';
//                             });
//                           },
//                           hint: const Text('Select Supervisor'))
//                     ])),
//                 Container(
//                     width: 150,
//                     padding: const EdgeInsets.all(8.0),
//                     child: Column(children: [
//                       const Text('Caritas Supervisor',
//                           style: TextStyle(fontWeight: FontWeight.bold)),
//                       TextField(
//                           controller: caritasSupervisorController,
//                           decoration: const InputDecoration(
//                               border: OutlineInputBorder(),
//                               hintText: 'Enter name')),
//                       DropdownButton<String>(
//                           items: caritasSupervisors
//                               .map((String supervisor) =>
//                               DropdownMenuItem<String>(
//                                   value: supervisor, child: Text(supervisor)))
//                               .toList(),
//                           onChanged: (String? newValue) {
//                             setState(() {
//                               caritasSupervisorController.text = newValue ?? '';
//                             });
//                           },
//                           hint: const Text('Select Supervisor'))
//                     ]))
//               ])
//             ]),
//           )
//         ]),
//       ),
//     );
//   }
// }