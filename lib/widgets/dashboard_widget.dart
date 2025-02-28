import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

Widget dashBoardWidget(BuildContext context, Function setState) {
  String month = DateFormat("MMMM yyyy").format(DateTime.now());
  List<FlSpot> dataSet = [];
  return ListView(
    children: [
      SizedBox(
        height: MediaQuery.of(context).size.height * 0.025,
      ),
      Stack(
        children: [
          Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 20),
            child: Text(
              month,
              style: TextStyle(
                  color: Colors.brown,
                  fontFamily: "NexaBold",
                  fontSize: MediaQuery.of(context).size.width * (MediaQuery.of(context).size.shortestSide < 600 ? 0.050 : 0.025),
                  fontWeight: FontWeight.bold),
            ),
          ),
          Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: Text(
              "No Attendance for current month",
              style: TextStyle(
                  color: Colors.red,
                  fontFamily: "NexaBold",
                  fontSize: MediaQuery.of(context).size.width * (MediaQuery.of(context).size.shortestSide < 600 ? 0.050 : 0.025),
                  fontWeight: FontWeight.bold),
            ),

            // GestureDetector(
            //   onTap: () async {
            //     final month = await showMonthYearPicker(
            //         context: context,
            //         initialDate: DateTime.now(),
            //         firstDate: DateTime(2022),
            //         lastDate: DateTime(2099),
            //         builder: (context, child) {
            //           return Theme(
            //             data: Theme.of(context).copyWith(
            //               colorScheme: ColorScheme.light(
            //                 primary: Colors.red,
            //                 secondary: Colors.red,
            //                 onSecondary: Colors.white,
            //               ),
            //               textButtonTheme: TextButtonThemeData(
            //                 style: TextButton.styleFrom(
            //                   foregroundColor: Colors.red,
            //                 ),
            //               ),
            //               textTheme: const TextTheme(
            //                 headline4: TextStyle(
            //                   fontFamily: "NexaBold",
            //                 ),
            //                 overline: TextStyle(
            //                   fontFamily: "NexaBold",
            //                 ),
            //                 button: TextStyle(
            //                   fontFamily: "NexaBold",
            //                 ),
            //               ),
            //             ),
            //             child: child!,
            //           );
            //         });

            //     if (month != null) {
            //       setState(() {
            //         dataSet = [];
            //         _month = DateFormat('MMMM yyyy').format(month);
            //       });
            //     }
            //   },
            //   child: Text(
            //     "Pick a Month",
            //     style: TextStyle(
            //         color: Colors.red,
            //         fontFamily: "NexaBold",
            //         fontSize: MediaQuery.of(context).size.width / 18,
            //         fontWeight: FontWeight.bold),
            //   ),
            // ),
          ),
        ],
      ),

      // Next Create card
      Container(
        width: MediaQuery.of(context).size.width * 0.9,
        margin: const EdgeInsets.all(12.0),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.red,
                Colors.black,
              ],
            ),
            borderRadius: BorderRadius.all(
              Radius.circular(24),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
          child: Column(
            children: [
              const Text(
                "Attendance Summary",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22.0,
                  fontWeight: FontWeight.w400,
                  color: Colors.white,
                ),
              ),
              const SizedBox(
                height: 12.0,
              ),
              const Text(
                "Total Hours Worked = ${"0 Hour(s) 0 minute(s)"}",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(
                height: 12.0,
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    cardClockIn("0"),
                    cardClockOut("0"),
                  ],
                ),
              )
            ],
          ),
        ),
      ),

      // dataSet.isEmpty
      //     ? Container(
      //         //height: MediaQuery.of(context).size.width*0.95,//300
      //         padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 20.0),
      //         margin: EdgeInsets.all(12),
      //         decoration: BoxDecoration(
      //           borderRadius: BorderRadius.circular(8.0),
      //           boxShadow: [
      //             BoxShadow(
      //               color: Colors.grey.withOpacity(0.4),
      //               spreadRadius: 5,
      //               blurRadius: 6,
      //               offset: Offset(0, 4),
      //             )
      //           ],
      //           color: Colors.white,
      //         ),
      //         child: Center(
      //             child: Text(
      //           "No values to render chart",
      //           style: TextStyle(
      //             color: Colors.brown,
      //             fontSize: MediaQuery.of(context).size.width * 0.045,
      //           ),
      //         )),
      //       )
      //     :
      Container(
        height: MediaQuery.of(context).size.width * 0.95,
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 20.0),
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8.0),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.4),
              spreadRadius: 5,
              blurRadius: 6,
              offset: const Offset(0, 4),
            ),
          ],
          color: Colors.white,
        ),
        child: LineChart(
          LineChartData(borderData: FlBorderData(show: false), lineBarsData: [
            LineChartBarData(
              // spots: (){
              //   data.add
              // },
              isCurved: false,
              barWidth: 2.5,
              color: const Color.fromARGB(255, 63, 7, 3),
            )
          ]),
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(12.0),
        child: Text(
          "Out-Of-Office History:",
          style: TextStyle(
              fontSize: MediaQuery.of(context).size.width * (MediaQuery.of(context).size.shortestSide < 600 ? 0.050 : 0.025),
              fontWeight: FontWeight.w900,
              color: Colors.brown),
        ),
      ),

      //   SizedBox(
      //     height: MediaQuery.of(context).size.height * 0.30,
      //     child: StreamBuilder<List>(
      //       stream: widget.service.getDaysOffForMonth(_month),
      //       builder: (context, snapshot) {
      //         if (snapshot.hasError) {
      //           return Center(
      //             child: Text("UnExpected Error!"),
      //           );
      //         }
      //         if (snapshot.hasData) {
      //           if (snapshot.data!.isEmpty) {
      //             return Center(
      //               child: Text("No Day Off for the Month"),
      //             );
      //           }

      //           return ListView.builder(
      //             itemCount: snapshot.data!.length,
      //             itemBuilder: (context, index) {
      //               return snapshot.data![index].month == _month
      //                   ? Container(
      //                       margin: EdgeInsets.only(
      //                           top: index > 0 ? 12 : 0, left: 6, right: 6),
      //                       height: 70,
      //                       decoration: const BoxDecoration(
      //                         color: Colors.white,
      //                         boxShadow: [
      //                           BoxShadow(
      //                             color: Colors.black26,
      //                             blurRadius: 10,
      //                             offset: Offset(2, 2),
      //                           )
      //                         ],
      //                         borderRadius: BorderRadius.all(Radius.circular(20)),
      //                       ),
      //                       child: Row(
      //                         mainAxisAlignment: MainAxisAlignment.center,
      //                         crossAxisAlignment: CrossAxisAlignment.center,
      //                         children: [
      //                           Expanded(
      //                             child: Container(
      //                               margin: const EdgeInsets.only(),
      //                               decoration: BoxDecoration(
      //                                 gradient: LinearGradient(
      //                                   colors: [
      //                                     Colors.red,
      //                                     Colors.black,
      //                                   ],
      //                                 ),
      //                                 borderRadius: BorderRadius.all(
      //                                   Radius.circular(24),
      //                                 ),
      //                               ),
      //                               child: Column(
      //                                 mainAxisAlignment: MainAxisAlignment.center,
      //                                 crossAxisAlignment:
      //                                     CrossAxisAlignment.center,
      //                                 children: [
      //                                   Center(
      //                                     // List Date
      //                                     child: Text(
      //                                       snapshot.data![index].date,
      //                                       style: TextStyle(
      //                                         fontFamily: "NexaBold",
      //                                         fontSize: MediaQuery.of(context)
      //                                                 .size
      //                                                 .width /
      //                                             23,
      //                                         color: Colors.white,
      //                                       ),
      //                                     ),
      //                                   ),
      //                                   SizedBox(height: 2),
      //                                   Center(
      //                                     // Reasons For Day Off

      //                                     child: Text(
      //                                       snapshot.data![index].durationWorked,
      //                                       style: TextStyle(
      //                                         fontFamily: "NexaBold",
      //                                         fontSize: MediaQuery.of(context)
      //                                                 .size
      //                                                 .width /
      //                                             24,
      //                                         color: Colors.white,
      //                                       ),
      //                                     ),
      //                                   ),
      //                                 ],
      //                               ),
      //                             ),
      //                           ),
      //                           //Clock in
      //                           Expanded(
      //                               child: Column(
      //                             mainAxisAlignment: MainAxisAlignment.center,
      //                             crossAxisAlignment: CrossAxisAlignment.center,
      //                             children: [
      //                               Text(
      //                                 "Start Time",
      //                                 style: TextStyle(
      //                                     fontFamily: "NexaLight",
      //                                     fontSize:
      //                                         MediaQuery.of(context).size.width /
      //                                             22,
      //                                     color: Colors.black54),
      //                               ),
      //                               Text(
      //                                 snapshot.data![index].clockIn,
      //                                 style: TextStyle(
      //                                   fontFamily: "NexaBold",
      //                                   fontSize:
      //                                       MediaQuery.of(context).size.width /
      //                                           20,
      //                                 ),
      //                               ),
      //                             ],
      //                           )),
      //                           //Clock Out
      //                           Expanded(
      //                               child: Column(
      //                             mainAxisAlignment: MainAxisAlignment.center,
      //                             crossAxisAlignment: CrossAxisAlignment.center,
      //                             children: [
      //                               Text(
      //                                 "End Time",
      //                                 style: TextStyle(
      //                                     fontFamily: "NexaLight",
      //                                     fontSize:
      //                                         MediaQuery.of(context).size.width /
      //                                             22,
      //                                     color: Colors.black54),
      //                               ),
      //                               Text(
      //                                 snapshot.data![index].clockOut,
      //                                 style: TextStyle(
      //                                   fontFamily: "NexaBold",
      //                                   fontSize:
      //                                       MediaQuery.of(context).size.width /
      //                                           20,
      //                                 ),
      //                               )
      //                             ],
      //                           )),
      //                         ],
      //                       ),
      //                     )
      //                   : Container(
      //                       //If the Location is not empty,it displays the container widget
      //                       width: MediaQuery.of(context).size.width * 0.9,
      //                       //height: MediaQuery.of(context).size.height * 100,
      //                       margin: const EdgeInsets.all(12.0),
      //                       child: Container(
      //                         decoration: const BoxDecoration(
      //                           gradient: LinearGradient(
      //                             colors: [
      //                               Colors.red,
      //                               Colors.black,
      //                             ],
      //                           ),
      //                           borderRadius: BorderRadius.all(
      //                             Radius.circular(24),
      //                           ),
      //                         ),
      //                         padding: const EdgeInsets.symmetric(
      //                             vertical: 12.0, horizontal: 8.0),
      //                         child: Column(
      //                           children: [
      //                             Text(
      //                               "No Day Off For Current Month",
      //                               textAlign: TextAlign.center,
      //                               style: TextStyle(
      //                                   fontSize:
      //                                       MediaQuery.of(context).size.width /
      //                                           20,
      //                                   fontFamily: "NexaBold",
      //                                   color: Colors.white,
      //                                   fontWeight: FontWeight.bold),
      //                             ),
      //                           ],
      //                         ),
      //                       ),
      //                     );
      //             },
      //           );
      //         } else {
      //           return Center(child: Text("No Day Off Recorded !!"));
      //         }
      //       },
      //     ),
      //   )
      //
    ],
    // -----------------------------------------
  );
}

