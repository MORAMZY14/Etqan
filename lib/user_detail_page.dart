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
        title: const Text('User Profile'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showFAQDialog(context),
          ),
        ],
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('Users').doc(userId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00BFA5)),
                ));
                }

                if (!snapshot.hasData || !snapshot.data!.exists) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    const Text(
                      'User not found',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              );
            }

            final userData = snapshot.data!.data() as Map<String, dynamic>;
            final dialCode = userData['dial'] ?? '';
            final phoneNumber = userData['phone'] ?? '';
            final whatsappNumber = userData['whatsapp'] ?? phoneNumber;
            final fullPhoneNumber = _formatPhoneNumber('$dialCode$phoneNumber');
            final fullWhatsAppNumber = _formatPhoneNumber('$dialCode$whatsappNumber');

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
              // Profile Header
              Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
              BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
              )],
            ),
          child: Column(
          children: [
          CircleAvatar(
          radius: 48,
          backgroundColor: const Color(0xFFE0F2F1),
          child: Text(
          userData['name']?[0] ?? '?',
          style: const TextStyle(
          fontSize: 40,
          fontWeight: FontWeight.bold,
          color: Color(0xFF00796B),
          ),
          ),
          ),
          const SizedBox(height: 16),
          Text(
          userData['name'] ?? 'No Name',
          style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          ),
          ),
          const SizedBox(height: 4),
          Text(
          userData['email'] ?? 'No Email',
          style: TextStyle(
          fontSize: 16,
          color: Colors.grey[600],
          ),
          ),
          const SizedBox(height: 16),
          if (userData['studentID'] != null && userData['studentID'].isNotEmpty)
          Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
          Icon(Icons.badge, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
          userData['studentID'],
          style: TextStyle(
          fontSize: 16,
          color: Colors.grey[600],
          fontWeight: FontWeight.w500,
          ),
          ),
          ],
          ),
          ],
          ),
          ),

          const SizedBox(height: 24),

          // Contact Information
          Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
          BoxShadow(
          color: Colors.grey.withOpacity(0.1),
          blurRadius: 20,
          offset: const Offset(0, 10),
          ),
          ],
          ),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
          'Contact Information',
          style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          ),
          ),
          ),
          const SizedBox(height: 16),
          _buildContactTile(
          context,
          icon: Icons.phone,
          title: 'Phone Number',
          value: fullPhoneNumber,
          onTap: () => _makePhoneCall(fullPhoneNumber, context),
          ),
          _buildContactTile(
          context,
          icon: FontAwesomeIcons.whatsapp,
          title: 'WhatsApp',
          value: fullWhatsAppNumber,
          onTap: () => _openWhatsApp(fullWhatsAppNumber, context),
          ),
          ],
          ),
          ),

          const SizedBox(height: 24),

          // Action Buttons
          GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 3.5,
          children: [
          _buildActionButton(
          icon: Icons.phone,
          label: 'Call',
          color: const Color(0xFF00BFA5),
          onPressed: () => _makePhoneCall(fullPhoneNumber, context),
          ),
          _buildActionButton(
          icon: FontAwesomeIcons.whatsapp,
          label: 'WhatsApp',
          color: const Color(0xFF25D366),
          onPressed: () => _openWhatsApp(fullWhatsAppNumber, context),
          ),
          _buildActionButton(
          icon: Icons.contact_page,
          label: 'Save Contact',
          color: const Color(0xFF5C6BC0),
          onPressed: () => _saveContact(userData['name'], fullPhoneNumber, context),
          ),
          _buildActionButton(
          icon: Icons.message,
          label: 'Message',
          color: const Color(0xFFFFA000),
          onPressed: () => _sendSMS(fullPhoneNumber, context),
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

  String _formatPhoneNumber(String number) {
    String formatted = number.replaceAll(' ', '');
    if (!formatted.startsWith('+')) {
      formatted = '+$formatted';
    }
    return formatted;
  }

  Widget _buildContactTile(
      BuildContext context, {
        required IconData icon,
        required String title,
        required String value,
        required VoidCallback onTap,
      }) {
    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFE0F2F1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: const Color(0xFF00796B), size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey[600],
        ),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
      onTap: onTap,
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        elevation: 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber, BuildContext context) async {
    final url = 'tel:$phoneNumber';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not make call'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      );
    }
  }

  Future<void> _openWhatsApp(String phoneNumber, BuildContext context) async {
    if (await _isWhatsAppInstalled()) {
      final whatsappUrl = 'https://wa.me/$phoneNumber';
      if (await canLaunchUrl(Uri.parse(whatsappUrl))) {
        await launchUrl(Uri.parse(whatsappUrl));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open WhatsApp'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('WhatsApp is not installed'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      );
    }
  }

  Future<void> _sendSMS(String phoneNumber, BuildContext context) async {
    final url = 'sms:$phoneNumber';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open messaging app'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      );
    }
  }

  Future<bool> _isWhatsAppInstalled() async {
    final whatsappUrl = 'whatsapp://send?phone=123456789';
    return await canLaunchUrl(Uri.parse(whatsappUrl));
  }

  Future<void> _saveContact(String name, String phoneNumber, BuildContext context) async {
    try {
      if (await FlutterContacts.requestPermission()) {
        final newContact = Contact(
          name: Name(first: name),
          phones: [Phone(phoneNumber)],
        );
        await FlutterContacts.insertContact(newContact);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contact saved successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permission denied to access contacts'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save contact: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      );
    }
  }

  void _showFAQDialog(BuildContext context) {
    final faqOptions = [
      {'label': 'Price List', 'message': 'Here is our price list...'},
      {'label': 'Groups', 'message': 'Here is the information about groups...'},
      {'label': 'Sample Materials', 'message': 'Here is a sample...'},
      {'label': 'Important Links', 'message': 'Here are some important links...'},
    ];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Frequently Asked',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'Questions',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00BFA5),
                  ),
                ),
                const SizedBox(height: 16),
                ...faqOptions.map((option) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            option['label']!,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(FontAwesomeIcons.whatsapp,
                              size: 20, color: Color(0xFF25D366)),
                          onPressed: () async {
                            final message = Uri.encodeComponent(option['message']!);
                            final whatsappUrl = 'https://wa.me/?text=$message';
                            if (await canLaunchUrl(Uri.parse(whatsappUrl))) {
                              await launchUrl(Uri.parse(whatsappUrl));
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Could not open WhatsApp'),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  );
                }).toList(),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'CLOSE',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00BFA5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}