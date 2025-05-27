import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:http/http.dart' as http;
import 'login_page.dart';
import 'bottom_bar.dart';
import 'course_detailed_page.dart';
import 'wishlist_page.dart';
import 'show_courses_users_page.dart';

class UserPage extends StatefulWidget {
  final String email;

  const UserPage({super.key, required this.email});

  @override
  _UserPageState createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String _userName = 'Loading...';
  String _studentId = 'Loading...';
  String? _profileImageUrl;
  List<CustomListItem> _items = [];
  Map<String, String> _courseImages = {};
  late Map<String, List<dynamic>> _previousSignedUsers = {};
  bool _isLoading = true;
  int _selectedIndex = 0;
  late TabController _tabController;
  String _selectedCategory = 'All';

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
      await Future.wait([
        _fetchUserData(widget.email),
        _fetchCoursesFromFirestore(),
        _fetchCourseImagesFromStorage(),
        _fetchUserProfileImage(widget.email),
      ]);
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

  Future<void> _fetchUserData(String email) async {
    try {
      final DocumentSnapshot doc =
      await _firestore.collection('Users').doc(email.toLowerCase()).get();

      final String name = doc['name']?.toString() ?? 'Unknown User';
      final String studentId = doc['studentID']?.toString() ?? 'N/A';

      setState(() {
        _userName = _getFirstName(name);
        _studentId = studentId;
      });
    } catch (e) {
      setState(() {
        _userName = 'Error Loading';
        _studentId = 'ID: N/A';
      });
    }
  }

  String _getFirstName(String fullName) {
    final parts = fullName.split(' ').where((part) => part.isNotEmpty).toList();
    return parts.isNotEmpty ? parts.first : 'User';
  }

  Future<void> _fetchUserProfileImage(String email) async {
    try {
      final profileImagePath = 'users/$email/profile_picture.png';
      final profileImageUrl = await _storage.ref(profileImagePath).getDownloadURL();
      setState(() => _profileImageUrl = profileImageUrl);
    } catch (e) {
      setState(() => _profileImageUrl = null);
    }
  }

  Future<void> _fetchCoursesFromFirestore({String? status}) async {
    try {
      Query query = _firestore.collection('Courses');
      if (status != null) query = query.where('status', isEqualTo: status);

      final QuerySnapshot snapshot = await query.get();
      final List<CustomListItem> courses = snapshot.docs.map((doc) {
        return CustomListItem(
          name: doc['name']?.toString() ?? 'Unnamed Course',
          content: doc['content']?.toString() ?? '',
        );
      }).toList();

      setState(() => _items = courses);
    } catch (e) {
      print('Error fetching courses: $e');
    }
  }

