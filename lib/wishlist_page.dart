import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WishlistPage extends StatefulWidget {
  const WishlistPage({super.key});

  @override
  _WishlistPageState createState() => _WishlistPageState();
}

class _WishlistPageState extends State<WishlistPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late Future<List<Map<String, dynamic>>> _coursesFuture;
  final Set<String> _selectedCourses = <String>{};

  @override
  void initState() {
    super.initState();
    _coursesFuture = _fetchCourses();
  }

  Future<List<Map<String, dynamic>>> _fetchCourses() async {
    final user = _auth.currentUser;
    if (user == null) {
      print('User not logged in');
      return [];
    }

    final userEmail = user.email!;

    // Fetch the user's signed courses from the user's document
    final userDoc = await _firestore.collection('Users').doc(userEmail).get();
    final List<dynamic> signedCoursesByUser = userDoc.data()?['courses'] ?? [];

    // Fetch all courses from the Courses collection
    final snapshot = await _firestore.collection('Courses').get();
    final futures = snapshot.docs.map((doc) async {
      final courseName = doc.data()['name'] ?? 'Unknown Course';

      // Fetch the signed users from the course's document
      final List<dynamic> signedUsersByCourse = doc.data()['signedUsers'] ?? [];

      // Skip courses if the user has already signed up or if the course document indicates so
      if (signedCoursesByUser.contains(courseName) || signedUsersByCourse.contains(userEmail)) {
        return null; // Skip this course
      }

      // Fetch the course image URL
      final imageUrl = await _getCourseImageUrl(courseName);
      return {
        'name': courseName,
        'imageUrl': imageUrl,
      };
    }).toList();

    // Wait for all the futures to complete
    final courses = await Future.wait(futures);

    // Filter out any null values
    return courses.where((course) => course != null).cast<Map<String, dynamic>>().toList();
  }

  Future<String> _getCourseImageUrl(String courseName) async {
    try {
      final ref = _storage.ref().child('courses/$courseName/$courseName.png');
      return await ref.getDownloadURL();
    } catch (e) {
      print('Error fetching image URL for $courseName: $e');
      return '';
    }
  }

  void _toggleSelection(String courseName, bool isSelected) {
    setState(() {
      if (isSelected) {
        _selectedCourses.add(courseName);
      } else {
        _selectedCourses.remove(courseName);
      }
    });
  }

  void _registerCourses() async {
    final user = _auth.currentUser;
    if (user == null) {
      print('User not logged in');
      return;
    }

    final userEmail = user.email!;
    final userDoc = _firestore.collection('Users').doc(userEmail);
    final selectedCourseNames = _selectedCourses.toList();
    final registrationDate = DateTime.now(); // Current date and time

    // Prepare the registered course data for the user's document
    final List<Map<String, dynamic>> registeredCoursesData = selectedCourseNames.map((courseName) {
      return {
        'courseName': courseName,
        'registrationDate': registrationDate,
      };
    }).toList();

    // Update user's document: add registered courses and dates
    await userDoc.update({
      'RegisteredCourses': FieldValue.arrayUnion(registeredCoursesData),
    });

    // For each selected course, add the user to PendingUsers in the course document
    for (final courseName in selectedCourseNames) {
      await _firestore.collection('Courses').doc(courseName).update({
        'signedUsers': FieldValue.arrayUnion([userEmail]),
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Courses registered successfully! Awaiting admin approval.')),
    );

    Navigator.pop(context);
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Courses', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _coursesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No courses available.'));
          }

          final courses = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: courses.length,
            itemBuilder: (context, index) {
              final course = courses[index];
              final courseName = course['name'] ?? 'Unknown Course';
              final courseImageUrl = course['imageUrl'] ?? '';

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    radius: 30,
                    backgroundImage: courseImageUrl.isNotEmpty ? NetworkImage(courseImageUrl) : null,
                    backgroundColor: Colors.grey.shade200,
                    child: courseImageUrl.isEmpty ? const Icon(Icons.image, size: 30, color: Colors.grey) : null,
                  ),
                  title: Text(courseName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  trailing: Checkbox(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                    value: _selectedCourses.contains(courseName),
                    onChanged: (bool? isSelected) {
                      _toggleSelection(courseName, isSelected ?? false);
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _registerCourses,
        label: const Text('Register', style: TextStyle(fontSize: 16)),
        icon: const Icon(Icons.check),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
