import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const CourseUsersApp());
}

class CourseUsersApp extends StatelessWidget {
  const CourseUsersApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Course Users',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const CourseUsersPage(
        courseId: 'your_course_id_here',
        courseName: 'Advanced Flutter Development',
      ),
    );
  }
}

class CourseUsersPage extends StatefulWidget {
  final String courseId;
  final String courseName;

  const CourseUsersPage({
    super.key,
    required this.courseId,
    required this.courseName,
  });

  @override
  State<CourseUsersPage> createState() => _CourseUsersPageState();
}

class _CourseUsersPageState extends State<CourseUsersPage> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            collapsedHeight: 80,
            pinned: true,
            stretch: true,
            backgroundColor: const Color(0xFF1D1E33),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                '${widget.courseName} Users',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  shadows: [
                    Shadow(
                      color: Colors.black45,
                      blurRadius: 6,
                      offset: Offset(1, 1),
                    )
                  ],
                ),
              ),
              centerTitle: true,
              background: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.blue.withOpacity(0.8),
                      Colors.indigo.withOpacity(0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 20, left: 16, right: 16, bottom: 10),
              child: Column(
                children: [
                  Text(
                    'Enrolled Students',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.blueAccent.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value.toLowerCase();
                        });
                      },
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search by name, email or ID...',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                        prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.7)),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                          icon: Icon(Icons.clear, color: Colors.white.withOpacity(0.7)),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      cursorColor: Colors.blueAccent,
                    ),
                  ),
                ],
              ),
            ),
          ),
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('Courses')
                .doc(widget.courseId)
                .snapshots(),
            builder: (context, courseSnapshot) {
              if (courseSnapshot.connectionState == ConnectionState.waiting) {
                return SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade200),
                      ),
                    ),
                  ),
                );
              }

              if (courseSnapshot.hasError) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Text(
                        'Error: ${courseSnapshot.error}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                );
              }

              if (!courseSnapshot.hasData || !courseSnapshot.data!.exists) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: const Text(
                        'Course not found',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                );
              }

              final courseData = courseSnapshot.data!.data() as Map<String, dynamic>;
              final approvedUsers = courseData['ApprovedUsers'] ?? [];

              if (approvedUsers.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.group, size: 64, color: Colors.blueGrey[300]),
                          const SizedBox(height: 16),
                          const Text(
                            'No enrolled students yet',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('Students')
                    .where('email', whereIn: approvedUsers)
                    .snapshots(),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade200),
                          ),
                        ),
                      ),
                    );
                  }

                  if (userSnapshot.hasError) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.withOpacity(0.3)),
                          ),
                          child: Text(
                            'Error loading users: ${userSnapshot.error}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    );
                  }

                  if (!userSnapshot.hasData || userSnapshot.data!.docs.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.withOpacity(0.3)),
                          ),
                          child: const Text(
                            'No users found',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    );
                  }

                  // Filter users based on search query
                  List<QueryDocumentSnapshot> filteredUsers = userSnapshot.data!.docs.where((userDoc) {
                    if (_searchQuery.isEmpty) return true;

                    final userData = userDoc.data() as Map<String, dynamic>;
                    final name = userData['name']?.toString().toLowerCase() ?? '';
                    final email = userData['email']?.toString().toLowerCase() ?? '';
                    final studentId = userData['studentId']?.toString().toLowerCase() ??
                        userData['id']?.toString().toLowerCase() ?? '';

                    return name.contains(_searchQuery) ||
                        email.contains(_searchQuery) ||
                        studentId.contains(_searchQuery);
                  }).toList();

                  if (filteredUsers.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.search_off, size: 64, color: Colors.blueGrey[300]),
                              const SizedBox(height: 16),
                              const Text(
                                'No matching students found',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, index) {
                        final userDoc = filteredUsers[index];
                        final userData = userDoc.data() as Map<String, dynamic>;
                        final userEmail = userData['email'] ?? '';

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: UserCard(
                            userEmail: userEmail,
                            courseId: widget.courseId,
                            onDelete: () => _confirmDeleteUser(context, userEmail),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => UserDetailPage(
                                    userId: userDoc.id,
                                    userData: userData,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                      childCount: filteredUsers.length,
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteUser(BuildContext context, String userEmail) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1D1E33),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded,
                  size: 48, color: Colors.orange),
              const SizedBox(height: 16),
              const Text(
                'Remove User?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'This will remove the user from the course. Continue?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Remove',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (shouldDelete == true) {
      try {
        await _deleteUser(userEmail);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('User $userEmail removed from course'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteUser(String userEmail) async {
    // Find the user document by email
    final usersQuery = await FirebaseFirestore.instance
        .collection('Students')
        .where('email', isEqualTo: userEmail)
        .get();

    if (usersQuery.docs.isEmpty) {
      throw Exception('User not found with email: $userEmail');
    }

    final userDoc = usersQuery.docs.first;
    final courseDoc = FirebaseFirestore.instance.collection('Courses').doc(widget.courseId);

    // Remove user from course's ApprovedUsers
    await courseDoc.update({
      'ApprovedUsers': FieldValue.arrayRemove([userEmail])
    });

    // Remove course from user's registeredCourses
    final userData = userDoc.data();
    final List<dynamic> registeredCourses = List<dynamic>.from(userData['registeredCourses'] ?? []);

    // Remove course from user's registered courses
    final updatedCourses = registeredCourses.where((course) {
      if (course is String) {
        return course != widget.courseId;
      } else if (course is Map<String, dynamic>) {
        return course['courseId'] != widget.courseId && course['id'] != widget.courseId;
      }
      return true;
    }).toList();

    await userDoc.reference.update({'registeredCourses': updatedCourses});
  }
}

class UserCard extends StatefulWidget {
  final String userEmail;
  final String courseId;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const UserCard({
    super.key,
    required this.userEmail,
    required this.courseId,
    required this.onDelete,
    required this.onTap,
  });

  @override
  State<UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<UserCard> {
  Future<String?>? _avatarUrlFuture;

  @override
  void initState() {
    super.initState();
    // Get the avatar URL from Firebase Storage
    _avatarUrlFuture = _getAvatarUrl(widget.userEmail);
  }

  Future<String?> _getAvatarUrl(String email) async {
    try {
      // Use the exact email format including dots for the path
      final ref = FirebaseStorage.instance
          .ref()
          .child('users')
          .child(email)  // No sanitization - use original email
          .child('profile_picture.png');  // Changed to match actual filename

      return await ref.getDownloadURL();
    } catch (e) {
      // If no avatar is found, return null
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('Students')
          .where('email', isEqualTo: widget.userEmail)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingCard();
        }

        if (snapshot.hasError) {
          return _buildErrorCard('Error: ${snapshot.error}');
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildErrorCard('User not found');
        }

        final userDoc = snapshot.data!.docs.first;
        final userData = userDoc.data() as Map<String, dynamic>;
        final userName = userData['name'] ?? 'Unknown User';
        final userEmail = userData['email'] ?? 'No email';
        final studentId = userData['studentId'] ?? userData['id'] ?? userDoc.id;

        return GestureDetector(
          onTap: widget.onTap,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF242538),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(
                color: Colors.blueAccent.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // User avatar from Firebase Storage
                  FutureBuilder<String?>(
                    future: _avatarUrlFuture,
                    builder: (context, avatarSnapshot) {
                      if (avatarSnapshot.connectionState == ConnectionState.waiting) {
                        return Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.blueGrey.withOpacity(0.3),
                            border: Border.all(
                              color: Colors.blueAccent.withOpacity(0.5),
                              width: 2,
                            ),
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                        );
                      }

                      if (avatarSnapshot.hasData && avatarSnapshot.data != null) {
                        return CachedNetworkImage(
                          imageUrl: avatarSnapshot.data!,
                          imageBuilder: (context, imageProvider) => Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.blueAccent.withOpacity(0.5),
                                width: 2,
                              ),
                              image: DecorationImage(
                                image: imageProvider,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          placeholder: (context, url) => Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.blueGrey.withOpacity(0.3),
                              border: Border.all(
                                color: Colors.blueAccent.withOpacity(0.5),
                                width: 2,
                              ),
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.blueGrey.withOpacity(0.3),
                              border: Border.all(
                                color: Colors.blueAccent.withOpacity(0.5),
                                width: 2,
                              ),
                            ),
                            child: const Icon(Icons.person, color: Colors.white, size: 30),
                          ),
                        );
                      }

                      return Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.blueGrey.withOpacity(0.3),
                          border: Border.all(
                            color: Colors.blueAccent.withOpacity(0.5),
                            width: 2,
                          ),
                        ),
                        child: const Icon(Icons.person, color: Colors.white, size: 30),
                      );
                    },
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'ID: $studentId',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blueGrey[200],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          userEmail,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blueGrey[400],
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: Colors.red[300],
                      size: 28,
                    ),
                    onPressed: widget.onDelete,
                    tooltip: 'Remove user',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      height: 92,
      decoration: BoxDecoration(
        color: const Color(0xFF242538),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 20,
                  width: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey[700],
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 16,
                  width: 180,
                  decoration: BoxDecoration(
                    color: Colors.grey[700],
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.grey[700],
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String error) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF242538),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: Colors.red.withOpacity(0.3),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.red.withOpacity(0.2),
              border: Border.all(
                color: Colors.red.withOpacity(0.4),
                width: 2,
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 28,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'User not found',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Email: ${widget.userEmail}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blueGrey[200],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  error,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red[300],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.delete_outline,
              color: Colors.red[300],
              size: 28,
            ),
            onPressed: widget.onDelete,
            tooltip: 'Remove user',
          ),
        ],
      ),
    );
  }
}