  Future<void> _fetchCourseImagesFromStorage() async {
    try {
      final QuerySnapshot snapshot = await _firestore.collection('Courses').get();
      final Map<String, String> images = {};

      for (var doc in snapshot.docs) {
        final name = doc['name']?.toString() ?? '';
        if (name.isNotEmpty) {
          try {
            final path = 'courses/$name/$name.png';
            final url = await _storage.ref(path).getDownloadURL();
            images[name] = url;
          } catch (e) {
            images[name] = 'https://via.placeholder.com/150';
          }
        }
      }

      setState(() => _courseImages = images);
    } catch (e) {
      print('Error fetching course images: $e');
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  Future<void> _monitorCourses() async {
    final userEmail = FirebaseAuth.instance.currentUser?.email;
    if (userEmail == null) return;

    _firestore.collection('Courses').snapshots().listen((snapshot) {
      for (var doc in snapshot.docs) {
        final approved = doc['ApprovedUsers'] as List<dynamic>? ?? [];
        if (approved.contains(userEmail)) {
          _sendNotification(doc.id, 'Approved for course: ${doc.id}');
        }
        _previousSignedUsers[doc.id] = doc['signedUsers'] as List<dynamic>? ?? [];
      }
    });
  }

  Future<void> _sendNotification(String courseId, String message) async {
    try {
      final response = await http.post(
        Uri.parse("https://onesignal.com/api/v1/notifications"),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Basic MGZhZjUwOGQtYmY0NS00ZGEwLWFjZjItNzRmODVlMTMzNTJk',
        },
        body: jsonEncode({
          "app_id": "151302a4-82cd-4872-8135-4d15a4f43a83",
          "headings": {"en": "Course Update"},
          "contents": {"en": message},
          "included_segments": ["All"],
        }),
      );

      if (response.statusCode != 200) {
        print('Notification failed: ${response.statusCode}');
      }
    } catch (e) {
      print('Notification error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? _buildShimmerLoader()
          : BottomBar(
        currentPage: _selectedIndex,
        tabController: _tabController,
        colors: const [Colors.blueAccent, Colors.deepPurpleAccent],
        unselectedColor: Colors.grey[400]!,
        barColor: Colors.white,
        start: 20.0,  // Fixed parameter
        end: 0.0,     // Fixed parameter
        onTap: _onItemTapped,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildMainContent(),
            _buildWishlistContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 200,
          flexibleSpace: _buildProfileHeader(),
          pinned: true,
        ),
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildCategoryFilter(),
              const SizedBox(height: 25),
              _buildCourseGrid(),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileHeader() {
    return FlexibleSpaceBar(
      background: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue[800]!, Colors.blue[400]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: CircleAvatar(
                  radius: 32,
                  backgroundImage: _profileImageUrl != null
                      ? NetworkImage(_profileImageUrl!)
                      : const AssetImage('assets/default_avatar.png') as ImageProvider,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hello, $_userName',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'ID: $_studentId',
                      style: GoogleFonts.poppins(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.white),
                onPressed: _showSettingsDialog,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return SizedBox(
      height: 45,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: ['All', 'Popular', 'New'].length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final category = ['All', 'Popular', 'New'][index];
          final isSelected = _selectedCategory == category;
          return ChoiceChip(
            label: Text(category),
            selected: isSelected,
            onSelected: (_) => _updateCategory(category),
            labelStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
              color: isSelected ? Colors.white : Colors.blue[800],
            ),
            backgroundColor: Colors.grey[200],
            selectedColor: Colors.blue[800]!,
          );
        },
      ),
    );
  }

  void _updateCategory(String category) {
    setState(() => _selectedCategory = category);
    _fetchCoursesFromFirestore(status: category == 'All' ? null : category);
  }

  Widget _buildCourseGrid() {
    return _items.isEmpty
        ? _buildEmptyState()
        : GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.8,
        mainAxisSpacing: 15,
        crossAxisSpacing: 15,
      ),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final course = _items[index];
        final image = _courseImages[course.name] ?? '';
        return _buildCourseCard(course.name, image);
      },
    );
  }

  Widget _buildCourseCard(String title, String imageUrl) {
    return GestureDetector(
      onTap: () => _navigateToCourseDetail(title, imageUrl),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Stack(
            children: [
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey[200],
                  child: const Icon(Icons.broken_image, size: 40),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                    ),
                  ),
                  child: Text(
                    title,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWishlistContent() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildActionButton(
            icon: Icons.checklist_rounded,
            label: 'Select Courses',
            color: Colors.blueAccent,
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WishlistPage())),
          ),
          const SizedBox(height: 20),
          _buildActionButton(
            icon: Icons.delete_outline,
            label: 'Delete Course',
            color: Colors.redAccent,
            onPressed: _deleteCourse,
          ),
          const SizedBox(height: 20),
          _buildActionButton(
            icon: Icons.list_alt,
            label: 'Show All Courses',
            color: Colors.green,
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisteredCoursesPage()));
              _showAllCourses();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Material(
      borderRadius: BorderRadius.circular(15),
      elevation: 4,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Text(
                label,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 40, color: Colors.grey[400]),
          const SizedBox(height: 10),
          Text(
            'No courses available',
            style: GoogleFonts.poppins(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoader() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator.adaptive(),
          const SizedBox(height: 20),
          Text(
            'Loading your courses...',
            style: GoogleFonts.poppins(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        contentPadding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.blue),
              title: Text('Settings', style: GoogleFonts.poppins()),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: Text('Logout', style: GoogleFonts.poppins()),
              onTap: () {
                Navigator.pop(context);
                _logout();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    _tabController.animateTo(index);
  }

  void _navigateToCourseDetail(String title, String image) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CourseDetailedPage(
          courseName: title,
          courseImage: image,
          courseDescription: '',
          imageUrl: '',
          courseImageUrl: '',
        ),
      ),
    );
  }

  Future<void> _deleteCourse() async {
    // Implement course deletion logic
  }

  Future<void> _showAllCourses() async {
    try {
      await _fetchCoursesFromFirestore();
    } catch (e) {
      print('Error showing all courses: $e');
    }
  }
}

class CustomListItem {
  final String name;
  final String content;

  CustomListItem({
    required this.name,
    required this.content,
  });
}