List getPlotPoints() {
  var dataSet = [];
  dataSet.add(
    FlSpot(
      (int.parse("0")).toDouble(),
      (int.parse("0")).toDouble(),
    ),
  );
  return dataSet;

  // for (var specificMonthAttend in entireData) {
  //   dataSet.add(
  //     FlSpot(
  //       (int.parse(specificMonthAttend.date.split("-")[0])).toDouble(),
  //       (specificMonthAttend.noOfHours as double).toDouble(),
  //     ),
  //   );
  // }
}

Widget cardClockIn(String value) {
  return Row(
    children: [
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.0),
        ),
        padding: const EdgeInsets.all(6.0),
        margin: const EdgeInsets.only(right: 8.0),
        child: Icon(
          Icons.arrow_downward,
          size: 28.0,
          color: Colors.green[700],
        ),
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Clock-In Total",
            style: TextStyle(fontSize: 14.0, color: Colors.white),
          ),
          Text(
            value,
            style: const TextStyle(
                fontSize: 20.0,
                fontWeight: FontWeight.w700,
                color: Colors.white),
          )
        ],
      )
    ],
  );
}

Widget cardClockOut(String value) {
  return Row(
    children: [
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.0),
        ),
        padding: const EdgeInsets.all(6.0),
        margin: const EdgeInsets.only(right: 8.0),
        child: Icon(
          Icons.arrow_upward,
          size: 28.0,
          color: Colors.red[700],
        ),
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Clock-Out Total",
            style: TextStyle(fontSize: 14.0, color: Colors.white),
          ),
          Text(
            value,
            style: const TextStyle(
                fontSize: 20.0,
                fontWeight: FontWeight.w700,
                color: Colors.white),
          )
        ],
      )
    ],
  );
}
