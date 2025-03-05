// profile_page.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import '../models/staff_model.dart';
import '../widgets/editable_department.dart';
import '../widgets/editable_designation.dart';
import '../widgets/editable_location.dart';
import '../widgets/editable_project.dart';
import '../widgets/editable_staffcategory.dart';
import '../widgets/editable_state.dart';
import '../widgets/editable_supervisor.dart';
import '../widgets/drawer.dart';
import '../widgets/header_widget.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:firebase_auth/firebase_auth.dart';


class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<StatefulWidget> createState() {
    return _ProfilePageState();
  }
}

class _ProfilePageState extends State<ProfilePage> {

  final double _drawerIconSize = 24;
  final double _drawerFontSize = 17;
  String? firebaseAuthId;
  StaffModel? _staffData;
  var newstaffCategory;
  var locationName;
  var updatedDepartment;
  var newState;
  var newCategory;
  bool isSynced = true;
  bool newSynced = true;

  // Controllers for editable fields
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  File? _signatureImage;
  String? _signatureLink;
  File? _profileImage;
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _getUserId().then((_) {
      _getUserDetail();
      _checkSignature();
      _checkProfilePic();
    });
  }

  Future<void> _getUserId() async {
    setState(() {
      firebaseAuthId = FirebaseAuth.instance.currentUser?.uid;
    });
  }


  Future<void> _checkSignature() async {
    if (firebaseAuthId != null) {
      DocumentSnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore.instance
          .collection("Staff")
          .doc(firebaseAuthId)
          .get();
      if (snapshot.exists) {
        StaffModel staffModel = StaffModel.fromFirestore(snapshot);
        setState(() {
          _signatureLink = staffModel.signatureLink;
        });
      }
    }
  }

  Future<void> _checkProfilePic() async {
    if (firebaseAuthId != null) {
      DocumentSnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore.instance
          .collection("Staff")
          .doc(firebaseAuthId)
          .get();
      if (snapshot.exists) {
        StaffModel staffModel = StaffModel.fromFirestore(snapshot);
        setState(() {
          _profileImageUrl = staffModel.photoUrl;
        });
      }
    }
  }


  Future<void> _pickSignatureImage() async {
    try {
      final imagePicker = ImagePicker();
      final image = await imagePicker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        setState(() {
          _signatureImage = File(image.path);
          newSynced = false;
          isSynced = false;
        });
      }
    } catch (e) {
      print('Error picking image: $e');
    }
  }


  Future<void> _uploadSignatureAndSync() async {
    if (_signatureImage == null) {
      Fluttertoast.showToast(msg: "Please select a signature image.");
      return;
    }

    String bucketName = "attendanceapp-a6853.appspot.com";
    String storagePath =
        'signatures/${firebaseAuthId}_signature.jpg';

    await firebase_storage
        .FirebaseStorage.instance
        .ref('$bucketName/$storagePath')
        .putFile(_signatureImage!)
        .then((value) async {
      String downloadURL =
      await firebase_storage
          .FirebaseStorage.instance
          .ref('$bucketName/$storagePath')
          .getDownloadURL();

      await FirebaseFirestore.instance
          .collection("Staff")
          .doc("$firebaseAuthId")
          .update({
        "signatureLink": downloadURL,
      });

      setState(() {
        _signatureLink = downloadURL;
        _signatureImage = null;
        newSynced = true;
        isSynced = true;
      });

      Fluttertoast.showToast(msg: "Signature Updated successfully!");
    }).catchError((error){
      Fluttertoast.showToast(msg: "Error uploading signature.");
    });

  }


  Future<void> _getUserDetail() async {
    if (firebaseAuthId != null) {
      DocumentSnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore.instance
          .collection("Staff")
          .doc(firebaseAuthId)
          .get();

      if (snapshot.exists) {
        StaffModel staffModel = StaffModel.fromFirestore(snapshot);
        setState(() {
          _staffData = staffModel;
          newstaffCategory = _staffData?.staffCategory == "Facility Staff"
              ? "Facility"
              : _staffData?.staffCategory == "State Office Staff"
              ? "State Office"
              : "HQ";
          isSynced = _staffData?.isSynced ?? true;
          newSynced = isSynced;

          _emailController.text = _staffData?.emailAddress ?? "";
          _phoneController.text = _staffData?.mobile ?? "";
        });
      } else {
        print("Profile document not found for user: $firebaseAuthId");
      }
    }
  }

  Future<void> _pickProfileImage() async {
    try {
      ImagePicker imagePicker = ImagePicker();
      XFile? image = await imagePicker.pickImage(
        source: ImageSource.gallery,
        maxHeight: 512,
        maxWidth: 512,
        imageQuality: 90,
      );
      if (image == null) return;

      setState(() {
        _profileImage = File(image.path);
      });


    } catch (e) {
      Fluttertoast.showToast(
          msg: "Error:${e.toString()}",
          toastLength: Toast.LENGTH_LONG,
          backgroundColor: Colors.black54,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          textColor: Colors.white,
          fontSize: 16.0);
    }
  }

  void pickUpLoadProfilePic() async {
    if (_profileImage == null) {
      Fluttertoast.showToast(msg: "Please select a profile image.");
      return;
    }
    Reference ref = FirebaseStorage.instance.ref().child(
        'profilePics/${firebaseAuthId}_profilepic.jpg');

    await ref.putFile(_profileImage!);

    ref.getDownloadURL().then((value) async {
      setState(() {
        _profileImageUrl = value;
        if (_staffData != null) {
          _staffData!.photoUrl = value;
        }
      });
      await FirebaseFirestore.instance
          .collection("Staff")
          .doc(firebaseAuthId)
          .update({"photoUrl": value});
      Fluttertoast.showToast(msg: "Profile picture updated successfully!");
    }).catchError((error){
      Fluttertoast.showToast(msg: "Error uploading profile picture.");
    });
  }

  Future<void> getAttendance() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Assuming SuperAdminUserDashBoard can handle navigation appropriately
      // Navigator.push(
      //     context,
      //     MaterialPageRoute(
      //         builder: (context) => const SuperAdminUserDashBoard()));
    } else {
      Fluttertoast.showToast(
          msg: "User not logged in.",
          toastLength: Toast.LENGTH_SHORT,
          backgroundColor: Colors.red,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          textColor: Colors.white,
          fontSize: 16.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isDesktop = constraints.maxWidth > 900;
        bool isTablet = constraints.maxWidth > 600 && constraints.maxWidth <= 900;
        double fontSizeName = isDesktop ? 28 : isTablet ? 24 : 22;
        double fontSizeDesignation = isDesktop ? 20 : isTablet ? 18 : 16;
        double fontSizeSectionTitle = isDesktop ? 18 : isTablet ? 17 : 16;
        double fontSizeDetailTitle = isDesktop ? 16 : isTablet ? 15 : 14;
        double fontSizeDetailSubtitle = isDesktop ? 16 : isTablet ? 15 : 14;
        double cardPadding = isDesktop ? 20 : 15;
        double cardMarginVertical = isDesktop ? 15 : 10;
        double cardMarginHorizontal = isDesktop ? 20 : 10;
        double profileImageSize = isDesktop ? 150 : isTablet ? 130 : 120;
        double syncButtonWidth = isDesktop ? 0.4 : 0.6;
        double syncButtonHeight = isDesktop ? 0.05 : 0.06;
        double sectionTitlePaddingBottom = isDesktop ? 10 : 8;

        return Scaffold(
          drawer: drawer(context,),
          body: firebaseAuthId == null || _staffData == null
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
            child: Stack(
              // ... (rest of the Stack and Container widgets are the same as before)
              children: [
                const SizedBox(
                  height: 100,
                  child: HeaderWidget(100, false, Icons.house_rounded),
                ),
                Container(
                  alignment: Alignment.center,
                  margin: EdgeInsets.fromLTRB(cardMarginHorizontal, 10, cardMarginHorizontal, 10),
                  padding: const EdgeInsets.fromLTRB(7, 0, 7, 0),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () {
                          _pickProfileImage().then((_) {
                            pickUpLoadProfilePic();
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(
                            top: 20,
                            bottom: 24,
                          ),
                          height: profileImageSize,
                          width: profileImageSize,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: Colors.grey.shade300,
                          ),
                          child: _profileImageUrl != null
                              ? ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.network(
                              _profileImageUrl!,
                              width: profileImageSize,
                              height: profileImageSize,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Icon(Icons.person, size: profileImageSize * 0.6, color: Colors.grey.shade600),
                              loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                        : null,
                                  ),
                                );
                              },
                            ),
                          )
                              : Icon(
                            Icons.person,
                            size: profileImageSize * 0.6,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '${_staffData?.firstName?.toString().toUpperCase()} ${_staffData?.lastName?.toString().toUpperCase()}',
                        style: TextStyle(
                          fontSize: fontSizeName,
                          fontWeight: FontWeight.bold,
                          fontFamily: "NexaLight",
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _staffData?.designation?.toString().toUpperCase() ?? '',
                        style: TextStyle(
                          fontSize: fontSizeDesignation,
                          fontWeight: FontWeight.bold,
                          fontFamily: "NexaLight",
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: EdgeInsets.all(cardPadding),
                        child: Column(
                          children: <Widget>[
                            Container(
                              padding: EdgeInsets.only(left: 8.0, bottom: sectionTitlePaddingBottom),
                              alignment: Alignment.topLeft,
                              child: Text(
                                "${_staffData?.role}'s Information",
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w500,
                                  fontSize: fontSizeSectionTitle,
                                ),
                                textAlign: TextAlign.left,
                              ),
                            ),
                            SizedBox(
                              width: double.infinity,
                              child: Card(
                                elevation: 3,
                                margin: EdgeInsets.symmetric(vertical: cardMarginVertical),
                                child: Container(
                                  alignment: Alignment.topLeft,
                                  padding: EdgeInsets.all(cardPadding),
                                  child: Column(
                                    children: <Widget>[
                                      EditableStaffCategoryTile(
                                        icon: Icons.category,
                                        title: "Staff Category",
                                        initialValue: _staffData?.staffCategory ?? '',
                                        fontSizeTitle: fontSizeDetailTitle,
                                        fontSizeSubtitle: fontSizeDetailSubtitle,
                                        onSave: (newValue) {
                                          _updateFirestoreField('staffCategory', newValue);
                                          setState(() {
                                            isSynced = false;
                                            newCategory = newValue;
                                          });
                                        },
                                        fetchStaffCategory: () => _fetchStaffCategoryFromFirestore(),
                                      ),
                                      newCategory != null || _staffData?.state != null
                                          ? EditableStateTile(
                                        icon: Icons.place,
                                        title: "State",
                                        initialValue: _staffData?.state ?? '',
                                        fontSizeTitle: fontSizeDetailTitle,
                                        fontSizeSubtitle: fontSizeDetailSubtitle,
                                        onSave: (newValue) {
                                          _updateFirestoreField('state', newValue);
                                          setState(() {
                                            newState = newValue;
                                            isSynced = false;
                                          });
                                        },
                                        fetchStates: () => _fetchStatesFromFirestore(_staffData?.staffCategory ?? ''),
                                      )
                                          : ListTile(
                                        leading: const Icon(Icons.place),
                                        title: Text("State", style: TextStyle(fontSize: fontSizeDetailTitle)),
                                        subtitle: Text(_staffData?.state.toString() ?? '', style: TextStyle(fontSize: fontSizeDetailSubtitle)),
                                      ),
                                      _staffData?.state != null
                                          ? EditableLocationTile(
                                        icon: Icons.my_location,
                                        title: _staffData?.staffCategory == "Facility Staff"
                                            ? "Facility Name"
                                            : _staffData?.staffCategory == "State Office Staff"
                                            ? "Office Name"
                                            : "Office Name",
                                        initialValue: _staffData?.location ?? '',
                                        fontSizeTitle: fontSizeDetailTitle,
                                        fontSizeSubtitle: fontSizeDetailSubtitle,
                                        onSave: (newValue) {
                                          _updateFirestoreField('location', newValue);
                                          setState(() {
                                            isSynced = false;
                                          });
                                        },
                                        fetchLocations: () => _fetchLocationsFromFirestore(_staffData?.state ?? '', _staffData?.staffCategory ?? ''),
                                      )
                                          : ListTile(
                                        leading: const Icon(Icons.my_location),
                                        title: Text("Office Name", style: TextStyle(fontSize: fontSizeDetailTitle)),
                                        subtitle: Text(_staffData?.location.toString() ?? '', style: TextStyle(fontSize: fontSizeDetailSubtitle)),
                                      ),
                                      _buildEditableListTile1(
                                        icon: Icons.email,
                                        title: 'Email',
                                        initialValue: _staffData?.emailAddress,
                                        controller: _emailController,
                                        fontSizeTitle: fontSizeDetailTitle,
                                        fontSizeSubtitle: fontSizeDetailSubtitle,
                                        onSave: (newValue) async {
                                          _updateFirestoreField('emailAddress', newValue);
                                          setState(() {
                                            isSynced = false;
                                          });
                                        },
                                      ),
                                      _buildEditableListTile1(
                                        icon: Icons.phone,
                                        title: 'Phone',
                                        controller: _phoneController,
                                        initialValue: _staffData?.mobile,
                                        fontSizeTitle: fontSizeDetailTitle,
                                        fontSizeSubtitle: fontSizeDetailSubtitle,
                                        onSave: (newValue) async {
                                          _updateFirestoreField('mobile', newValue);
                                          setState(() {
                                            isSynced = false;
                                          });
                                        },
                                      ),
                                      EditableDepartmentTile(
                                        icon: Icons.local_fire_department_sharp,
                                        title: 'Department',
                                        initialValue: _staffData?.department ?? '',
                                        fontSizeTitle: fontSizeDetailTitle,
                                        fontSizeSubtitle: fontSizeDetailSubtitle,
                                        onSave: (newValue) {
                                          _updateFirestoreField('department', newValue);
                                          setState(() {
                                            updatedDepartment = newValue;
                                            isSynced = false;
                                          });
                                        },
                                        fetchDepartments: () => _staffData?.staffCategory == 'Facility Staff'
                                            ? _fetchDepartmentsForFacilityFromFirestore()
                                            : _fetchDepartmentsFromFirestore(),
                                      ),
                                      updatedDepartment != null || _staffData?.designation != null
                                          ? EditableDesignationTile(
                                        icon: Icons.person,
                                        title: 'Designation',
                                        initialValue: _staffData?.designation ?? '',
                                        fontSizeTitle: fontSizeDetailTitle,
                                        fontSizeSubtitle: fontSizeDetailSubtitle,
                                        onSave: (newValue) {
                                          _updateFirestoreField('designation', newValue);
                                          setState(() {
                                            isSynced = false;
                                          });
                                        },
                                        fetchDesignations: () => _fetchDesignationsFromFirestore(_staffData?.department ?? '', _staffData?.staffCategory ?? ''),
                                      )
                                          : ListTile(
                                        leading: const Icon(Icons.person),
                                        title: Text("Designation", style: TextStyle(fontSize: fontSizeDetailTitle)),
                                        subtitle: Text(_staffData?.designation.toString() ?? '', style: TextStyle(fontSize: fontSizeDetailSubtitle)),
                                      ),
                                      EditableProjectTile(
                                        icon: Icons.work,
                                        title: 'Project',
                                        initialValue: _staffData?.project ?? '',
                                        fontSizeTitle: fontSizeDetailTitle,
                                        fontSizeSubtitle: fontSizeDetailSubtitle,
                                        onSave: (newValue) {
                                          _updateFirestoreField('project', newValue);
                                          setState(() {
                                            isSynced = false;
                                          });
                                        },
                                        fetchProjects: () => _fetchProjectsFromFirestore(),
                                      ),
                                      updatedDepartment != null || _staffData?.supervisor != null
                                          ? EditableSupervisorTile(
                                        icon: Icons.person,
                                        title: "Supervisor's Name",
                                        initialValue: _staffData?.supervisor ?? '',
                                        fontSizeTitle: fontSizeDetailTitle,
                                        fontSizeSubtitle: fontSizeDetailSubtitle,
                                        onSave: (newValue) async {
                                          List<String?> supervisorsemail = await _getSupervisorEmailFromFirestore(_staffData?.department ?? '', newValue);

                                          _updateFirestoreField('supervisor', newValue);
                                          _updateFirestoreField('supervisorEmail', supervisorsemail.isNotEmpty ? supervisorsemail[0] : null);

                                          setState(() {
                                            _staffData!.supervisorEmail = supervisorsemail.isNotEmpty ? supervisorsemail[0] : null;
                                            isSynced = false;
                                          });
                                        },
                                        fetchSupervisor: () => _fetchSupervisorsFromFirestore(_staffData?.department ?? '', _staffData?.state ?? ''),
                                      )
                                          : ListTile(
                                        leading: const Icon(Icons.person),
                                        title: Text("Supervisor's Name", style: TextStyle(fontSize: fontSizeDetailTitle)),
                                        subtitle: Text(_staffData?.supervisor.toString() ?? '', style: TextStyle(fontSize: fontSizeDetailSubtitle)),
                                      ),
                                      ListTile(
                                        leading: const Icon(Icons.email),
                                        title: Text("Supervisor's Email", style: TextStyle(fontSize: fontSizeDetailTitle)),
                                        subtitle: Text(_staffData?.supervisorEmail.toString() ?? '', style: TextStyle(fontSize: fontSizeDetailSubtitle)),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 10.0),
                                        child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                            children: [
                                              Row(children: [
                                                const Icon(Icons.draw),
                                                Text("Is Signature saved?", style: TextStyle(fontSize: fontSizeDetailTitle)),
                                                Text(_signatureLink != null ? "Yes" : "No", style: TextStyle(fontSize: fontSizeDetailSubtitle)),
                                              ]),
                                              Row(children: [
                                                ElevatedButton(
                                                  onPressed: () {
                                                    showModalBottomSheet(
                                                      context: context,
                                                      builder: (context) => Container(
                                                        height: MediaQuery.of(context).size.width *
                                                            (MediaQuery.of(context).size.shortestSide < 600 ? 0.30 : 0.60),
                                                        padding: const EdgeInsets.all(16),
                                                        child: Column(children: [
                                                          SizedBox(
                                                            height: MediaQuery.of(context).size.width *
                                                                (MediaQuery.of(context).size.shortestSide < 600 ? 0.30 : 0.50),
                                                            child: GestureDetector(
                                                              onTap: () {
                                                                _pickSignatureImage();
                                                              },
                                                              child: Container(
                                                                margin: const EdgeInsets.only(
                                                                  top: 20,
                                                                  bottom: 24,
                                                                ),
                                                                height: MediaQuery.of(context).size.width *
                                                                    (MediaQuery.of(context).size.shortestSide < 600 ? 0.30 : 0.15),
                                                                width: MediaQuery.of(context).size.width *
                                                                    (MediaQuery.of(context).size.shortestSide < 600 ? 0.30 : 0.30),
                                                                alignment: Alignment.center,
                                                                decoration: BoxDecoration(
                                                                  borderRadius: BorderRadius.circular(20),
                                                                ),
                                                                child: _signatureImage != null
                                                                    ? ClipRRect(
                                                                    borderRadius: BorderRadius.circular(20),
                                                                    child: Image.file(
                                                                      _signatureImage!,
                                                                      width: MediaQuery.of(context).size.width *
                                                                          (MediaQuery.of(context).size.shortestSide < 600 ? 0.30 : 0.30),
                                                                      height: MediaQuery.of(context).size.width *
                                                                          (MediaQuery.of(context).size.shortestSide < 600 ? 0.30 : 0.15),
                                                                      fit: BoxFit.cover,
                                                                    )
                                                                )
                                                                    : Column(
                                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                                  children: [
                                                                    Icon(
                                                                      Icons.upload_file,
                                                                      size: MediaQuery.of(context).size.width *
                                                                          (MediaQuery.of(context).size.shortestSide < 600 ? 0.075 : 0.05),
                                                                      color: Colors.grey.shade600,
                                                                    ),
                                                                    const SizedBox(height: 8),
                                                                    const Text(
                                                                      "Click to Upload Signature Image Here",
                                                                      style: TextStyle(
                                                                        fontSize: 14,
                                                                        color: Colors.grey,
                                                                        fontWeight: FontWeight.bold,
                                                                      ),
                                                                      textAlign: TextAlign.center,
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                          ElevatedButton(
                                                              onPressed: () {
                                                                _uploadSignatureAndSync().then((_){
                                                                  Navigator.pop(context);
                                                                });

                                                              },
                                                              child: const Text("Save Signature")),
                                                        ]),
                                                      ),
                                                    );
                                                  },
                                                  child: _signatureLink == null ? const Text("Add") : const Text("Update"),
                                                ),
                                              ]),
                                            ]),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                      !isSynced
                          ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20.0),
                          child: GestureDetector(
                            onTap: () async {
                              await syncCompleteData();
                              setState(() {
                                isSynced = newSynced;
                              });
                            },
                            child: Container(
                              width: MediaQuery.of(context).size.width * syncButtonWidth,
                              height: MediaQuery.of(context).size.height * syncButtonHeight,
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.red,
                                    Colors.black,
                                  ],
                                ),
                                borderRadius: BorderRadius.all(
                                  Radius.circular(15),
                                ),
                              ),
                              child: Center(
                                child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        "Sync Updated Bio Data",
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: fontSizeDetailTitle),
                                      ),
                                      const SizedBox(width: 10),
                                      Icon(
                                        Icons.arrow_upward,
                                        size: fontSizeDetailTitle + 4,
                                        color: Colors.white,
                                      ),
                                    ]),
                              ),
                            ),
                          ))
                          : const SizedBox.shrink(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _updateFirestoreField(String field, String? newValue) async {
    if (firebaseAuthId != null) {
      await FirebaseFirestore.instance
          .collection("Staff")
          .doc(firebaseAuthId)
          .update({field: newValue});

      // Update local StaffModel as well
      if (_staffData != null) {
        switch (field) {
          case 'staffCategory': _staffData!.staffCategory = newValue; break;
          case 'state': _staffData!.state = newValue; break;
          case 'location': _staffData!.location = newValue; break;
          case 'emailAddress': _staffData!.emailAddress = newValue; break;
          case 'mobile': _staffData!.mobile = newValue; break;
          case 'department': _staffData!.department = newValue; break;
          case 'designation': _staffData!.designation = newValue; break;
          case 'project': _staffData!.project = newValue; break;
          case 'supervisor': _staffData!.supervisor = newValue; break;
          case 'supervisorEmail': _staffData!.supervisorEmail = newValue; break;
          case 'signatureLink': _staffData!.signatureLink = newValue; break;
          case 'photoUrl': _staffData!.photoUrl = newValue; break;
        }
      }
    }
  }


  Future<void> syncCompleteData() async {
    if (firebaseAuthId != null && _staffData != null) {
      try {
        await FirebaseFirestore.instance
            .collection("Staff")
            .doc(firebaseAuthId)
            .set(_staffData!.toFirestore(), SetOptions(merge: true)).then((value) {
          Fluttertoast.showToast(
            msg: "Syncing BioData to Server...",
            toastLength: Toast.LENGTH_SHORT,
            backgroundColor: Colors.black54,
            gravity: ToastGravity.BOTTOM,
            timeInSecForIosWeb: 1,
            textColor: Colors.white,
            fontSize: 16.0,
          );
          setState(() {
            isSynced = true;
            newSynced = true;
            _staffData!.isSynced = true;
          });
          Fluttertoast.showToast(
            msg: "Syncing Completed...",
            toastLength: Toast.LENGTH_SHORT,
            backgroundColor: Colors.black54,
            gravity: ToastGravity.BOTTOM,
            timeInSecForIosWeb: 1,
            textColor: Colors.white,
            fontSize: 16.0,
          );
        });
      } catch (e) {
        Fluttertoast.showToast(
          msg: "Sync Error: ${e.toString()}",
          toastLength: Toast.LENGTH_SHORT,
          backgroundColor: Colors.black54,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          textColor: Colors.white,
          fontSize: 16.0,
        );
        setState(() {
          isSynced = false;
          newSynced = false;
          if (_staffData != null) {
            _staffData!.isSynced = false;
          }
        });
      }
    }
  }


  Future<List<DropdownMenuItem<String>>> _fetchLocationsFromFirestore(String state, String category) async {
    CollectionReference locationsRef;
    if (category == "Facility Staff") {
      locationsRef = FirebaseFirestore.instance.collection('FacilityLocations');
    } else if (category == "State Office Staff") {
      locationsRef = FirebaseFirestore.instance.collection('StateOfficeLocations');
    } else {
      locationsRef = FirebaseFirestore.instance.collection('HQOfficeLocations');
    }

    QuerySnapshot snapshot = await locationsRef.where('state', isEqualTo: state).get();
    List<String> locations = snapshot.docs.map((doc) => doc['locationName'] as String).toList();

    return locations.map((location) => DropdownMenuItem<String>(
      value: location,
      child: Text(location),
    )).toList();
  }


  Future<List<DropdownMenuItem<String>>> _fetchDepartmentsFromFirestore() async {
    CollectionReference departmentsRef = FirebaseFirestore.instance.collection('Departments');
    QuerySnapshot snapshot = await departmentsRef.get();
    List<String> departments = snapshot.docs.map((doc) => doc['departmentName'] as String).toList();

    return departments.map((department) => DropdownMenuItem<String>(
      value: department,
      child: Text(department),
    )).toList();
  }

  Future<List<DropdownMenuItem<String>>> _fetchStaffCategoryFromFirestore() async {
    CollectionReference staffCategoryRef = FirebaseFirestore.instance.collection('StaffCategories');
    QuerySnapshot snapshot = await staffCategoryRef.get();
    List<String> staffCategories = snapshot.docs.map((doc) => doc['categoryName'] as String).toList();

    return staffCategories.map((category) => DropdownMenuItem<String>(
      value: category,
      child: Text(category),
    )).toList();
  }


  Future<List<DropdownMenuItem<String>>> _fetchDepartmentsForFacilityFromFirestore() async {
    CollectionReference departmentsRef = FirebaseFirestore.instance.collection('Departments');
    QuerySnapshot snapshot = await departmentsRef.get();
    List<String> allDepartments = snapshot.docs.map((doc) => doc['departmentName'] as String).toList();
    List<String> departmentFilterList = ['Care and Treatment','Laboratory','Pharmacy and Logistics','Preventions','Strategic Information'];

    List<String> filteredDepartments = allDepartments.where((department) {
      return departmentFilterList.contains(department);
    }).toList();


    return filteredDepartments.map((department) => DropdownMenuItem<String>(
      value: department,
      child: Text(department),
    )).toList();
  }


  Future<List<DropdownMenuItem<String>>> _fetchDesignationsFromFirestore(String department, String category) async {
    CollectionReference designationsRef;
    if(category == "Facility Staff"){
      designationsRef = FirebaseFirestore.instance.collection('FacilityDesignations');
    }else{
      designationsRef = FirebaseFirestore.instance.collection('OfficeDesignations');
    }

    QuerySnapshot snapshot = await designationsRef.where('department', isEqualTo: department).get();
    List<String> designations = snapshot.docs.map((doc) => doc['designationName'] as String).toList();

    return designations.map((designation) => DropdownMenuItem<String>(
      value: designation,
      child: Text(designation),
    )).toList();
  }


  Future<List<DropdownMenuItem<String>>> _fetchStatesFromFirestore(String category) async {
    CollectionReference statesRef = FirebaseFirestore.instance.collection('States');
    QuerySnapshot snapshot = await statesRef.get();
    List<String> allStates = snapshot.docs.map((doc) => doc['stateName'] as String).toList();

    List<String> states;
    if (category == 'HQ Staff') {
      states = allStates.where((state) => state == "Federal Capital Territory").toList();
    } else {
      states = allStates.where((state) => state != "Federal Capital Territory").toList();
    }

    return states.map((state) => DropdownMenuItem<String>(
      value: state,
      child: Text(state),
    )).toList();
  }

  Future<List<DropdownMenuItem<String>>> _fetchProjectsFromFirestore() async {
    CollectionReference projectsRef = FirebaseFirestore.instance.collection('Projects');
    QuerySnapshot snapshot = await projectsRef.get();
    List<String> projects = snapshot.docs.map((doc) => doc['projectName'] as String).toList();

    return projects.map((project) => DropdownMenuItem<String>(
      value: project,
      child: Text(project),
    )).toList();
  }


  Future<List<DropdownMenuItem<String>>> _fetchSupervisorsFromFirestore(String department, String state) async {
    CollectionReference supervisorsRef = FirebaseFirestore.instance.collection('Supervisors');
    QuerySnapshot snapshot = await supervisorsRef.where('department', isEqualTo: department).where('state',isEqualTo:state).get();
    List<String> supervisors = snapshot.docs.map((doc) => doc['supervisorName'] as String).toList();

    return supervisors.map((supervisor) => DropdownMenuItem<String>(
      value: supervisor,
      child: Text(supervisor),
    )).toList();
  }

  Future<List<String?>> _getSupervisorEmailFromFirestore(String department, String supervisorName) async {
    CollectionReference supervisorsRef = FirebaseFirestore.instance.collection('Supervisors');
    QuerySnapshot snapshot = await supervisorsRef.where('department', isEqualTo: department).where('supervisorName',isEqualTo:supervisorName).get();
    List<String?> supervisorEmails = snapshot.docs.map((doc) => doc['supervisorEmail'] as String?).toList();

    return supervisorEmails;
  }


  Widget _buildEditableListTile1({
    required IconData icon,
    required String title,
    String? initialValue,
    TextEditingController? controller,
    required Function(String) onSave,
    double? fontSizeTitle,
    double? fontSizeSubtitle,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontSize: 20)),
      subtitle: initialValue != null
          ? Text(initialValue, style: const TextStyle(fontSize: 14))
          : null,
      trailing: IconButton(
        icon: const Icon(Icons.edit),
        onPressed: () {
          _showEditDialog1(
            context: context,
            title: title,
            initialValue: initialValue ?? controller?.text,
            onSave: onSave,
          );
        },
      ),
    );
  }

  void _showEditDialog1({
    required BuildContext context,
    required String title,
    String? initialValue,
    required Function(String) onSave,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        String? newValue = initialValue;

        return AlertDialog(
          title: Text('Edit $title'),
          content: TextField(
            onChanged: (value) {
              newValue = value;
            },
            controller: TextEditingController(text: initialValue),
            decoration: InputDecoration(
              hintText: 'Enter new $title',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                onSave(newValue ?? "");
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }


  Future<List<Uint8List>?> _readImagesFromDatabase() async {
    return null;
  }

  Future<List<Uint8List>?> _readSignatureImagesFromDatabase() async {
    return null;
  }
}