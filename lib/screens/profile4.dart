// profile_page.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart'; // Import Google Fonts
import '../models/staff_model.dart';
import '../widgets/drawer4.dart';
import '../widgets/editable_gender.dart';
import '../widgets/editable_maritalstatus.dart';
import '../widgets/header_widget.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:firebase_auth/firebase_auth.dart';


class ProfilePage4 extends StatefulWidget {
  const ProfilePage4({super.key});

  @override
  State<StatefulWidget> createState() {
    return _ProfilePage4State();
  }
}

class _ProfilePage4State extends State<ProfilePage4> {

  final double _drawerIconSize = 24;
  final double _drawerFontSize = 17;
  String? firebaseAuthId;
  StaffModel? _staffData;
  var newstaffCategory;
  var locationName;
  var updatedDepartment;
  var newState;
  var newCategory;
  var newMaritalStatus;
  var newGender;
  bool isSynced = true;
  bool newSynced = true;
  final String _currentUsername = "";
  String? selectedProjectName;
  String? selectedBioFirstName;
  String? selectedBioLastName;
  String? selectedBioDepartment;
  String? selectedBioState;
  String? selectedBioDesignation;
  String? selectedBioLocation;
  String? selectedBioStaffCategory;
  String? selectedBioEmail;
  String? selectedBioPhone;
  String? selectedFirebaseId;
  String? facilitySupervisor;
  String? caritasSupervisor;
  DateTime? selectedDate;
  String? staffSignatureLink;

  String? selectedSupervisor; // State variable to store the selected supervisor
  String? selectedFacilitySupervisor; // State variable to store the selected supervisor
  String? _selectedSupervisorEmail;
  
