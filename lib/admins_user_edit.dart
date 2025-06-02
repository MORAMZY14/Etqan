import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminsUserEditPage extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
  GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('User Management',
              style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          elevation: 0,
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: _firestore.collection('Users').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.group_off, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text('No users found',
                        style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: snapshot.data!.docs.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                return _buildUserCard(
                    context, snapshot.data!.docs[index]);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildUserCard(BuildContext context, DocumentSnapshot userDoc) {
    final userData = userDoc.data() as Map<String, dynamic>? ?? {};
    final profileImageUrl = userData['profileImageUrl'] as String? ?? 'assets/etqan.png';
    final userName = userData['name'] as String? ?? 'Unknown User';
    final userEmail = userData['email'] as String? ?? 'No email';
    final userPhone = userData['phone'] as String? ?? 'No number';
    final userDial = userData['dial'] as String? ?? '';
    final registeredCourses = userData['RegisteredCourses'] as List<dynamic>?;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1,
                    ),
                  ),
                  child: ClipOval(
                    child: profileImageUrl.startsWith('http')
                        ? Image.network(
                      profileImageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                          Icons.person,
                          size: 32,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant),
                    )
                        : Icon(
                        Icons.person,
                        size: 32,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        userEmail,
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$userDial$userPhone',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _showEditUserDialog(context, userDoc),
                  icon: Icon(Icons.edit_outlined,
                      color: Theme.of(context).colorScheme.primary),
                  tooltip: 'Edit user',
                ),
                IconButton(
                  onPressed: () => _showDeleteConfirmationDialog(context, userDoc.id),
                  icon: Icon(Icons.delete_outline,
                      color: Theme.of(context).colorScheme.error),
                  tooltip: 'Delete user',
                ),
              ],
            ),
          ),
          if (registeredCourses != null && registeredCourses.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Text(
                    'REGISTERED COURSES',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...registeredCourses.map((course) {
                    final courseName = course['courseName'] ?? 'Unknown Course';
                    final registrationDate = course['registrationDate']?.toDate() ?? DateTime.now();

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.circle,
                            size: 8,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              courseName,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          Text(
                            registrationDate.toLocal().toString().split(' ')[0],
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: Column(
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Text(
                    'No courses registered',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showEditUserDialog(BuildContext context, DocumentSnapshot userDoc) {
    final userData = userDoc.data() as Map<String, dynamic>? ?? {};
    final userName = userData['name'] as String? ?? '';
    final userEmail = userData['email'] as String? ?? '';
    final userBranch = userData['branch'] as String? ?? '';
    final userPhone = userData['phone'] as String? ?? '';
    final userStudentID = userData['StudentID'] as String? ?? '';
    final userUniversity = userData['university'] as String? ?? '';

    final controllers = {
      'name': TextEditingController(text: userName),
      'email': TextEditingController(text: userEmail),
      'branch': TextEditingController(text: userBranch),
      'phone': TextEditingController(text: userPhone),
      'studentID': TextEditingController(text: userStudentID),
      'university': TextEditingController(text: userUniversity),
    };

    final fields = [
      {'label': 'Name', 'key': 'name'},
      {'label': 'Email', 'key': 'email'},
      {'label': 'Branch', 'key': 'branch'},
      {'label': 'Phone', 'key': 'phone'},
      {'label': 'Student ID', 'key': 'studentID'},
      {'label': 'University', 'key': 'university'},
    ];

    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit User',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              ...fields.map((field) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextField(
                    controller: controllers[field['key']],
                    decoration: InputDecoration(
                      labelText: field['label'],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                );
              }).toList(),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      _updateUser(
                        userDoc.id,
                        controllers['name']!.text,
                        controllers['email']!.text,
                        controllers['branch']!.text,
                        controllers['phone']!.text,
                        controllers['studentID']!.text,
                        controllers['university']!.text,
                      );
                      Navigator.pop(context);
                    },
                    child: const Text('Save Changes'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _updateUser(String userId, String name, String email, String branch,
      String phone, String studentID, String university) {
    _firestore.collection('Users').doc(userId).update({
      'name': name,
      'email': email,
      'branch': branch,
      'phone': phone,
      'studentID': studentID,
      'university': university,
    }).then((_) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('$name updated successfully'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }).catchError((error) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Update failed: $error'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    });
  }

  void _showDeleteConfirmationDialog(BuildContext context, String userId) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Delete User?',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'This action cannot be undone. All user data will be permanently removed.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.errorContainer,
                      foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                    onPressed: () {
                      _deleteUser(userId);
                      Navigator.pop(context);
                    },
                    child: const Text('Delete'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _deleteUser(String userId) {
    _firestore.collection('Users').doc(userId).delete().then((_) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: const Text('User deleted successfully'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }).catchError((error) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Deletion failed: $error'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    });
  }
}