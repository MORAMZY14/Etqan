import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class RegisteredCoursesPage extends StatelessWidget {
  const RegisteredCoursesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registered Courses'),
        backgroundColor: Colors.teal,
      ),
      body: FutureBuilder<List<CourseData>>(
        future: _getRegisteredCourses(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'No registered courses found.',
                style: TextStyle(fontSize: 16, color: Colors.red),
              ),
            );
          }

          final courses = snapshot.data!;

          return ListView.builder(
            itemCount: courses.length,
            itemBuilder: (context, index) {
              final course = courses[index];
              return Card(
                elevation: 4.0,
                margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                child: ListTile(
                  leading: course.imageUrl.isNotEmpty
                      ? Image.network(course.imageUrl, width: 50, height: 50, fit: BoxFit.cover)
                      : const Icon(Icons.image, size: 50),
                  title: Text(course.name ?? 'No name'),
                  subtitle: Text(course.overview ?? 'No overview'),
                  trailing: Text(course.status ?? 'No status'),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<List<CourseData>> _getRegisteredCourses() async {
    try {
      // Get the current user's email
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User is not signed in');
      }
      final email = user.email;

      if (email == null || email.isEmpty) {
        throw Exception('User email is not available');
      }

      // Fetch user document by email
      final userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (userDoc.docs.isEmpty) {
        throw Exception('User not found');
      }

      final registeredCourses = userDoc.docs.first.data()['courses'] as List<dynamic>?;

      if (registeredCourses == null || registeredCourses.isEmpty) {
        return [];  // Return an empty list if no courses
      }

      // Fetch registered courses from the Courses collection
      final courseQuery = FirebaseFirestore.instance
          .collection('Courses')
          .where(FieldPath.documentId, whereIn: registeredCourses);

      final courseSnapshot = await courseQuery.get();

      // Get image URLs for the courses
      final List<CourseData> courses = [];
      for (var doc in courseSnapshot.docs) {
        final courseData = doc.data();
        final courseId = doc.id;

        // Get image URL from Firebase Storage
        final imageUrl = await _getCourseImageUrl(courseId);

        courses.add(CourseData(
          name: courseData['name'],
          overview: courseData['overview'],
          status: courseData['status'],
          imageUrl: imageUrl,
        ));
      }

      return courses;
    } catch (e) {
      print('Error fetching registered courses: $e');
      return [];  // Return an empty list in case of error
    }
  }

  Future<String> _getCourseImageUrl(String courseId) async {
    try {
      final storage = FirebaseStorage.instance;
      String? imageUrl;

      // Try fetching the image with .png extension
      try {
        final pngRef = storage.ref().child('courses/$courseId/$courseId.png');
        imageUrl = await pngRef.getDownloadURL();
      } catch (e) {
        // If fetching .png fails, try .jpg
        print('PNG not found, trying JPG: $e');
        try {
          final jpgRef = storage.ref().child('courses/$courseId/$courseId.jpg');
          imageUrl = await jpgRef.getDownloadURL();
        } catch (e) {
          // If fetching .jpg fails, handle the error
          print('Error fetching JPG image URL: $e');
        }
      }

      // If imageUrl is still null, return an error message
      if (imageUrl == null) {
        throw Exception('Image not found for course ID $courseId');
      }

      return imageUrl;
    } catch (e) {
      print('Error fetching image URL: $e');
      return '';  // Return an empty string if there's an error
    }
  }
}

class CourseData {
  final String name;
  final String overview;
  final String status;
  final String imageUrl;

  CourseData({
    required this.name,
    required this.overview,
    required this.status,
    required this.imageUrl,
  });
}
