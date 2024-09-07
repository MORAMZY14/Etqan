import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'pending_user_admin_page.dart';

class ApproveRequestsPage extends StatefulWidget {
  const ApproveRequestsPage({super.key});

  @override
  _ApproveRequestsPageState createState() => _ApproveRequestsPageState();
}

class _ApproveRequestsPageState extends State<ApproveRequestsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late Future<List<Map<String, dynamic>>> _coursesFuture;

  @override
  void initState() {
    super.initState();
    _coursesFuture = _fetchCoursesWithPendingUsers();
  }

  Future<List<Map<String, dynamic>>> _fetchCoursesWithPendingUsers() async {
    final snapshot = await _firestore.collection('Courses').get();
    final coursesWithPendingUsers = snapshot.docs.where((doc) {
      final pendingUsers = doc.data()['signedUsers'] ?? [];
      return pendingUsers.isNotEmpty;
    }).map((doc) {
      return {
        'courseName': doc.data()['name'],
        'courseId': doc.id,
      };
    }).toList();

    return coursesWithPendingUsers;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Approve Requests',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 4.0,
        backgroundColor: Colors.teal,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _coursesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'No courses with pending users.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          final courses = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: courses.length,
            itemBuilder: (context, index) {
              final course = courses[index];
              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15.0),
                ),
                elevation: 5,
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
                  leading: CircleAvatar(
                    backgroundColor: Colors.teal,
                    child: Icon(Icons.book, color: Colors.white),
                  ),
                  title: Text(
                    course['courseName'],
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, color: Colors.teal),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PendingUsersPage(courseId: course['courseId']),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
