import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_page.dart';

class RegisterAdminPage extends StatefulWidget {
  const RegisterAdminPage({super.key});

  @override
  _RegisterAdminPageState createState() => _RegisterAdminPageState();
}

class _RegisterAdminPageState extends State<RegisterAdminPage> {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _universityController = TextEditingController();
  final TextEditingController _branchController = TextEditingController();

  String _selectedDialCode = '+20';
  bool _isRegisterButtonEnabled = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_checkFields);
    _nameController.addListener(_checkFields);
    _passwordController.addListener(_checkFields);
    _usernameController.addListener(_checkFields);
    _phoneController.addListener(_checkFields);
    _universityController.addListener(_checkFields);
    _branchController.addListener(_checkFields);
  }

  void _checkFields() {
    setState(() {
      _isRegisterButtonEnabled = _emailController.text.isNotEmpty &&
          _nameController.text.isNotEmpty &&
          _passwordController.text.isNotEmpty &&
          _usernameController.text.isNotEmpty &&
          _phoneController.text.isNotEmpty &&
          _universityController.text.isNotEmpty &&
          _branchController.text.isNotEmpty;
    });
  }

  Future<void> _registerUser() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final UserCredential userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final User? user = userCredential.user;
      if (user != null) {
        await _createUser();
      }
    } on FirebaseAuthException catch (e) {
      print('Exception registering user: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Registration failed: ${e.message}'),
      ));
    } catch (e) {
      print('Exception registering user: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Registration failed: ${e.toString()}'),
      ));
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
      final String DoctorID = _generateDoctorID();
      final newUser = {
        'email': userEmail,
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'dial': _selectedDialCode,
        'university': _universityController.text.trim(),
        'branch': _branchController.text.trim(),
        'username': _usernameController.text.trim(),
        'studentID': DoctorID,
        'status': 'Pending',
        'paymentstatus': 'Pending',
      };

      await _firestore.collection('Admins').doc(userEmail).set(newUser);

      // Show a dialog upon successful registration
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Registration Successful'),
            content: const Text('Your registration was completed successfully.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                  );
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    }
  }

  String _generateDoctorID() {
    const String allowedChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final Random random = Random();
    return String.fromCharCodes(Iterable.generate(
      6,
          (_) => allowedChars.codeUnitAt(random.nextInt(allowedChars.length)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctors Register'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTextField(_nameController, 'Name'),
              const SizedBox(height: 16),
              _buildTextField(_usernameController, 'Username'),
              const SizedBox(height: 16),
              _buildTextField(_emailController, 'Email'),
              const SizedBox(height: 16),
              _buildTextField(_passwordController, 'Password', obscureText: true),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedDialCode,
                      items: ['+20', '+966', '+44', '+33', '+49', '+81', '+86']
                          .map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedDialCode = newValue!;
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: 'Country Code',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: _buildTextField(_phoneController, 'WhatsApp Number'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildTextField(_universityController, 'University'),
              const SizedBox(height: 16),
              _buildTextField(_branchController, 'Branch'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isRegisterButtonEnabled ? _registerUser : null,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Register'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {bool obscureText = false}) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      obscureText: obscureText,
    );
  }
}
