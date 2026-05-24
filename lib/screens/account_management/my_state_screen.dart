// IMPORTANT: Adjust these import paths to match your project structure.
import 'package:service_delivery_workspace/models/staff.dart';
import 'package:service_delivery_workspace/screens/account_management/location_staff_list_screen.dart';
import 'package:service_delivery_workspace/screens/registration_page.dart';
import 'package:service_delivery_workspace/screens/supervisor/supervisor_list_screen.dart';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../../widgets/drawer2.dart';

class MyStateScreen extends StatefulWidget {
  const MyStateScreen({super.key});

  @override
  State<MyStateScreen> createState() => _MyStateScreenState();
}

class _MyStateScreenState extends State<MyStateScreen> {
  // State variables to manage the UI based on data fetching status
  bool _isLoading = true;
  String? _errorMessage;
  String? _stateName;
  String? _stateId;

  // Special identifiers for our action cards
  static const String _manageSupervisorsAction = '__manageSupervisorsAction__';
  static const String _createUserAction = '__createUserAction__';

  @override
  void initState() {
    super.initState();
    _fetchUserState();
  }

  /// Fetches the current user's assigned state name and ID.
  Future<void> _fetchUserState() async {
    // ... (This fetch logic remains unchanged)
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("You are not logged in.");

      final staffDoc = await FirebaseFirestore.instance.collection('Staff').doc(user.uid).get();
      if (!staffDoc.exists) throw Exception("Your staff profile could not be found.");

      final stateName = staffDoc.data()?['state'] as String?;
      if (stateName == null || stateName.isEmpty) throw Exception("State is not assigned to your profile.");

      final locationQuery = await FirebaseFirestore.instance.collection('Location').where('name', isEqualTo: stateName).limit(1).get();
      if (locationQuery.docs.isEmpty) throw Exception("The state '$stateName' in your profile does not exist.");

      final stateId = locationQuery.docs.first.id;

      if (mounted) {
        setState(() {
          _stateName = stateName;
          _stateId = stateId;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst("Exception: ", "");
          _isLoading = false;
        });
      }
    }
  }

  /// Builds the main content of the page based on the current state (loading, error, or success)
  Widget _buildBodyContent() {
    if (_isLoading) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_errorMessage != null) {
      return SliverFillRemaining(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Text('Error: $_errorMessage', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 18)),
          ),
        ),
      );
    }

    return SliverToBoxAdapter(
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('Staff').where('state', isEqualTo: _stateName!).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Padding(padding: EdgeInsets.only(top: 50.0), child: CircularProgressIndicator(color: Colors.white)),
            );
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
          }

          // Group staff by category
          final Map<String, List<Staff>> groupedByCategory = {};
          if (snapshot.hasData) {
            for (var doc in snapshot.data!.docs) {
              final staff = Staff.fromFirestore(doc);
              final category = staff.staffCategory.isEmpty ? 'Uncategorized' : staff.staffCategory;
              groupedByCategory.putIfAbsent(category, () => []).add(staff);
            }
          }

          final categories = groupedByCategory.keys.toList()..sort();

          // --- NEW: Combine categories with action items for the grid ---
          final List<Object> gridItems = [
            ...categories,
            _manageSupervisorsAction,
            _createUserAction,
          ];

          return Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 700),
              child: GridView.builder(
                padding: const EdgeInsets.all(24.0),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.85, // Aspect ratio can be adjusted
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                ),
                itemCount: gridItems.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  final item = gridItems[index];

                  // --- NEW: Conditionally build the correct card ---
                  if (item == _manageSupervisorsAction) {
                    return _ActionCard(
                      title: 'Manage Supervisors',
                      icon: Icons.supervisor_account,
                      color: Colors.blue.shade700,
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => SupervisorListScreen(
                            stateName: _stateName!,
                            stateId: _stateId!,
                          ),
                        ));
                      },
                    );
                  } else if (item == _createUserAction) {
                    return _ActionCard(
                      title: 'Create New User',
                      icon: Icons.person_add_alt_1_rounded,
                      color: Colors.red.shade700,
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const RegistrationPageWeb(),
                        ));
                      },
                    );
                  } else {
                    // It's a staff category
                    final category = item as String;
                    final staffList = groupedByCategory[category] ?? [];
                    return _CategoryCard(
                      category: category,
                      staffList: staffList,
                      stateName: _stateName!,
                      stateId: _stateId!,
                    );
                  }
                },
              ),
            ),
          );
        },
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      drawer: drawer2(context),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF5C1A2E), Color(0xFF2E0215)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SelectionArea(
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                title: Text(
                  _isLoading ? 'Loading...' : '${_stateName ?? 'My State'} Dashboard',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, color: Colors.white),
                ),
                backgroundColor: Colors.transparent,
                elevation: 0,
                centerTitle: true,
                pinned: true,
                iconTheme: const IconThemeData(color: Colors.white),
              ),
  
              // Tutorial Banner
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.amber.shade200,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.amber.shade700,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Need help with account management?',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.amber.shade800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: () async {
                                const url = 'https://youtu.be/dTBm7-FNI_g';
                                if (await canLaunch(url)) {
                                  await launch(url);
                                } else {
                                  Fluttertoast.showToast(
                                    msg: "Could not open tutorial link",
                                    toastLength: Toast.LENGTH_SHORT,
                                    gravity: ToastGravity.BOTTOM,
                                    backgroundColor: Colors.red,
                                    textColor: Colors.white,
                                  );
                                }
                              },
                              child: Text(
                                'View Tutorial',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.amber.shade600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
  
              _buildBodyContent(),
            ],
          ),
        ),
      ),
      // --- REMOVED: No more FloatingActionButton here ---
    );
  }
}

// --- NEW: A dedicated card for actions ---
class _ActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20.0),
      child: Card(
        elevation: 8,
        color: Colors.white.withOpacity(0.95),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
          side: const BorderSide(color: Color(0xFFD4A03C), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: color),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF5C1A2E),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// The CategoryCard widget remains the same
class _CategoryCard extends StatelessWidget {
  final String category;
  final List<Staff> staffList;
  final String stateName;
  final String stateId;

  const _CategoryCard({
    required this.category,
    required this.staffList,
    required this.stateName,
    required this.stateId,
  });

  @override
  Widget build(BuildContext context) {
    final icons = {
      "Facility Staff": Icons.local_hospital_outlined,
      "State Office Staff": Icons.corporate_fare_outlined,
      "Facility Supervisor": Icons.supervisor_account_outlined,
      "HQ Staff": Icons.domain_verification_outlined,
    };

    return InkWell(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => LocationStaffListScreen(
            stateName: stateName,
            stateId: stateId,
            staffCategory: category,
          ),
        ));
      },
      borderRadius: BorderRadius.circular(20.0),
      child: Card(
        elevation: 8,
        color: Colors.white.withOpacity(0.95),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
          side: const BorderSide(color: Color(0xFFD4A03C), width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icons[category] ?? Icons.people_outline,
                  size: 48, color: const Color(0xFF5C1A2E)),
              const Spacer(),
              Text('${staffList.length}',
                  style: GoogleFonts.poppins(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF5C1A2E),
                      height: 1)),
              Text(category,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700)),
            ],
          ),
        ),
      ),
    );
  }
}