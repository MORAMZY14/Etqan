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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Course Management',
            style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Theme.of(context).colorScheme.onBackground,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddCourseDialog,
            tooltip: 'Add New Course',
          ),
        ],
      ),
      body: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.03),
              Theme.of(context).colorScheme.primary.withOpacity(0.01),
            ],
          ),
        ),
        child: Column(
          children: [
            _buildSearchBar(),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('Courses').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildLoadingIndicator();
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.school, size: 64,
                              color: Theme.of(context).colorScheme.outline),
                          const SizedBox(height: 16),
                          Text('No courses available',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Text('Tap + to add a new course',
                              style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    );
                  }

                  final courses = snapshot.data!.docs.where((course) {
                    final name = course['name'].toString().toLowerCase();
                    return name.contains(_searchQuery.toLowerCase());
                  }).toList();

                  return ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: courses.length,
                    itemBuilder: (context, index) {
                      final course = courses[index];
                      return _buildCourseCard(context, course);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddCourseDialog,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        icon: const Icon(Icons.add),
        label: const Text('New Course'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: 'Search courses...',
          prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.outline),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: Icon(Icons.close, color: Theme.of(context).colorScheme.outline),
            onPressed: () {
              _searchController.clear();
              setState(() => _searchQuery = '');
            },
          )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return ListView.builder(
      itemCount: 5,
      itemBuilder: (context, index) {
        return Container(
          height: 120,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Center(child: CircularProgressIndicator()),
        );
      },
    );
  }

  Widget _buildCourseCard(BuildContext context, DocumentSnapshot course) {
    final imageUrl = _getImageUrl(course.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
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
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Course Image
                Hero(
                  tag: 'course-${course.id}',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      imageUrl,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 80,
                          height: 80,
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          child: Icon(Icons.school,
                              size: 40,
                              color: Theme.of(context).colorScheme.primary),
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          width: 80,
                          height: 80,
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          child: const CircularProgressIndicator(),
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // Course Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              course['name'],
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _buildStatusBadge(course['status']),
                        ],
                      ),

                      const SizedBox(height: 6),

                      Text(
                        course['description'] ?? 'No description',
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 10),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.schedule, size: 16,
                                  color: Theme.of(context).colorScheme.outline),
                              const SizedBox(width: 4),
                              Text(course['duration'],
                                  style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),

                          Row(
                            children: [
                              Icon(Icons.people, size: 16,
                                  color: Theme.of(context).colorScheme.outline),
                              const SizedBox(width: 4),
                              Text(course['totalStudents'].toString(),
                                  style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),

                          Text(
                            '${course['price']} SAR',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.primary
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: Icon(Icons.edit,
                                size: 20,
                                color: Theme.of(context).colorScheme.outline),
                            onPressed: () => _showEditCourseDialog(course),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete,
                                size: 20,
                                color: Theme.of(context).colorScheme.error),
                            onPressed: () => _deleteCourse(course.id),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;

    switch (status.toLowerCase()) {
      case 'active':
        bgColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
        break;
      case 'upcoming':
        bgColor = Colors.blue.shade100;
        textColor = Colors.blue.shade800;
        break;
      case 'completed':
        bgColor = Colors.orange.shade100;
        textColor = Colors.orange.shade800;
        break;
      default:
        bgColor = Colors.grey.shade100;
        textColor = Colors.grey.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: textColor),
      ),
    );
  }

  String _getImageUrl(String courseId) {
    return 'https://firebasestorage.googleapis.com/v0/b/etqan-center.appspot.com/o/courses%2F$courseId%2F$courseId.png?alt=media';
  }

  void _showAddCourseDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _buildCourseForm(context, isEditing: false);
      },
    );
  }

  void _showEditCourseDialog(DocumentSnapshot course) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _buildCourseForm(context, course: course, isEditing: true);
      },
    );
  }

  Widget _buildCourseForm(BuildContext context, {DocumentSnapshot? course, bool isEditing = false}) {
    final nameController = TextEditingController(text: course?['name']);
    final descriptionController = TextEditingController(text: course?['description']);
    final statusController = TextEditingController(text: course?['status']);
    final durationController = TextEditingController(text: course?['duration']);
    final totalStudentsController = TextEditingController(text: course?['totalStudents']?.toString());
    final priceController = TextEditingController(text: course?['price']?.toString());
    File? selectedImage;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 60,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Text(
              isEditing ? 'Edit Course' : 'Create New Course',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700
              ),
            ),

            const SizedBox(height: 24),

            // Image Picker
            Center(
              child: GestureDetector(
                onTap: () async {
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
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    shape: BoxShape.circle,
                  ),
                  child: selectedImage != null
                      ? ClipOval(child: Image.file(selectedImage!, fit: BoxFit.cover))
                      : Icon(Icons.add_a_photo, size: 40,
                      color: Theme.of(context).colorScheme.outline),
                ),
              ),
            ),

            const SizedBox(height: 24),

            _buildFormField(
              controller: nameController,
              label: 'Course Name',
              icon: Icons.school,
              isRequired: true,
            ),

            _buildFormField(
              controller: descriptionController,
              label: 'Description',
              icon: Icons.description,
              maxLines: 3,
            ),

            Row(
              children: [
                Expanded(
                  child: _buildFormField(
                    controller: statusController,
                    label: 'Status',
                    icon: Icons.circle,
                    isRequired: true,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildFormField(
                    controller: durationController,
                    label: 'Duration',
                    icon: Icons.schedule,
                    isRequired: true,
                  ),
                ),
              ],
            ),

            Row(
              children: [
                Expanded(
                  child: _buildFormField(
                    controller: totalStudentsController,
                    label: 'Total Students',
                    icon: Icons.people,
                    keyboardType: TextInputType.number,
                    isRequired: true,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildFormField(
                    controller: priceController,
                    label: 'Price (SAR)',
                    icon: Icons.attach_money,
                    keyboardType: TextInputType.number,
                    isRequired: true,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      if (nameController.text.isEmpty ||
                          statusController.text.isEmpty ||
                          durationController.text.isEmpty ||
                          totalStudentsController.text.isEmpty ||
                          priceController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please fill required fields'))
                        );
                        return;
                      }

                      if (isEditing && course != null) {
                        await _updateCourse(
                          course.id,
                          nameController.text,
                          descriptionController.text,
                          statusController.text,
                          durationController.text,
                          int.tryParse(totalStudentsController.text) ?? 0,
                          double.tryParse(priceController.text) ?? 0.0,
                        );
                      } else {
                        if (selectedImage == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please select a course image'))
                          );
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
                        _showUploadSuccessDialog();
                      }

                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(isEditing ? 'Update' : 'Create'),
                  ),
                ),
              ],
            ),
             SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
          ],
        ),
      ),
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isRequired = false,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: '$label${isRequired ? '*' : ''}',
          prefixIcon: Icon(icon, size: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
      ),
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
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle,
                size: 64,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 24),
            Text('Course Created',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text('The course has been added successfully'),
          ],
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Continue'),
            ),
          ),
        ],
      ),
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
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$name updated successfully'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          )
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating course: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          )
      );
    }
  }

  Future<void> _deleteCourse(String courseId) async {
    try {
      await _firestore.collection('Courses').doc(courseId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Course deleted successfully'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          )
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting course: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          )
      );
    }
  }
}