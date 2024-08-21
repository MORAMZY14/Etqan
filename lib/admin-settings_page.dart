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
        title: const Text('Settings'),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSettingsButton(context, 'Account Settings', Icons.person, () {
              // Navigate to Account Settings Page
            }),
            _buildSettingsButton(context, 'Notifications', Icons.notifications, () {
              // Navigate to Notifications Settings Page
            }),
            _buildSettingsButton(context, 'Privacy', Icons.lock, () {
              // Navigate to Privacy Settings Page
            }),
            const SizedBox(height: 20),
            _buildSettingsButton(context, 'Backup Users', Icons.backup, () async {
              await _backupToFirebase(context, 'Users');
            }),
            _buildSettingsButton(context, 'Backup Admins', Icons.backup, () async {
              await _backupToFirebase(context, 'Admins');
            }),
            _buildSettingsButton(context, 'Backup Courses', Icons.backup, () async {
              await _backupToFirebase(context, 'Courses');
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsButton(BuildContext context, String title, IconData icon, VoidCallback onPressed) {
    return Card(
      elevation: 4.0,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: ListTile(
        leading: Icon(icon, color: Colors.teal),
        title: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.teal),
        onTap: onPressed,
      ),
    );
  }

  Future<void> _backupToFirebase(BuildContext context, String collectionName) async {
    try {
      // Step 1: Retrieve data from Firestore
      final snapshot = await FirebaseFirestore.instance.collection(collectionName).get();
      final data = snapshot.docs.map((doc) => doc.data()).toList();

      // Step 2: Convert data to JSON
      final jsonData = jsonEncode(data);
      final fileName = '${collectionName.toLowerCase()}_backup_${DateTime.now().millisecondsSinceEpoch}.json';

      // Step 3: Upload JSON data to Firebase Storage
      final storageRef = FirebaseStorage.instance.ref().child('backups/$fileName');
      await storageRef.putData(Uint8List.fromList(utf8.encode(jsonData)));

      _showSnackBar(context, '$collectionName backup successful! File uploaded to Firebase Storage.');
    } catch (e) {
      _showSnackBar(context, '$collectionName backup failed: $e');
    }
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
