import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminsUserEditPage extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Users'),
        backgroundColor: Colors.purple, // Change app bar color to purple
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('Users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No users found.'));
          }

          return ListView(
            children: snapshot.data!.docs.map((userDoc) {
              return _buildUserCard(context, userDoc);
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildUserCard(BuildContext context, DocumentSnapshot userDoc) {
    // Safely access data and provide default values if necessary
    var userData = userDoc.data() as Map<String, dynamic>? ?? {};
    String profileImageUrl = userData['profileImageUrl'] as String? ?? 'assets/etqan.png';
    String userName = userData['name'] as String? ?? 'Unknown User';
    String userEmail = userData['email'] as String? ?? 'No email';
    String userPhone = userData['phone'] as String? ?? 'No number';
    String userdial = userData['dial'] as String? ?? 'no dial : ';

    return Card(
      elevation: 5,
      margin: EdgeInsets.symmetric(vertical: 10, horizontal: 15),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: profileImageUrl.startsWith('http')
              ? NetworkImage(profileImageUrl)
              : AssetImage(profileImageUrl) as ImageProvider,
          onBackgroundImageError: (_, __) {
            // Handle image loading error
          },
          backgroundColor: Colors.grey.shade200, // Optional: background color if image fails
          child: profileImageUrl == 'assets/images/default-avatar.png'
              ? Icon(Icons.person, color: Colors.grey)
              : null,
        ),
        title: Text(userName),
        subtitle: Text('$userEmail\n$userdial$userPhone'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.edit, color: Colors.purple), // Change icon color to purple
              onPressed: () {
                _showEditUserDialog(context, userDoc);
              },
            ),
            IconButton(
              icon: Icon(Icons.delete, color: Colors.purple), // Change icon color to purple
              onPressed: () {
                _showDeleteConfirmationDialog(context, userDoc.id, userEmail);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditUserDialog(BuildContext context, DocumentSnapshot userDoc) {
    var userData = userDoc.data() as Map<String, dynamic>? ?? {};
    String userName = userData['name'] as String? ?? '';
    String userEmail = userData['email'] as String? ?? '';
    String userbranch = userData['branch'] as String? ?? '';
    String userphone = userData['phone'] as String? ?? '';
    String userstudentID = userData['StudentID'] as String? ?? '';
    String useruniversity = userData['university'] as String? ?? '';

    showDialog(
      context: context,
      builder: (context) {
        TextEditingController nameController = TextEditingController(text: userName);
        TextEditingController emailController = TextEditingController(text: userEmail);
        TextEditingController branchController = TextEditingController(text: userbranch);
        TextEditingController phoneController = TextEditingController(text: userphone);
        TextEditingController studentIDController = TextEditingController(text: userstudentID);
        TextEditingController UniversityController = TextEditingController(text: useruniversity);

        return AlertDialog(
          title: Text('Edit User'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: emailController,
                decoration: InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: branchController,
                decoration: InputDecoration(labelText: 'Branch'),
              ),
              TextField(
                controller: phoneController,
                decoration: InputDecoration(labelText: 'Phone'),
              ),
              TextField(
                controller: studentIDController,
                decoration: InputDecoration(labelText: 'StudentID'),
              ),
              TextField(
                controller: UniversityController,
                decoration: InputDecoration(labelText: 'University'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _updateUser(
                  userDoc.id,
                  nameController.text,
                  emailController.text,
                  branchController.text,
                  phoneController.text,
                  studentIDController.text,
                  UniversityController.text,
                );
                Navigator.of(context).pop();
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _updateUser(
      String userId, String name, String email, String branch, String phone, String studentID, String university) {
    _firestore.collection('Users').doc(userId).update({
      'name': name,
      'email': email,
      'branch': branch,
      'phone': phone,
      'studentID': studentID,
      'university': university,
    }).then((_) {
      print('User updated');
    }).catchError((error) {
      print('Failed to update user: $error');
    });
  }

  void _showDeleteConfirmationDialog(BuildContext context, String userId, String userEmail) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Confirm Deletion'),
          content: Text('Are you sure you want to delete this user?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _deleteUser(userId, userEmail);
                Navigator.of(context).pop();
              },
              child: Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _deleteUser(String userId, String userEmail) async {
    // Delete user from Firestore
    try {
      await _firestore.collection('Users').doc(userId).delete();
      print('User deleted from Firestore');
    } catch (error) {
      print('Failed to delete user from Firestore: $error');
      return;
    }

    // Check if the user to be deleted is the currently signed-in user
    User? currentUser = _auth.currentUser;
    if (currentUser != null && currentUser.email == userEmail) {
      try {
        await currentUser.delete();
        print('User deleted from Firebase Authentication');
      } catch (error) {
        print('Failed to delete user from Firebase Authentication: $error');
      }
    } else {
      print('User is not currently signed in, cannot delete from Firebase Authentication');
    }
  }
}
