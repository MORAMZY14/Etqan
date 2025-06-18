import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'wishlist_page.dart'; // Make sure this import points to your WishlistPage file

class CourseDetailedPage extends StatefulWidget {
  final String courseName;
  final String courseImageUrl;
  final String courseId;

  const CourseDetailedPage({
    super.key,
    required this.courseName,
    required this.courseImageUrl,
    required this.courseId,
  });

  @override
  State<CourseDetailedPage> createState() => _CourseDetailedPageState();
}

class _CourseDetailedPageState extends State<CourseDetailedPage> {
  late Future<Map<String, dynamic>> _courseData;
  String _instructorName = "Loading...";

  @override
  void initState() {
    super.initState();
    _courseData = _fetchCourseData();
  }

  Future<Map<String, dynamic>> _fetchCourseData() async {
    final courseDoc = await FirebaseFirestore.instance
        .collection('Courses')
        .doc(widget.courseId)
        .get();

    if (!courseDoc.exists) {
      return {'description': 'Course not found', 'instructorEmail': ''};
    }

    final courseData = courseDoc.data() as Map<String, dynamic>;
    final description = courseData['description'] ?? 'No description available';
    final instructorEmail = courseData['instructor'] ?? '';

    if (instructorEmail.isNotEmpty) {
      final instructorDoc = await FirebaseFirestore.instance
          .collection('Admins')
          .doc(instructorEmail)
          .get();

      if (instructorDoc.exists) {
        final instructorData = instructorDoc.data() as Map<String, dynamic>;
        setState(() {
          _instructorName = instructorData['name'] ?? 'Unknown Instructor';
        });
      }
    }

    return {
      'description': description,
      'instructorEmail': instructorEmail,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<Map<String, dynamic>>(
        future: _courseData,
        builder: (context, snapshot) {
          final description = snapshot.hasData
              ? snapshot.data!['description']
              : 'Loading description...';

          return Column(
            children: [
              // Header with course image
              Container(
                height: 280,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: NetworkImage(widget.courseImageUrl),
                    fit: BoxFit.cover,
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black.withOpacity(0.4),
                                ),
                                child: const Icon(Icons.arrow_back, color: Colors.white),
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const Spacer(),
                            // Wishlist and Share buttons completely removed
                          ],
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.star, color: Colors.amber, size: 18),
                                  const SizedBox(width: 4),
                                  Text(
                                    "4.8",
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              "12 hours • Intermediate",
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Course content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.courseName,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 26,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // About section
                      Text(
                        "About this course",
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          height: 1.6,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // What you'll learn
                      Text(
                        "What you'll learn",
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildLearnItem("Industry-relevant skills", context),
                      _buildLearnItem("Real-world project experience", context),
                      _buildLearnItem("Expert mentorship", context),
                      _buildLearnItem("Career preparation", context),
                      const SizedBox(height: 24),

                      // Instructor section
                      Text(
                        "Instructor",
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildInstructorCard(context),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),

      // Enroll button - Now navigates to WishlistPage directly
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: () {
              // Navigate directly to WishlistPage using MaterialPageRoute
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => WishlistPage()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              "Enroll Now",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLearnItem(String text, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, color: Colors.green[600], size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructorCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 30,
            backgroundImage: NetworkImage("https://randomuser.me/api/portraits/men/41.jpg"),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _instructorName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Senior Instructor",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.star, color: Colors.amber[600], size: 16),
                    const SizedBox(width: 4),
                    Text(
                      "4.9 Instructor Rating",
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}