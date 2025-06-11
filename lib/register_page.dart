import 'dart:math';
import 'verification_screen.dart';
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
  bool _verificationEmailSent = false;

  Uint8List? _selectedImageBytes;

  // Modern color palette
  final Color _primaryColor = const Color(0xFF6C63FF); // Purple
  final Color _secondaryColor = const Color(0xFF4D8DEE); // Blue
  final Color _accentColor = const Color(0xFF00BFA6); // Teal
  final Color _backgroundColor = const Color(0xFFF8F9FA); // Light gray
  final Color _surfaceColor = Colors.white;
  final Color _errorColor = const Color(0xFFFF5252); // Red
  final Color _textColor = const Color(0xFF2D3748); // Dark gray
  final Color _hintColor = const Color(0xFFA0AEC0); // Light gray

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

  Future<void> _sendVerificationEmail(String email, String code) async {
    await FirebaseFirestore.instance.collection('verificationCodes').doc(email).set({
      'code': code,
      'createdAt': FieldValue.serverTimestamp(),
    });
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

  String _generateVerificationCode() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
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

      final User? user = userCredential.user;

      if (user != null) {
        final verificationCode = _generateVerificationCode();
        await _sendVerificationEmail(_emailController.text.trim(), verificationCode);
        await _createStudent(user);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => VerificationScreen(
              email: _emailController.text.trim(),
            ),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registration failed: ${e.message}'),
          backgroundColor: _errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registration failed: ${e.toString()}'),
          backgroundColor: _errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
      'emailVerified': false,
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
            return Dialog(
              backgroundColor: _surfaceColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Terms and Conditions',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: _textColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      height: MediaQuery.of(context).size.height * 0.4,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _backgroundColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          'By registering, you agree to our terms and conditions...\n\n'
                              '1. You must be a current student at an accredited university\n'
                              '2. You agree to use this platform for educational purposes only\n'
                              '3. You will not share your account credentials with others\n'
                              '4. You will respect the intellectual property of others\n'
                              '5. You understand that violations may result in account termination\n\n'
                              'We respect your privacy and will handle your personal information '
                              'in accordance with our Privacy Policy.',
                          style: TextStyle(
                            fontSize: 14,
                            color: _textColor.withOpacity(0.8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Transform.scale(
                          scale: 1.2,
                          child: Checkbox(
                            value: localAgreeToTerms,
                            activeColor: _primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            onChanged: (bool? value) {
                              setState(() {
                                localAgreeToTerms = value ?? false;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'I agree to the terms',
                          style: TextStyle(
                            fontSize: 14,
                            color: _textColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            foregroundColor: _hintColor,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                          ),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: localAgreeToTerms
                              ? () {
                            setState(() {
                              _agreeToTerms = localAgreeToTerms;
                            });
                            Navigator.of(context).pop();
                            _updateButtonState();
                          }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            elevation: 0,
                          ),
                          child: const Text('Confirm'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180.0,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'Create Account',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
              centerTitle: true,
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_primaryColor, _secondaryColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      'Join our community of learners',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                children: [
                  // Profile picture section
                  _buildProfilePictureSection(),
                  const SizedBox(height: 32),

                  // Form container
                  Container(
                    decoration: BoxDecoration(
                      color: _surfaceColor,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfilePictureSection() {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _primaryColor.withOpacity(0.2),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipOval(
                child: _selectedImageBytes != null
                    ? Image.memory(
                  _selectedImageBytes!,
                  fit: BoxFit.cover,
                )
                    : Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _primaryColor.withOpacity(0.1),
                        _secondaryColor.withOpacity(0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Icon(
                    Icons.person_outline_rounded,
                    size: 50,
                    color: _primaryColor.withOpacity(0.4),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _primaryColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: _primaryColor.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
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
        const SizedBox(height: 16),
        Text(
          'Add Profile Photo',
          style: TextStyle(
            fontSize: 15,
            color: _textColor.withOpacity(0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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
            color: _textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: TextStyle(color: _textColor),
          decoration: InputDecoration(
            filled: true,
            fillColor: _backgroundColor,
            prefixIcon: Icon(Icons.email_rounded, color: _hintColor),
            hintText: 'your.email@gmail.com',
            hintStyle: TextStyle(color: _hintColor),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 16,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _primaryColor, width: 1.5),
            ),
          ),
          onChanged: (value) => _updateButtonState(),
        ),
        if (!_isGmail)
          Padding(
            padding: const EdgeInsets.only(top: 6.0),
            child: Row(
              children: [
                Icon(Icons.error_outline_rounded, size: 16, color: _errorColor),
                const SizedBox(width: 4),
                Text(
                  'Please use a Gmail address',
                  style: TextStyle(
                    color: _errorColor,
                    fontSize: 13,
                  ),
                ),
              ],
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
            color: _textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          keyboardType: TextInputType.name,
          style: TextStyle(color: _textColor),
          decoration: InputDecoration(
            filled: true,
            fillColor: _backgroundColor,
            prefixIcon: Icon(Icons.person_rounded, color: _hintColor),
            hintText: 'Your full name',
            hintStyle: TextStyle(color: _hintColor),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 16,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _primaryColor, width: 1.5),
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
                      color: _textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: TextStyle(color: _textColor),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: _backgroundColor,
                      prefixIcon: Icon(Icons.lock_rounded, color: _hintColor),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: _hintColor,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      hintText: '••••••••',
                      hintStyle: TextStyle(color: _hintColor),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 16,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _primaryColor, width: 1.5),
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
                      color: _textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    style: TextStyle(color: _textColor),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: _backgroundColor,
                      prefixIcon: Icon(Icons.lock_outline_rounded, color: _hintColor),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: _hintColor,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                      hintText: '••••••••',
                      hintStyle: TextStyle(color: _hintColor),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 16,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _primaryColor, width: 1.5),
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
            child: Row(
              children: [
                Icon(Icons.error_outline_rounded, size: 16, color: _errorColor),
                const SizedBox(width: 4),
                Text(
                  'Passwords do not match',
                  style: TextStyle(
                    color: _errorColor,
                    fontSize: 13,
                  ),
                ),
              ],
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
            color: _textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: _backgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedDialCode,
                  icon: Icon(Icons.arrow_drop_down_rounded, color: _hintColor),
                  items: <String>['+20', '+1', '+44', '+91']
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: 16,
                          color: _textColor,
                        ),
                      ),
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
                style: TextStyle(color: _textColor),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: _backgroundColor,
                  prefixIcon: Icon(Icons.phone_iphone_rounded, color: _hintColor),
                  hintText: '123 456 7890',
                  hintStyle: TextStyle(color: _hintColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 16,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _primaryColor, width: 1.5),
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
            color: _textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _universityController,
          style: TextStyle(color: _textColor),
          decoration: InputDecoration(
            filled: true,
            fillColor: _backgroundColor,
            prefixIcon: Icon(Icons.school_rounded, color: _hintColor),
            hintText: 'University name',
            hintStyle: TextStyle(color: _hintColor),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 16,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _primaryColor, width: 1.5),
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
            color: _textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _branchController,
          style: TextStyle(color: _textColor),
          decoration: InputDecoration(
            filled: true,
            fillColor: _backgroundColor,
            prefixIcon: Icon(Icons.business_center_rounded, color: _hintColor),
            hintText: 'Your field of study',
            hintStyle: TextStyle(color: _hintColor),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 16,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _primaryColor, width: 1.5),
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
            activeColor: _primaryColor,
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
              Text(
                'I agree to the ',
                style: TextStyle(
                  fontSize: 14,
                  color: _hintColor,
                ),
              ),
              GestureDetector(
                onTap: _showAgreementDialog,
                child: Text(
                  'Terms and Conditions',
                  style: TextStyle(
                    fontSize: 14,
                    color: _primaryColor,
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
        onPressed: _verificationEmailSent
            ? null
            : (_isRegisterButtonEnabled ? _registerUser : null),
        style: ElevatedButton.styleFrom(
          backgroundColor: _verificationEmailSent
              ? _hintColor
              : _isRegisterButtonEnabled ? _primaryColor : _hintColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shadowColor: _primaryColor.withOpacity(0.3),
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
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _verificationEmailSent ? 'Verification Sent' : 'Create Account',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (!_isLoading && _isRegisterButtonEnabled)
              const SizedBox(width: 8),
            if (!_isLoading && _isRegisterButtonEnabled)
              Icon(Icons.arrow_forward_rounded, size: 20),
          ],
        ),
      ),
    );
  }
}