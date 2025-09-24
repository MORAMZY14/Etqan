import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'course_users_page.dart';

// Add these constants at the top of the file
const List<String> _categories = ['Development', 'Designing', 'Business', 'Marketing', 'Other'];

class CourseManagementPage extends StatefulWidget {
  const CourseManagementPage({super.key});

  @override
  _CourseManagementPageState createState() => _CourseManagementPageState();
}

class _CourseManagementPageState extends State<CourseManagementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
        foregroundColor: Theme.of(context).colorScheme.onSurface,
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
                    final code = course['code']?.toString().toLowerCase() ?? ''; // Handle null code
                    final category = course['category']?.toString().toLowerCase() ?? ''; // Handle null category
                    final query = _searchQuery.toLowerCase();
                    return name.contains(query) || code.contains(query) || category.contains(query);
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
          hintText: 'Search courses by name, code, or category...',
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
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
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

                      const SizedBox(height: 4),

                      // Display course code and category
                      Row(
                        children: [
                          Text(
                            course['code'] ?? 'No code', // Handle null code
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              course['category'] ?? 'No category', // Handle null category
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 4),

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

                          // Updated price display with currency
                          Text(
                            '${course['price']} ${course['currency']}',
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
        return const _CourseForm(isEditing: false);
      },
    ).then((result) async {
      if (mounted && result != null) {
        await _handleFormResult(result);
      }
    });
  }

  void _showEditCourseDialog(DocumentSnapshot course) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _CourseForm(isEditing: true, course: course);
      },
    ).then((result) async {
      if (mounted && result != null) {
        await _handleFormResult(result);
      }
    });
  }

  Future<void> _handleFormResult(Map<String, dynamic> result) async {
    final isEditing = result['isEditing'] as bool;
    final courseData = result['courseData'] as Map<String, dynamic>;
    final imageBytes = result['image'] as Uint8List?;
    final courseId = result['courseId'] as String?;

    try {
      if (isEditing && courseId != null) {
        await _updateCourse(
          courseId,
          courseData['name'],
          courseData['code'],
          courseData['category'],
          courseData['description'],
          courseData['content'],
          courseData['status'],
          courseData['duration'],
          courseData['totalStudents'],
          courseData['price'],
          courseData['currency'],
        );
      } else if (!isEditing && imageBytes != null) {
        await _addCourse(
          courseData['name'],
          courseData['code'],
          courseData['category'],
          courseData['description'],
          courseData['content'],
          courseData['status'],
          courseData['duration'],
          courseData['totalStudents'],
          courseData['price'],
          courseData['currency'],
          imageBytes,
        );

        if (mounted) {
          _showUploadSuccessDialog();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Theme.of(context).colorScheme.error,
            )
        );
      }
    }
  }

  Future<void> _addCourse(
      String name,
      String code,
      String category,
      String description,
      String content,
      String status,
      String duration,
      int totalStudents,
      double price,
      String currency,
      Uint8List imageBytes,
      ) async {
    try {
      final courseId = name;
      final currentUserEmail = _auth.currentUser!.email!;

      await _firestore.collection('Courses').doc(courseId).set({
        'name': name,
        'code': code,
        'category': category,
        'description': description,
        'content': content,
        'status': status,
        'duration': duration,
        'totalStudents': totalStudents,
        'price': price,
        'currency': currency,
        // New fields
        'instructor': currentUserEmail,
        'new': true,
        'popular': false,
        'pendingSince': {}, // Empty map
        'PendingStudent': {}, // Empty map
        'signedUsers': {
          'status': status,
          'totalStudents': totalStudents,
        },
      });

      final imageRef = _storage.ref('courses/$courseId/$courseId.png');
      await imageRef.putData(imageBytes);
    } catch (e) {
      print('Error adding course: $e');
      rethrow;
    }
  }

  void _showUploadSuccessDialog() {
    // FIX: Check if widget is still mounted
    if (!mounted) return;

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
      String code,
      String category,
      String description,
      String content,
      String status,
      String duration,
      int totalStudents,
      double price,
      String currency,
      ) async {
    try {
      final updateData = {
        'name': name,
        'description': description,
        'content': content,
        'status': status,
        'duration': duration,
        'totalStudents': totalStudents,
        'price': price,
        'currency': currency,
        'signedUsers.status': status,
        'signedUsers.totalStudents': totalStudents,
      };

      // Only add code and category if they're not empty
      if (code.isNotEmpty) updateData['code'] = code;
      if (category.isNotEmpty) updateData['category'] = category;

      await _firestore.collection('Courses').doc(courseId).update(updateData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$name updated successfully'),
              backgroundColor: Theme.of(context).colorScheme.primary,
            )
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating course: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            )
        );
      }
    }
  }

  Future<void> _deleteCourse(String courseId) async {
    try {
      await _firestore.collection('Courses').doc(courseId).delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Course deleted successfully'),
              backgroundColor: Theme.of(context).colorScheme.primary,
            )
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting course: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            )
        );
      }
    }
  }
}

class _CourseForm extends StatefulWidget {
  final bool isEditing;
  final DocumentSnapshot? course;

  const _CourseForm({required this.isEditing, this.course});

  @override
  __CourseFormState createState() => __CourseFormState();
}

