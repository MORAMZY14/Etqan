import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'admins_user_edit.dart';
import 'announcement_admin_page.dart';
import 'bottom_bar_admin.dart';
import 'admin_login_page.dart';
import 'course_management_page.dart';
import 'admin-settings_page.dart';
import 'firebase_notifications.dart';


class AdminPage extends StatefulWidget {
  final String email;

  const AdminPage({super.key, required this.email});


  @override
  _AdminPageState createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  late String _fcmToken;




  String _userName = 'Loading...';
  String _adminId = 'Loading...';
  bool _isLoading = true;
  int _selectedIndex = 0;
  late TabController _tabController;


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeData();
    _activateAppCheck();

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



    } catch (e) {
      print('Error activating Firebase App Check: $e');
    }
  }


  Future<void> _fetchAdminData(String email) async {
    try {
      final DocumentSnapshot doc = await _firestore.collection('Admins').doc(
          email).get();

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
    return fullName.split(' ').firstWhere((part) => part.isNotEmpty,
        orElse: () => '');
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
          contentPadding: EdgeInsets.zero,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Settings'),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Logout'),
                onTap: () {
                  Navigator.pop(context);
                  _logout();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _tabController.animateTo(index);
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : BottomBarAdmin(
        currentPage: _selectedIndex,
        tabController: _tabController,
        colors: const [
          Colors.blue,
          Colors.red,
          Colors.green,
        ],
        unselectedColor: Colors.grey,
        barColor: Colors.white,
        end: 0.0,
        start: 10.0,
        onTap: _onItemTapped,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildMainPage(),
            _buildAdminActionsPage(),
            _buildProfilePage(),
          ],
        ),
      ),
    );
  }

  Widget _buildMainPage() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    return SingleChildScrollView(
      child: Column(
        children: [
          _buildTopSection(isSmallScreen),
          const SizedBox(height: 20),
          _buildCategoryButtons(isSmallScreen),
          const SizedBox(height: 20),
          _buildTrendingCoursesSection(isSmallScreen),
        ],
      ),
    );
  }

  Widget _buildAdminActionsPage() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    return SingleChildScrollView(
      child: Column(
        children: [
          _buildAdminActionsSection(isSmallScreen),
          const SizedBox(height: 20),
          _buildCourseManagementSection(isSmallScreen),
        ],
      ),
    );
  }

  Widget _buildProfilePage() {
    return const Center(
      child: Text('Profile Page', style: TextStyle(fontSize: 24)),
    );
  }

  Widget _buildTopSection(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 20 : 40,
        vertical: isSmallScreen ? 30 : 50,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF160E30),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGreetingAndNotificationIcon(isSmallScreen),
          const SizedBox(height: 20),
          Text(
            'Manage your courses here!',
            style: TextStyle(
              color: Colors.white,
              fontSize: isSmallScreen ? 24 : 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          _buildSearchBar(isSmallScreen),
        ],
      ),
    );
  }

  Widget _buildGreetingAndNotificationIcon(bool isSmallScreen) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: isSmallScreen ? 25 : 30,
              backgroundImage: const AssetImage('assets/etqan.png'),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, Dr. $_userName!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isSmallScreen ? 18 : 24,
                  ),
                ),
                Text(
                  'ID: $_adminId',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isSmallScreen ? 12 : 16,
                  ),
                ),
              ],
            ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onPressed: _showOptionsDialog,
        ),
      ],
    );
  }

  Widget _buildSearchBar(bool isSmallScreen) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const TextField(
        decoration: InputDecoration(
          hintText: 'Search',
          border: InputBorder.none,
          suffixIcon: Icon(Icons.search, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildCategoryButtons(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 20 : 40),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildCategoryButton('Courses', Icons.book, Colors.blue, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) =>   CourseManagementPage()),
                );
              }),
              _buildCategoryButton('Announce', Icons.notifications, Colors.red, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) =>   AnnouncementsPage()),
                );
              }),
              _buildCategoryButton('Grades', Icons.grade, Colors.green, () {}),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildCategoryButton('Payments', Icons.payment, Colors.orange, () {}),
              _buildCategoryButton('Users', Icons.people, Colors.purple, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) =>   AdminsUserEditPage()),
                );
              }),
              _buildCategoryButton('Settings', Icons.settings, Colors.grey, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) =>  const SettingsPage()),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryButton(String title, IconData icon, Color color, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 100,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(height: 5),
            Text(title, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendingCoursesSection(bool isSmallScreen) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('Courses').where('status', isEqualTo: 'trendy').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No trending courses available.'));
        }

        final courses = snapshot.data!.docs;

        return Container(
          padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 20 : 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Trending Courses',
                style: TextStyle(
                  fontSize: isSmallScreen ? 18 : 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: isSmallScreen ? 200 : 250,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: courses.length,
                  itemBuilder: (context, index) {
                    final course = courses[index];
                    final imageUrl = _getImageUrl(course.id);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Image.network(imageUrl, fit: BoxFit.cover, height: 120, width: 160),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(course['name']),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getImageUrl(String courseId) {
    return 'https://firebasestorage.googleapis.com/v0/b/${_storage.bucket}/o/courses%2F$courseId%2F$courseId.png?alt=media';
  }

  Widget _buildAdminActionsSection(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 20 : 40,
        vertical: isSmallScreen ? 20 : 40,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Admin Actions',
            style: TextStyle(
              fontSize: isSmallScreen ? 18 : 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          _buildActionButton('Add New Course', Icons.add, Colors.blue, () {
            // Add your functionality here
          }),
          const SizedBox(height: 10),
          _buildActionButton('Manage Courses', Icons.manage_search, Colors.green, () {
            // Add your functionality here
          }),
          const SizedBox(height: 10),
          _buildActionButton('View Announcements', Icons.announcement, Colors.orange, () {
            // Add your functionality here
          }),
        ],
      ),
    );
  }

  Widget _buildCourseManagementSection(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 20 : 40,
        vertical: isSmallScreen ? 20 : 40,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Course Management',
            style: TextStyle(
              fontSize: isSmallScreen ? 18 : 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          _buildActionButton('Manage Courses', Icons.school, Colors.blue, () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CourseManagementPage()),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildActionButton(String title, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white),
      label: Text(title, style: const TextStyle(color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}
