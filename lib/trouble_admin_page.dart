import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class TroubleCenterPage extends StatefulWidget {
  const TroubleCenterPage({super.key});

  @override
  State<TroubleCenterPage> createState() => _TroubleCenterPageState();
}

class _TroubleCenterPageState extends State<TroubleCenterPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<QueryDocumentSnapshot> _tickets = [];
  bool _isLoading = true;
  String _debugInfo = '';

  @override
  void initState() {
    super.initState();
    _loadAllTickets();
  }

  Future<void> _loadAllTickets() async {
    setState(() {
      _isLoading = true;
      _tickets.clear();
      _debugInfo = 'Starting ticket loading...\n${DateTime.now()}\n';
    });

    try {
      // 1. Check root-level tickets collection
      _debugInfo += '\n===== QUERYING ROOT TICKETS =====\n';
      final ticketsSnapshot = await _firestore.collection('tickets').get();
      _debugInfo += 'Found ${ticketsSnapshot.docs.length} tickets in root collection\n';
      _tickets.addAll(ticketsSnapshot.docs);

      // 2. Check user-based collections
      final userCollections = [
        'Trouble Center',
        'Troable Center',
        'Toolsle Center',
        'trouble_center',
        'TroubleCenter',
        'users',
        'user_tickets',
        'customer_support'
      ];

      for (final collectionName in userCollections) {
        _debugInfo += '\n===== PROCESSING "$collectionName" COLLECTION =====\n';

        try {
          final collectionRef = _firestore.collection(collectionName);
          final userSnapshot = await collectionRef.get();

          _debugInfo += 'Found ${userSnapshot.docs.length} documents\n';

          for (final userDoc in userSnapshot.docs) {
            final data = userDoc.data();

            // Check if document is a ticket itself
            if (_isTicketDocument(data)) {
              _debugInfo += '✅ DIRECT TICKET: ${userDoc.id}\n';
              _tickets.add(userDoc);
            }
            // Check for tickets subcollection
            else {
              try {
                final ticketsRef = userDoc.reference.collection('tickets');
                final ticketsSnapshot = await ticketsRef.get();

                _debugInfo += 'Found ${ticketsSnapshot.docs.length} tickets for user ${userDoc.id}\n';
                _tickets.addAll(ticketsSnapshot.docs);
              } catch (e) {
                _debugInfo += '⚠️ No tickets subcollection for ${userDoc.id}: ${e.toString()}\n';
              }
            }
          }
        } catch (e) {
          _debugInfo += '⛔ ERROR ACCESSING "$collectionName": ${e.toString()}\n';
        }
      }
    } catch (e) {
      _debugInfo += '\n‼️ CRITICAL ERROR: ${e.toString()}\n';
    } finally {
      _debugInfo += '\n===== FINAL RESULT =====\n';
      _debugInfo += 'TOTAL TICKETS FOUND: ${_tickets.length}\n';
      _debugInfo += 'Completed at: ${DateTime.now()}\n';

      setState(() => _isLoading = false);
    }
  }

  bool _isTicketDocument(Map<String, dynamic> data) {
    return data.containsKey('subject') ||
        data.containsKey('problem') ||
        data.containsKey('description') ||
        data.containsKey('content') ||
        data.containsKey('category');
  }

  String _formatDateTime(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F111E),
      appBar: AppBar(
        title: const Text('Trouble Center', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1E1F2B),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllTickets,
          ),
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Debug Information'),
                  content: SingleChildScrollView(
                    child: Text(_debugInfo),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                    TextButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _debugInfo));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Debug info copied to clipboard')),
                        );
                      },
                      child: const Text('Copy'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tickets.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'No tickets found',
              style: TextStyle(color: Colors.white70, fontSize: 18),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _createTestTicket,
              child: const Text('Create Test Ticket'),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Debug Information'),
                  content: SingleChildScrollView(
                    child: Text(_debugInfo),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
              child: const Text('View Debug Log'),
            ),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _tickets.length,
        itemBuilder: (context, index) {
          final ticket = _tickets[index];
          final data = ticket.data() as Map<String, dynamic>;

          // Extract fields with fallbacks
          final userEmail = data['userEmail'] as String? ??
              data['User\'s Email'] as String? ??
              data['email'] as String? ??
              'Unknown';
          final userName = data['userName'] as String? ??
              data['name'] as String? ??
              data['username'] as String? ??
              'Unknown';
          final category = data['category'] as String? ??
              data['Category'] as String? ??
              data['type'] as String? ??
              'No category';
          final subject = data['subject'] as String? ??
              data['Subject'] as String? ??
              data['title'] as String? ??
              'No subject';
          final status = data['status'] as String? ??
              data['state'] as String? ??
              data['Status'] as String? ??
              'Unknown';

          List<String> attachments = [];
          if (data['attachments'] is List) {
            attachments = (data['attachments'] as List).cast<String>();
          } else if (data['attachments'] is String) {
            attachments = [data['attachments'] as String];
          } else if (data['attachment'] is String) {
            attachments = [data['attachment'] as String];
          }

          DateTime createdAt = DateTime.now();
          if (data['createdAt'] != null) {
            createdAt = (data['createdAt'] as Timestamp).toDate();
          } else if (data['timestamp'] != null) {
            createdAt = (data['timestamp'] as Timestamp).toDate();
          } else if (data['date'] != null) {
            createdAt = (data['date'] as Timestamp).toDate();
          } else if (data['time'] != null) {
            createdAt = (data['time'] as Timestamp).toDate();
          }

          return Card(
            color: const Color(0xFF1E1F2B),
            margin: const EdgeInsets.only(bottom: 16),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: const Icon(Icons.warning, color: Color(0xFFFFD700)),
              title: Text(
                subject,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    'User: $userName ($userEmail)',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Category: $category',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Status: $status',
                    style: TextStyle(
                      color: _getStatusColor(status),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Created: ${_formatDateTime(createdAt)}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.redAccent),
                onPressed: () => _deleteTicket(ticket),
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TicketDetailPage(
                    ticket: ticket,
                    onStatusChanged: (newStatus) {
                      // Update status in the list
                      setState(() {
                        data['status'] = newStatus;
                      });
                    },
                  ),
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createTestTicket,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return Colors.orange;
      case 'submitted':
        return Colors.blue;
      case 'queued':
        return Colors.purple;
      case 'solved':
        return Colors.green;
      case 'closed':
        return Colors.grey;
      default:
        return Colors.yellow;
    }
  }

  Future<void> _createTestTicket() async {
    try {
      // Create in multiple locations
      await _createTestInLocation('tickets');
      await _createTestInLocation('Trouble Center');
      await _createTestInLocation('users');
      await _createTestInLocation('customer_support');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test tickets created in multiple locations'),
          backgroundColor: Colors.green,
        ),
      );

      // Reload tickets
      _loadAllTickets();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create test tickets: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _createTestInLocation(String collection) async {
    try {
      final testEmail = 'test${DateTime.now().millisecondsSinceEpoch}@example.com';
      final testTicketId = 'test-ticket-${DateTime.now().millisecondsSinceEpoch}';

      if (collection == 'tickets') {
        // Direct tickets collection
        await _firestore.collection(collection).doc(testTicketId).set({
          'userEmail': testEmail,
          'userName': 'Test User',
          'category': 'Test',
          'subject': 'Test Ticket in $collection',
          'content': 'This is a test ticket created at ${DateTime.now()}',
          'attachments': [],
          'status': 'Open',
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        // User-based collection
        final userDocRef = _firestore.collection(collection).doc(testEmail);

        // Create user document if needed
        if (!(await userDocRef.get()).exists) {
          await userDocRef.set({
            'email': testEmail,
            'name': 'Test User',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        // Create ticket in subcollection
        await userDocRef.collection('tickets').doc(testTicketId).set({
          'ticketId': testTicketId,
          'userEmail': testEmail,
          'userName': 'Test User',
          'category': 'Test',
          'subject': 'Test Ticket in $collection',
          'content': 'This is a test ticket created at ${DateTime.now()}',
          'attachments': [],
          'status': 'Open',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error creating test ticket in $collection: $e');
      rethrow;
    }
  }

  Future<void> _openAttachment(String url) async {
    if (url.isEmpty) return;
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open attachment')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening attachment: $e')),
      );
    }
  }

  Future<void> _deleteTicket(QueryDocumentSnapshot ticket) async {
    try {
      await ticket.reference.delete();
      setState(() {
        _tickets.remove(ticket);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ticket deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete ticket: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class TicketDetailPage extends StatefulWidget {
  final QueryDocumentSnapshot ticket;
  final Function(String) onStatusChanged;

  const TicketDetailPage({
    super.key,
    required this.ticket,
    required this.onStatusChanged,
  });

  @override
  State<TicketDetailPage> createState() => _TicketDetailPageState();
}

class _TicketDetailPageState extends State<TicketDetailPage> {
  final TextEditingController _replyController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<String> _statusOptions = ['Open', 'Submitted', 'Queued', 'Solved', 'Closed'];
  String? _selectedStatus;
  List<DocumentSnapshot> _replies = [];
  bool _isLoadingReplies = true;

  @override
  void initState() {
    super.initState();
    final data = widget.ticket.data() as Map<String, dynamic>;
    _selectedStatus = data['status'] as String? ?? 'Open';
    _loadReplies();
  }

  Future<void> _loadReplies() async {
    try {
      final repliesSnapshot = await widget.ticket.reference
          .collection('replies')
          .orderBy('timestamp', descending: true)
          .get();

      setState(() {
        _replies = repliesSnapshot.docs;
        _isLoadingReplies = false;
      });
    } catch (e) {
      setState(() => _isLoadingReplies = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load replies: $e')),
      );
    }
  }

  Future<void> _addReply() async {
    if (_replyController.text.trim().isEmpty) return;

    try {
      await widget.ticket.reference.collection('replies').add({
        'message': _replyController.text,
        'sender': 'Admin',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Also update last activity timestamp
      await widget.ticket.reference.update({
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _replyController.clear();
      _loadReplies();
      FocusScope.of(context).unfocus();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add reply: $e')),
      );
    }
  }

  Future<void> _updateStatus() async {
    if (_selectedStatus == null) return;

    try {
      await widget.ticket.reference.update({
        'status': _selectedStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      widget.onStatusChanged(_selectedStatus!);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status updated to $_selectedStatus')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $e')),
      );
    }
  }

  String _formatDateTime(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.ticket.data() as Map<String, dynamic>;
    final userEmail = data['userEmail'] as String? ?? 'Unknown';
    final userName = data['userName'] as String? ?? 'Unknown';
    final category = data['category'] as String? ?? 'No category';
    final subject = data['subject'] as String? ?? 'No subject';
    final content = data['content'] as String? ?? 'No content';
    final createdAt = data['createdAt'] != null
        ? (data['createdAt'] as Timestamp).toDate()
        : DateTime.now();
    final updatedAt = data['updatedAt'] != null
        ? (data['updatedAt'] as Timestamp).toDate()
        : null;

    List<String> attachments = [];
    if (data['attachments'] is List) {
      attachments = (data['attachments'] as List).cast<String>();
    } else if (data['attachments'] is String) {
      attachments = [data['attachments'] as String];
    } else if (data['attachment'] is String) {
      attachments = [data['attachment'] as String];
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F111E),
      appBar: AppBar(
        title: const Text('Ticket Details', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1E1F2B),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ticket header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        subject,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getStatusColor(_selectedStatus!),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _selectedStatus!,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // User info
                  Row(
                    children: [
                      const Icon(Icons.person, color: Colors.white70, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        '$userName ($userEmail)',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const Spacer(),
                      const Icon(Icons.category, color: Colors.white70, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        category,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Ticket content
                  Text(
                    content,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 20),

                  // Attachments
                  if (attachments.isNotEmpty) ...[
                    const Text(
                      'Attachments:',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...attachments.map((url) => GestureDetector(
                      onTap: () async {
                        if (await canLaunchUrl(Uri.parse(url))) {
                          await launchUrl(Uri.parse(url));
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1F2B),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.attachment, color: Colors.blue),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                Uri.parse(url).pathSegments.last,
                                style: const TextStyle(
                                  color: Colors.blue,
                                  decoration: TextDecoration.underline,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )),
                    const SizedBox(height: 20),
                  ],

                  // Ticket metadata
                  const Divider(color: Colors.grey),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Created: ${_formatDateTime(createdAt)}',
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      if (updatedAt != null)
                        Text(
                          'Updated: ${_formatDateTime(updatedAt)}',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                    ],
                  ),
                  const Divider(color: Colors.grey),
                  const SizedBox(height: 20),

                  // Replies section
                  const Text(
                    'Replies',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 10),

                  if (_isLoadingReplies)
                    const Center(child: CircularProgressIndicator())
                  else if (_replies.isEmpty)
                    const Center(
                      child: Text(
                        'No replies yet',
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                  else
                    ..._replies.map((reply) {
                      final replyData = reply.data() as Map<String, dynamic>;
                      final message = replyData['message'] as String? ?? '';
                      final sender = replyData['sender'] as String? ?? 'Unknown';
                      final timestamp = replyData['timestamp'] != null
                          ? (replyData['timestamp'] as Timestamp).toDate()
                          : DateTime.now();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1F2B),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  sender,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  _formatDateTime(timestamp),
                                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              message,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),

          // Status control and reply input
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF1E1F2B),
            child: Column(
              children: [
                // Status selector
                Row(
                  children: [
                    const Text(
                      'Status:',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButton<String>(
                          value: _selectedStatus,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF1E1F2B),
                          style: const TextStyle(color: Colors.white),
                          underline: const SizedBox(),
                          items: _statusOptions.map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() => _selectedStatus = newValue);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _updateStatus,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                      ),
                      child: const Text('Update'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Reply input
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _replyController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Type your reply...',
                          hintStyle: const TextStyle(color: Colors.grey),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.grey),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _addReply,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(16),
                      ),
                      child: const Icon(Icons.send, color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return Colors.orange;
      case 'submitted':
        return Colors.blue;
      case 'queued':
        return Colors.purple;
      case 'solved':
        return Colors.green;
      case 'closed':
        return Colors.grey;
      default:
        return Colors.yellow;
    }
  }
}