  // Define Maroon theme colors
  static const Color maroonPrimary = Color(0xFF5C1A2E); 
  static const LinearGradient appBarGradient = LinearGradient(
    colors: [maroonPrimary, Color(0xFF2E0215)], // Consistent Maroon/Gold gradient
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

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
      _loadBioData();
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
          drawer: drawer4(context,),
          appBar: AppBar(
            title: Text('Profile Page', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
            centerTitle: true,
            iconTheme: const IconThemeData(color: Colors.white), // Makes the drawer icon white
            flexibleSpace: Container(
              decoration: const BoxDecoration(gradient: appBarGradient),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(top: 15, right: 15, bottom: 15),
                child: Image.asset("assets/image/ccfn_logo.png"),
              )
            ],
          ),
          body: SelectionArea( // Wrapped in SelectionArea for copyable text
            child: firebaseAuthId == null || _staffData == null
                ? const Center(child: CircularProgressIndicator(color: maroonPrimary))
                : SingleChildScrollView(
              child: Stack(
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
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
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
                          style: GoogleFonts.poppins(
                            fontSize: fontSizeName,
                            fontWeight: FontWeight.bold,
                            color: maroonPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _staffData?.designation?.toString().toUpperCase() ?? '',
                          style: GoogleFonts.poppins(
                            fontSize: fontSizeDesignation,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: cardPadding),
                          child: Column(
                            children: <Widget>[
                              Container(
                                padding: EdgeInsets.only(left: 8.0, bottom: sectionTitlePaddingBottom),
                                alignment: Alignment.topLeft,
                                child: Text(
                                  "${_staffData?.role}'s Information",
                                  style: GoogleFonts.poppins(
                                    color: maroonPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: fontSizeSectionTitle,
                                  ),
                                  textAlign: TextAlign.left,
                                ),
                              ),
                              SizedBox(
                                width: double.infinity,
                                child: Card(
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                  margin: EdgeInsets.symmetric(vertical: cardMarginVertical),
                                  child: Container(
                                    alignment: Alignment.topLeft,
                                    padding: EdgeInsets.all(cardPadding),
                                    child: Column(
                                      children: <Widget>[
                                        EditableGenderTile(
                                          icon: Icons.person_outline,
                                          title: "Sex",
                                          initialValue: _staffData?.gender ?? '',
                                          onSave: (newValue) {
                                            _updateFirestoreField('gender', newValue);
                                            setState(() {
                                              newGender = newValue;
                                              isSynced = false;
                                            });
                                          },
                                          fetchGender: () => _fetchGenderFromFirestore(),
                                        ),
                                        EditableMaritalStatusTile(
                                          icon: Icons.favorite_border,
                                          title: "Marital Status",
                                          initialValue: _staffData?.maritalStatus ?? '',
                                          onSave: (newValue) {
                                            _updateFirestoreField('maritalStatus', newValue);
                                            setState(() {
                                              newMaritalStatus = newValue;
                                              isSynced = false;
                                            });
                                          },
                                          fetchMaritalStatus: () => _fetchMaritalStatusFromFirestore(),
                                        ),

                                        _buildDetailTile(Icons.category_outlined, "Staff Category", _staffData?.staffCategory ?? '', fontSizeDetailTitle, fontSizeDetailSubtitle),
                                        _buildDetailTile(Icons.map_outlined, "State", _staffData?.state.toString() ?? '', fontSizeDetailTitle, fontSizeDetailSubtitle),
                                        _buildDetailTile(
                                          Icons.location_on_outlined,
                                          _staffData?.staffCategory == "Facility Staff"
                                              ? "Facility Name"
                                              : "Office Name",
                                          _staffData?.location.toString() ?? '',
                                          fontSizeDetailTitle,
                                          fontSizeDetailSubtitle,
                                        ),
                                        _buildDetailTile(Icons.email_outlined, 'Email', _staffData?.emailAddress ?? '', fontSizeDetailTitle, fontSizeDetailSubtitle),
                                        
                                        _buildEditableListTile1(
                                          icon: Icons.phone_outlined,
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
                                        _buildDetailTile(Icons.business_outlined, 'Department', _staffData?.department ?? '', fontSizeDetailTitle, fontSizeDetailSubtitle),
                                        _buildDetailTile(Icons.assignment_ind_outlined, "Designation", _staffData?.designation.toString() ?? '', fontSizeDetailTitle, fontSizeDetailSubtitle),
                                        _buildDetailTile(Icons.work_outline, 'Project', _staffData?.project ?? '', fontSizeDetailTitle, fontSizeDetailSubtitle),
                                        _buildDetailTile(Icons.supervisor_account_outlined, "Supervisor's Name", _staffData?.supervisor.toString() ?? '', fontSizeDetailTitle, fontSizeDetailSubtitle),
                                        _buildDetailTile(Icons.mark_email_read_outlined, "Supervisor's Email", _staffData?.supervisorEmail.toString() ?? '', fontSizeDetailTitle, fontSizeDetailSubtitle),

                                        // System Information Section
                                        const Divider(height: 40),
                                        Container(
                                          padding: EdgeInsets.only(left: 8.0, bottom: sectionTitlePaddingBottom),
                                          alignment: Alignment.topLeft,
                                          child: Text(
                                            "System Information",
                                            style: GoogleFonts.poppins(
                                              color: maroonPrimary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: fontSizeSectionTitle,
                                            ),
                                            textAlign: TextAlign.left,
                                          ),
                                        ),

                                        _buildDetailTile(Icons.badge_outlined, "Staff ID", _staffData?.id?.toString() ?? 'Not Available', fontSizeDetailTitle, fontSizeDetailSubtitle),
                                        _buildDetailTile(Icons.sync_outlined, "Sync Status", _staffData?.isSynced == true ? 'Synced' : 'Not Synced', fontSizeDetailTitle, fontSizeDetailSubtitle),
                                        _buildDetailTile(Icons.person_add_outlined, "Created By", _staffData?.createdBy?.toString() ?? 'Not Available', fontSizeDetailTitle, fontSizeDetailSubtitle),
                                        _buildDetailTile(Icons.alternate_email_outlined, "Created By Email", _staffData?.createdByEmail?.toString() ?? 'Not Available', fontSizeDetailTitle, fontSizeDetailSubtitle),
                                        _buildDetailTile(Icons.update_outlined, "Last Updated By", _staffData?.lastUpdatedBy?.toString() ?? 'Not Available', fontSizeDetailTitle, fontSizeDetailSubtitle),
                                        _buildDetailTile(Icons.alternate_email_outlined, "Last Updated By Email", _staffData?.lastUpdatedByEmail?.toString() ?? 'Not Available', fontSizeDetailTitle, fontSizeDetailSubtitle),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                            ],
                          ),
                        ),
                        if (!isSynced)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32.0),
                            child: Center(
                              child: GestureDetector(
                                onTap: () async {
                                  await syncCompleteData();
                                  setState(() {
                                    isSynced = newSynced;
                                  });
                                },
                                child: Container(
                                  width: MediaQuery.of(context).size.width * syncButtonWidth,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    gradient: appBarGradient,
                                    borderRadius: BorderRadius.circular(15),
                                    boxShadow: [
                                      BoxShadow(
                                        color: maroonPrimary.withOpacity(0.3),
                                        blurRadius: 10,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            "Sync Updated Bio Data",
                                            style: GoogleFonts.poppins(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: fontSizeDetailTitle),
                                          ),
                                          const SizedBox(width: 12),
                                          const Icon(
                                            Icons.sync,
                                            size: 20,
                                            color: Colors.white,
                                          ),
                                        ]),
                                  ),
                                ),
                              ),
                            ),
                          )
                        else 
                          const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailTile(IconData icon, String title, String subtitle, double titleSize, double subtitleSize) {
    return ListTile(
      leading: Icon(icon, color: maroonPrimary),
      title: Text(title, style: GoogleFonts.poppins(fontSize: titleSize, fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: GoogleFonts.poppins(fontSize: subtitleSize, color: Colors.black87)),
    );
  }

  Future<void> _loadBioData() async {
    String? userId = FirebaseAuth.instance.currentUser?.uid;

    try {
      DocumentSnapshot<Map<String, dynamic>> docSnapshot = await FirebaseFirestore.instance
          .collection('Staff')
          .doc(userId)
          .get();

      if (docSnapshot.exists && docSnapshot.data() != null) {
        Map<String, dynamic> data = docSnapshot.data()!;
        setState(() {
          selectedBioFirstName = data['firstName'] ?? '';
          selectedBioLastName = data['lastName'] ?? '';
          selectedBioDepartment = data['department'] ?? '';
          selectedBioState = data['state'] ?? '';
          selectedBioDesignation = data['designation'] ?? '';
          selectedBioLocation = data['location'] ?? '';
          selectedBioStaffCategory = data['staffCategory'] ?? '';
          selectedBioEmail = data['emailAddress'] ?? '';
          selectedBioPhone = data['mobile'] ?? '';
          staffSignatureLink = data['signatureLink'] ?? '';
          selectedFirebaseId = userId; // Store the Firebase UUID

        });


      } else {
        print("No bio data found for user ID: $userId");

        Fluttertoast.showToast(
          msg: "No bio data found for user. Please ensure your profile is complete.",
          toastLength: Toast.LENGTH_SHORT,
          backgroundColor: Colors.black54,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      }
    } catch (e) {
      print("Error loading bio data: $e");

      Fluttertoast.showToast(
        msg: "Error loading bio data. Please check your internet connection.",
        toastLength: Toast.LENGTH_SHORT,
        backgroundColor: Colors.black54,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
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
          case 'gender': _staffData!.gender = newValue; break;
          case 'maritalStatus': _staffData!.maritalStatus = newValue; break;
          case 'photoUrl': _staffData!.photoUrl = newValue; break;
          // --- NEW FIELDS ADDED ---
          case 'accountNumber': _staffData!.accountNumber = newValue; break;
          case 'accountStatus': _staffData!.accountStatus = newValue; break;
          case 'bankName': _staffData!.bankName = newValue; break;
          case 'sortCode': _staffData!.sortCode = newValue; break;
          case 'programManager': _staffData!.programManager = newValue; break;
          case 'programManagerEmail': _staffData!.programManagerEmail = newValue; break;
          case 'createdBy': _staffData!.createdBy = newValue; break;
          case 'createdByEmail': _staffData!.createdByEmail = newValue; break;
          case 'lastUpdatedBy': _staffData!.lastUpdatedBy = newValue; break;
          case 'lastUpdatedByEmail': _staffData!.lastUpdatedByEmail = newValue; break;
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
          );
          setState(() {
            isSynced = true;
            newSynced = true;
            _staffData!.isSynced = true;
          });
          Fluttertoast.showToast(
            msg: "Syncing Completed...",
          );
        });
      } catch (e) {
        Fluttertoast.showToast(
          msg: "Sync Error: ${e.toString()}",
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

    locationsRef = FirebaseFirestore.instance.collection('Location').doc(state).collection(state);

    QuerySnapshot snapshot = await locationsRef.get();
    List<String> locations = snapshot.docs.map((doc) => doc['LocationName'] as String).toList();

    return locations.map((location) => DropdownMenuItem<String>(
      value: location,
      child: Text(location, style: GoogleFonts.poppins()),
    )).toList();
  }


  Future<List<DropdownMenuItem<String>>> _fetchDepartmentsFromFirestore() async {
    CollectionReference departmentsRef = FirebaseFirestore.instance.collection('Departments');
    QuerySnapshot snapshot = await departmentsRef.get();
    List<String> departments = snapshot.docs.map((doc) => doc['departmentName'] as String).toList();

    return departments.map((department) => DropdownMenuItem<String>(
      value: department,
      child: Text(department, style: GoogleFonts.poppins()),
    )).toList();
  }
  Future<List<DropdownMenuItem<String>>> _fetchMaritalStatusFromFirestore() async {
    CollectionReference staffCategoryRef = FirebaseFirestore.instance.collection('MaritalStatus');
    QuerySnapshot snapshot = await staffCategoryRef.get();
    List<String> staffCategories = snapshot.docs.map((doc) => doc['name'] as String).toList();

    return staffCategories.map((category) => DropdownMenuItem<String>(
      value: category,
      child: Text(category, style: GoogleFonts.poppins()),
    )).toList();
  }
  Future<List<DropdownMenuItem<String>>> _fetchGenderFromFirestore() async {
    CollectionReference staffCategoryRef = FirebaseFirestore.instance.collection('Gender');
    QuerySnapshot snapshot = await staffCategoryRef.get();
    List<String> staffCategories = snapshot.docs.map((doc) => doc['name'] as String).toList();

    return staffCategories.map((category) => DropdownMenuItem<String>(
      value: category,
      child: Text(category, style: GoogleFonts.poppins()),
    )).toList();
  }

  Future<List<DropdownMenuItem<String>>> _fetchStaffCategoryFromFirestore() async {
    CollectionReference staffCategoryRef = FirebaseFirestore.instance.collection('StaffCategory');
    QuerySnapshot snapshot = await staffCategoryRef.get();
    List<String> staffCategories = snapshot.docs.map((doc) => doc['name'] as String).toList();

    return staffCategories.map((category) => DropdownMenuItem<String>(
      value: category,
      child: Text(category, style: GoogleFonts.poppins()),
    )).toList();
  }


  Future<List<DropdownMenuItem<String>>> _fetchDepartmentsForFacilityFromFirestore() async {
    CollectionReference departmentsRef = FirebaseFirestore.instance.collection('Designation');
    QuerySnapshot snapshot = await departmentsRef.get();
    List<String> allDepartments = snapshot.docs.map((doc) => doc.id).toList();
    List<String> departmentFilterList = ['Care and Treatment','Laboratory','Pharmacy and Logistics','Preventions','Strategic Information'];

    List<String> filteredDepartments = allDepartments.where((department) {
      return departmentFilterList.contains(department);
    }).toList();


    return filteredDepartments.map((department) => DropdownMenuItem<String>(
      value: department,
      child: Text(department, style: GoogleFonts.poppins()),
    )).toList();
  }


  Future<List<DropdownMenuItem<String>>> _fetchDesignationsFromFirestore(String department, String category) async {
    CollectionReference designationsRef;
    QuerySnapshot snapshot;
    designationsRef = FirebaseFirestore.instance.collection('Designation').doc(department).collection(department);
    if(category == "Facility Staff"){
      snapshot = await designationsRef.where('category', isEqualTo: "Facility Staff").get();
    }else{
      snapshot = await designationsRef.where('category', isEqualTo: "Office Staff").get();
    }


    List<String> designations = snapshot.docs.map((doc) => doc.id).toList();

    return designations.map((designation) => DropdownMenuItem<String>(
      value: designation,
      child: Text(designation, style: GoogleFonts.poppins()),
    )).toList();
  }



  Future<List<DropdownMenuItem<String>>> _fetchStatesFromFirestore(String category) async {
    CollectionReference statesRef = FirebaseFirestore.instance.collection('Location');
    QuerySnapshot snapshot = await statesRef.get();
    List<String> allStates = snapshot.docs.map((doc) => doc['name'] as String).toList();

    List<String> states;
    if (category == 'HQ Staff') {
      states = allStates.where((state) => state == "Federal Capital Territory").toList();
    } else {
      states = allStates.where((state) => state != "Federal Capital Territory").toList();
    }

    return states.map((state) => DropdownMenuItem<String>(
      value: state,
      child: Text(state, style: GoogleFonts.poppins()),
    )).toList();
  }

  Future<List<DropdownMenuItem<String>>> _fetchProjectsFromFirestore() async {
    CollectionReference projectsRef = FirebaseFirestore.instance.collection('Project');
    QuerySnapshot snapshot = await projectsRef.get();
    List<String> projects = snapshot.docs.map((doc) => doc['name'] as String).toList();

    return projects.map((project) => DropdownMenuItem<String>(
      value: project,
      child: Text(project, style: GoogleFonts.poppins()),
    )).toList();
  }


  Future<List<DropdownMenuItem<String>>> _fetchSupervisorsFromFirestore(String department, String state) async {
    CollectionReference supervisorsRef = FirebaseFirestore.instance.collection('Supervisors').doc(state).collection(state);
    QuerySnapshot snapshot = await supervisorsRef.where('department', isEqualTo: department).get();
    List<String> supervisors = snapshot.docs.map((doc) => doc['supervisor'] as String).toList();

    return supervisors.map((supervisor) => DropdownMenuItem<String>(
      value: supervisor,
      child: Text(supervisor, style: GoogleFonts.poppins()),
    )).toList();
  }



  Future<List<String?>> _getSupervisorEmailFromFirestore(String department, String supervisorName,String state) async {
    print("Supervisor Email State===$state");
    print("Supervisor Email supervisorName===$supervisorName");
    print("Supervisor Email department===$department");
    CollectionReference supervisorsRef = FirebaseFirestore.instance.collection('Supervisors').doc(state).collection(state);
    QuerySnapshot snapshot = await supervisorsRef.where('department', isEqualTo: department).where('supervisor',isEqualTo:supervisorName).get();
    List<String?> supervisorEmails = snapshot.docs.map((doc) => doc['email'] as String?).toList();

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
      leading: Icon(icon, color: maroonPrimary),
      title: Text(title, style: GoogleFonts.poppins(fontSize: fontSizeTitle, fontWeight: FontWeight.bold)),
      subtitle: initialValue != null
          ? Text(initialValue, style: GoogleFonts.poppins(fontSize: fontSizeSubtitle))
          : null,
      trailing: IconButton(
        icon: const Icon(Icons.edit_outlined, color: maroonPrimary),
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
          title: Text('Edit $title', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: TextField(
            onChanged: (value) {
              newValue = value;
            },
            style: GoogleFonts.poppins(),
            controller: TextEditingController(text: initialValue),
            decoration: InputDecoration(
              hintText: 'Enter new $title',
              hintStyle: GoogleFonts.poppins(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                onSave(newValue ?? "");
                Navigator.of(context).pop();
              },
              child: Text('Save', style: GoogleFonts.poppins(color: maroonPrimary, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}