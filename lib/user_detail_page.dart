import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class UserDetailsPage extends StatelessWidget {
  final String userId;

  const UserDetailsPage({Key? key, required this.userId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Details'),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showFAQDialog(context),
          ),
        ],
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

          final fullPhoneNumber = '$dialCode$phoneNumber'.replaceAll(' ', '');
          final fullWhatsAppNumber = '$dialCode$whatsappNumber'.replaceAll(' ', '');

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
                          final whatsappUrl = 'https://wa.me/$fullWhatsAppNumber';
                          if (await canLaunchUrl(Uri.parse(whatsappUrl))) {
                            await launchUrl(Uri.parse(whatsappUrl));
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text('Could not open WhatsApp.'),
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
                ElevatedButton.icon(
                  onPressed: () async {
                    // Launch native contacts app with pre-filled data (this URL scheme varies by platform)
                    final contactUrl = Uri.encodeFull(
                        'content://contacts/people/?name=${userData['name']}&phone=$fullPhoneNumber'
                    );
                    if (await canLaunchUrl(Uri.parse(contactUrl))) {
                      await launchUrl(Uri.parse(contactUrl));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Could not open contacts app.')),
                      );
                    }
                  },
                  icon: const Icon(Icons.contact_page, color: Colors.white),
                  label: const Text('Save Contact'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                ),
              ],
            ),
          );
        },
      ),
    );
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
