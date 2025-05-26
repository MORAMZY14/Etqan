import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:libphonenumber_plugin/libphonenumber_plugin.dart';
import 'login_page.dart';

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
  final TextEditingController _universityController = TextEditingController();
  final TextEditingController _branchController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  String _selectedCountryCode = 'EG';
  String _formattedPhoneNumber = '';
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
    _emailController.addListener(_checkFields);
    _nameController.addListener(_checkFields);
    _passwordController.addListener(_checkFields);
    _confirmPasswordController.addListener(_checkFields);
    _universityController.addListener(_checkFields);
    _branchController.addListener(_checkFields);
    _phoneController.addListener(_checkFields);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _universityController.dispose();
    _branchController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _checkFields() {
    setState(() {
      _isGmail = _emailController.text.endsWith('@gmail.com');
      _passwordsMatch =
          _passwordController.text == _confirmPasswordController.text;

      _isRegisterButtonEnabled = _emailController.text.isNotEmpty &&
          _nameController.text.isNotEmpty &&
          _passwordController.text.isNotEmpty &&
          _confirmPasswordController.text.isNotEmpty &&
          _universityController.text.isNotEmpty &&
          _branchController.text.isNotEmpty &&
          _phoneController.text.isNotEmpty &&
          _isGmail &&
          _passwordsMatch &&
          _agreeToTerms;
    });
  }

  Future<void> _registerUser() async {
    if (!_agreeToTerms) {
      _showAgreementDialog();
      return;
    }

    try {
      // Validate phone number with positional arguments
      bool? isValid = await PhoneNumberUtil.isValidPhoneNumber(
        _phoneController.text.trim(),  // phoneNumber (position 1)
        _selectedCountryCode,          // isoCode (position 2)
      );

      if (isValid != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid phone number')),
        );
        return;
      }

      // Format phone number with positional arguments
      String? formatted = await PhoneNumberUtil.normalizePhoneNumber(
        _phoneController.text.trim(),  // phoneNumber (position 1)
        _selectedCountryCode,          // isoCode (position 2)
      );

      _formattedPhoneNumber = formatted ?? _phoneController.text.trim();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Phone error: ${e.toString()}')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final UserCredential userCredential =
      await _firebaseAuth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (userCredential.user != null) {
        await _createUser();
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration failed: ${e.message}')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createUser() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return;

    final userData = {
      'email': user.email,
      'name': _nameController.text.trim(),
      'phone': _formattedPhoneNumber,
      'university': _universityController.text.trim(),
      'branch': _branchController.text.trim(),
      'studentID': await _generateStudentID(),
      'Status': 'New',
      'profilePictureUrl': _selectedImageBytes != null
          ? 'users/${user.email}/profile.jpg'
          : null,
    };

    if (_selectedImageBytes != null) {
      await _uploadProfilePicture(user.email!);
    }

    await _firestore.collection('Users').doc(user.email).set(userData);
    _showSuccessDialog();
  }

  Future<void> _uploadProfilePicture(String email) async {
    try {
      final ref = _firebaseStorage.ref('users/$email/profile.jpg');
      await ref.putData(_selectedImageBytes!);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload image: $e')),
      );
    }
  }

  Future<String> _generateStudentID() async {
    final snapshot = await _firestore.collection('Users').get();
    return '${DateTime.now().year}${(snapshot.docs.length + 1).toString().padLeft(4, '0')}';
  }

  Future<void> _pickImage() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image == null) return;

    final bytes = await image.readAsBytes();
    setState(() => _selectedImageBytes = bytes);
  }

  void _showAgreementDialog() => showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Agreement Required'),
      content: const Text('You must agree to the terms to register'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        )
      ],
    ),
  );

  void _showSuccessDialog() => showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Success'),
      content: const Text('Registration successful!'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginPage()),
          ),
          child: const Text('Continue'),
        )
      ],
    ),
  );

  Widget _buildPhoneNumberField() {
    return Row(
      children: [
        DropdownButton<String>(
          value: _selectedCountryCode,
          items: const [
            DropdownMenuItem(value: 'EG', child: Text('Egypt +20')),
            DropdownMenuItem(value: 'US', child: Text('USA +1')),
            DropdownMenuItem(value: 'IN', child: Text('India +91')),
          ],
          onChanged: (value) => setState(() {
            if (value != null) _selectedCountryCode = value;
          }),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              prefixIcon: Icon(Icons.phone),
              border: OutlineInputBorder(),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSmall = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Register'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isSmall ? 16 : 24),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Colors.grey[200],
                backgroundImage: _selectedImageBytes != null
                    ? MemoryImage(_selectedImageBytes!)
                    : null,
                child: _selectedImageBytes == null
                    ? const Icon(Icons.add_a_photo, size: 40)
                    : null,
              ),
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: _emailController,
              label: 'Email',
              icon: Icons.email,
              isEmail: true,
              errorText: _isGmail ? null : 'Must be a Gmail address',
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _nameController,
              label: 'Full Name',
              icon: Icons.person,
            ),
            const SizedBox(height: 16),
            _buildPhoneNumberField(),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _universityController,
              label: 'University',
              icon: Icons.school,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _branchController,
              label: 'Branch',
              icon: Icons.architecture,
            ),
            const SizedBox(height: 16),
            _buildPasswordField(
              controller: _passwordController,
              label: 'Password',
              isConfirm: false,
            ),
            const SizedBox(height: 16),
            _buildPasswordField(
              controller: _confirmPasswordController,
              label: 'Confirm Password',
              isConfirm: true,
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('I agree to the terms and conditions'),
              value: _agreeToTerms,
              onChanged: (v) => setState(() => _agreeToTerms = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isRegisterButtonEnabled && !_isLoading
                    ? _registerUser
                    : null,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Register'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isEmail = false,
    String? errorText,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
        errorText: errorText,
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool isConfirm,
  }) {
    return TextField(
      controller: controller,
      obscureText: isConfirm ? _obscureConfirmPassword : _obscurePassword,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock),
        suffixIcon: IconButton(
          icon: Icon(isConfirm
              ? _obscureConfirmPassword
              ? Icons.visibility_off
              : Icons.visibility
              : _obscurePassword
              ? Icons.visibility_off
              : Icons.visibility),
          onPressed: () => setState(() {
            if (isConfirm) {
              _obscureConfirmPassword = !_obscureConfirmPassword;
            } else {
              _obscurePassword = !_obscurePassword;
            }
          }),
        ),
        border: const OutlineInputBorder(),
        errorText: isConfirm && !_passwordsMatch
            ? 'Passwords do not match'
            : null,
      ),
    );
  }
}