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
  String _selectedCountryCode = 'EG';
  bool _isRegisterButtonEnabled = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isGmail = true;
  bool _passwordsMatch = true;
  bool _agreeToTerms = false;
  final bool _verificationEmailSent = false;

  Uint8List? _selectedImageBytes;

  // Liquid Glass Apple Style Colors
  final Color _primaryColor = const Color(0xFF007AFF); // Apple Blue
  final Color _secondaryColor = const Color(0xFF34C759); // Apple Green
  final Color _accentColor = const Color(0xFF5856D6); // Apple Purple
  final Color _backgroundColor = const Color(0xFFF2F2F7); // Apple Gray
  final Color _surfaceColor = Colors.white;
  final Color _errorColor = const Color(0xFFFF3B30); // Apple Red
  final Color _textColor = const Color(0xFF1C1C1E); // Apple Black
  final Color _hintColor = const Color(0xFF8E8E93); // Apple Gray

  // List of countries with dial codes and flags
  final List<Map<String, String>> countries = [
    {'code': 'US', 'name': 'United States', 'dial_code': '+1', 'flag': '🇺🇸'},
    {'code': 'GB', 'name': 'United Kingdom', 'dial_code': '+44', 'flag': '🇬🇧'},
    {'code': 'IN', 'name': 'India', 'dial_code': '+91', 'flag': '🇮🇳'},
    {'code': 'EG', 'name': 'Egypt', 'dial_code': '+20', 'flag': '🇪🇬'},
    {'code': 'SA', 'name': 'Saudi Arabia', 'dial_code': '+966', 'flag': '🇸🇦'},
    {'code': 'AE', 'name': 'United Arab Emirates', 'dial_code': '+971', 'flag': '🇦🇪'},
    {'code': 'FR', 'name': 'France', 'dial_code': '+33', 'flag': '🇫🇷'},
    {'code': 'DE', 'name': 'Germany', 'dial_code': '+49', 'flag': '🇩🇪'},
    {'code': 'CA', 'name': 'Canada', 'dial_code': '+1', 'flag': '🇨🇦'},
    {'code': 'AU', 'name': 'Australia', 'dial_code': '+61', 'flag': '🇦🇺'},
    {'code': 'BR', 'name': 'Brazil', 'dial_code': '+55', 'flag': '🇧🇷'},
    {'code': 'CN', 'name': 'China', 'dial_code': '+86', 'flag': '🇨🇳'},
    {'code': 'JP', 'name': 'Japan', 'dial_code': '+81', 'flag': '🇯🇵'},
    {'code': 'KR', 'name': 'South Korea', 'dial_code': '+82', 'flag': '🇰🇷'},
    {'code': 'MX', 'name': 'Mexico', 'dial_code': '+52', 'flag': '🇲🇽'},
    {'code': 'IT', 'name': 'Italy', 'dial_code': '+39', 'flag': '🇮🇹'},
    {'code': 'ES', 'name': 'Spain', 'dial_code': '+34', 'flag': '🇪🇸'},
    {'code': 'RU', 'name': 'Russia', 'dial_code': '+7', 'flag': '🇷🇺'},
    {'code': 'ZA', 'name': 'South Africa', 'dial_code': '+27', 'flag': '🇿🇦'},
    {'code': 'TR', 'name': 'Turkey', 'dial_code': '+90', 'flag': '🇹🇷'},
    // Add more countries as needed
  ];

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
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Terms and Conditions',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: _textColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      height: MediaQuery.of(context).size.height * 0.4,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _backgroundColor,
                        borderRadius: BorderRadius.circular(12),
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
                        Checkbox(
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
                                horizontal: 16, vertical: 10),
                          ),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
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
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
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
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.grey[900] : _backgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 160.0,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'Create Account',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              centerTitle: true,
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_primaryColor, Color(0xFF5AC8FA)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                children: [
                  // Profile picture section
                  _buildProfilePictureSection(),
                  const SizedBox(height: 24),
                  Text(
                    'Join our learning community',
                    style: TextStyle(
                      fontSize: 16,
                      color: isDarkMode ? Colors.white70 : _hintColor,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Form container
                  Container(
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey[800] : _surfaceColor,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildEmailField(isDarkMode),
                        const SizedBox(height: 16),
                        _buildNameField(isDarkMode),
                        const SizedBox(height: 16),
                        _buildPasswordField(isDarkMode),
                        const SizedBox(height: 16),
                        _buildConfirmPasswordField(isDarkMode),
                        const SizedBox(height: 16),
                        _buildPhoneField(isDarkMode),
                        const SizedBox(height: 16),
                        _buildUniversityField(isDarkMode),
                        const SizedBox(height: 16),
                        _buildBranchField(isDarkMode),
                        const SizedBox(height: 20),
                        _buildTermsAgreement(isDarkMode),
                        const SizedBox(height: 24),
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
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: _pickImage,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [_primaryColor.withOpacity(0.1), _secondaryColor.withOpacity(0.1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
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
                  : Icon(
                Icons.person_outline_rounded,
                size: 50,
                color: _primaryColor.withOpacity(0.4),
              ),
            ),
          ),
          if (_selectedImageBytes == null)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _primaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.add,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmailField(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Email Address',
          style: TextStyle(
            fontSize: 14,
            color: isDarkMode ? Colors.white : _textColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: TextStyle(color: isDarkMode ? Colors.white : _textColor, fontSize: 16),
          decoration: InputDecoration(
            filled: true,
            fillColor: isDarkMode ? Colors.grey[700] : _backgroundColor,
            prefixIcon: Icon(Icons.email_rounded, color: isDarkMode ? Colors.white70 : _hintColor),
            hintText: 'your.email@gmail.com',
            hintStyle: TextStyle(color: isDarkMode ? Colors.white60 : _hintColor),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 14,
              horizontal: 16,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: _primaryColor, width: 1),
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

  Widget _buildNameField(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Full Name',
          style: TextStyle(
            fontSize: 14,
            color: isDarkMode ? Colors.white : _textColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _nameController,
          keyboardType: TextInputType.name,
          style: TextStyle(color: isDarkMode ? Colors.white : _textColor, fontSize: 16),
          decoration: InputDecoration(
            filled: true,
            fillColor: isDarkMode ? Colors.grey[700] : _backgroundColor,
            prefixIcon: Icon(Icons.person_rounded, color: isDarkMode ? Colors.white70 : _hintColor),
            hintText: 'Your full name',
            hintStyle: TextStyle(color: isDarkMode ? Colors.white60 : _hintColor),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 14,
              horizontal: 16,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: _primaryColor, width: 1),
            ),
          ),
          onChanged: (value) => _updateButtonState(),
        ),
      ],
    );
  }

  Widget _buildPasswordField(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Password',
          style: TextStyle(
            fontSize: 14,
            color: isDarkMode ? Colors.white : _textColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: TextStyle(color: isDarkMode ? Colors.white : _textColor, fontSize: 16),
          decoration: InputDecoration(
            filled: true,
            fillColor: isDarkMode ? Colors.grey[700] : _backgroundColor,
            prefixIcon: Icon(Icons.lock_rounded, color: isDarkMode ? Colors.white70 : _hintColor),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: isDarkMode ? Colors.white70 : _hintColor,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
            hintText: '••••••••',
            hintStyle: TextStyle(color: isDarkMode ? Colors.white60 : _hintColor),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 14,
              horizontal: 16,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: _primaryColor, width: 1),
            ),
          ),
          onChanged: (value) => _updateButtonState(),
        ),
      ],
    );
  }

  Widget _buildConfirmPasswordField(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Confirm Password',
          style: TextStyle(
            fontSize: 14,
            color: isDarkMode ? Colors.white : _textColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          style: TextStyle(color: isDarkMode ? Colors.white : _textColor, fontSize: 16),
          decoration: InputDecoration(
            filled: true,
            fillColor: isDarkMode ? Colors.grey[700] : _backgroundColor,
            prefixIcon: Icon(Icons.lock_outline_rounded, color: isDarkMode ? Colors.white70 : _hintColor),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: isDarkMode ? Colors.white70 : _hintColor,
              ),
              onPressed: () {
                setState(() {
                  _obscureConfirmPassword = !_obscureConfirmPassword;
                });
              },
            ),
            hintText: '••••••••',
            hintStyle: TextStyle(color: isDarkMode ? Colors.white60 : _hintColor),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 14,
              horizontal: 16,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: _primaryColor, width: 1),
            ),
          ),
          onChanged: (value) => _updateButtonState(),
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

  Widget _buildPhoneField(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Phone Number',
          style: TextStyle(
            fontSize: 14,
            color: isDarkMode ? Colors.white : _textColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[700] : _backgroundColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCountryCode,
                  icon: Icon(Icons.arrow_drop_down_rounded, color: isDarkMode ? Colors.white70 : _hintColor),
                  dropdownColor: isDarkMode ? Colors.grey[800] : _surfaceColor,
                  items: countries.map<DropdownMenuItem<String>>((Map<String, String> country) {
                    return DropdownMenuItem<String>(
                      value: country['code'],
                      child: Row(
                        children: [
                          Text(
                            country['flag']!,
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            country['dial_code']!,
                            style: TextStyle(
                              fontSize: 16,
                              color: isDarkMode ? Colors.white : _textColor,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedCountryCode = newValue!;
                      _selectedDialCode = countries.firstWhere((country) => country['code'] == newValue)['dial_code']!;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: TextStyle(color: isDarkMode ? Colors.white : _textColor, fontSize: 16),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: isDarkMode ? Colors.grey[700] : _backgroundColor,
                  prefixIcon: Icon(Icons.phone_iphone_rounded, color: isDarkMode ? Colors.white70 : _hintColor),
                  hintText: '123 456 7890',
                  hintStyle: TextStyle(color: isDarkMode ? Colors.white60 : _hintColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 16,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: _primaryColor, width: 1),
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

  Widget _buildUniversityField(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'University',
          style: TextStyle(
            fontSize: 14,
            color: isDarkMode ? Colors.white : _textColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _universityController,
          style: TextStyle(color: isDarkMode ? Colors.white : _textColor, fontSize: 16),
          decoration: InputDecoration(
            filled: true,
            fillColor: isDarkMode ? Colors.grey[700] : _backgroundColor,
            prefixIcon: Icon(Icons.school_rounded, color: isDarkMode ? Colors.white70 : _hintColor),
            hintText: 'University name',
            hintStyle: TextStyle(color: isDarkMode ? Colors.white60 : _hintColor),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 14,
              horizontal: 16,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: _primaryColor, width: 1),
            ),
          ),
          onChanged: (value) => _updateButtonState(),
        ),
      ],
    );
  }

  Widget _buildBranchField(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Branch/Department',
          style: TextStyle(
            fontSize: 14,
            color: isDarkMode ? Colors.white : _textColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _branchController,
          style: TextStyle(color: isDarkMode ? Colors.white : _textColor, fontSize: 16),
          decoration: InputDecoration(
            filled: true,
            fillColor: isDarkMode ? Colors.grey[700] : _backgroundColor,
            prefixIcon: Icon(Icons.business_center_rounded, color: isDarkMode ? Colors.white70 : _hintColor),
            hintText: 'Your field of study',
            hintStyle: TextStyle(color: isDarkMode ? Colors.white60 : _hintColor),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 14,
              horizontal: 16,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: _primaryColor, width: 1),
            ),
          ),
          onChanged: (value) => _updateButtonState(),
        ),
      ],
    );
  }

  Widget _buildTermsAgreement(bool isDarkMode) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
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
        const SizedBox(width: 8),
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'I agree to the ',
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode ? Colors.white70 : _hintColor,
                ),
              ),
              GestureDetector(
                onTap: _showAgreementDialog,
                child: Text(
                  'Terms and Conditions',
                  style: TextStyle(
                    fontSize: 14,
                    color: _primaryColor,
                    fontWeight: FontWeight.w500,
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
      height: 50,
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
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: _isLoading
            ? const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: Colors.white,
          ),
        )
            : Text(
          _verificationEmailSent ? 'Verification Sent' : 'Create Account',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}