import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PendingUsersPage extends StatefulWidget {
  final String courseId;
  const PendingUsersPage({required this.courseId, super.key});

  @override
  _PendingUsersPageState createState() => _PendingUsersPageState();
}

class _PendingUsersPageState extends State<PendingUsersPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  late Future<List<String>> _pendingUsersFuture;
  List<String> _selectedUsers = [];

  @override
  void initState() {
    super.initState();
    _pendingUsersFuture = _fetchPendingUsers();
  }

  Future<List<String>> _fetchPendingUsers() async {
    try {
      final courseDoc = await _firestore.collection('Courses').doc(widget.courseId).get();
      final List<dynamic> signedUsers = courseDoc.data()?['signedUsers'] ?? [];
      return List<String>.from(signedUsers);
    } catch (e) {
      print('Error fetching pending users: $e');
      return [];
    }
  }

  void _toggleSelection(String userEmail, bool isSelected) {
    setState(() {
      if (isSelected) {
        _selectedUsers.add(userEmail);
      } else {
        _selectedUsers.remove(userEmail);
      }
    });
  }

  void _approveSelectedUsers() async {
    final courseDocRef = _firestore.collection('Courses').doc(widget.courseId);

    try {
      await courseDocRef.update({
        'ApprovedUsers': FieldValue.arrayUnion(_selectedUsers),
        'signedUsers': FieldValue.arrayRemove(_selectedUsers),
      });

      setState(() {
        _pendingUsersFuture = _fetchPendingUsers(); // Refresh list after approval
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Users approved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error approving users: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Error approving users'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _deleteSelectedUsers() async {
    final courseDocRef = _firestore.collection('Courses').doc(widget.courseId);

    try {
      await courseDocRef.update({
        'signedUsers': FieldValue.arrayRemove(_selectedUsers),
      });

      setState(() {
        _pendingUsersFuture = _fetchPendingUsers(); // Refresh list after deletion
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Users removed from pending!'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      print('Error removing users: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Error removing users'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Users'),
        backgroundColor: Colors.blueAccent,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search by email',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
              ),
              onChanged: (query) {
                setState(() {
                  // Trigger UI refresh when search query changes
                });
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<String>>(
              future: _pendingUsersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No pending users for this course.'));
                }

                final pendingUsers = snapshot.data!
                    .where((userEmail) => userEmail.contains(_searchController.text))
                    .toList();

                return ListView.builder(
                  itemCount: pendingUsers.length,
                  itemBuilder: (context, index) {
                    final userEmail = pendingUsers[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                      elevation: 4.0,
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16.0),
                        title: Text(userEmail),
                        trailing: Checkbox(
                          value: _selectedUsers.contains(userEmail),
                          onChanged: (bool? isSelected) {
                            _toggleSelection(userEmail, isSelected ?? false);
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _approveSelectedUsers,
                  child: const Text('Approve'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    minimumSize: const Size(120, 40),
                  ),
                ),
                ElevatedButton(
                  onPressed: _deleteSelectedUsers,
                  child: const Text('Delete'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    minimumSize: const Size(120, 40),
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
