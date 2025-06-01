import 'package:cloud_firestore/cloud_firestore.dart';

class AdminActivityLogger {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> logActivity({
    required String adminEmail,
    required String action,
    String? targetEmail,
  }) async {
    try {
      await _firestore.collection('AdminActivity').add({
        'adminEmail': adminEmail,
        'action': action,
        'targetEmail': targetEmail,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error logging activity: $e');
    }
  }
}
