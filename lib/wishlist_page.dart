import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

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
  Uint8List? _paymentScreenshotBytes;
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
    final List<Map<String, dynamic>> result = [];

    for (final doc in snapshot.docs) {
      final courseName = doc.data()['name'] ?? 'Unknown Course';
      final List<dynamic> PendingStudentByCourse = doc.data()['PendingStudent'] ?? [];
      final List<dynamic> approvedUsersByCourse = doc.data()['ApprovedUsers'] ?? [];

      if (signedCoursesByUser.contains(courseName) ||
          PendingStudentByCourse.contains(userEmail) ||
          approvedUsersByCourse.contains(userEmail)) {
        continue;
      }

      final imageUrl = await _getCourseImageUrl(courseName);
      final coursePrice = doc.data()?['price'] ?? 0;

      result.add({
        'name': courseName,
        'imageUrl': imageUrl,
        'price': coursePrice,
      });
    }

    return result;
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
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.payment, size: 48, color: Colors.blue),
              const SizedBox(height: 16),
              const Text(
                'Payment Required',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Complete your payment using the link below:',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SelectableText(
                  _paymentLink,
                  style: const TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _showScreenshotUploadDialog();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Continue',
                        style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showScreenshotUploadDialog() {
    Uint8List? tempScreenshotBytes = _paymentScreenshotBytes;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: StatefulBuilder(
          builder: (context, setState) => Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.upload, size: 48, color: Colors.blue),
                const SizedBox(height: 16),
                const Text(
                  'Upload Payment Proof',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Please upload a screenshot of your payment confirmation',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: tempScreenshotBytes == null
                      ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.image, size: 48, color: Colors.grey),
                      const SizedBox(height: 8),
                      Text('No screenshot selected',
                          style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  )
                      : ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.memory(tempScreenshotBytes!, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    OutlinedButton(
                      onPressed: () async {
                        final picker = ImagePicker();
                        final pickedFile = await picker.pickImage(
                            source: ImageSource.gallery);
                        if (pickedFile != null) {
                          final bytes = await pickedFile.readAsBytes();
                          setState(() {
                            tempScreenshotBytes = bytes;
                          });
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: const BorderSide(color: Colors.blue),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
                      child: const Text('Choose File',
                          style: TextStyle(color: Colors.blue)),
                    ),
                    ElevatedButton(
                      onPressed: tempScreenshotBytes == null
                          ? null
                          : () {
                        Navigator.pop(context);
                        setState(() {
                          _paymentScreenshotBytes = tempScreenshotBytes;
                        });
                        _registerCourses();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
                      child: const Text('Submit',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      _paymentScreenshotBytes = null;
                    });
                  },
                  child:
                  const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  void _registerCourses() async {
    final user = _auth.currentUser;
    if (user == null || _paymentScreenshotBytes == null) return;

    final userEmail = user.email!;
    final registrationDate = DateTime.now();

    try {
      // Fetch student's Name and ID from Students collection
      final studentDoc = await _firestore.collection('Students').doc(userEmail).get();
      final studentName = studentDoc.data()?['name'] ?? '';
      final studentID = studentDoc.data()?['studentID'] ?? '';

      // Upload payment screenshot
      final storageRef = _storage.ref().child(
          'transactions/$userEmail/${registrationDate.millisecondsSinceEpoch}.png'
      );
      await storageRef.putData(_paymentScreenshotBytes!);
      final downloadUrl = await storageRef.getDownloadURL();

      final batch = _firestore.batch();

      for (final courseName in _selectedCourses) {
        // Get course number from Courses collection
        final courseDocRef = _firestore.collection('Courses').doc(courseName);
        final courseDocSnap = await courseDocRef.get();
        final courseNumber = courseDocSnap.data()?['number'] ?? '';

        // Build formatted timestamp for transaction document ID
        final formattedDate = DateFormat('yyyyMMdd_HHmmss').format(registrationDate);
        final transactionDocId = '$courseName-$formattedDate';

        // Reference to student's transactions subcollection
        final transactionDocRef = _firestore
            .collection('Transactions')
            .doc(userEmail)
            .collection('transactions')
            .doc(transactionDocId);

        // Add transaction document including studentName and studentID
        batch.set(transactionDocRef, {
          'transactionNumber': transactionDocRef.id,
          'studentEmail': userEmail,
          'studentName': studentName, // <-- Added studentName
          'studentID': studentID,     // <-- Added studentID
          'courseName': courseName,
          'courseNumber': courseNumber,
          'timestamp': registrationDate,
          'paymentScreenshot': downloadUrl,
          'status': 'pending', // possible: pending, rejected, approved
        });

        // Update PendingStudent array in the course doc
        batch.update(courseDocRef, {
          'PendingStudent': FieldValue.arrayUnion([userEmail]),
        });
      }

      // Commit batch updates
      await batch.commit();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration successful! Awaiting approval.')),
        );
      }

      // Clear selected courses and payment screenshot, refresh UI
      setState(() {
        _selectedCourses.clear();
        _paymentScreenshotBytes = null;
        _coursesFuture = _fetchCourses();
      });
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }





  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Courses',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _coursesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingGrid();
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text('No courses available',
                      style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
            );
          }

          final courses = snapshot.data!;
          return Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.8,
              ),
              itemCount: courses.length,
              itemBuilder: (context, index) {
                final course = courses[index];
                final courseName = course['name'] ?? 'Unknown Course';
                final courseImageUrl = course['imageUrl'] ?? '';
                final coursePrice = course['price'] ?? 0;
                final isSelected = _selectedCourses.contains(courseName);

                return GestureDetector(
                  onTap: () => _toggleSelection(courseName, !isSelected),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.blue.withOpacity(0.1)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                      border: Border.all(
                        color: isSelected ? Colors.blue : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(18)),
                              child: AspectRatio(
                                aspectRatio: 1.5,
                                child: courseImageUrl.isNotEmpty
                                    ? Image.network(
                                  courseImageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _buildPlaceholderImage(),
                                )
                                    : _buildPlaceholderImage(),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    courseName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '\$${coursePrice.toString()}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Positioned(
                          top: 12,
                          right: 12,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: isSelected
                                ? Container(
                              key: const ValueKey('selected'),
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check,
                                  size: 20, color: Colors.white),
                            )
                                : Container(
                              key: const ValueKey('unselected'),
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.3),
                                    blurRadius: 4,
                                  )
                                ],
                              ),
                              child: const Icon(Icons.add,
                                  size: 20, color: Colors.grey),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: _selectedCourses.isNotEmpty
          ? FloatingActionButton.extended(
        heroTag: UniqueKey(), // FIX FOR HERO TAG CONFLICT
        onPressed: _showPaymentDialog,
        backgroundColor: Colors.blue,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        icon: const Icon(Icons.shopping_cart_checkout, color: Colors.white),
        label: Text(
          'Register (${_selectedCourses.length})',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      color: Colors.grey.shade200,
      child: const Center(
        child: Icon(Icons.image, size: 40, color: Colors.grey),
      ),
    );
  }

  Widget _buildLoadingGrid() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.8,
        ),
        itemCount: 4,
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  child: AspectRatio(
                    aspectRatio: 1.5,
                    child: Container(
                      color: Colors.grey.shade200,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 16,
                        width: 120,
                        color: Colors.grey.shade200,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 14,
                        width: 80,
                        color: Colors.grey.shade200,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}