class UserDetailPage extends StatefulWidget {
  final String userId;
  final Map<String, dynamic> userData;

  const UserDetailPage({
    super.key,
    required this.userId,
    required this.userData,
  });

  @override
  State<UserDetailPage> createState() => _UserDetailPageState();
}

class _UserDetailPageState extends State<UserDetailPage> {
  Future<String?>? _avatarUrlFuture;

  @override
  void initState() {
    super.initState();
    final email = widget.userData['email'] ?? '';
    _avatarUrlFuture = _getAvatarUrl(email);
  }

  Future<String?> _getAvatarUrl(String email) async {
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('users')
          .child(email)
          .child('profile_picture.png');

      return await ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  Future<void> _launchWhatsApp(String phone) async {
    // Clean the phone number - remove any non-digit characters
    final cleanedPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');

    String url;

    // Check if the phone number includes country code
    if (cleanedPhone.startsWith('00')) {
      // Convert 00 prefix to +
      url = "https://wa.me/${cleanedPhone.replaceFirst('00', '+')}";
    } else if (!cleanedPhone.startsWith('+')) {
      // Add your default country code if needed
      url = "https://wa.me/$cleanedPhone"; 
    } else {
      url = "https://wa.me/$cleanedPhone";
    }

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not launch WhatsApp'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userName = widget.userData['name'] ?? 'Unknown User';
    final userEmail = widget.userData['email'] ?? 'No email';
    final studentId = widget.userData['studentId'] ?? widget.userData['studentID'] ?? 'N/A';
    final phone = widget.userData['phone'] ?? widget.userData['phoneNumber'] ?? 'N/A';
    final university = widget.userData['University'] ?? widget.userData['university'] ?? 'N/A';


    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            stretch: true,
            backgroundColor: const Color(0xFF1D1E33),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                userName,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  shadows: [
                    Shadow(
                      color: Colors.black45,
                      blurRadius: 6,
                      offset: Offset(1, 1),
                    )
                  ],
                ),
              ),
              centerTitle: true,
              background: FutureBuilder<String?>(
                future: _avatarUrlFuture,
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data != null) {
                    return CachedNetworkImage(
                      imageUrl: snapshot.data!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.blueGrey.withOpacity(0.3),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.blueGrey.withOpacity(0.3),
                        child: const Icon(Icons.person, color: Colors.white, size: 60),
                      ),
                    );
                  }

                  return Container(
                    color: Colors.blueGrey.withOpacity(0.3),
                    child: const Icon(Icons.person, color: Colors.white, size: 60),
                  );
                },
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // WhatsApp Button
                  if (phone != 'N/A')
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _launchWhatsApp(phone),
                          icon: const Icon(Icons.chat, size: 24),
                          label: const Text('Message on WhatsApp'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // User Information
                  _buildInfoCard('Personal Information', [
                    _buildInfoItem('Full Name', userName),
                    _buildInfoItem('Email', userEmail),
                    _buildInfoItem('Phone', phone),
                  ]),

                  const SizedBox(height: 16),

                  _buildInfoCard('Academic Information', [
                    _buildInfoItem('Student ID', studentId),
                    _buildInfoItem('University', university),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF242538),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.blueGrey[300],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}