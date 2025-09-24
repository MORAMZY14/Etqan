import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  _ReportPageState createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  DateTime? _startDate;
  DateTime? _endDate;
  List<Map<String, dynamic>> _allRegistrations = [];
  List<Map<String, dynamic>> _displayedRegistrations = [];
  bool _isGenerating = false;
  bool _isSending = false;
  String? _errorMessage;
  String? _successMessage;
  String _searchQuery = '';
  String? _currentStatusFilter;
  bool _hasGeneratedReport = false;

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
        _allRegistrations.clear();
        _displayedRegistrations.clear();
        _hasGeneratedReport = false;
        _errorMessage = null;
        _successMessage = null;
      });
    }
  }

  Future<void> _generateReport() async {
    if (_startDate == null || _endDate == null) {
      setState(() => _errorMessage = 'Please select both start and end dates');
      return;
    }

    setState(() {
      _isGenerating = true;
      _allRegistrations.clear();
      _displayedRegistrations.clear();
      _errorMessage = null;
      _successMessage = null;
      _hasGeneratedReport = false;
    });

    try {
      // Get registrations - force server fetch
      final QuerySnapshot regSnapshot = await FirebaseFirestore.instance
          .collection('Registrations')
          .where('registrationDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(_startDate!),
          isLessThanOrEqualTo: Timestamp.fromDate(
            _endDate!.add(const Duration(days: 1)),
          ))
          .get(const GetOptions(source: Source.server));

      if (regSnapshot.docs.isEmpty) {
        setState(() {
          _errorMessage = 'No registrations found';
          _hasGeneratedReport = true;
        });
        return;
      }

      // Get transactions for these registrations
      final List<String> regIds = regSnapshot.docs.map((doc) => doc.id).toList();
      final List<DocumentSnapshot> allTransactionDocs = [];

      // Process in chunks
      for (int i = 0; i < regIds.length; i += 10) {
        final chunk = regIds.sublist(i, i+10 > regIds.length ? regIds.length : i+10);
        final QuerySnapshot transactionChunk = await FirebaseFirestore.instance
            .collection('Transactions')
            .where('registrationId', whereIn: chunk)
            .get(const GetOptions(source: Source.server));
        allTransactionDocs.addAll(transactionChunk.docs);
      }

      // Map registrationId -> latest transaction
      final Map<String, Map<String, dynamic>> latestTransactionMap = {};
      for (var doc in allTransactionDocs) {
        final data = doc.data() as Map<String, dynamic>;
        final regId = data['registrationId'] as String?;
        final timestamp = data['createdAt'] as Timestamp?;
        final status = data['status'] as String?;

        if (regId == null || timestamp == null || status == null) continue;

        if (!latestTransactionMap.containsKey(regId) ||
            latestTransactionMap[regId]!['createdAt'].seconds < timestamp.seconds) {
          latestTransactionMap[regId] = {
            'status': status.toLowerCase(),
            'createdAt': timestamp,
          };
        }
      }

      // Build registration objects with TRANSACTION STATUS
      final List<Map<String, dynamic>> registrations = [];
      for (var doc in regSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final regId = doc.id;
        final transaction = latestTransactionMap[regId];
        final status = transaction?['status'] ?? 'pending'; // Use transaction status

        registrations.add({
          'id': regId,
          'email': data['email'] ?? 'No email',
          'name': data['studentName'] ?? 'Unknown', // Add student name
          'course': data['course'] ?? 'Unknown course',
          'date': (data['registrationDate'] as Timestamp).toDate(),
          'status': data['status'] ?? 'No Data', // Store transaction status here
          'transactionTime': transaction?['createdAt']?.toDate(),
        });
      }

      setState(() {
        _allRegistrations = registrations;
        _displayedRegistrations = registrations;
        _successMessage = 'Found ${registrations.length} registrations';
        _hasGeneratedReport = true;
      });
    } catch (e) {
      setState(() => _errorMessage = 'Error fetching data: ${e.toString()}');
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  // Apply filters based on status and search query
  void _applyFilters() {
    setState(() {
      _displayedRegistrations = _allRegistrations.where((reg) {
        // Apply status filter
        final statusMatch = _currentStatusFilter == null ||
            (reg['status'] as String? ?? '').toLowerCase() == _currentStatusFilter;

        // Apply search filter
        final email = reg['email']?.toString().toLowerCase() ?? '';
        final name = reg['name']?.toString().toLowerCase() ?? '';
        final searchMatch = _searchQuery.isEmpty ||
            email.contains(_searchQuery) ||
            name.contains(_searchQuery);

        return statusMatch && searchMatch;
      }).toList();
    });
  }

  // Handle search query changes
  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.trim().toLowerCase();
      _applyFilters();
    });
  }

  Future<void> _sendEmail() async {
    if (_startDate == null || _endDate == null) {
      setState(() => _errorMessage = 'Please select both dates');
      return;
    }

    if (_allRegistrations.isEmpty) {
      setState(() => _errorMessage = 'No data to send. Please generate report first');
      return;
    }

    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'generateRegistrationReport',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
      );

      final result = await callable.call({
        'startDate': _startDate!.toIso8601String(),
        'endDate': _endDate!.toIso8601String(),
      });

      setState(() => _successMessage = result.data['message'] ?? 'Email sent successfully');
    } catch (e) {
      setState(() => _errorMessage = 'Failed to send email: ${e.toString()}');
    } finally {
      setState(() => _isSending = false);
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
      case 'dismissed':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'approved':
        return 'Approved';
      case 'rejected':
      case 'dismissed':
        return 'Rejected';
      case 'pending':
        return 'Pending';
      default:
        return status;
    }
  }

  // Calculate counts from FULL report data
  Map<String, int> _getCounts() {
    int approved = 0;
    int pending = 0;
    int rejected = 0;

    for (var reg in _allRegistrations) {
      final status = reg['status'] as String? ?? 'pending';
      if (status == 'approved') {
        approved++;
      } else if (status == 'pending') pending++;
      else if (status == 'rejected' || status == 'dismissed') rejected++;
    }

    return {
      'total': _allRegistrations.length,
      'approved': approved,
      'pending': pending,
      'rejected': rejected,
    };
  }

  @override
  Widget build(BuildContext context) {
    final counts = _getCounts();
    final showDashboard = _allRegistrations.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registration Report Dashboard'),
        backgroundColor: const Color(0xFF1E1F2B),
        elevation: 5,
        centerTitle: true,
      ),
      backgroundColor: const Color(0xFF0F111E),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dashboard Cards (use counts from full report)
            if (showDashboard) ...[
              const Text(
                'Registration Summary',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildDashboardCard('TOTAL', counts['total'].toString(), Colors.blue),
                  _buildDashboardCard('APPROVED', counts['approved'].toString(), Colors.green),
                  _buildDashboardCard('PENDING', counts['pending'].toString(), Colors.orange),
                  _buildDashboardCard('REJECTED', counts['rejected'].toString(), Colors.red),
                ],
              ),
              const SizedBox(height: 24),
            ],

            // Date Range Selector
            _buildDateRangeSelector(),
            const SizedBox(height: 24),

            // Action Buttons
            _buildActionButtons(),
            const SizedBox(height: 24),

            // Messages
            if (_errorMessage != null) _buildMessageCard(_errorMessage!, true),
            if (_successMessage != null) _buildMessageCard(_successMessage!, false),

            // Results section - always show after generating report
            if (_hasGeneratedReport)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Registrations (${_displayedRegistrations.length})',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.filter_alt, color: Colors.white70),
                            onPressed: _showFilterOptions,
                          ),
                        ],
                      ),
                    ),
                    // Search Bar - always visible
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: TextField(
                        onChanged: _onSearchChanged,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Search by email or name...',
                          hintStyle: const TextStyle(color: Colors.white54),
                          prefixIcon: const Icon(Icons.search, color: Colors.white70),
                          filled: true,
                          fillColor: const Color(0xFF1E1F2B),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        ),
                      ),
                    ),
                    // Results list or "no results" message
                    Expanded(
                      child: _displayedRegistrations.isEmpty
                          ? const Center(
                        child: Text(
                          'No registrations found',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 18,
                          ),
                        ),
                      )
                          : ListView.builder(
                        itemCount: _displayedRegistrations.length,
                        itemBuilder: (context, index) {
                          return _buildRegistrationItem(_displayedRegistrations[index], index);
                        },
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: 1),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRangeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Date Range',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildDatePicker('Start Date', _startDate, true),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildDatePicker('End Date', _endDate, false),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDatePicker(String label, DateTime? date, bool isStart) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: () => _selectDate(context, isStart),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E1F2B),
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                date != null
                    ? DateFormat.yMMMd().format(date)
                    : 'Select Date',
                style: const TextStyle(fontSize: 16),
              ),
              const Icon(Icons.calendar_today, size: 20),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionButton(
          'Generate Report',
          Icons.bar_chart,
          _isGenerating ? null : _generateReport,
          _isGenerating,
          const Color(0xFF6C63FF),
        ),
        _buildActionButton(
          'Send as Email',
          Icons.email,
          _isSending ? null : _sendEmail,
          _isSending,
          const Color(0xFF4CAF50),
        ),
      ],
    );
  }

  Widget _buildActionButton(
      String text,
      IconData icon,
      VoidCallback? onPressed,
      bool isLoading,
      Color color,
      ) {
    return SizedBox(
      width: 160,
      child: ElevatedButton.icon(
        icon: isLoading
            ? const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        )
            : Icon(icon, color: Colors.white),
        label: Text(
          text,
          style: const TextStyle(color: Colors.white),
        ),
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageCard(String message, bool isError) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isError ? const Color(0x22FF6B6B) : const Color(0x224CAF50),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isError ? const Color(0x88FF6B6B) : const Color(0x884CAF50),
        ),
      ),
      child: Row(
        children: [
          Icon(isError ? Icons.error : Icons.check_circle,
              color: isError ? const Color(0xFFFF6B6B) : const Color(0xFF4CAF50)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: isError ? const Color(0xFFFF6B6B) : const Color(0xFF4CAF50),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegistrationItem(Map<String, dynamic> reg, int index) {
    final status = reg['status'] as String? ?? 'pending';
    final transactionTime = reg['transactionTime'] as DateTime?;

    return Card(
      color: const Color(0xFF1E1F2B),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getColorForIndex(index),
          child: Text(
            '${index + 1}',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          reg['name'] ?? 'Unknown name', // Show student name
          style: const TextStyle(color: Colors.white),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              reg['email'] ?? 'No email',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 4),
            Text(
              reg['course'] ?? 'Unknown course',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Chip(
                  label: Text(
                    _getStatusText(status),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  backgroundColor: _getStatusColor(status),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                ),
                if (transactionTime != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('MMM dd').format(transactionTime),
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ]
              ],
            ),
          ],
        ),
        trailing: Text(
          DateFormat.yMMMd().format(reg['date']),
          style: const TextStyle(color: Colors.white54),
        ),
      ),
    );
  }

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1F2B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Filter Registrations',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              _buildFilterOption('All', Icons.all_inclusive, () => _filterRegistrations(null)),
              _buildFilterOption('Approved', Icons.check_circle, () => _filterRegistrations('approved')),
              _buildFilterOption('Pending', Icons.access_time, () => _filterRegistrations('pending')),
              _buildFilterOption('Rejected', Icons.cancel, () => _filterRegistrations('rejected')),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterOption(String text, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(
        text,
        style: const TextStyle(color: Colors.white),
      ),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  void _filterRegistrations(String? status) {
    setState(() {
      _currentStatusFilter = status?.toLowerCase();
      _applyFilters();
    });
  }

  Color _getColorForIndex(int index) {
    final colors = [
      const Color(0xFF6C63FF),
      const Color(0xFFFF6B6B),
      const Color(0xFF4CAF50),
      const Color(0xFFFFA726),
      const Color(0xFF26C6DA),
    ];
    return colors[index % colors.length];
  }
}