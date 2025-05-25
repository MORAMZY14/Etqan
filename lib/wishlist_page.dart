import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

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
  File? _paymentScreenshot;
  String _paymentLink = '';

  @override
  void initState() {
    super.initState();
    _coursesFuture = _fetchCourses();
    _fetchPaymentLink();
  }

  Future<void> _fetchPaymentLink() async {
    final doc = await _firestore.collection('Settings').doc('Payment').get();
    setState(() {
      _paymentLink = doc.data()?['link'] ?? '';
    });
  }

  Future<List<Map<String, dynamic>>> _fetchCourses() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final userEmail = user.email!;
    final userDoc = await _firestore.collection('Users').doc(userEmail).get();
    final List<dynamic> signedCoursesByUser = userDoc.data()?['courses'] ?? [];

    final snapshot = await _firestore.collection('Courses').get();
    final futures = snapshot.docs.map((doc) async {
      final courseName = doc.data()['name'] ?? 'Unknown Course';
      final List<dynamic> signedUsersByCourse = doc.data()['signedUsers'] ?? [];
      final List<dynamic> approvedUsersByCourse = doc.data()['ApprovedUsers'] ?? [];

      if (signedCoursesByUser.contains(courseName) ||
          signedUsersByCourse.contains(userEmail) ||
          approvedUsersByCourse.contains(userEmail)) {
        return null;
      }

      final imageUrl = await _getCourseImageUrl(courseName);
      final coursePrice = doc.data()['price'] ?? 0;

      return {
        'name': courseName,
        'imageUrl': imageUrl,
        'price': coursePrice,
      };
    }).toList();

    final courses = await Future.wait(futures);
    return courses.where((course) => course != null).cast<Map<String, dynamic>>().toList();
  }

  Future<String> _getCourseImageUrl(String courseName) async {
    try {
      final ref = _storage.ref().child('courses/$courseName/$courseName.png');
      return await ref.getDownloadURL();
    } catch (e) {
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

  void _showPaymentDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment Required'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please pay using the link below:'),
            const SizedBox(height: 10),
            SelectableText(_paymentLink, style: const TextStyle(color: Colors.blue)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showScreenshotUploadDialog();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showScreenshotUploadDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Upload Payment Screenshot'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _paymentScreenshot == null
                  ? const Text('No screenshot selected')
                  : Image.file(_paymentScreenshot!, height: 150),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () async {
                  final picker = ImagePicker();
                  final pickedFile = await picker.pickImage(source: ImageSource.gallery);
                  if (pickedFile != null) {
                    setState(() {
                      _paymentScreenshot = File(pickedFile.path);
                    });
                  }
                },
                child: const Text('Choose Screenshot'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _paymentScreenshot = null;
              },
              child: const Text('Quit'),
            ),
            ElevatedButton(
              onPressed: _paymentScreenshot == null ? null : () {
                Navigator.pop(context);
                _registerCourses();
              },
              child: const Text('Proceed'),
            ),
          ],
        ),
      ),
    );
  }

  void _registerCourses() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userEmail = user.email!;
    final userDoc = _firestore.collection('Users').doc(userEmail);
    final selectedCourseNames = _selectedCourses.toList();
    final registrationDate = DateTime.now();

    final List<Map<String, dynamic>> registeredCoursesData = selectedCourseNames.map((courseName) {
      return {
        'courseName': courseName,
        'registrationDate': registrationDate,
      };
    }).toList();

    await userDoc.update({
      'RegisteredCourses': FieldValue.arrayUnion(registeredCoursesData),
    });

    for (final courseName in selectedCourseNames) {
      await _firestore.collection('Courses').doc(courseName).update({
        'signedUsers': FieldValue.arrayUnion([userEmail]),
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Courses registered successfully! Awaiting admin approval.')),
    );

    setState(() {
      _selectedCourses.clear();
    });
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
              final coursePrice = course['price'] ?? 0;

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
                    child: courseImageUrl.isEmpty
                        ? const Icon(Icons.image, size: 30, color: Colors.grey)
                        : null,
                  ),
                  title: Text(
                    courseName,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '\$${coursePrice.toString()}',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
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
        onPressed: _selectedCourses.isEmpty ? null : _showPaymentDialog,
        label: const Text('Register', style: TextStyle(fontSize: 16)),
        icon: const Icon(Icons.check),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
