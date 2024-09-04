import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
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
    _emailController.addListener(_checkFields);
    _nameController.addListener(_checkFields);
    _passwordController.addListener(_checkFields);
    _confirmPasswordController.addListener(_checkFields);
    _phoneController.addListener(_checkFields);
    _universityController.addListener(_checkFields);
    _branchController.addListener(_checkFields);
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
      final UserCredential userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final User? user = userCredential.user;
      if (user != null) {
        await _createUser();
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Registration failed: ${e.message}'),
      ));
    } catch (e) {
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
      final String studentID = await _generateStudentID();
      final newUser = {
        'email': userEmail,
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'dial': _selectedDialCode,
        'university': _universityController.text.trim(),
        'branch': _branchController.text.trim(),
        'studentID': studentID,
        'Status': 'New',
      };

      if (_selectedImageBytes != null) {
        await _uploadProfilePicture(userEmail);
      }

      await _firestore.collection('Users').doc(userEmail).set(newUser);

      _showSuccessDialog();
    }
  }

  Future<void> _uploadProfilePicture(String userEmail) async {
    final storageRef = _firebaseStorage.ref().child('users/$userEmail/profile_picture.png');

    try {
      final uploadTask = storageRef.putData(_selectedImageBytes!);
      await uploadTask.whenComplete(() => null);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to upload profile picture: ${e.toString()}'),
      ));
    }
  }

  Future<String> _generateStudentID() async {
    final year = DateTime.now().year.toString();
    final studentDocs = await _firestore.collection('Users').get();
    final nextId = (studentDocs.docs.length + 1).toString().padLeft(4, '0');
    return '$year$nextId';
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
                          'Long terms and conditions text goes here. '
                              'This should be long enough to require scrolling... '
                              'Lorem ipsum dolor sit amet, consectetur adipiscing elit. '
                              'Pellentesque vel malesuada justo. Vivamus non tortor nisi. '
                              'Integer vel lacus cursus, faucibus justo eu, consequat arcu. '
                              'Vestibulum euismod orci eu augue cursus, in cursus justo faucibus. '
                              'Donec eget lorem et mi varius congue sit amet non est. '
                              'Phasellus nec finibus libero, non aliquet mi. '
                              'Aliquam erat volutpat. Duis ornare augue a quam suscipit bibendum. '
                              'Etiam vel magna a nisi pharetra blandit. Sed a ante turpis.',
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
                    if (localAgreeToTerms) {
                      setState(() {
                        _agreeToTerms = localAgreeToTerms;
                      });
                      Navigator.of(context).pop();
                      _registerUser();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('You must agree to the terms and conditions to register.'),
                        ),
                      );
                    }
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

  Future<void> _pickImage() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image);

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: const Text('Register'),
        centerTitle : true ,
        backgroundColor: Colors.grey[200],
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.only(bottom: 90.0), // Add padding to move the container down
          child: Container(
            width: MediaQuery.of(context).size.width * 0.78,
            height: MediaQuery.of(context).size.height * 0.85,
            padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.02),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  blurRadius: 10.0,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: _selectedImageBytes != null
                              ? MemoryImage(_selectedImageBytes!)
                              : null,
                          child: _selectedImageBytes == null
                              ? const Icon(Icons.person, size: 40, color: Colors.grey)
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.teal,
                              child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 9),
                  _buildTextField(_emailController, 'Email', TextInputType.emailAddress, Icons.email),
                  if (!_isGmail)
                    Padding(
                      padding: const EdgeInsets.only(top: 5.0),
                      child: Text(
                        'Please use a Gmail address.',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: MediaQuery.of(context).size.width * 0.025,
                        ),
                      ),
                    ),
                  const SizedBox(height: 15),
                  _buildTextField(_nameController, 'Name', TextInputType.name, Icons.person),
                  const SizedBox(height: 15),
                  _buildPasswordField(_passwordController, 'Password', Icons.lock, _obscurePassword, () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  }),
                  if (!_passwordsMatch)
                    Padding(
                      padding: const EdgeInsets.only(top: 5.0),
                      child: Text(
                        'Passwords do not match.',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: MediaQuery.of(context).size.width * 0.025,
                        ),
                      ),
                    ),
                  const SizedBox(height: 15),
                  _buildPasswordField(_confirmPasswordController, 'Confirm Password', Icons.lock, _obscureConfirmPassword, () {
                    setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    });
                  }),
                  const SizedBox(height: 15),
                  // Phone number and country code input
                  Row(
                    children: [
                      // Country code dropdown
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedDialCode,
                            items: <String>['+20', '+1', '+44', '+91'] // Add more dial codes as needed
                                .map<DropdownMenuItem<String>>((String value) {
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
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Phone number text field
                      Expanded(
                        child: _buildTextField(
                          _phoneController,
                          'Phone Number',
                          TextInputType.phone,
                          Icons.phone,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  _buildTextField(_universityController, 'University', TextInputType.text, Icons.school),
                  const SizedBox(height: 15),
                  _buildTextField(_branchController, 'Branch', TextInputType.text, Icons.business),
                  const SizedBox(height: 15),
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                    onPressed: _isRegisterButtonEnabled ? _registerUser : null,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        vertical: MediaQuery.of(context).size.height * 0.02,
                      ),
                      backgroundColor: _isRegisterButtonEnabled ? Colors.teal : Colors.grey,
                    ),
                    child: const Text('Register'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }



  Widget _buildTextField(TextEditingController controller, String label, TextInputType type,
      IconData icon) {
    return TextField(
      controller: controller,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
      ),
    );
  }

  Widget _buildPasswordField(TextEditingController controller, String label, IconData icon,
      bool obscureText, VoidCallback onToggle) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: IconButton(
          icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility),
          onPressed: onToggle,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
      ),
    );
  }
}