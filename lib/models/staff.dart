import 'package:cloud_firestore/cloud_firestore.dart';

class Staff {
  final String id;
  final String firstName;
  final String lastName;
  final String emailAddress;
  final String mobile;
  final String staffCategory;
  final String project;
  final String state; // This will store the STATE NAME (e.g., "Lagos")
  final String stateId; // This will store the STATE DOCUMENT ID
  final String location;
  final String department;
  final String designation;
  final String supervisor;
  final String supervisorEmail;
  final String role;
  final String gender;
  final String maritalStatus;
  final String photoUrl;
  final bool disabled; // <-- ADD THIS
  final String bankName;
  final String accountNumber;
  final String sortCode;


  String get fullName => '$firstName $lastName'.trim();

  Staff({
    required this.id,
    this.firstName = '',
    this.lastName = '',
    this.emailAddress = '',
    this.mobile = '',
    this.staffCategory = '',
    this.project = '',
    this.state = '',
    this.stateId = '',
    this.location = '',
    this.department = '',
    this.designation = '',
    this.supervisor = '',
    this.supervisorEmail = '',
    this.role = '',
    this.gender = '',
    this.maritalStatus = '',
    this.photoUrl = '',
    this.disabled = false,
    this.bankName = '',
    this.accountNumber = '',
    this.sortCode = '',
  });


  // Helper getter for full name
  //String get fullName => '$firstName $lastName'.trim();

  factory Staff.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Staff(
      id: doc.id,
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      emailAddress: data['emailAddress'] ?? '',
      mobile: data['mobile'] ?? '',
      staffCategory: data['staffCategory'] ?? '',
      project: data['project'] ?? '',
      state: data['state'] ?? '',
      stateId: data['stateId'] ?? '',
      location: data['location'] ?? '',
      department: data['department'] ?? '',
      designation: data['designation'] ?? '',
      supervisor: data['supervisor'] ?? '',
      supervisorEmail: data['supervisorEmail'] ?? '',
      role: data['role'] ?? '',
      gender: data['gender'] ?? '',
      maritalStatus: data['maritalStatus'] ?? '',
      photoUrl: data['photoUrl'] ?? '',
      disabled: data['disabled'] ?? false, // <-- ADD THIS
      bankName: data['bankName'] ?? '',
      accountNumber: data['accountNumber'] ?? '',
      sortCode: data['sortCode'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'emailAddress': emailAddress,
      'mobile': mobile,
      'staffCategory': staffCategory,
      'project': project,
      'state': state,
      'stateId': stateId,
      'location': location,
      'department': department,
      'designation': designation,
      'supervisor': supervisor,
      'supervisorEmail': supervisorEmail,
      'role': role,
      'gender': gender,
      'maritalStatus': maritalStatus,
      'photoUrl': photoUrl,
      'bankName': bankName,
      'accountNumber': accountNumber,
      'sortCode': sortCode,
    };
  }
}