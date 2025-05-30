import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _firebaseStorage = FirebaseStorage.instance;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _universityController = TextEditingController();
  final TextEditingController _branchController = TextEditingController();

  String _selectedDialCode = '+20';
  bool _isRegisterButtonEnabled = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isGmail = true;
  bool _passwordsMatch = true;
  bool _agreeToTerms = false;

  Uint8List? _selectedImageBytes;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_updateButtonState);
    _nameController.addListener(_updateButtonState);
    _passwordController.addListener(_updateButtonState);
    _confirmPasswordController.addListener(_updateButtonState);
    _phoneController.addListener(_updateButtonState);
    _universityController.addListener(_updateButtonState);
    _branchController.addListener(_updateButtonState);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _universityController.dispose();
    _branchController.dispose();
    super.dispose();
  }

  void _updateButtonState() {
    setState(() {
      _isGmail = _emailController.text.endsWith('@gmail.com');
      _passwordsMatch = _passwordController.text == _confirmPasswordController.text;

      _isRegisterButtonEnabled =
          _emailController.text.isNotEmpty &&
              _nameController.text.isNotEmpty &&
              _passwordController.text.isNotEmpty &&
              _confirmPasswordController.text.isNotEmpty &&
              _phoneController.text.isNotEmpty &&
              _universityController.text.isNotEmpty &&
              _branchController.text.isNotEmpty &&
              _isGmail &&
              _passwordsMatch &&
              _agreeToTerms;
    });
  }

  Future<void> _registerUser() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final UserCredential userCredential =
      await _firebaseAuth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      await _createStudent(userCredential.user!);
      _showSuccessDialog();
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration failed: ${e.message}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration failed: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createStudent(User user) async {
    final String email = user.email!;

    await _firestore.collection('Students').doc(email).set({
      'email': email,
      'name': _nameController.text.trim(),
      'phone': '$_selectedDialCode ${_phoneController.text.trim()}',
      'university': _universityController.text.trim(),
      'branch': _branchController.text.trim(),
      'studentID': await _generateStudentID(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (_selectedImageBytes != null) {
      await _uploadProfilePicture(email);
    }
  }

  Future<void> _uploadProfilePicture(String email) async {
    try {
      final storageRef = _firebaseStorage.ref().child('students/$email/profile_picture.png');
      await storageRef.putData(_selectedImageBytes!);
    } catch (e) {
      print('Error uploading profile picture: $e');
    }
  }

  Future<String> _generateStudentID() async {
    final year = DateTime.now().year.toString();
    final studentDocs = await _firestore.collection('Students').get();
    final nextId = (studentDocs.docs.length + 1).toString().padLeft(4, '0');
    return '$year$nextId';
  }

  Future<void> _pickImage() async {
    FilePickerResult? result =
    await FilePicker.platform.pickFiles(type: FileType.image);

    if (result != null) {
      PlatformFile file = result.files.first;
      final imageBytes = file.bytes;
      if (imageBytes != null) {
        setState(() {
          _selectedImageBytes = imageBytes;
        });
      }
    }
  }

  void _showAgreementDialog() {
    showDialog(
      context: context,
      builder: (context) {
        bool localAgreeToTerms = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Agreement License and Rules'),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.8,
                height: MediaQuery.of(context).size.height * 0.6,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: const Text(
                          'By registering, you agree to our terms and conditions...',
                          textAlign: TextAlign.justify,
                        ),
                      ),
                    ),
                    CheckboxListTile(
                      title: const Text('I agree to the terms and conditions'),
                      value: localAgreeToTerms,
                      onChanged: (bool? value) {
                        setState(() {
                          localAgreeToTerms = value ?? false;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _agreeToTerms = localAgreeToTerms;
                    });
                    Navigator.of(context).pop();
                    _updateButtonState();
                  },
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Registration Successful'),
          content: const Text('Your registration was completed successfully. You can now log in.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120.0,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'Create Account',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              centerTitle: true,
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1A73E8), Color(0xFF0D47A1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildProfilePictureSection(),
                      const SizedBox(height: 28),
                      _buildEmailField(),
                      const SizedBox(height: 20),
                      _buildNameField(),
                      const SizedBox(height: 20),
                      _buildPasswordFields(),
                      const SizedBox(height: 20),
                      _buildPhoneField(),
                      const SizedBox(height: 20),
                      _buildUniversityField(),
                      const SizedBox(height: 20),
                      _buildBranchField(),
                      const SizedBox(height: 24),
                      _buildTermsAgreement(),
                      const SizedBox(height: 28),
                      _buildRegisterButton(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfilePictureSection() {
    return Center(
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFE0E0E0),
                    width: 2,
                  ),
                ),
                child: ClipOval(
                  child: _selectedImageBytes != null
                      ? Image.memory(
                    _selectedImageBytes!,
                    fit: BoxFit.cover,
                  )
                      : Container(
                    color: const Color(0xFFF5F7FA),
                    child: const Icon(
                      Icons.person_outline_rounded,
                      size: 50,
                      color: Color(0xFF9E9E9E),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -4,
                right: -4,
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A73E8),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Add Profile Photo',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Email Address',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF5F7FA),
            prefixIcon: const Icon(Icons.email_rounded, color: Colors.grey),
            hintText: 'your.email@gmail.com',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 16,
            ),
          ),
          onChanged: (value) => _updateButtonState(),
        ),
        if (!_isGmail)
          Padding(
            padding: const EdgeInsets.only(top: 6.0),
            child: Text(
              'Please use a Gmail address',
              style: TextStyle(
                color: Colors.red[400],
                fontSize: 13,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Full Name',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          keyboardType: TextInputType.name,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF5F7FA),
            prefixIcon: const Icon(Icons.person_rounded, color: Colors.grey),
            hintText: 'Your full name',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 16,
            ),
          ),
          onChanged: (value) => _updateButtonState(),
        ),
      ],
    );
  }

  Widget _buildPasswordFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Password',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF5F7FA),
                      prefixIcon: const Icon(Icons.lock_rounded, color: Colors.grey),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      hintText: '••••••••',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 16,
                      ),
                    ),
                    onChanged: (value) => _updateButtonState(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Confirm Password',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF5F7FA),
                      prefixIcon: const Icon(Icons.lock_outline_rounded, color: Colors.grey),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                      hintText: '••••••••',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 16,
                      ),
                    ),
                    onChanged: (value) => _updateButtonState(),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (!_passwordsMatch)
          Padding(
            padding: const EdgeInsets.only(top: 6.0),
            child: Text(
              'Passwords do not match',
              style: TextStyle(
                color: Colors.red[400],
                fontSize: 13,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPhoneField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Phone Number',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedDialCode,
                  icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.grey),
                  items: <String>['+20', '+1', '+44', '+91']
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value, style: const TextStyle(fontSize: 16)),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedDialCode = newValue!;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF5F7FA),
                  prefixIcon: const Icon(Icons.phone_iphone_rounded, color: Colors.grey),
                  hintText: '123 456 7890',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 16,
                  ),
                ),
                onChanged: (value) => _updateButtonState(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUniversityField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'University',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _universityController,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF5F7FA),
            prefixIcon: const Icon(Icons.school_rounded, color: Colors.grey),
            hintText: 'University name',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 16,
            ),
          ),
          onChanged: (value) => _updateButtonState(),
        ),
      ],
    );
  }

  Widget _buildBranchField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Branch/Department',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _branchController,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF5F7FA),
            prefixIcon: const Icon(Icons.business_center_rounded, color: Colors.grey),
            hintText: 'Your field of study',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 16,
            ),
          ),
          onChanged: (value) => _updateButtonState(),
        ),
      ],
    );
  }

  Widget _buildTermsAgreement() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Transform.scale(
          scale: 1.2,
          child: Checkbox(
            value: _agreeToTerms,
            activeColor: const Color(0xFF1A73E8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            onChanged: (bool? value) {
              setState(() {
                _agreeToTerms = value ?? false;
                _updateButtonState();
              });
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'I agree to the ',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              GestureDetector(
                onTap: _showAgreementDialog,
                child: const Text(
                  'Terms and Conditions',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF1A73E8),
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterButton() {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: _isRegisterButtonEnabled ? _registerUser : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1A73E8),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: _isLoading
            ? const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: Colors.white,
          ),
        )
            : const Text(
          'Create Account',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}