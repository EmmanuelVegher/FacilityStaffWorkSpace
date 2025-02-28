// import 'package:flutter/cupertino.dart';
// import 'package:flutter/material.dart';
//
// import '../services/isar_service.dart';
// import 'input_field.dart';
//
// class DesignationDropdown extends StatefulWidget {
//   final String departmentName;
//   final String facilityDesignationName;
//
//   const DesignationDropdown({
//     Key? key,
//     required this.departmentName,
//     required this.facilityDesignationName,
//   }) : super(key: key);
//
//   @override
//   _DesignationDropdownState createState() => _DesignationDropdownState();
// }
//
// class _DesignationDropdownState extends State<DesignationDropdown> {
//   String? selectedFacilityDesignationName;
//
//   Future<List<DropdownMenuItem<String>>> _fetchDesignationsFromIsar(String department,String category) async {
//     // Query Isar database for designation based on the selected Department
//     List<String?> designation = await IsarService().getDesignationsFromIsar(department,department);
//
//     // Convert the locations list to DropdownMenuItem list
//     return designation.map((designation) => DropdownMenuItem<String>(
//       value: designation,
//       child: Text(designation!),
//
//     )).toList();
//   }
//
//
//
//   @override
//   void initState() {
//     super.initState();
//     selectedFacilityDesignationName = widget.facilityDesignationName;
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return FutureBuilder<List<DropdownMenuItem<String>>>(
//       future: getDesignationsFromIsar(widget.department),
//       builder: (context, snapshot) {
//         if (snapshot.hasError) {
//           return Text('Error: ${snapshot.error}', style: TextStyle(color: Colors.red));
//         }
//         if (snapshot.connectionState == ConnectionState.waiting) {
//           return Center(child: CircularProgressIndicator());
//         }
//         if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
//           // Check if facilityLocationName exists in the dropdown items
//           if (!snapshot.data!.any((item) => item.value == selectedFacilityLocationName)) {
//             selectedFacilityLocationName = snapshot.data!.first.value;
//           }
//
//           return MyInputField(
//             title: "Facility",
//             hint: "",
//             widget: Container(
//               width: MediaQuery.of(context).size.width*0.81,
//               //height: MediaQuery.of(context).size.height * 1,// Set your desired width
//               //color:Colors.red,
//               child: SizedBox(
//                 //height: 100,
//                   child:SizedBox(
//                     //height: 100,
//                       child:
//                       DropdownButtonFormField<String>(
//                         //focusColor:Colors.yellow,
//
//                         decoration: InputDecoration(
//                           iconColor:Colors.blue,
//                           labelText: "",
//                           filled: true,
//                           fillColor: Colors.white,
//                           contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 15),
//                           border: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(8),
//                             borderSide: BorderSide.none,
//                           ),
//                         ),
//                         value: selectedFacilityLocationName,
//                         icon: Icon(Icons.keyboard_arrow_down, size: 24, color: Colors.black),
//                         dropdownColor: Colors.white,
//                         elevation: 4,
//                         style: TextStyle(
//                           color: Colors.black,
//                           fontSize: 16,
//                           fontFamily: "NexaBold",
//                         ),
//                         items: snapshot.data!.map((item) => DropdownMenuItem<String>(
//                           value: item.value,
//                           child: Container( // Wrap the Text inside the DropdownMenuItem
//                             // width: MediaQuery.of(context).size.width * 0.66,
//                             //color: Colors.pink,// Adjust this width as needed
//                             child: Text(
//                               (item.child as Text).data!,
//                               softWrap: true,
//                             ),
//                           ),
//                         )).toList(),
//                         onChanged: (value) {
//                           setState(() {
//                             selectedFacilityLocationName = value;
//                           });
//                         },
//                         isExpanded: true,
//                       ))),
//             ),
//           );
//           //   DropdownButtonFormField<String>(
//           //   decoration: InputDecoration(
//           //     labelText: "Select Facility",
//           //     filled: true,
//           //     fillColor: Colors.grey[200],
//           //     contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 15),
//           //     border: OutlineInputBorder(
//           //       borderRadius: BorderRadius.circular(8),
//           //       borderSide: BorderSide.none,
//           //     ),
//           //   ),
//           //   value: selectedFacilityLocationName,
//           //   icon: Icon(Icons.keyboard_arrow_down, size: 24, color: Colors.black),
//           //   dropdownColor: Colors.white,
//           //   elevation: 4,
//           //   style: TextStyle(
//           //     color: Colors.black,
//           //     fontSize: 16,
//           //     fontFamily: "NexaBold",
//           //   ),
//           //   items: snapshot.data,
//           //   onChanged: (value) {
//           //     setState(() {
//           //       selectedFacilityLocationName = value;
//           //     });
//           //   },
//           // );
//         } else {
//           return Center(child: Text("No facilities available."));
//         }
//       },
//     );
//   }
// }
