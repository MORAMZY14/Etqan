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
    final Color primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text('$courseName Users',
            style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                primaryColor,
                Color.lerp(primaryColor, Colors.blue, 0.7)!,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('Courses')
            .doc(courseId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingList();
          }

          if (!snapshot.hasData ||
              snapshot.data == null ||
              snapshot.data!['ApprovedUsers'] == null) {
            return _buildEmptyState();
          }

          final List<String> signedUserIds =
          List<String>.from(snapshot.data!['ApprovedUsers']);

          if (signedUserIds.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16.0),
            itemCount: signedUserIds.length,
            separatorBuilder: (context, index) => SizedBox(height: 12),
            itemBuilder: (context, index) {
              final userId = signedUserIds[index];
              return _UserCard(
                userId: userId,
                courseId: courseId,
                onDelete: () => _confirmDeleteUser(context, userId),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildLoadingList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: 8,
      itemBuilder: (context, index) {
        return _PlaceholderCard();
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.group_off, size: 64, color: Colors.grey[400]),
          SizedBox(height: 20),
          Text('No Enrolled Users',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          SizedBox(height: 10),
          Text('Users will appear here once they enroll',
              style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteUser(BuildContext context, String userId) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 10),
            Text('Remove User?'),
          ],
        ),
        content: Text('This will remove the user from the course. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('Remove'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      await _deleteUser(userId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('User removed from course'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<void> _deleteUser(String userId) async {
    final userDoc = FirebaseFirestore.instance.collection('Users').doc(userId);
    final courseDoc = FirebaseFirestore.instance.collection('Courses').doc(courseId);

    try {
      // Get user document
      final userSnapshot = await userDoc.get();
      final List<dynamic> registeredCourses =
      List<dynamic>.from(userSnapshot.data()?['RegisteredCourses'] ?? []);

      // Find and remove the course from the user's RegisteredCourses
      registeredCourses.removeWhere((course) {
        return course is Map<String, dynamic> && course['courseName'] == courseId;
      });

      await userDoc.update({'RegisteredCourses': registeredCourses});

      // Update course document to remove the user from signedUsers
      final courseSnapshot = await courseDoc.get();
      final List<dynamic> courseUsers =
      List<String>.from(courseSnapshot.data()?['ApprovedUsers'] ?? []);

      if (courseUsers.contains(userId)) {
        courseUsers.remove(userId);
        await courseDoc.update({'ApprovedUsers': courseUsers});
      }
    } catch (e) {
      print('Error deleting user: $e');
    }
  }
}

class _UserCard extends StatelessWidget {
  final String userId;
  final String courseId;
  final VoidCallback onDelete;

  const _UserCard({
    required this.userId,
    required this.courseId,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('Users').doc(userId).get(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingCard();
        }

        if (!userSnapshot.hasData || userSnapshot.data == null) {
          return _buildErrorCard(context);
        }

        final userData = userSnapshot.data!;
        final userName = userData['name'] ?? 'No Name';
        final userEmail = userData['email'] ?? 'No Email';
        final userAvatar = userData['avatarUrl'] ?? '';

        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UserDetailsPage(userId: userId),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (userAvatar.isNotEmpty)
                  CircleAvatar(
                    radius: 28,
                    backgroundImage: NetworkImage(userAvatar),
                  )
                else
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.secondary,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        userName[0].toUpperCase(),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Text(
                        userEmail,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).textTheme.bodySmall!.color,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.red[400]),
                  onPressed: onDelete,
                  tooltip: 'Remove user',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingCard() {
    return _PlaceholderCard();
  }

  Widget _buildErrorCard(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor, // Now uses valid context
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[200],
            ),
            child: Icon(Icons.error_outline, color: Colors.red),
          ),
          SizedBox(width: 16),
          Text('Failed to load user',
              style: TextStyle(color: Colors.red)),
        ],
      ),
    );
  }
}


class _PlaceholderCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            margin: EdgeInsets.only(left: 16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[300],
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 16,
                  width: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  height: 12,
                  width: 180,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}