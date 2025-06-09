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

  int _selectedIndex = 0;
  final List<BottomNavigationBarItem> _navItems = [
    BottomNavigationBarItem(
      icon: Icon(Icons.home_outlined),
      activeIcon: Icon(Icons.home),
      label: 'Home',
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
      MaterialPageRoute(builder: (context) => LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _isLoading
          ? _buildShimmerLoader()
          : IndexedStack(
        index: _selectedIndex,
        children: [
          _buildHomeScreen(),
          _isEditingProfile ? _buildEditProfileForm() : _buildProfileScreen(),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
      floatingActionButton: _selectedIndex == 0 ? _buildFloatingActionMenu() : null,
    );
  }

  Widget _buildFloatingActionMenu() {
    return FloatingActionButton(
      backgroundColor: Colors.blue[800],
      onPressed: () {
        showModalBottomSheet(
          context: context,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (context) {  // Fixed: Added proper builder function
            return Container(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Course Actions', style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[800]
                  )),
                  SizedBox(height: 20),
                  _buildActionButton(
                      icon: Icons.checklist_rounded,
                      label: 'Select Courses',
                      color: Colors.blueAccent,
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(
                            builder: (_) => WishlistPage()));
                      }
                  ),
                  _buildActionButton(
                      icon: Icons.delete_outline,
                      label: 'Delete Courses',
                      color: Colors.redAccent,
                      onPressed: () {
                        Navigator.pop(context);
                        _deleteCourse();
                      }
                  ),
                  _buildActionButton(
                      icon: Icons.list_alt,
                      label: 'Show All Courses',
                      color: Colors.green,
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(
                            builder: (_) => RegisteredCoursesPage()));
                      }
                  ),
                  SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
      child: Icon(Icons.menu, color: Colors.white),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(label, style: GoogleFonts.poppins(
          fontWeight: FontWeight.w500,
          fontSize: 16
      )),
      trailing: Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onPressed,
    );
  }

  Widget _buildHomeScreen() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverAppBar(
          expandedHeight: 180,
          floating: true,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            title: Text('Explore Courses', style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: Colors.white,
                fontSize: 18
            )),
            centerTitle: true,
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue[800]!, Colors.indigo[900]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.search, color: Colors.white),
              onPressed: () {},
            ),
          ],
        ),

        SliverPadding(
          padding: EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hello, $_userName!', style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800]
                )),
                SizedBox(height: 8),
                Text('Find your next course', style: GoogleFonts.poppins(
                    color: Colors.grey[600]
                )),
                SizedBox(height: 24),
              ],
            ),
          ),
        ),

        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverToBoxAdapter(
            child: _buildCategoryFilter(),
          ),
        ),

        SliverPadding(
          padding: EdgeInsets.all(16),
          sliver: _items.isEmpty
              ? SliverToBoxAdapter(child: _buildEmptyState())
              : SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.75,
            ),
            delegate: SliverChildBuilderDelegate(
                  (context, index) {
                final course = _items[index];
                final image = _courseImages[course.name] ??
                    'https://via.placeholder.com/150';
                return _buildCourseCard(course.name, image);
              },
              childCount: _items.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryFilter() {
    final categories = ['All', 'Popular', 'New', 'Design', 'Development'];
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => SizedBox(width: 12),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category == 'All';
          return FilterChip(
            label: Text(category),
            selected: isSelected,
            onSelected: (_) => {},
            labelStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
              color: isSelected ? Colors.white : Colors.blue[800],
            ),
            backgroundColor: Colors.white,
            selectedColor: Colors.blue[800]!,
            shape: StadiumBorder(
                side: BorderSide(color: Colors.grey[300]!)
            ),
          );
        },
      ),
    );
  }

  Widget _buildCourseCard(String title, String imageUrl) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _navigateToCourseDetail(title, imageUrl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey[200],
                    child: Icon(Icons.broken_image, color: Colors.grey[400]),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.star, color: Colors.amber, size: 16),
                      SizedBox(width: 4),
                      Text('4.8', style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600]
                      )),
                      Spacer(),
                      Text('\$49.99', style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          color: Colors.blue[800]
                      )),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileScreen() {
    return SingleChildScrollView(
      physics: BouncingScrollPhysics(),
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            SizedBox(height: 20),
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.blue[800]!,
                          width: 3
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 56,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: _profileImageUrl != null
                          ? NetworkImage(_profileImageUrl!)
                          : null,
                      child: _profileImageUrl == null
                          ? Icon(Icons.person, size: 50, color: Colors.grey[500])
                          : null,
                    ),
                  ),
                  FloatingActionButton.small(
                    backgroundColor: Colors.blue[800],
                    onPressed: _changeProfilePicture,
                    child: Icon(Icons.camera_alt, size: 20),
                  ),
                ],
              ),
            ),

            SizedBox(height: 24),
            Text(_userName, style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w600
            )),
            SizedBox(height: 4),
            Text(_userEmail, style: GoogleFonts.poppins(
                color: Colors.grey[600]
            )),

            SizedBox(height: 32),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey[200]!)
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildProfileItem(
                      icon: Icons.badge,
                      title: "Student ID",
                      value: _studentId,
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: Text("Account Settings", style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 18
              )),
            ),
            SizedBox(height: 16),
            _buildSettingItem(
              icon: Icons.edit,
              title: "Edit Profile",
              onTap: () => setState(() => _isEditingProfile = true),
            ),
            _buildSettingItem(
              icon: Icons.help_center,
              title: "Help Center",
            ),
            _buildSettingItem(
              icon: Icons.logout,
              title: "Logout",
              color: Colors.red,
              onTap: _logout,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditProfileForm() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        children: [
          AppBar(
            leading: IconButton(
              icon: Icon(Icons.arrow_back),
              onPressed: () => setState(() => _isEditingProfile = false),
            ),
            title: Text('Edit Profile'),
          ),
          SizedBox(height: 20),
          CircleAvatar(
            radius: 60,
            backgroundImage: _profileImageUrl != null
                ? NetworkImage(_profileImageUrl!)
                : null,
            child: _profileImageUrl == null
                ? Icon(Icons.person, size: 50, color: Colors.grey)
                : null,
          ),
          SizedBox(height: 20),
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Full Name',
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: _updateUserProfile,
            child: Text('Save Changes'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[800],
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileItem({required IconData icon, required String title, required String value}) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.blue[800], size: 20),
        ),
        SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: GoogleFonts.poppins(
                color: Colors.grey[600],
                fontSize: 14
            )),
            SizedBox(height: 4),
            Text(value, style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 16
            )),
          ],
        ),
      ],
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    Color? color,
    VoidCallback? onTap,
  }) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey[100]!)
      ),
      child: ListTile(
        leading: Icon(icon, color: color ?? Colors.blue[800]),
        title: Text(title, style: GoogleFonts.poppins()),
        trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
        onTap: onTap,
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          backgroundColor: Colors.white,
          selectedItemColor: Colors.blue[800],
          unselectedItemColor: Colors.grey[600],
          showSelectedLabels: false,
          showUnselectedLabels: false,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_filled),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerLoader() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator.adaptive(),
          SizedBox(height: 20),
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

  Widget _buildEmptyState() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            'No courses available',
            style: GoogleFonts.poppins(
              color: Colors.grey[600],
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Check back later for new courses',
            style: GoogleFonts.poppins(
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
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