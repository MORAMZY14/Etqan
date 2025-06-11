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

  // Modern color palette
  final Color _backgroundColor = const Color(0xFF0F1016);
  final Color _cardColor = const Color(0xFF1E2029);
  final Color _primaryColor = const Color(0xFF6C5CE7);
  final Color _successColor = const Color(0xFF00B894);
  final Color _warningColor = const Color(0xFFFDCB6E);
  final Color _errorColor = const Color(0xFFD63031);
  final Color _textPrimary = const Color(0xFFF5F6FA);
  final Color _textSecondary = const Color(0xFFBDC3C7);

  @override
  void initState() {
    super.initState();
    _initializeFirebase();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Missing student data - cannot create approval record'),
                backgroundColor: _warningColor,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ));
              }

              if (courseName != null && courseName.isNotEmpty &&
              studentEmail != null && studentEmail.isNotEmpty) {
            final courseRef = _firestore.collection('Courses').doc(courseName);
            batch.update(courseRef, {
              'PendingStudent': FieldValue.arrayRemove([studentEmail]),
              'signedUsers': FieldValue.arrayUnion([studentEmail]),
            });
          } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Missing required fields (courseId or studentEmail)'),
              backgroundColor: _warningColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ));
        }
        }

            await batch.commit();
        debugPrint('Transaction updated successfully');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transaction ${newStatus == 'approved' ? 'approved' : 'dismissed'}'),
            backgroundColor: newStatus == 'approved' ? _successColor : _warningColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      } catch (e, stackTrace) {
      debugPrint('Error updating payment status: $e');
      debugPrint('Stack trace: $stackTrace');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update status: ${e.toString()}'),
          backgroundColor: _errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  void showTransactionDialog(DocumentSnapshot transaction, String statusFilter) {
    final data = transaction.data() as Map<String, dynamic>;
    final screenSize = MediaQuery.of(context).size;
    final isLargeScreen = screenSize.width > 400; // iPhone 16 Pro Max width

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: _cardColor,
          insetPadding: EdgeInsets.symmetric(
            horizontal: isLargeScreen ? 24 : 16,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(isLargeScreen ? 24 : 16),
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
                          fontSize: isLargeScreen ? 22 : 20,
                          fontWeight: FontWeight.w600,
                          color: _textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: _textSecondary, size: 24),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Modern detail cards
                  _buildDetailCard(
                    icon: Icons.person_outline,
                    title: 'Student Information',
                    items: [
                      _DetailItem('Name', data['studentName']?.toString() ?? 'N/A'),
                      _DetailItem('Email', data['studentEmail']?.toString() ?? 'N/A'),
                      _DetailItem('Student ID', data['studentId']?.toString() ?? 'N/A'),
                    ],
                  ),

                  const SizedBox(height: 16),

                  _buildDetailCard(
                    icon: Icons.school_outlined,
                    title: 'Course Information',
                    items: [
                      _DetailItem('Course', data['courseName']?.toString() ?? 'N/A'),
                      _DetailItem('Date', '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}'),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Status chip
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: _getStatusColor(data['status']?.toString() ?? 'pending').withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _getStatusColor(data['status']?.toString() ?? 'pending').withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getStatusIcon(data['status']?.toString() ?? 'pending'),
                            size: 18,
                            color: _getStatusColor(data['status']?.toString() ?? 'pending'),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            (data['status']?.toString() ?? 'pending').toUpperCase(),
                            style: GoogleFonts.poppins(
                              color: _getStatusColor(data['status']?.toString() ?? 'pending'),
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Payment proof section
                  if (data['paymentScreenshot'] != null) ...[
                    Text(
                      'Payment Proof',
                      style: GoogleFonts.poppins(
                        color: _textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () {
                        // TODO: Implement full-screen image viewer
                      },
                      child: Hero(
                        tag: 'payment-image-${transaction.id}',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            height: isLargeScreen ? 280 : 220,
                            decoration: BoxDecoration(
                              color: _backgroundColor.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Stack(
                              children: [
                                Image.network(
                                  data['paymentScreenshot'].toString(),
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, progress) {
                                    return progress == null
                                        ? child
                                        : Center(
                                      child: CircularProgressIndicator(
                                        color: _primaryColor,
                                      ),
                                    );
                                  },
                                ),
                                Positioned(
                                  bottom: 12,
                                  right: 12,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.fullscreen,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Action buttons for pending transactions
                  if (statusFilter == 'pending')
                    Row(
                      children: [
                        Expanded(
                          child: _buildModernButton(
                            label: 'Approve',
                            icon: Icons.check_rounded,
                            color: _successColor,
                            onPressed: () {
                              updatePaymentStatus(transaction, 'approved');
                              Navigator.pop(context);
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildModernButton(
                            label: 'Reject',
                            icon: Icons.close_rounded,
                            color: _errorColor,
                            onPressed: () {
                              updatePaymentStatus(transaction, 'dismissed');
                              Navigator.pop(context);
                            },
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailCard({
    required IconData icon,
    required String title,
    required List<_DetailItem> items,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _backgroundColor.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _cardColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: _primaryColor),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.poppins(
                  color: _textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.label}:',
                  style: GoogleFonts.poppins(
                    color: _textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.value,
                    style: GoogleFonts.poppins(
                      color: _textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildModernButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: color.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        elevation: 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(DocumentSnapshot transaction, String statusFilter) {
    final data = transaction.data() as Map<String, dynamic>;
    final status = data['status']?.toString() ?? 'pending';
    final statusColor = _getStatusColor(status);
    final screenSize = MediaQuery.of(context).size;
    final isLargeScreen = screenSize.width > 400;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isLargeScreen ? 16 : 12,
        vertical: isLargeScreen ? 8 : 6,
      ),
      child: Material(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        elevation: 0,
        child: InkWell(
          onTap: () => showTransactionDialog(transaction, statusFilter),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: EdgeInsets.all(isLargeScreen ? 20 : 16),
            child: Row(
              children: [
                // Status indicator
                Container(
                  width: 6,
                  height: 60,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 16),

                // Content
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
                              fontSize: isLargeScreen ? 18 : 16,
                              fontWeight: FontWeight.w600,
                              color: _textPrimary,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: statusColor.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              status,
                              style: GoogleFonts.poppins(
                                color: statusColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        data['courseName']?.toString() ?? 'No course',
                        style: GoogleFonts.poppins(
                          color: _textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 16,
                            color: _textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                            style: GoogleFonts.poppins(
                              color: _textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'View Details',
                            style: GoogleFonts.poppins(
                              color: _primaryColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: _primaryColor,
                          ),
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
      return Center(
        child: CircularProgressIndicator(color: _primaryColor),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collectionGroup('transactions').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: _primaryColor),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 60,
                  color: _textSecondary.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No transactions found',
                  style: GoogleFonts.poppins(
                    color: _textSecondary,
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
                  color: _textSecondary.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No $statusFilter transactions',
                  style: GoogleFonts.poppins(
                    color: _textSecondary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom + 16,
            top: 8,
          ),
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
        backgroundColor: _backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: _primaryColor),
              const SizedBox(height: 20),
              Text(
                'Initializing payment system...',
                style: GoogleFonts.poppins(color: _textPrimary),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: NestedScrollView(
          physics: const ClampingScrollPhysics(),
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                backgroundColor: _cardColor,
                expandedHeight: 140,
                floating: true,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    'Payment Approval',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 22,
                      color: _textPrimary,
                    ),
                  ),
                  centerTitle: true,
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_cardColor, _backgroundColor],
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
                      gradient: LinearGradient(
                        colors: [_primaryColor, Color(0xFF9D6BFF)],
                      ),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: _textPrimary,
                    unselectedLabelColor: _textSecondary,
                    labelStyle: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    unselectedLabelStyle: GoogleFonts.poppins(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                    isScrollable: false,
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
      ),
    );
  }

  // Helper methods
  Color _getStatusColor(String status) {
    return status == 'approved'
        ? _successColor
        : status == 'dismissed'
        ? _errorColor
        : _warningColor;
  }

  IconData _getStatusIcon(String status) {
    return status == 'approved'
        ? Icons.check_circle
        : status == 'dismissed'
        ? Icons.cancel
        : Icons.pending;
  }
}

class _DetailItem {
  final String label;
  final String value;

  _DetailItem(this.label, this.value);
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverTabBarDelegate(this.tabBar);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final _PaymentApprovalPageState state = context.findAncestorStateOfType<_PaymentApprovalPageState>()!;

    return Container(
      decoration: BoxDecoration(
        color: state._cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
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