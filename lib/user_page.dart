import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
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
  bool _isLoading = true;
  int _selectedIndex = 0;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); // Initialize TabController
    _initializeData();
    _activateAppCheck();
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
        _fetchUserProfileImage(widget.email), // Fetch user's profile image
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
        start: 10.0,
        onTap: _onItemTapped,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildMainPage(),
            _buildWishlistPage(),
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
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 20.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
        elevation: 5.0,
      ),
    );
  }

  Widget _buildTopSection(bool isSmallScreen) {
    return Container(
      decoration: BoxDecoration(
        image: const DecorationImage(
          image: AssetImage('assets/login1.png'), // Background image
          fit: BoxFit.cover,
        ),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(isSmallScreen ? 20 : 30), // Adjust the radius as needed
        ),
      ),
      padding: EdgeInsets.symmetric(
        vertical: isSmallScreen ? 10 : 20,
        horizontal: isSmallScreen ? 15 : 20,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(isSmallScreen ? 20 : 30), // Ensure the content respects the border radius
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

  Widget _buildGreetingAndNotificationIcon(bool isSmallScreen) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: isSmallScreen ? 30 : 40,
              backgroundImage: _profileImageUrl != null
                  ? NetworkImage(_profileImageUrl!)
                  : const AssetImage('assets/placeholder.png') as ImageProvider,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, $_userName!',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 16 : 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                Text(
                  'ID: $_studentId',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 12 : 16,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.notifications, size: 30),
          onPressed: () {
            // Handle notification icon press
          },
        ),
      ],
    );
  }

  Widget _buildCategoryButtons(bool isSmallScreen) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Wrap(
        spacing: 10.0,
        children: [
          _buildCategoryButton(
            'All',
            isSmallScreen,
            Icons.all_inclusive,
                () => _fetchCoursesFromFirestore(),
          ),
          _buildCategoryButton(
            'Popular',
            isSmallScreen,
            Icons.star,
                () => _fetchCoursesFromFirestore(status: 'popular'),
          ),
          _buildCategoryButton(
            'New',
            isSmallScreen,
            Icons.new_releases,
                () => _fetchCoursesFromFirestore(status: 'new'),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryButton(String label, bool isSmallScreen, IconData icon, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: isSmallScreen ? 16 : 24),
      label: Text(label, style: TextStyle(fontSize: isSmallScreen ? 14 : 18)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
      ),
    );
  }

  Widget _buildTrendingCoursesSection(bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Trending Courses',
            style: TextStyle(
              fontSize: isSmallScreen ? 20 : 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: isSmallScreen ? 180 : 250,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _items.length,
            itemBuilder: (context, index) {
              final item = _items[index];
              final imageUrl = _courseImages[item.name] ?? 'https://example.com/placeholder.png';
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CourseDetailedPage(
                      courseName: item.name,
                      courseDescription: '',
                      courseImageUrl: '',
                      courseImage: '',
                      imageUrl: imageUrl,
                    ),
                  ),
                ),
                child: Container(
                  width: isSmallScreen ? 140 : 180,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    image: DecorationImage(
                      image: NetworkImage(imageUrl),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      color: Colors.black.withOpacity(0.5),
                      child: Text(
                        item.name,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isSmallScreen ? 14 : 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProfilePage() {
    return Center(
      child: ElevatedButton(
        onPressed: () {
          // Implement profile page functionality
        },
        child: const Text('Profile Page'),
      ),
    );
  }

  Future<void> _deleteCourse() async {
    // Implement course deletion functionality
  }

  void _showAllCourses() {
    // Implement showing all courses functionality
  }
}

class CustomListItem {
  final String name;
  final String content;

  CustomListItem({required this.name, required this.content});
}
