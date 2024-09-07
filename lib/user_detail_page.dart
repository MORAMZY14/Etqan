import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

class UserDetailsPage extends StatelessWidget {
  final String userId;

  const UserDetailsPage({Key? key, required this.userId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Details'),
        backgroundColor: Colors.teal,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('Users').doc(userId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text(
                'User data not found.',
                style: TextStyle(fontSize: 16, color: Colors.red),
              ),
            );
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>;
          final dialCode = userData['dial'] ?? '';
          final phoneNumber = userData['phone'] ?? '';
          final whatsappNumber = userData['whatsapp'] ?? phoneNumber;

          // Ensure the phone number has correct format with + and no spaces
          String fullPhoneNumber = '$dialCode$phoneNumber'.replaceAll(' ', '');
          String fullWhatsAppNumber = '$dialCode$whatsappNumber'.replaceAll(' ', '');
          if (!fullWhatsAppNumber.startsWith('+')) {
            fullWhatsAppNumber = '+$fullWhatsAppNumber';
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildUserInfo(Icons.person, 'Name', userData['name']),
                _buildUserInfo(Icons.email, 'Email', userData['email']),
                _buildUserInfo(Icons.card_membership, 'Student ID', userData['studentID']),
                const SizedBox(height: 20),
                _buildUserInfo(
                  Icons.phone,
                  'Number',
                  fullPhoneNumber,
                  onTap: () async {
                    final url = 'tel:$fullPhoneNumber';
                    if (await canLaunchUrl(Uri.parse(url))) {
                      await launchUrl(Uri.parse(url));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Could not open dialer.'),
                      ));
                    }
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          if (await _isWhatsAppInstalled()) {
                            final whatsappUrl = 'https://wa.me/$fullWhatsAppNumber';
                            if (await canLaunchUrl(Uri.parse(whatsappUrl))) {
                              await launchUrl(Uri.parse(whatsappUrl));
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                content: Text('Could not open WhatsApp.'),
                              ));
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text('WhatsApp is not installed.'),
                            ));
                          }
                        },
                        icon: const Icon(FontAwesomeIcons.whatsapp, color: Colors.white),
                        label: const Text('WhatsApp'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final callUrl = 'tel:$fullPhoneNumber';
                          if (await canLaunchUrl(Uri.parse(callUrl))) {
                            await launchUrl(Uri.parse(callUrl));
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text('Could not open dialer.'),
                            ));
                          }
                        },
                        icon: const Icon(Icons.phone, color: Colors.white),
                        label: const Text('Call'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          try {
                            await _saveContact(userData['name'], fullPhoneNumber);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text('Contact saved successfully.'),
                            ));
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('Failed to save contact: $e'),
                            ));
                          }
                        },
                        icon: const Icon(Icons.contact_page, color: Colors.white),
                        label: const Text('Save Contact'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _showFAQDialog(context);
                        },
                        icon: const Icon(Icons.help_outline, color: Colors.white),
                        label: const Text('FAQ'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<bool> _isWhatsAppInstalled() async {
    final whatsappUrl = 'whatsapp://send?phone=123456789';
    return await canLaunchUrl(Uri.parse(whatsappUrl));
  }

  Future<void> _saveContact(String name, String phoneNumber) async {
    if (await FlutterContacts.requestPermission()) {
      final newContact = Contact(
        name: Name(first: name),
        phones: [Phone(phoneNumber)],
      );
      await FlutterContacts.insertContact(newContact);
    } else {
      print('Permission denied to access contacts');
    }
  }

  void _showFAQDialog(BuildContext context) {
    final faqOptions = [
      {'label': 'Price List', 'message': 'Here is our price list...'},
      {'label': 'Groups', 'message': 'Here is the information about groups...'},
      {'label': 'Sample', 'message': 'Here is a sample...'},
      {'label': 'Links', 'message': 'Here are some important links...'},
    ];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Frequently Asked Questions'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: faqOptions.map((option) {
              return ListTile(
                title: Text(option['label']!),
                trailing: IconButton(
                  icon: const Icon(FontAwesomeIcons.whatsapp, color: Colors.teal),
                  onPressed: () async {
                    final message = Uri.encodeComponent(option['message']!);
                    final whatsappUrl = 'https://wa.me/?text=$message';
                    if (await canLaunchUrl(Uri.parse(whatsappUrl))) {
                      await launchUrl(Uri.parse(whatsappUrl));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Could not open WhatsApp.'),
                      ));
                    }
                  },
                ),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              child: const Text('Close'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildUserInfo(IconData icon, String label, String value, {VoidCallback? onTap}) {
    return Card(
      elevation: 4.0,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: ListTile(
        leading: Icon(icon, color: Colors.teal),
        title: Text(
          '$label:',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          value,
          style: const TextStyle(fontSize: 16),
        ),
        onTap: onTap,
      ),
    );
  }
}
