import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_detail_page.dart';

class CourseUsersPage extends StatelessWidget {
  final String courseId;
  final String courseName;

  const CourseUsersPage({
    super.key,
    required this.courseId,
    required this.courseName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Users of $courseName'),
        backgroundColor: Colors.teal,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('Courses')
            .doc(courseId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data == null || snapshot.data!['ApprovedUsers'] == null) {
            return const Center(child: Text('No users enrolled in this course.'));
          }

          // Fetch signedUsers from the course document
          final List<String> signedUserIds = List<String>.from(snapshot.data!['ApprovedUsers']);

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: signedUserIds.length,
            itemBuilder: (context, index) {
              final userId = signedUserIds[index];
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('Users').doc(userId).get(),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return const ListTile(
                      title: Text('Loading user...'),
                    );
                  }

                  if (!userSnapshot.hasData || userSnapshot.data == null) {
                    return const ListTile(
                      title: Text('User not found'),
                    );
                  }

                  final userData = userSnapshot.data!;
                  final userName = userData['name'] ?? 'No Name';
                  final userEmail = userData['email'] ?? 'No Email';

                  return Card(
                    elevation: 4.0,
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.teal,
                        child: Text(
                          userName[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(
                        userName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(userEmail),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          _confirmDeleteUser(context, userId);
                        },
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => UserDetailsPage(userId: userId),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmDeleteUser(BuildContext context, String userId) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: const Text('Are you sure you want to delete this user from the course?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      await _deleteUser(userId);
    }
  }

  Future<void> _deleteUser(String userId) async {
    final userDoc = FirebaseFirestore.instance.collection('Users').doc(userId);
    final courseDoc = FirebaseFirestore.instance.collection('Courses').doc(courseId);

    try {
      // Get user document
      final userSnapshot = await userDoc.get();
      final List<dynamic> registeredCourses = List<dynamic>.from(userSnapshot.data()?['RegisteredCourses'] ?? []);

      // Find and remove the course from the user's RegisteredCourses
      registeredCourses.removeWhere((course) {
        return course is Map<String, dynamic> && course['courseName'] == courseId;
      });

      await userDoc.update({'RegisteredCourses': registeredCourses});

      // Update course document to remove the user from signedUsers
      final courseSnapshot = await courseDoc.get();
      final List<dynamic> courseUsers = List<String>.from(courseSnapshot.data()?['ApprovedUsers'] ?? []);

      if (courseUsers.contains(userId)) {
        courseUsers.remove(userId);
        await courseDoc.update({'ApprovedUsers': courseUsers});
      }
    } catch (e) {
      print('Error deleting user: $e');
    }
  }
}

