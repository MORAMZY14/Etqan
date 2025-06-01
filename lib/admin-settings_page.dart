import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show Uint8List, kIsWeb;

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Theme.of(context).colorScheme.onBackground,
      ),
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.03),
              Theme.of(context).colorScheme.primary.withOpacity(0.01),
            ],
          ),
        ),
        child: ListView(
          physics: const BouncingScrollPhysics(),
          children: [
            _buildSectionHeader(context, 'General'), // Fixed: context passed here
            _buildModernSettingsButton(context, 'Account Settings', Icons.person_outline, () {}),
            _buildModernSettingsButton(context, 'Notifications', Icons.notifications_outlined, () {}),
            _buildModernSettingsButton(context, 'Privacy', Icons.lock_outline, () {}),

            const SizedBox(height: 24),
            _buildSectionHeader(context, 'Backup Management'), // Fixed: context passed here
            _buildBackupButton(context, 'Backup Users', Icons.group_outlined, 'Users'),
            _buildBackupButton(context, 'Backup Admins', Icons.admin_panel_settings_outlined, 'Admins'),
            _buildBackupButton(context, 'Backup Courses', Icons.school_outlined, 'Courses'),

            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Backups are stored in Firebase Storage\nin JSON format with timestamped filenames',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Fixed: Added context parameter
  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 4),
      child: Text(
        title,
        style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Theme.of(context).colorScheme.primary,
            letterSpacing: 0.5
        ),
      ),
    );
  }

  Widget _buildModernSettingsButton(BuildContext context, String title, IconData icon, VoidCallback onPressed) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: Icon(Icons.arrow_forward_ios_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.outline),
        onTap: onPressed,
      ),
    );
  }

  Widget _buildBackupButton(BuildContext context, String title, IconData icon, String collectionName) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.4),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Theme.of(context).colorScheme.secondary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: IconButton(
          icon: Icon(Icons.backup_rounded,
              color: Theme.of(context).colorScheme.secondary),
          onPressed: () => _backupToFirebase(context, collectionName),
        ),
      ),
    );
  }

  Future<void> _backupToFirebase(BuildContext context, String collectionName) async {
    try {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      final snapshot = await FirebaseFirestore.instance.collection(collectionName).get();
      final data = snapshot.docs.map((doc) => doc.data()).toList();
      final jsonData = jsonEncode(data);
      final fileName = '${collectionName.toLowerCase()}_backup_${DateTime.now().millisecondsSinceEpoch}.json';
      final storageRef = FirebaseStorage.instance.ref().child('backups/$fileName');
      await storageRef.putData(Uint8List.fromList(utf8.encode(jsonData)));

      scaffoldMessenger.showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Theme.of(context).colorScheme.tertiary),
                const SizedBox(width: 12),
                Text('$collectionName backup successful!',
                    style: TextStyle(color: Theme.of(context).colorScheme.onTertiaryContainer)),
              ],
            ),
          )
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup failed: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
          )
      );
    }
  }
}