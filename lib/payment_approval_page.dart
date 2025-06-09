import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';

class PaymentApprovalPage extends StatefulWidget {
  const PaymentApprovalPage({super.key});

  @override
  State<PaymentApprovalPage> createState() => _PaymentApprovalPageState();
}

class _PaymentApprovalPageState extends State<PaymentApprovalPage>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late TabController _tabController;
  bool _isFirebaseInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeFirebase();
    _tabController = TabController(length: 2, vsync: this);
  }

  Future<void> _initializeFirebase() async {
    try {
      await Firebase.initializeApp();
      setState(() {
        _isFirebaseInitialized = true;
      });
    } catch (e) {
      debugPrint('Firebase initialization error: $e');
    }
  }

  Future<void> updatePaymentStatus(DocumentSnapshot transaction, String newStatus) async {
    try {
      final data = transaction.data() as Map<String, dynamic>;
      WriteBatch batch = _firestore.batch();

      batch.update(transaction.reference, {'status': newStatus});

      if (newStatus == 'approved') {
        final String? courseName = data['courseName']?.toString();
        final String? studentEmail = data['studentEmail']?.toString();
        final String? studentID = data['studentID']?.toString();

        // 1. CREATE APPROVING STUDENT DOCUMENT
        if (studentEmail != null && studentEmail.isNotEmpty &&
            studentID != null && studentID.isNotEmpty) {
          final approvingStudentRef = _firestore.collection('ApprovingStudents').doc();
          batch.set(approvingStudentRef, {
            'studentEmail': studentEmail,
            'studentId': studentID,
            'courseName': courseName,
            'transactionId': transaction.id,
            'approvedAt': FieldValue.serverTimestamp(),
          });
        } else {
          debugPrint('Missing studentEmail or studentId for ApprovingStudents document');

          // Show error to admin
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Missing student data - cannot create approval record'),
              backgroundColor: Colors.orange,
            ),
          );
        }

        // 2. UPDATE COURSE ENROLLMENT
        if (courseName != null && courseName.isNotEmpty &&
            studentEmail != null && studentEmail.isNotEmpty) {
          final courseRef = _firestore.collection('Courses').doc(courseName);
          batch.update(courseRef, {
            'PendingStudent': FieldValue.arrayRemove([studentEmail]),
            'signedUsers': FieldValue.arrayUnion([studentEmail]),
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Missing required fields (courseId or studentEmail)'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

      await batch.commit();
      debugPrint('Transaction updated successfully');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Transaction ${newStatus == 'approved' ? 'approved' : 'dismissed'}'),
          backgroundColor: newStatus == 'approved' ? Colors.green : Colors.orange,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('Error updating payment status: $e');
      debugPrint('Stack trace: $stackTrace');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update status: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void showTransactionDialog(DocumentSnapshot transaction, String statusFilter) {
    final data = transaction.data() as Map<String, dynamic>;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: const Color(0xFF1E2029),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Transaction Details',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildDetailRow(Icons.person, 'Name:', data['studentName']?.toString() ?? 'N/A'),
                _buildDetailRow(Icons.email, 'Email:', data['studentEmail']?.toString() ?? 'N/A'),
                _buildDetailRow(Icons.credit_card, 'Student ID:', data['studentId']?.toString() ?? 'N/A'),
                _buildDetailRow(Icons.school, 'Course:', data['courseName']?.toString() ?? 'N/A'),
                const SizedBox(height: 10),
                _buildStatusIndicator(data['status']?.toString() ?? 'pending'),
                const SizedBox(height: 20),

                if (data['paymentScreenshot'] != null) ...[
                  Text('Payment Proof', style: _detailTitleStyle),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      data['paymentScreenshot'].toString(),
                      height: 250,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        return progress == null
                            ? child
                            : Container(
                          height: 250,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade800,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(child: CircularProgressIndicator()),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                if (statusFilter == 'pending')
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: _buildActionButton(
                            'Approve',
                            Colors.green,
                            Icons.check_circle,
                                () {
                              updatePaymentStatus(transaction, 'approved');
                              Navigator.pop(context);
                            }
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildActionButton(
                            'Dismiss',
                            Colors.red,
                            Icons.cancel,
                                () {
                              updatePaymentStatus(transaction, 'dismissed');
                              Navigator.pop(context);
                            }
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.blueAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: _detailLabelStyle),
                const SizedBox(height: 4),
                Text(value, style: _detailValueStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(String status) {
    final color = status == 'approved'
        ? Colors.green
        : status == 'dismissed'
        ? Colors.red
        : Colors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            status.toUpperCase(),
            style: GoogleFonts.poppins(
              color: color,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String text, Color color, IconData icon, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withOpacity(0.3)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(text, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(DocumentSnapshot transaction, String statusFilter) {
    final data = transaction.data() as Map<String, dynamic>;
    final status = data['status']?.toString() ?? 'pending';
    final statusColor = status == 'approved'
        ? Colors.green
        : status == 'dismissed'
        ? Colors.red
        : Colors.orange;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2029),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => showTransactionDialog(transaction, statusFilter),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2D3A),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    Icons.receipt_long,
                    color: statusColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            data['studentName']?.toString() ?? 'Unknown',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              status,
                              style: GoogleFonts.poppins(
                                color: statusColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        data['courseName']?.toString() ?? 'No course',
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text(
                            '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                            style: GoogleFonts.poppins(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            'View Details',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF6C63FF),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward, size: 16, color: Color(0xFF6C63FF)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget transactionList(String statusFilter) {
    if (!_isFirebaseInitialized) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collectionGroup('transactions').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: const Color(0xFF6C63FF),
              strokeWidth: 2,
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.receipt_long,
                  size: 60,
                  color: Colors.grey.withOpacity(0.5),
                ),
                const SizedBox(height: 20),
                Text(
                  'No transactions found',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        final filteredDocs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = data['status']?.toString() ?? 'pending';
          return status == statusFilter;
        }).toList();

        if (filteredDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  statusFilter == 'approved'
                      ? Icons.check_circle_outline
                      : Icons.hourglass_empty,
                  size: 60,
                  color: Colors.grey.withOpacity(0.5),
                ),
                const SizedBox(height: 20),
                Text(
                  'No $statusFilter transactions',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final transaction = filteredDocs[index];
            return _buildTransactionCard(transaction, statusFilter);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isFirebaseInitialized) {
      return Scaffold(
        backgroundColor: const Color(0xFF13141C),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(
                'Initializing payment system...',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF13141C),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              backgroundColor: const Color(0xFF1E2029),
              expandedHeight: 120,
              floating: true,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  'Payment Approval',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 20,
                  ),
                ),
                centerTitle: true,
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF2A2D3A), Color(0xFF1E2029)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverTabBarDelegate(
                TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(50),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFF9D6BFF)],
                    ),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                  unselectedLabelStyle: GoogleFonts.poppins(),
                  tabs: const [
                    Tab(text: 'Pending'),
                    Tab(text: 'Approved'),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            transactionList('pending'),
            transactionList('approved'),
          ],
        ),
      ),
    );
  }

  // Styles
  final TextStyle _detailTitleStyle = GoogleFonts.poppins(
    color: Colors.white,
    fontWeight: FontWeight.w500,
    fontSize: 16,
  );

  final TextStyle _detailLabelStyle = GoogleFonts.poppins(
    color: Colors.white70,
    fontSize: 12,
    letterSpacing: 0.5,
  );

  final TextStyle _detailValueStyle = GoogleFonts.poppins(
    color: Colors.white,
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverTabBarDelegate(this.tabBar);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: const Color(0xFF1E2029),
      child: tabBar,
    );
  }

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar;
  }
}