class __CourseFormState extends State<_CourseForm> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _contentController;
  late TextEditingController _statusController;
  late TextEditingController _durationController;
  late TextEditingController _totalStudentsController;
  late TextEditingController _priceController;
  late TextEditingController _codeController;
  Uint8List? _imageBytes;
  final ImagePicker _picker = ImagePicker();

  String _selectedCurrency = 'SAR';
  String _selectedCategory = 'Development';
  final List<String> _currencies = ['EGP', 'SAR', 'USD'];
  final String _instructorEmail = FirebaseAuth.instance.currentUser?.email ?? '';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.course?['name']);
    _descriptionController = TextEditingController(text: widget.course?['description']);
    _contentController = TextEditingController(text: widget.course?['content'] ?? '');
    _statusController = TextEditingController(text: widget.course?['status']);
    _durationController = TextEditingController(text: widget.course?['duration']);
    _totalStudentsController = TextEditingController(
        text: widget.course?['totalStudents']?.toString());
    _priceController = TextEditingController(text: widget.course?['price']?.toString());
    _codeController = TextEditingController(text: widget.course?['code'] ?? ''); // Handle null code
    _selectedCurrency = widget.course?['currency'] ?? 'SAR';
    _selectedCategory = widget.course?['category'] ?? 'Development'; // Handle null category
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _contentController.dispose();
    _statusController.dispose();
    _durationController.dispose();
    _totalStudentsController.dispose();
    _priceController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        // FIX: Check if widget is still mounted before updating state
        if (mounted) {
          setState(() {
            _imageBytes = bytes;
          });
        }
      }
    } catch (e) {
      print('Error picking image: $e');
    }
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

  Widget _buildInstructorField() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        initialValue: _instructorEmail,
        readOnly: true,
        decoration: InputDecoration(
          labelText: 'Instructor',
          prefixIcon: const Icon(Icons.person, size: 20),
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

  Widget _buildCurrencyDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCurrency,
          isExpanded: true,
          icon: Icon(Icons.arrow_drop_down,
              color: Theme.of(context).colorScheme.primary),
          items: _currencies.map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
            );
          }).toList(),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() {
                _selectedCurrency = newValue;
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Category*',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCategory,
                isExpanded: true,
                icon: Icon(Icons.arrow_drop_down,
                    color: Theme.of(context).colorScheme.primary),
                items: _categories.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedCategory = newValue;
                    });
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              widget.isEditing ? 'Edit Course' : 'Create New Course',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700
              ),
            ),

            const SizedBox(height: 24),

            // Image Picker
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: _imageBytes != null
                      ? ClipOval(child: Image.memory(_imageBytes!, fit: BoxFit.cover))
                      : Icon(Icons.add_a_photo, size: 40,
                      color: Theme.of(context).colorScheme.outline),
                ),
              ),
            ),

            const SizedBox(height: 24),

            _buildFormField(
              controller: _nameController,
              label: 'Course Name',
              icon: Icons.school,
              isRequired: true,
            ),

            _buildFormField(
              controller: _codeController,
              label: 'Course Code',
              icon: Icons.code,
              isRequired: true,
            ),

            _buildCategoryDropdown(),

            _buildFormField(
              controller: _descriptionController,
              label: 'Description',
              icon: Icons.description,
              maxLines: 3,
            ),

            // Content Field
            _buildFormField(
              controller: _contentController,
              label: 'Course Content',
              icon: Icons.library_books,
              maxLines: 5,
            ),

            // Instructor Field
            _buildInstructorField(),

            Row(
              children: [
                Expanded(
                  child: _buildFormField(
                    controller: _statusController,
                    label: 'Status',
                    icon: Icons.circle,
                    isRequired: true,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildFormField(
                    controller: _durationController,
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
                    controller: _totalStudentsController,
                    label: 'Total Students',
                    icon: Icons.people,
                    keyboardType: TextInputType.number,
                    isRequired: true,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Price*',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: _buildFormField(
                              controller: _priceController,
                              label: '',
                              icon: Icons.attach_money,
                              keyboardType: TextInputType.number,
                              isRequired: true,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 1,
                            child: _buildCurrencyDropdown(),
                          ),
                        ],
                      ),
                    ],
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
                      if (_nameController.text.isEmpty ||
                          _codeController.text.isEmpty ||
                          _statusController.text.isEmpty ||
                          _durationController.text.isEmpty ||
                          _totalStudentsController.text.isEmpty ||
                          _priceController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please fill required fields'))
                        );
                        return;
                      }

                      if (!widget.isEditing && _imageBytes == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please select a course image'))
                        );
                        return;
                      }

                      final courseData = {
                        'name': _nameController.text,
                        'code': _codeController.text,
                        'category': _selectedCategory,
                        'description': _descriptionController.text,
                        'content': _contentController.text,
                        'status': _statusController.text,
                        'duration': _durationController.text,
                        'totalStudents': int.tryParse(_totalStudentsController.text) ?? 0,
                        'price': double.tryParse(_priceController.text) ?? 0.0,
                        'currency': _selectedCurrency,
                      };

                      Navigator.pop(context, {
                        'isEditing': widget.isEditing,
                        'courseId': widget.course?.id,
                        'courseData': courseData,
                        'image': _imageBytes,
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(widget.isEditing ? 'Update' : 'Create'),
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
}