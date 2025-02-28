class UserModel {
  static String id = "";
  static String staffId = " ";
  static double lat = 0;
  static double long = 0;
  static String firstName = " ";
  static String lastName = " ";
  static String project = " ";
  static String state = " ";
  static String emailAddress = "";
  static String profilePicLink = " ";
  static String department = " ";
  static String designation = " ";
  static String location = " ";
  static String mobile = " ";
  static String role = "";
  static String staffCategory = " ";
  static bool canEdit = true;
  static String password = " ";
  //static String birthDate = " ";
  //static String address = " ";

  String? email;
  String? wrole;
  String? uid;

// // receiving data
//   UserModel({this.uid, this.email, this.wr ole});
//   factory UserModel.fromMap(map) {
//     return UserModel(
//       uid: map['id'],
//       email: map['emailAddress'],
//       wrole: map['role'],
//     );
//   }

// receiving data
  UserModel({this.uid, this.email, this.wrole});
  factory UserModel.fromMap(map) {
    return UserModel(
      email: map['emailAddress'],
      uid: map['id'],
      wrole: map['role'],
    );
  }

// sending data
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'emailAddress': emailAddress,
      'role': role,
    };
  }
}
