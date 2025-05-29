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
import 'course_detailed_page.dart';
import 'wishlist_page.dart';
import 'show_courses_users_page.dart';

class UserPage extends StatefulWidget {
  final String email;

  const UserPage({super.key, required this.email});

  @override
  _UserPageState createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String _userName = 'Loading...';
  String _studentId = 'Loading...';
  String _userEmail = '';
  String? _profileImageUrl;
  List<CustomListItem> _items = [];
  Map<String, String> _courseImages = {};
  bool _isLoading = true;
  bool _isEditingProfile = false;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _idController = TextEditingController();

  // Modern bottom navigation items
  int _selectedIndex = 0;
  final List<BottomNavigationBarItem> _navItems = [
    BottomNavigationBarItem(
      icon: Icon(Icons.home_outlined),
      activeIcon: Icon(Icons.home),
      label: 'Home',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.favorite_border),
      activeIcon: Icon(Icons.favorite),
      label: 'Wishlist',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.person_outline),
      activeIcon: Icon(Icons.person),
      label: 'Profile',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _userEmail = widget.email;
    _initializeData();
    _activateAppCheck();
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
      await _firestore.collection('Students').doc(email.toLowerCase()).get();

      final String name = doc['name']?.toString() ?? 'Unknown User';
      final String studentId = doc['studentID']?.toString() ?? 'N/A';

