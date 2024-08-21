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

          // Ensure numbers are in correct format
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
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: const Text('Could not open dialer.'),
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
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: const Text('Could not open WhatsApp.'),
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
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: const Text('Could not open dialer.'),
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
              ],
            ),
          );
        },
      ),
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
