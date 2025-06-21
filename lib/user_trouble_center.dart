import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpCenterPage extends StatefulWidget {
  final String userEmail;
  final String userName;

  const HelpCenterPage({
    super.key,
    required this.userEmail,
    required this.userName,
  });

  @override
  _HelpCenterPageState createState() => _HelpCenterPageState();
}

class _HelpCenterPageState extends State<HelpCenterPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _isSubmitting = false;
  List<PlatformFile> _attachments = [];
  String? _selectedCategory = 'Technical Issue';
  List<QueryDocumentSnapshot> _userTickets = [];
  bool _isLoadingTickets = true;
  String? _errorMessage;
  bool _indexCreated = false;
  bool _isRetrying = false;

  final List<String> _categories = [
    'Technical Issue',
    'Account Problem',
    'Course Enrollment',
    'Payment Issue',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserTickets();
  }

  Future<void> _loadUserTickets() async {
    setState(() {
      _isLoadingTickets = true;
      _errorMessage = null;
      _isRetrying = true;
    });

    try {
      final ticketsSnapshot = await FirebaseFirestore.instance
          .collection('tickets')
          .where('userEmail', isEqualTo: widget.userEmail.toLowerCase())
          .orderBy('createdAt', descending: true)
          .get(const GetOptions(source: Source.server));

      debugPrint('Successfully loaded ${ticketsSnapshot.docs.length} tickets');

      setState(() {
        _userTickets = ticketsSnapshot.docs;
        _isLoadingTickets = false;
        _isRetrying = false;
      });
    } on FirebaseException catch (e) {
      debugPrint('Firestore error: ${e.code} - ${e.message}');

      String errorMsg = 'Failed to load tickets: ${e.message}';

      if (e.code == 'failed-precondition') {
        errorMsg = 'Firebase requires an index for this query. Please create it using the button below.';
      } else if (e.code == 'unavailable') {
        errorMsg = 'Network error. Please check your internet connection.';
      }

      setState(() {
        _isLoadingTickets = false;
        _errorMessage = errorMsg;
        _isRetrying = false;
      });
    } catch (e) {
      debugPrint('General error: $e');
      setState(() {
        _isLoadingTickets = false;
        _errorMessage = 'Unexpected error: ${e.toString()}';
        _isRetrying = false;
      });
    }
  }

  Future<void> _createIndexManually() async {
    const indexUrl = 'https://console.firebase.google.com/v1/r/project/etqan-center/firestore/indexes?create_composite=Cklwcm9qZWN0cy9ldHFhbi1jZW50ZXIvZGF0YWJhc2VzLyhkZWZhdWx0KS9jb2xsZWN0aW9uR3JvdXBzL3RpY2tldHMvaW5kZXhlcy9fEAEaDQoJdXNlckVtYWlsEAEaDQoJY3JlYXRlZEF0EAE';

    try {
      if (await canLaunchUrl(Uri.parse(indexUrl))) {
        await launchUrl(Uri.parse(indexUrl));
        setState(() => _indexCreated = true);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Index creation page opened in browser. Please click "Create Index"'),
            duration: Duration(seconds: 5),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open index creation page')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  String _generateTicketId() {
    final now = DateTime.now();
    final datePart = '${now.year % 100}${_twoDigits(now.month)}${_twoDigits(now.day)}';
    final timePart = '${_twoDigits(now.hour)}${_twoDigits(now.minute)}';
    final randomPart = _generateRandomString(3).toUpperCase();
    final userPrefix = widget.userName
        .split(' ')
        .where((s) => s.isNotEmpty)
        .map((s) => s[0])
        .join('')
        .toUpperCase();

    return '${userPrefix.isNotEmpty ? '$userPrefix-' : ''}$datePart-$timePart-$randomPart';
  }

  String _twoDigits(int n) => n >= 10 ? '$n' : '0$n';

  String _generateRandomString(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(
        Iterable.generate(length, (_) => chars.codeUnitAt(random.nextInt(chars.length)))
    );
  }

  Future<void> _pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result != null) {
        setState(() => _attachments.addAll(result.files));
      }
    } on PlatformException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('File picking failed: ${e.message}')),
      );
    }
  }

  Future<void> _removeAttachment(int index) async {
    setState(() => _attachments.removeAt(index));
  }

  Future<List<String>> _uploadAttachments(String ticketId) async {
    List<String> downloadUrls = [];
    firebase_storage.Reference storageRef = firebase_storage
        .FirebaseStorage.instance
        .ref()
        .child('tickets')
        .child(ticketId);

    for (var attachment in _attachments) {
      try {
        String fileName = '${DateTime.now().millisecondsSinceEpoch}_${attachment.name}';
        firebase_storage.Reference fileRef = storageRef.child(fileName);

        await fileRef.putData(
          attachment.bytes!,
          firebase_storage.SettableMetadata(contentType: attachment.extension),
        );

        downloadUrls.add(await fileRef.getDownloadURL());
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload ${attachment.name}')),
        );
      }
    }
    return downloadUrls;
  }

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final ticketId = _generateTicketId();
      List<String> attachmentUrls = await _uploadAttachments(ticketId);

      await FirebaseFirestore.instance
          .collection('tickets')
          .doc(ticketId)
          .set({
        'ticketId': ticketId,
        'userEmail': widget.userEmail.toLowerCase(),
        'userName': widget.userName,
        'category': _selectedCategory,
        'subject': _subjectController.text,
        'content': _descriptionController.text,
        'attachments': attachmentUrls,
        'status': 'Open',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ticket #$ticketId submitted successfully!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );

      _subjectController.clear();
      _descriptionController.clear();
      setState(() => _attachments.clear());

      _loadUserTickets();
      _tabController.animateTo(1);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit ticket: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'open': return Colors.orange;
      case 'submitted': return Colors.blue;
      case 'queued': return Colors.purple;
      case 'solved': return Colors.green;
      case 'closed': return Colors.grey;
      default: return Colors.yellow;
    }
  }

  String _formatDateTime(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown date';
    return DateFormat('MMM dd, yyyy - hh:mm a').format(timestamp.toDate());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Trouble Center', style: GoogleFonts.poppins()),
        backgroundColor: Colors.blue[800],
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Submit Ticket', icon: Icon(Icons.edit)),
            Tab(text: 'My Tickets', icon: Icon(Icons.list)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Submit Ticket Tab
          _buildSubmitTicketTab(),

          // My Tickets Tab
          _isLoadingTickets
              ? Center(child: _buildLoadingIndicator())
              : _errorMessage != null
              ? _buildErrorState()
              : _userTickets.isEmpty
              ? _buildEmptyState()
              : _buildTicketList(),
        ],
      ),
    );
  }

  Widget _buildSubmitTicketTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Submit a Support Ticket',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Colors.blue[800],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Our team will get back to you within 24 hours',
              style: GoogleFonts.poppins(color: Colors.grey[600]),
            ),
            const SizedBox(height: 30),

            // User info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.person, color: Colors.blue[800]),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('User: ${widget.userName}',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                      Text('Email: ${widget.userEmail}',
                          style: GoogleFonts.poppins(fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Category
            Text('Category', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButton<String>(
                value: _selectedCategory,
                isExpanded: true,
                underline: const SizedBox(),
                items: _categories.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value, style: GoogleFonts.poppins()),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() => _selectedCategory = newValue);
                },
              ),
            ),
            const SizedBox(height: 20),

            // Subject
            Text('Subject', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _subjectController,
              decoration: InputDecoration(
                hintText: 'Briefly describe your issue',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Please enter a subject';
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Description
            Text('Description', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: 'Describe your issue in detail...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Please enter a description';
                if (value.length < 20) return 'Please provide more details (min 20 characters)';
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Attachments
            Text('Attachments', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ElevatedButton.icon(
                  onPressed: _pickFiles,
                  icon: const Icon(Icons.attach_file),
                  label: Text('Add Attachments', style: GoogleFonts.poppins()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[200],
                    foregroundColor: Colors.blue[800],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ..._attachments.asMap().entries.map((entry) {
                  final index = entry.key;
                  final file = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.insert_drive_file, color: Colors.blue[800]),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            file.name,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => _removeAttachment(index),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
            const SizedBox(height: 30),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitTicket,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[800],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                  'Submit Ticket',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.orange),
          const SizedBox(height: 20),
          Text(
            'Error Loading Tickets',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.blue[800],
            ),
          ),
          const SizedBox(height: 15),
          Text(
            _errorMessage!,
            style: GoogleFonts.poppins(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 25),

          if (_errorMessage!.contains('index'))
            Column(
              children: [
                ElevatedButton(
                  onPressed: _createIndexManually,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[800],
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: Text(
                    'Create Index Now',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  'After creating the index, it may take 2-5 minutes to activate',
                  style: GoogleFonts.poppins(
                    color: Colors.grey[700],
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),

          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isRetrying ? null : _loadUserTickets,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[200],
              foregroundColor: Colors.blue[800],
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: _isRetrying
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(),
            )
                : Text(
              'Retry',
              style: GoogleFonts.poppins(fontSize: 16),
            ),
          ),
          if (_indexCreated) ...[
            const SizedBox(height: 15),
            Text(
              '✓ Index creation initiated. Please wait before retrying',
              style: GoogleFonts.poppins(
                color: Colors.green,
                fontSize: 14,
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 20),
        Text(
          'Loading your tickets...',
          style: GoogleFonts.poppins(fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.support_agent, size: 64, color: Colors.grey),
          const SizedBox(height: 20),
          Text(
            'No tickets submitted yet',
            style: GoogleFonts.poppins(
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Submit your first ticket using the "Submit Ticket" tab',
            style: GoogleFonts.poppins(
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTicketList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _userTickets.length,
      itemBuilder: (context, index) {
        final ticket = _userTickets[index];
        final data = ticket.data() as Map<String, dynamic>;

        final subject = data['subject'] as String? ?? 'No subject';
        final status = data['status'] as String? ?? 'Unknown';
        final createdAt = data['createdAt'] as Timestamp?;
        final hasReplies = (data['replyCount'] as int? ?? 0) > 0;

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 16),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Icon(
              hasReplies ? Icons.mark_email_read : Icons.mark_email_unread,
              color: hasReplies ? Colors.green : Colors.blue,
            ),
            title: Text(
              subject,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        status,
                        style: GoogleFonts.poppins(
                          color: _getStatusColor(status),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (hasReplies) ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Replied',
                          style: GoogleFonts.poppins(
                            color: Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ]
                  ],
                ),
                const SizedBox(height: 8),
                if (createdAt != null)
                  Text(
                    'Created: ${_formatDateTime(createdAt)}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UserTicketDetailPage(
                  ticket: ticket,
                  userEmail: widget.userEmail,
                  userName: widget.userName,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class UserTicketDetailPage extends StatefulWidget {
  final QueryDocumentSnapshot ticket;
  final String userEmail;
  final String userName;

  const UserTicketDetailPage({
    super.key,
    required this.ticket,
    required this.userEmail,
    required this.userName,
  });

  @override
  State<UserTicketDetailPage> createState() => _UserTicketDetailPageState();
}

class _UserTicketDetailPageState extends State<UserTicketDetailPage> {
  final TextEditingController _replyController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<QueryDocumentSnapshot> _replies = [];
  bool _isLoadingReplies = true;
  bool _isSubmittingReply = false;

  @override
  void initState() {
    super.initState();
    _loadReplies();
  }

  Future<void> _loadReplies() async {
    try {
      final repliesSnapshot = await widget.ticket.reference
          .collection('replies')
          .orderBy('timestamp', descending: false)
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

    setState(() => _isSubmittingReply = true);

    try {
      await widget.ticket.reference.collection('replies').add({
        'message': _replyController.text,
        'sender': widget.userName,
        'senderEmail': widget.userEmail,
        'isAdmin': false,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await widget.ticket.reference.update({
        'updatedAt': FieldValue.serverTimestamp(),
        'status': 'Submitted',
      });

      _replyController.clear();
      _loadReplies();
      FocusScope.of(context).unfocus();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reply added successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add reply: $e')),
      );
    } finally {
      setState(() => _isSubmittingReply = false);
    }
  }

  String _formatDateTime(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown date';
    return DateFormat('MMM dd, yyyy - hh:mm a').format(timestamp.toDate());
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.ticket.data() as Map<String, dynamic>;
    final subject = data['subject'] as String? ?? 'No subject';
    final content = data['content'] as String? ?? 'No content';
    final status = data['status'] as String? ?? 'Unknown';
    final createdAt = data['createdAt'] as Timestamp?;
    final updatedAt = data['updatedAt'] as Timestamp?;
    final attachments = (data['attachments'] as List<dynamic>? ?? []).cast<String>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Ticket Details', style: GoogleFonts.poppins()),
        backgroundColor: Colors.blue[800],
        elevation: 0,
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
                  Text(
                    subject,
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[800],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status,
                      style: GoogleFonts.poppins(
                        color: _getStatusColor(status),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // User info
                  Row(
                    children: [
                      const Icon(Icons.person, color: Colors.grey, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        '${widget.userName} (${widget.userEmail})',
                        style: GoogleFonts.poppins(color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Ticket content
                  Text(
                    content,
                    style: GoogleFonts.poppins(fontSize: 16),
                  ),
                  const SizedBox(height: 20),

                  // Attachments
                  if (attachments.isNotEmpty) ...[
                    Text(
                      'Attachments:',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w500,
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
                          color: Colors.grey[100],
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
                    )).toList(),
                    const SizedBox(height: 20),
                  ],

                  // Ticket metadata
                  const Divider(),
                  if (createdAt != null)
                    Text(
                      'Created: ${_formatDateTime(createdAt)}',
                      style: GoogleFonts.poppins(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  if (updatedAt != null)
                    Text(
                      'Updated: ${_formatDateTime(updatedAt)}',
                      style: GoogleFonts.poppins(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  const Divider(),
                  const SizedBox(height: 20),

                  // Replies section
                  Text(
                    'Conversation',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Initial ticket message
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              widget.userName,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w500,
                                color: Colors.blue[800],
                              ),
                            ),
                            const Spacer(),
                            if (createdAt != null)
                              Text(
                                _formatDateTime(createdAt),
                                style: GoogleFonts.poppins(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(content),
                      ],
                    ),
                  ),

                  // Admin replies
                  if (_isLoadingReplies)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_replies.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text(
                          'No replies yet. Our team will respond soon.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    ..._replies.map((reply) {
                      final replyData = reply.data() as Map<String, dynamic>;
                      final message = replyData['message'] as String? ?? '';
                      final sender = replyData['sender'] as String? ?? 'Support Team';
                      final timestamp = replyData['timestamp'] as Timestamp?;
                      final isAdmin = replyData['isAdmin'] as bool? ?? true;

                      return Container(
                        margin: const EdgeInsets.only(top: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isAdmin ? Colors.grey[100] : Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  isAdmin ? 'Support Team' : widget.userName,
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w500,
                                    color: isAdmin ? Colors.grey[700] : Colors.blue[800],
                                  ),
                                ),
                                const Spacer(),
                                if (timestamp != null)
                                  Text(
                                    _formatDateTime(timestamp),
                                    style: GoogleFonts.poppins(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(message),
                          ],
                        ),
                      );
                    }).toList(),
                ],
              ),
            ),
          ),

          // Reply input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _replyController,
                    decoration: InputDecoration(
                      hintText: 'Type your reply...',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _isSubmittingReply ? null : _addReply,
                  style: ElevatedButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(14),
                    backgroundColor: Colors.blue[800],
                  ),
                  child: _isSubmittingReply
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                      : const Icon(Icons.send, color: Colors.white),
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
      case 'open': return Colors.orange;
      case 'submitted': return Colors.blue;
      case 'queued': return Colors.purple;
      case 'solved': return Colors.green;
      case 'closed': return Colors.grey;
      default: return Colors.yellow;
    }
  }
}