      setState(() {
        _userName = name;
        _studentId = studentId;
        _nameController.text = name;
        _idController.text = studentId;
      });
    } catch (e) {
      setState(() {
        _userName = 'Error Loading';
        _studentId = 'ID: N/A';
      });
    }
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

  Future<void> _updateUserProfile() async {
    if (_nameController.text.isEmpty || _idController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Name and ID cannot be empty')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _firestore.collection('Users').doc(_userEmail.toLowerCase()).update({
        'name': _nameController.text,
        'studentID': _idController.text,
      });

      setState(() {
        _userName = _nameController.text;
        _studentId = _idController.text;
        _isEditingProfile = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile updated successfully')),
      );
    } catch (e) {
      print('Error updating profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchCoursesFromFirestore() async {
    try {
      final QuerySnapshot snapshot = await _firestore.collection('Courses').get();
      final List<CustomListItem> courses = snapshot.docs.map((doc) {
        return CustomListItem(
          name: doc['name']?.toString() ?? 'Unnamed Course',
          content: doc['content']?.toString() ?? '',
        );
      }).toList();

      setState(() => _items = courses);
    } catch (e) {
      print('Error fetching courses: $e');
      // Add fallback to show all courses on error
      if (_items.isEmpty) {
        final fallbackSnapshot = await _firestore.collection('Courses').get();
        final fallbackCourses = fallbackSnapshot.docs.map((doc) {
          return CustomListItem(
            name: doc['name']?.toString() ?? 'Unnamed Course',
            content: doc['content']?.toString() ?? '',
          );
        }).toList();
        setState(() => _items = fallbackCourses);
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? _buildShimmerLoader()
          : _buildCurrentPage(),
      bottomNavigationBar: _buildModernBottomBar(),
      floatingActionButton: _selectedIndex == 0 ? _buildFloatingActionButtons() : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildCurrentPage() {
    switch (_selectedIndex) {
      case 0:
        return _buildMainContent();
      case 1:
        return _buildWishlistContent();
      case 2:
        return _buildProfileContent();
      default:
        return _buildMainContent();
    }
  }

  Widget _buildMainContent() {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 150,
          flexibleSpace: _buildAppBarHeader(),
          pinned: true,
          backgroundColor: Colors.blue[800],
        ),
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 10),
              _buildCategoryFilter(),
              const SizedBox(height: 25),
              _buildCourseGrid(),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildAppBarHeader() {
    return FlexibleSpaceBar(
      title: Text(
        'Courses',
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
        ),
      ),
      centerTitle: true,
      background: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue[800]!, Colors.blue[600]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    final categories = ['All', 'Popular', 'New'];
    return SizedBox(
      height: 45,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category == 'All';
          return ChoiceChip(
            label: Text(category),
            selected: isSelected,
            onSelected: (_) => {},
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

  Widget _buildFloatingActionButtons() {
    return Container(
      height: 60,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildFloatingButton(
            icon: Icons.checklist_rounded,
            label: 'Select',
            color: Colors.blueAccent,
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WishlistPage())),
          ),
          _buildDivider(),
          _buildFloatingButton(
            icon: Icons.delete_outline,
            label: 'Delete',
            color: Colors.redAccent,
            onPressed: _deleteCourse,
          ),
          _buildDivider(),
          _buildFloatingButton(
            icon: Icons.list_alt,
            label: 'Show All',
            color: Colors.green,
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisteredCoursesPage()));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 2),
              Text(
                label,
                style: GoogleFonts.poppins(
                  color: Colors.blueGrey[800],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 30,
      width: 1,
      color: Colors.grey[300],
    );
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
        final image = _courseImages[course.name] ?? 'https://via.placeholder.com/150';
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 20),
          Text(
            'Your Wishlist',
            style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Text(
            'Courses you save will appear here',
            style: GoogleFonts.poppins(color: Colors.grey[600]),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => setState(() => _selectedIndex = 0),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[800],
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Browse Courses',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.blue[800]!, width: 3),
                  ),
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: _profileImageUrl != null
                        ? NetworkImage(_profileImageUrl!)
                        : null,
                    child: _profileImageUrl == null
                        ? Icon(Icons.person, size: 60, color: Colors.grey[500])
                        : null,
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.blue[800],
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.camera_alt, color: Colors.white),
                      onPressed: _changeProfilePicture,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          _buildProfileSectionTitle('Personal Information'),
          const SizedBox(height: 15),
          _isEditingProfile
              ? _buildEditableProfileForm()
              : _buildProfileInfoDisplay(),
          const SizedBox(height: 30),
          _buildProfileSectionTitle('Account Settings'),
          const SizedBox(height: 15),
          _buildProfileSettingItem(
            icon: Icons.notifications,
            title: 'Notifications',
            onTap: () {},
          ),
          _buildProfileSettingItem(
            icon: Icons.security,
            title: 'Privacy & Security',
            onTap: () {},
          ),
          _buildProfileSettingItem(
            icon: Icons.help_outline,
            title: 'Help & Support',
            onTap: () {},
          ),
          _buildProfileSettingItem(
            icon: Icons.logout,
            title: 'Logout',
            color: Colors.red,
            onTap: _logout,
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildProfileSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Colors.blue[800],
      ),
    );
  }

  Widget _buildProfileInfoDisplay() {
    return Column(
      children: [
        _buildProfileInfoItem('Full Name', _userName),
        _buildProfileInfoItem('Student ID', _studentId),
        _buildProfileInfoItem('Email', _userEmail),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () => setState(() => _isEditingProfile = true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[800],
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(
            'Edit Profile',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEditableProfileForm() {
    return Column(
      children: [
        TextFormField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: 'Full Name',
            prefixIcon: Icon(Icons.person, color: Colors.blue[800]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        const SizedBox(height: 15),
        TextFormField(
          controller: _idController,
          decoration: InputDecoration(
            labelText: 'Student ID',
            prefixIcon: Icon(Icons.badge, color: Colors.blue[800]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        const SizedBox(height: 15),
        TextFormField(
          initialValue: _userEmail,
          readOnly: true,
          decoration: InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.email, color: Colors.blue[800]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _isEditingProfile = false),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  side: BorderSide(color: Colors.blue[800]!),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.poppins(
                    color: Colors.blue[800],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: ElevatedButton(
                onPressed: _updateUserProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[800],
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : Text(
                  'Save Changes',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProfileInfoItem(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSettingItem({
    required IconData icon,
    required String title,
    Color? color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey[200]!),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color ?? Colors.blue[800]),
            const SizedBox(width: 15),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: color ?? Colors.grey[800],
              ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
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

  Widget _buildModernBottomBar() {
    return BottomNavigationBar(
      items: _navItems,
      currentIndex: _selectedIndex,
      onTap: (index) => setState(() => _selectedIndex = index),
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: Colors.blue[800],
      unselectedItemColor: Colors.grey,
      selectedLabelStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
      unselectedLabelStyle: GoogleFonts.poppins(fontSize: 12),
      elevation: 8,
    );
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

  void _deleteCourse() {
    // Implement course deletion logic
  }

  void _changeProfilePicture() {
    // Implement profile picture change logic
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Change Profile Picture', style: GoogleFonts.poppins()),
        content: Text('Select a method to update your profile picture', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Open camera
            },
            child: Text('Camera', style: GoogleFonts.poppins(color: Colors.blue[800])),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Open gallery
            },
            child: Text('Gallery', style: GoogleFonts.poppins(color: Colors.blue[800])),
          ),
        ],
      ),
    );
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