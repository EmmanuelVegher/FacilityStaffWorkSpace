// import 'package:flutter/cupertino.dart';
// import 'package:flutter/material.dart';
//
// import '../services/isar_service.dart';
// import 'input_field.dart';
//
// class FacilityDropdown extends StatefulWidget {
//   final String stateName;
//   final String facilityLocationName;
//
//   const FacilityDropdown({
//     Key? key,
//     required this.stateName,
//     required this.facilityLocationName,
//   }) : super(key: key);
//
//   @override
//   _FacilityDropdownState createState() => _FacilityDropdownState();
// }
//
// class _FacilityDropdownState extends State<FacilityDropdown> {
//   String? selectedFacilityLocationName;
//
//   Future<List<DropdownMenuItem<String>>> _fetchLocationsFromIsar(String state) async {
//     // Query Isar database for locations based on the selected state
//     List<String?> locations = await IsarService().getLocationsFromIsar(state);
//
//     // Convert the locations list to DropdownMenuItem list
//     return locations.map((location) => DropdownMenuItem<String>(
//       value: location,
//       child: Text(location!),
//
//     )).toList();
//   }
//
//
//
//   @override
//   void initState() {
//     super.initState();
//     selectedFacilityLocationName = widget.facilityLocationName;
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return FutureBuilder<List<DropdownMenuItem<String>>>(
//       future: _fetchLocationsFromIsar(widget.stateName),
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
//                       //height: 100,
//                       child:
//               DropdownButtonFormField<String>(
//                 //focusColor:Colors.yellow,
//
//                 decoration: InputDecoration(
//                   iconColor:Colors.blue,
//                   labelText: "",
//                   filled: true,
//                   fillColor: Colors.white,
//                   contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 15),
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(8),
//                     borderSide: BorderSide.none,
//                   ),
//                 ),
//                 value: selectedFacilityLocationName,
//                 icon: Icon(Icons.keyboard_arrow_down, size: 24, color: Colors.black),
//                 dropdownColor: Colors.white,
//                 elevation: 4,
//                 style: TextStyle(
//                   color: Colors.black,
//                   fontSize: 16,
//                   fontFamily: "NexaBold",
//                 ),
//                 items: snapshot.data!.map((item) => DropdownMenuItem<String>(
//                   value: item.value,
//                   child: Container( // Wrap the Text inside the DropdownMenuItem
//                    // width: MediaQuery.of(context).size.width * 0.66,
//                     //color: Colors.pink,// Adjust this width as needed
//                     child: Text(
//                       (item.child as Text).data!,
//                       softWrap: true,
//                     ),
//                   ),
//                 )).toList(),
//                 onChanged: (value) {
//                   setState(() {
//                     selectedFacilityLocationName = value;
//                   });
//                 },
//                 isExpanded: true,
//               ))),
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
