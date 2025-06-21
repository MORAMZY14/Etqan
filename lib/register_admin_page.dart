import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'admin_login_page.dart';
import 'dart:async';

class RegisterAdminPage extends StatefulWidget {
  const RegisterAdminPage({super.key});

  @override
  _RegisterAdminPageState createState() => _RegisterAdminPageState();
}

class _RegisterAdminPageState extends State<RegisterAdminPage> {
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
  final TextEditingController _verificationCodeController = TextEditingController();

  String _selectedDialCode = '+20';
  bool _isRegisterButtonEnabled = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isGmail = true;
  bool _passwordsMatch = true;
  bool _agreeToTerms = false;
  bool _showVerificationSection = false;
  String? _emailForVerification;
  int _resendTimer = 60;
  Timer? _resendTimerInstance;

  Uint8List? _selectedImageBytes;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_checkFields);
    _nameController.addListener(_checkFields);
    _passwordController.addListener(_checkFields);
    _confirmPasswordController.addListener(_checkFields);
    _phoneController.addListener(_checkFields);
    _universityController.addListener(_checkFields);
    _branchController.addListener(_checkFields);
  }

  @override
  void dispose() {
    _resendTimerInstance?.cancel();
    _emailController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _universityController.dispose();
    _branchController.dispose();
    _verificationCodeController.dispose();
    super.dispose();
  }

  void _checkFields() {
    setState(() {
      _isGmail = _emailController.text.endsWith('@gmail.com');
      _passwordsMatch = _passwordController.text == _confirmPasswordController.text;

      _isRegisterButtonEnabled = _emailController.text.isNotEmpty &&
          _nameController.text.isNotEmpty &&
          _passwordController.text.isNotEmpty &&
          _confirmPasswordController.text.isNotEmpty &&
          _phoneController.text.isNotEmpty &&
          _universityController.text.isNotEmpty &&
          _branchController.text.isNotEmpty &&
          _isGmail &&
          _passwordsMatch;
    });
  }

  Future<void> _registerUser() async {
    if (!_agreeToTerms) {
      _showAgreementDialog();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Store email for verification
      _emailForVerification = _emailController.text.trim();

      // Generate verification code
      final verificationCode = _generateVerificationCode();

      // Write to Firestore to trigger the Cloud Function
      await _firestore.collection('verificationCodes').doc(_emailForVerification).set({
        'code': verificationCode,
        'createdAt': FieldValue.serverTimestamp(),
        'purpose': 'admin_registration'
      });

      // Show verification UI
      setState(() {
        _showVerificationSection = true;
        _isLoading = false;
        _resendTimer = 60;
      });

      // Start resend timer
      _startResendTimer();

    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send verification code: ${e.toString()}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  String _generateVerificationCode() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  void _startResendTimer() {
    _resendTimerInstance?.cancel();
    _resendTimerInstance = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimer > 0) {
        setState(() {
          _resendTimer--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _verifyCode() async {
    final enteredCode = _verificationCodeController.text.trim();
    if (enteredCode.isEmpty || enteredCode.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a 6-digit code'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final doc = await _firestore.collection('verificationCodes').doc(_emailForVerification).get();

      if (!doc.exists) {
        throw Exception('Verification code expired or not found');
      }

      final storedCode = doc.data()!['code'] as String;
      final createdAt = (doc.data()!['createdAt'] as Timestamp).toDate();
      final now = DateTime.now();

      // Check if code is expired (10 minutes)
      if (now.difference(createdAt) > const Duration(minutes: 10)) {
        throw Exception('Verification code expired');
      }

      if (enteredCode != storedCode) {
        throw Exception('Invalid verification code');
      }

      // Code is valid - proceed with registration
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: _emailForVerification!,
        password: _passwordController.text.trim(),
      );

      if (userCredential.user != null) {
        await _createUser();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verification failed: ${e.toString()}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _resendVerificationCode() async {
    if (_resendTimer > 0) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final newCode = _generateVerificationCode();

      // Update Firestore document to trigger email resend
      await _firestore.collection('verificationCodes').doc(_emailForVerification).update({
        'code': newCode,
        'createdAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _resendTimer = 60;
      });
      _startResendTimer();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('New verification code sent'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to resend code: ${e.toString()}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createUser() async {
    final User? user = _firebaseAuth.currentUser;
    if (user != null) {
      final String userEmail = user.email!;
      final String adminID = await _generateAdminID();
      final newUser = {
        'email': userEmail,
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'dial': _selectedDialCode,
        'university': _universityController.text.trim(),
        'branch': _branchController.text.trim(),
        'adminID': adminID,
        'status': 'Active',
        'emailVerified': true,
        'role': 'admin',
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (_selectedImageBytes != null) {
        await _uploadProfilePicture(userEmail);
      }

      await _firestore.collection('Admins').doc(userEmail).set(newUser);

      _showSuccessDialog();
    }
  }

  Future<void> _uploadProfilePicture(String userEmail) async {
    final storageRef = _firebaseStorage.ref().child('admins/$userEmail/profile_picture.png');

    try {
      final uploadTask = storageRef.putData(_selectedImageBytes!);
      await uploadTask.whenComplete(() => null);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload profile picture: ${e.toString()}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<String> _generateAdminID() async {
    final year = DateTime.now().year.toString();
    final adminDocs = await _firestore.collection('Admins').get();
    final nextId = (adminDocs.docs.length + 1).toString().padLeft(4, '0');
    return 'ADM-$year$nextId';
  }

  void _showAgreementDialog() {
    showDialog(
      context: context,
      builder: (context) {
        bool localAgreeToTerms = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              insetPadding: const EdgeInsets.all(20),
              content: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Admin Agreement',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey[800],
                      ),
                    ),
                    const SizedBox(height: 15),
                    Container(
                      height: 250,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          'By registering as an admin, you agree to:\n\n'
                              '1. Maintain the confidentiality of all system data\n'
                              '2. Use administrative privileges responsibly\n'
                              '3. Protect user privacy and data security\n'
                              '4. Comply with all institutional policies\n'
                              '5. Not misuse the system for personal gain\n\n'
                              'Violation of these terms may result in account termination and legal action.',
                          style: TextStyle(
                            color: Colors.grey[700],
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Checkbox(
                          value: localAgreeToTerms,
                          onChanged: (bool? value) {
                            setState(() {
                              localAgreeToTerms = value ?? false;
                            });
                          },
                          activeColor: Colors.blueAccent,
                        ),
                        Text(
                          'I agree to the admin terms and conditions',
                          style: TextStyle(
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey,
                          ),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () {
                            if (localAgreeToTerms) {
                              setState(() {
                                _agreeToTerms = localAgreeToTerms;
                              });
                              Navigator.of(context).pop();
                              _registerUser();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('You must agree to the terms to register'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          child: const Text('Confirm', style: TextStyle(color: Colors.white)),
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

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          content: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_user, color: Colors.green[400], size: 80),
                const SizedBox(height: 20),
                Text(
                  'Admin Account Created!',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey[800],
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  'Your admin account has been successfully created. You can now manage the system.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 25),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (context) => const AdminLoginPage()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  ),
                  child: const Text('Go to Admin Login', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickImage() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result != null && result.files.isNotEmpty) {
      final imageBytes = result.files.first.bytes;
      if (imageBytes != null) {
        setState(() {
          _selectedImageBytes = imageBytes;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 150,
            floating: false,
            pinned: true,
            flexibleSpace: LayoutBuilder(
              builder: (context, constraints) {
                return FlexibleSpaceBar(
                  title: Text(
                    'Admin Registration',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: constraints.maxHeight > 100 ? 20 : 16,
                      fontWeight: FontWeight.w600,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                  ),
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blueAccent, Colors.indigo],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                );
              },
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_showVerificationSection) ...[
                            // Verification UI
                            Column(
                              children: [
                                Icon(Icons.admin_panel_settings, size: 60, color: Colors.blue),
                                const SizedBox(height: 20),
                                Text(
                                  'Verify Admin Email',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blueGrey[800],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Enter the 6-digit code sent to your admin email:',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  _emailForVerification ?? '',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.blue,
                                  ),
                                ),
                                const SizedBox(height: 30),
                                TextField(
                                  controller: _verificationCodeController,
                                  keyboardType: TextInputType.number,
                                  maxLength: 6,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    letterSpacing: 8,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: '------',
                                    counterText: '',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                      horizontal: 20,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Didn\'t receive the code? ',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                    TextButton(
                                      onPressed: _resendTimer > 0 ? null : _resendVerificationCode,
                                      child: Text(
                                        _resendTimer > 0
                                            ? 'Resend in $_resendTimer s'
                                            : 'Resend Code',
                                        style: TextStyle(
                                          color: _resendTimer > 0
                                              ? Colors.grey
                                              : Colors.blueAccent,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                _isLoading
                                    ? const Center(child: CircularProgressIndicator())
                                    : ElevatedButton(
                                  onPressed: _verifyCode,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blueAccent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    elevation: 3,
                                  ),
                                  child: const Text(
                                    'Verify and Create Admin Account',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 15),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _showVerificationSection = false;
                                      _resendTimerInstance?.cancel();
                                    });
                                  },
                                  child: const Text(
                                    'Change Email',
                                    style: TextStyle(
                                      color: Colors.blueAccent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            // Original Registration Form
                            Center(
                              child: Column(
                                children: [
                                  Stack(
                                    children: [
                                      Container(
                                        width: 100,
                                        height: 100,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.blueAccent.withOpacity(0.3),
                                            width: 2,
                                          ),
                                        ),
                                        child: ClipOval(
                                          child: _selectedImageBytes != null
                                              ? Image.memory(
                                            _selectedImageBytes!,
                                            fit: BoxFit.cover,
                                          )
                                              : Icon(
                                            Icons.person,
                                            size: 60,
                                            color: Colors.grey[400],
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: GestureDetector(
                                          onTap: _pickImage,
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Colors.blueAccent,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 2,
                                              ),
                                            ),
                                            child: const Icon(
                                              Icons.camera_alt,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Add Admin Profile Photo',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildTextField(_emailController, 'Admin Email', TextInputType.emailAddress, Icons.email),
                            if (!_isGmail)
                              Padding(
                                padding: const EdgeInsets.only(top: 5.0, left: 12),
                                child: Text(
                                  'Please use a Gmail address',
                                  style: TextStyle(
                                    color: Colors.red[400],
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 15),
                            _buildTextField(_nameController, 'Full Name', TextInputType.name, Icons.person),
                            const SizedBox(height: 15),
                            _buildPasswordField(_passwordController, 'Password', Icons.lock, _obscurePassword, () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            }),
                            const SizedBox(height: 15),
                            _buildPasswordField(_confirmPasswordController, 'Confirm Password', Icons.lock_outline, _obscureConfirmPassword, () {
                              setState(() {
                                _obscureConfirmPassword = !_obscureConfirmPassword;
                              });
                            }),
                            if (!_passwordsMatch)
                              Padding(
                                padding: const EdgeInsets.only(top: 5.0, left: 12),
                                child: Text(
                                  'Passwords do not match',
                                  style: TextStyle(
                                    color: Colors.red[400],
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 15),
                            Text(
                              'Admin Phone Number',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.grey[300]!),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedDialCode,
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
                                      icon: const Icon(Icons.arrow_drop_down),
                                      style: TextStyle(color: Colors.blueGrey[800]),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: _phoneController,
                                    keyboardType: TextInputType.phone,
                                    decoration: InputDecoration(
                                      hintText: 'Enter phone number',
                                      filled: true,
                                      fillColor: Colors.grey[100],
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide.none,
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 15),
                            _buildTextField(_universityController, 'University/Organization', TextInputType.text, Icons.school),
                            const SizedBox(height: 15),
                            _buildTextField(_branchController, 'Department/Branch', TextInputType.text, Icons.business),
                            const SizedBox(height: 25),
                            _isLoading
                                ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
                                : ElevatedButton(
                              onPressed: _isRegisterButtonEnabled ? _registerUser : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isRegisterButtonEnabled ? Colors.blueAccent : Colors.grey[400],
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                elevation: 3,
                                shadowColor: Colors.blueAccent.withOpacity(0.3),
                              ),
                              child: const Text(
                                'Create Admin Account',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an admin account?',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const AdminLoginPage()),
                          );
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.blueAccent,
                        ),
                        child: const Text('Sign In'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller,
      String label,
      TextInputType type,
      IconData icon,
      ) {
    return TextField(
      controller: controller,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[600]),
        prefixIcon: Icon(icon, color: Colors.grey[500]),
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      ),
    );
  }

  Widget _buildPasswordField(
      TextEditingController controller,
      String label,
      IconData icon,
      bool obscureText,
      VoidCallback onToggle,
      ) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[600]),
        prefixIcon: Icon(icon, color: Colors.grey[500]),
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText ? Icons.visibility_off : Icons.visibility,
            color: Colors.grey[500],
          ),
          onPressed: onToggle,
        ),
      ),
    );
  }
}