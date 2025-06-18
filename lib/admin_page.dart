import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:http/http.dart' as http;
import 'admins_user_edit.dart';
import 'announcement_admin_page.dart';
import 'bottom_bar_admin.dart';
import 'admin_login_page.dart';
import 'course_management_page.dart';
import 'admin-settings_page.dart';
import 'approval_admin_page.dart';
import 'payment_approval_page.dart';
import 'admin_report_page.dart';

class AdminPage extends StatefulWidget {
  final String email;

  const AdminPage({super.key, required this.email});

  @override
  _AdminPageState createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  late Map<String, List<dynamic>> _previousSignedUsers = {};

  String _userName = 'Loading...';
  String _adminId = 'Loading...';
  bool _isLoading = true;
  int _selectedIndex = 0;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeData();
    _activateAppCheck();
    _monitorCourses();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);
    try {
      await _fetchAdminData(widget.email);
    } catch (e) {
      print('Error initializing data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _activateAppCheck() async {
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.playIntegrity,
        appleProvider: AppleProvider.deviceCheck,
      );
      OneSignal.initialize("151302a4-82cd-4872-8135-4d15a4f43a83");
      OneSignal.Notifications.requestPermission(true);
    } catch (e) {
      print('Error activating Firebase App Check: $e');
    }
  }

  Future<void> _fetchAdminData(String email) async {
    try {
      final DocumentSnapshot doc = await _firestore.collection('Admins').doc(email).get();

      if (doc.exists) {
        final String name = doc['name'] ?? '';
        final String adminId = doc['adminID'] ?? '';
        setState(() {
          _userName = _getFirstName(name);
          _adminId = adminId;
        });
      } else {
        print('Admin document not found for email: $email');
        setState(() {
          _userName = 'Admin not found';
          _adminId = 'N/A';
        });
      }
    } catch (e) {
      print('Error fetching admin data for email $email: $e');
      setState(() {
        _userName = 'Error';
        _adminId = 'N/A';
      });
    }
  }

  String _getFirstName(String fullName) {
    return fullName.split(' ').firstWhere((part) => part.isNotEmpty, orElse: () => '');
  }

  Future<void> _logout() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const AdminLoginPage()),
    );
  }

  void _showOptionsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1F2B),
          contentPadding: EdgeInsets.zero,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildOptionTile(Icons.settings, 'Settings', () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsPage()),
                );
              }),
              _buildOptionTile(Icons.logout, 'Logout', () {
                Navigator.pop(context);
                _logout();
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOptionTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      onTap: onTap,
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _tabController.animateTo(index);
  }

  Future<void> _monitorCourses() async {
    final loggedInUserEmail = FirebaseAuth.instance.currentUser?.email;
    if (loggedInUserEmail == null) return;

    final coursesStream = _firestore.collection('Courses').snapshots();
    coursesStream.listen((snapshot) {
      for (var doc in snapshot.docs) {
        final courseId = doc.id;
        final signedUsers = doc['signedUsers'] as List<dynamic>? ?? [];
        final approvedUsers = doc['ApprovedUsers'] as List<dynamic>? ?? [];

        if (_previousSignedUsers.containsKey(courseId)) {
          final previousSignedUsers = _previousSignedUsers[courseId] ?? [];
          final newUsers = signedUsers.where((user) => !previousSignedUsers.contains(user)).toList();
          final removedUsers = previousSignedUsers.where((user) => !signedUsers.contains(user)).toList();

          if (newUsers.isNotEmpty) {
            for (var user in newUsers) {
              _sendNotification(courseId, 'New Student Registered: $user');
            }
          }

          if (removedUsers.isNotEmpty) {
            for (var user in removedUsers) {
              if (!approvedUsers.contains(user)) {
                _sendNotification(courseId, 'Student Has Unregistered: $user');
              }
            }
          }
        }

        _previousSignedUsers[courseId] = signedUsers;
      }
    });
  }

  Future<void> _sendNotification(String courseId, String message) async {
    final headers = {
      'Content-Type': 'application/json; charset=utf-8',
      'Authorization': 'Basic MGZhZjUwOGQtYmY0NS00ZGEwLWFjZjItNzRmODVlMTMzNTJk',
    };

    final payload = jsonEncode({
      "app_id": "151302a4-82cd-4872-8135-4d15a4f43a83",
      "headings": {"en": "New Registration"},
      "contents": {"en": "$message for course $courseId"},
      "included_segments": ["All"],
    });

    final response = await http.post(
      Uri.parse("https://onesignal.com/api/v1/notifications"),
      headers: headers,
      body: payload,
    );

    if (response.statusCode == 200) {
      print('Notification sent successfully.');
    } else {
      print('Failed to send notification. Status code: ${response.statusCode}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F111E),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
        ),
      )
          : BottomBarAdmin(
        currentPage: _selectedIndex,
        tabController: _tabController,
        colors: const [
          Color(0xFF6C63FF),
          Color(0xFF4CAF50),
          Color(0xFF2196F3),
        ],
        unselectedColor: const Color(0xFF2D2F3E),
        barColor: const Color(0xFF1E1F2B),
        end: 0.0,
        start: 10.0,
        onTap: _onItemTapped,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildMainPage(),
            _buildProfilePage(),
          ],
        ),
      ),
    );
  }

  Widget _buildMainPage() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildTopSection(),
          const SizedBox(height: 24),
          _buildCategoryGrid(),
          const SizedBox(height: 24),
          _buildTrendingCoursesSection(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildTopSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1F2B),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Welcome back,',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Dr. $_userName!',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications, color: Colors.white),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onPressed: _showOptionsDialog,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF2D2F3E),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const TextField(
              decoration: InputDecoration(
                hintText: 'Search courses, students...',
                hintStyle: TextStyle(color: Colors.white54),
                border: InputBorder.none,
                suffixIcon: Icon(Icons.search, color: Colors.white54),
              ),
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryGrid() {
    final categories = [
      {
        'title': 'Courses',
        'icon': Icons.menu_book,
        'color': const Color(0xFF6C63FF),
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CourseManagementPage()),
        ),
      },
      {
        'title': 'Announce',
        'icon': Icons.notifications,
        'color': const Color(0xFFFF6B6B),
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) =>  AnnouncementsPage()),
        ),
      },
      {
        'title': 'Approval',
        'icon': Icons.check_circle,
        'color': const Color(0xFF4CAF50),
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ApproveRequestsPage()),
        ),
      },
      {
        'title': 'Payment Approval',
        'icon': Icons.payment,
        'color': const Color(0xFFFFA726),
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const PaymentApprovalPage()),
        ),
      },
      {
        'title': 'Users',
        'icon': Icons.people,
        'color': const Color(0xFF26C6DA),
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) =>  AdminsUserEditPage()),
        ),
      },
      {
        'title': 'Settings',
        'icon': Icons.settings,
        'color': const Color(0xFF9C27B0),
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SettingsPage()),
        ),
      },
      {
        'title': 'Reports',
        'icon': Icons.bar_chart,
        'color': const Color(0xFFF44336),
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ReportPage()),
        ),
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.9,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        return GestureDetector(
          onTap: category['onTap'] as void Function(),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E1F2B),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: category['color'] as Color,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    category['icon'] as IconData,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  category['title'] as String,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTrendingCoursesSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Trending Courses',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'View All',
                style: TextStyle(
                  color: Color(0xFF6C63FF),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('Courses').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
                      ));
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text(
                        'No courses available',
                        style: TextStyle(color: Colors.white70),
                      ),
                    );
                  }

                  final courses = snapshot.data!.docs;
                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: courses.length,
                    itemBuilder: (context, index) {
                      final course = courses[index];
                      final imageUrl = _getImageUrl(course.id);
                      return Container(
                        width: 280,
                        margin: const EdgeInsets.only(right: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1F2B),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  topRight: Radius.circular(16),
                                ),
                                child: Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      color: const Color(0xFF2D2F3E),
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
                                        ),
                                      ),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: const Color(0xFF2D2F3E),
                                      child: const Center(
                                        child: Icon(Icons.image, color: Color(0xFF6C63FF)),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    course['name'] ?? 'Unnamed Course',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.people, size: 14, color: Colors.white70),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${course['signedUsers']?.length ?? 0} students',
                                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildActivityItem(IconData icon, String title, String description, String time, Color color) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfilePage() {
    return const Center(
      child: Text(
        'Profile Page',
        style: TextStyle(color: Colors.white, fontSize: 24),
      ),
    );
  }

  String _getImageUrl(String courseId) {
    return 'https://firebasestorage.googleapis.com/v0/b/${_storage.bucket}/o/courses%2F$courseId%2F$courseId.png?alt=media';
  }
}