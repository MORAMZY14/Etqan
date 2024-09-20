import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
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
  String _selectedCategory = 'All'; // Track selected category

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); // Initialize TabController
    _initializeData();
    _activateAppCheck();
    _monitorCourses();

  }

  @override
  void dispose() {
    _tabController.dispose(); // Dispose of TabController
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
        // Fetch user's profile image
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
      final DocumentSnapshot doc = await _firestore.collection('Users').doc(email.toLowerCase()).get();

      if (doc.exists) {
        final String name = doc['name'] ?? '';
        final String studentId = doc['studentID'] ?? '';
        setState(() {
          _userName = _getFirstName(name);
          _studentId = studentId;
        });
      } else {
        setState(() {
          _userName = 'User not found';
          _studentId = 'N/A';
        });
      }
    } catch (e) {
      print('Error fetching user data: $e');
      setState(() {
        _userName = 'Error';
        _studentId = 'N/A';
      });
    }
  }

  Future<void> _fetchUserProfileImage(String email) async {
    try {
      final String profileImagePath = 'users/$email/profile_picture.png'; // Assumes profile image is named 'profile.png'
      final String profileImageUrl = await _storage.ref(profileImagePath).getDownloadURL();
      setState(() {
        _profileImageUrl = profileImageUrl;
      });
    } catch (e) {
      print('Error fetching user profile image: $e');
      setState(() {
        _profileImageUrl = null; // Set to null if there's an error
      });
    }
  }

  Future<void> _fetchCoursesFromFirestore({String? status}) async {
    try {
      Query query = _firestore.collection('Courses');
      if (status != null) {
        query = query.where('status', isEqualTo: status);
      }
      final QuerySnapshot querySnapshot = await query.get();
      final List<CustomListItem> fetchedItems = querySnapshot.docs.map((doc) {
        return CustomListItem(
          name: doc['name'] ?? 'Unknown',
          content: '', // Assuming no content needed for courses
        );
      }).toList();
      setState(() {
        _items = fetchedItems;
      });
    } catch (e) {
      print('Error fetching courses from Firestore: $e');
    }
  }

  Future<void> _fetchCourseImagesFromStorage() async {
    try {
      final QuerySnapshot courseQuerySnapshot = await _firestore.collection('Courses').get();
      final Map<String, String> imageUrls = {};

      for (var courseDoc in courseQuerySnapshot.docs) {
        final String courseName = courseDoc['name'] ?? '';
        if (courseName.isNotEmpty) {
          try {
            final String courseImagePath = 'courses/$courseName/$courseName.png';
            final String courseImageUrl = await _storage.ref(courseImagePath).getDownloadURL();
            imageUrls[courseName] = courseImageUrl;
          } catch (e) {
            print('Error fetching image URL for $courseName: $e');
            imageUrls[courseName] = 'https://example.com/placeholder.png';
          }
        }
      }

      setState(() {
        _courseImages = imageUrls;
      });
    } catch (e) {
      print('Error fetching course images: $e');
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
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  Future<void> _monitorCourses() async {
    final loggedInUserEmail = FirebaseAuth.instance.currentUser?.email;

    if (loggedInUserEmail == null) return;

    final coursesStream = _firestore.collection('Courses').snapshots();

    coursesStream.listen((snapshot) {
      for (var doc in snapshot.docs) {
        final courseId = doc.id;
        final approvedUsers = doc.data().containsKey('ApprovedUsers') ? doc['ApprovedUsers'] as List<dynamic> : [];
        final signedUsers = doc.data().containsKey('signedUsers') ? doc['signedUsers'] as List<dynamic> : [];

        // Compare the logged-in user's email with ApprovedUsers
        if (approvedUsers.contains(loggedInUserEmail)) {
          _sendNotification(courseId, 'You have been approved for the course: $courseId');
        }

        // Update the previousSignedUsers for future comparisons
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
      "headings": {"en": "Course"},
      "contents": {"en": "$message "},
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
                  // Handle settings option
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
          : BottomBar(
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
        start: 20.0,
        onTap: _onItemTapped,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildMainPage(),
            _buildWishlistPage(),
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
        crossAxisAlignment: CrossAxisAlignment.start,
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

  Widget _buildWishlistPage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildModernButton(
              icon: Icons.checklist_rounded,
              color: Colors.blue,
              label: 'Select Courses',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const WishlistPage()),
                );
              },
            ),
            const SizedBox(height: 16),
            _buildModernButton(
              icon: Icons.delete,
              color: Colors.red,
              label: 'Delete Course',
              onPressed: () {
                _deleteCourse();
              },
            ),
            const SizedBox(height: 16),
            _buildModernButton(
              icon: Icons.list,
              color: Colors.green,
              label: 'Show All Courses',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RegisteredCoursesPage()),
                );
                _showAllCourses();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white),
      label: Text(label, style: const TextStyle(color: Colors.white)),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        backgroundColor: color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        elevation: 4,
      ),
    );
  }

  Widget _buildTopSection(bool isSmallScreen) {
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/login1.png'), // Background image
          fit: BoxFit.cover,
        ),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(30), // Adjust the radius as needed
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(30), // Ensure the content respects the border radius
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGreetingAndNotificationIcon(isSmallScreen),
          ],
        ),
      ),
    );
  }

  void _onCategoryButtonPressed(String category) {
    setState(() {
      _selectedCategory = category;
    });
    _fetchCoursesFromFirestore(status: category == 'All' ? null : category.toLowerCase());
  }

  bool _isButtonDisabled(String category) {
    return _selectedCategory == category;
  }

  Widget _buildGreetingAndNotificationIcon(bool isSmallScreen) {
    return Padding(
      padding: const EdgeInsets.only(top: 40.0), // Add padding to push it down
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: isSmallScreen ? 25 : 30,
                backgroundImage: _profileImageUrl != null
                    ? NetworkImage(_profileImageUrl!)
                    : const AssetImage('assets/etqan.png') as ImageProvider,
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hello, $_userName',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isSmallScreen ? 18 : 24,
                    ),
                  ),
                  Text(
                    'ID: $_studentId',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isSmallScreen ? 14 : 18,
                    ),
                  ),
                ],
              ),
            ],
          ),
          IconButton(
            icon: Icon(
              Icons.settings,
              color: Colors.white,
              size: isSmallScreen ? 30 : 36,
            ),
            onPressed: _showOptionsDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryButtons(bool isSmallScreen) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildCategoryButton(
          label: 'All',
          icon: Icons.list_alt,
          onPressed: () => _onCategoryButtonPressed('All'),
          isDisabled: _isButtonDisabled('All'),
        ),
        const SizedBox(width: 10),
        _buildCategoryButton(
          label: 'Popular',
          icon: Icons.trending_up,
          onPressed: () => _onCategoryButtonPressed('Popular'),
          isDisabled: _isButtonDisabled('Popular'),
        ),
        const SizedBox(width: 10),
        _buildCategoryButton(
          label: 'New',
          icon: Icons.new_releases,
          onPressed: () => _onCategoryButtonPressed('New'),
          isDisabled: _isButtonDisabled('New'),
        ),
      ],
    );
  }

  Widget _buildCategoryButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    required bool isDisabled,
  }) {
    return ElevatedButton.icon(
      onPressed: isDisabled ? null : onPressed,
      icon: Icon(icon, color: isDisabled ? Colors.grey : Colors.white),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 16,
          color: isDisabled ? Colors.grey : Colors.white,
        ),
      ),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
        backgroundColor: isDisabled ? Colors.grey : Colors.blueAccent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
    );
  }


  Widget _buildTrendingCoursesSection(bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 20 : 40),
          child: Text(
            'Trending Courses',
            style: TextStyle(
              fontSize: isSmallScreen ? 20 : 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 10),
        _items.isEmpty
            ? Padding(
          padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 20 : 40),
          child: Text(
            'No courses found',
            style: TextStyle(
              fontSize: isSmallScreen ? 16 : 20,
              color: Colors.grey,
            ),
          ),
        )
            : _buildCoursesList(isSmallScreen),
      ],
    );
  }
  Widget _buildCoursesList(bool isSmallScreen) {
    return SizedBox(
      height: isSmallScreen ? 200 : 250,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          final courseImage = _courseImages[item.name] ?? 'https://example.com/placeholder.png';

          return GestureDetector(
            onTap: () {
              // Navigate to CourseDetailedPage with item details
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CourseDetailedPage(
                    courseName: item.name,
                    courseImage: courseImage, courseDescription: '', imageUrl: '', courseImageUrl: '',
                  ),
                ),
              );
            },
            child: Container(
              width: isSmallScreen ? 160 : 200,
              margin: EdgeInsets.symmetric(horizontal: isSmallScreen ? 10 : 15),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                image: DecorationImage(
                  image: NetworkImage(courseImage),
                  fit: BoxFit.cover,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 10 : 15),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(20),
                        ),
                      ),
                      child: Text(
                        item.name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isSmallScreen ? 14 : 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }




  Widget _buildProfilePage() {
    return const Center(
      child: Text(
        'Profile Page',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
    );
  }

  Future<void> _showAllCourses() async {
    try {
      await _fetchCoursesFromFirestore();
    } catch (e) {
      print('Error showing all courses: $e');
    }
  }

  Future<void> _deleteCourse() async {
    // Add logic to delete a course
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
