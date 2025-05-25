import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'course_users_page.dart';

class CourseManagementPage extends StatefulWidget {
  const CourseManagementPage({super.key});

  @override
  _CourseManagementPageState createState() => _CourseManagementPageState();
}

class _CourseManagementPageState extends State<CourseManagementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Course Management'),
        backgroundColor: Colors.blue,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('Courses').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No courses available.'));
                  }

                  final courses = snapshot.data!.docs;

                  return ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: courses.length,
                    itemBuilder: (context, index) {
                      final course = courses[index];
                      final imageUrl = _getImageUrl(course.id);

                      return Card(
                        elevation: 5.0,
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundImage: NetworkImage(imageUrl),
                            backgroundColor: Colors.grey.shade200,
                            radius: 30,
                          ),
                          title: Text(course['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                              'Status: ${course['status']}\nPrice: ${course['price'] ?? 'N/A'}'),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () {
                                  _showEditCourseDialog(course);
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () {
                                  _deleteCourse(course.id);
                                },
                              ),
                            ],
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CourseUsersPage(
                                  courseId: course.id,
                                  courseName: course['name'],
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: FloatingActionButton(
                onPressed: _showAddCourseDialog,
                backgroundColor: Colors.blue,
                child: const Icon(Icons.add),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getImageUrl(String courseId) {
    return 'https://firebasestorage.googleapis.com/v0/b/etqan-center.appspot.com/o/courses%2F$courseId%2F$courseId.png?alt=media';
  }

  void _showAddCourseDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final nameController = TextEditingController();
        final descriptionController = TextEditingController();
        final statusController = TextEditingController();
        final durationController = TextEditingController();
        final totalStudentsController = TextEditingController();
        final priceController = TextEditingController();
        File? selectedImage;

        return AlertDialog(
          title: const Text('Add New Course'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Course Name')),
                TextField(controller: descriptionController, decoration: const InputDecoration(labelText: 'Description')),
                TextField(controller: statusController, decoration: const InputDecoration(labelText: 'Status')),
                TextField(controller: durationController, decoration: const InputDecoration(labelText: 'Duration')),
                TextField(controller: totalStudentsController, decoration: const InputDecoration(labelText: 'Total Students'), keyboardType: TextInputType.number),
                TextField(controller: priceController, decoration: const InputDecoration(labelText: 'Price'), keyboardType: TextInputType.number),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
                      if (pickedFile != null) {
                        setState(() {
                          selectedImage = File(pickedFile.path);
                        });
                      }
                    } catch (e) {
                      print('Error picking image: $e');
                    }
                  },
                  child: const Text('Select Image'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty ||
                    descriptionController.text.isEmpty ||
                    statusController.text.isEmpty ||
                    durationController.text.isEmpty ||
                    totalStudentsController.text.isEmpty ||
                    priceController.text.isEmpty ||
                    selectedImage == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill in all fields.')));
                  return;
                }

                await _addCourse(
                  nameController.text,
                  descriptionController.text,
                  statusController.text,
                  durationController.text,
                  int.tryParse(totalStudentsController.text) ?? 0,
                  double.tryParse(priceController.text) ?? 0.0,
                  selectedImage!,
                );
                Navigator.of(context).pop();
                _showUploadSuccessDialog();
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addCourse(
      String name,
      String description,
      String status,
      String duration,
      int totalStudents,
      double price,
      File imageFile,
      ) async {
    try {
      final courseId = name;
      final newCourseRef = _firestore.collection('Courses').doc(courseId);

      await newCourseRef.set({
        'name': name,
        'description': description,
        'status': status,
        'duration': duration,
        'totalStudents': totalStudents,
        'price': price,
      });

      final imageRef = _storage.ref('courses/$courseId/$courseId.png');
      await imageRef.putFile(imageFile);
      await imageRef.getDownloadURL();
    } catch (e) {
      print('Error adding course: $e');
    }
  }

  void _showUploadSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Upload Successful'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 50),
            SizedBox(height: 10),
            Text('The course has been added successfully.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showEditCourseDialog(DocumentSnapshot course) {
    showDialog(
      context: context,
      builder: (context) {
        final nameController = TextEditingController(text: course['name']);
        final descriptionController = TextEditingController(text: course['description']);
        final statusController = TextEditingController(text: course['status']);
        final durationController = TextEditingController(text: course['duration']);
        final totalStudentsController = TextEditingController(text: course['totalStudents'].toString());
        final priceController = TextEditingController(text: course['price'].toString());

        return AlertDialog(
          title: const Text('Edit Course'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Course Name')),
                TextField(controller: descriptionController, decoration: const InputDecoration(labelText: 'Description')),
                TextField(controller: statusController, decoration: const InputDecoration(labelText: 'Status')),
                TextField(controller: durationController, decoration: const InputDecoration(labelText: 'Duration')),
                TextField(controller: totalStudentsController, decoration: const InputDecoration(labelText: 'Total Students'), keyboardType: TextInputType.number),
                TextField(controller: priceController, decoration: const InputDecoration(labelText: 'Price'), keyboardType: TextInputType.number),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                await _updateCourse(
                  course.id,
                  nameController.text,
                  descriptionController.text,
                  statusController.text,
                  durationController.text,
                  int.tryParse(totalStudentsController.text) ?? 0,
                  double.tryParse(priceController.text) ?? 0.0,
                );
                Navigator.of(context).pop();
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateCourse(
      String courseId,
      String name,
      String description,
      String status,
      String duration,
      int totalStudents,
      double price,
      ) async {
    try {
      await _firestore.collection('Courses').doc(courseId).update({
        'name': name,
        'description': description,
        'status': status,
        'duration': duration,
        'totalStudents': totalStudents,
        'price': price,
      });
      print('Course updated successfully!');
    } catch (e) {
      print('Error updating course: $e');
    }
  }

  Future<void> _deleteCourse(String courseId) async {
    try {
      await _firestore.collection('Courses').doc(courseId).delete();
      print('Course deleted successfully!');
    } catch (e) {
      print('Error deleting course: $e');
    }
  }
}