import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
// import 'package:http/http.dart'; // http is not used
import 'package:intl/intl.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  _ReportPageState createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  DateTime? _startDate;
  DateTime? _endDate;
  List<Map<String, dynamic>> _registrations = [];
  bool _isGenerating = false;
  bool _isSending = false;
  String? _errorMessage;
  String? _successMessage;

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
        _registrations.clear();
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
      _registrations.clear();
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('Registrations')
          .where('registrationDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(_startDate!),
          isLessThanOrEqualTo: Timestamp.fromDate(
              _endDate!.add(const Duration(days: 1))
          ))
          .get(); // Added .get() here

      if (snapshot.docs.isEmpty) {
        setState(() => _errorMessage = 'No registrations found in the selected date range');
        return;
      }

      final List<Map<String, dynamic>> registrations = [];
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        registrations.add({
          'email': data['userEmail'] ?? 'No email',
          'course': data['courseName'] ?? 'Unknown course',
          'date': (data['registrationDate'] as Timestamp).toDate(),
        });
      }

      setState(() {
        _registrations = registrations;
        _successMessage = 'Found ${registrations.length} registrations';
      });
    } catch (e) {
      setState(() => _errorMessage = 'Error fetching data: ${e.toString()}');
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  Future<void> _sendEmail() async {
    if (_startDate == null || _endDate == null) {
      setState(() => _errorMessage = 'Please select both dates');
      return;
    }

    if (_registrations.isEmpty) {
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
        options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
      );

      final result = await callable.call({
        'startDate': _startDate!.toIso8601String(),
        'endDate': _endDate!.toIso8601String(),
      });

      setState(() => _successMessage = result.data['message']);
    } catch (e) {
      setState(() => _errorMessage = 'Failed to send email: ${e.toString()}');
    } finally {
      setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registration Report'),
        backgroundColor: const Color(0xFF1E1F2B),
      ),
      backgroundColor: const Color(0xFF0F111E),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Date Range',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Date Selection
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
            const SizedBox(height: 24),

            // Action Buttons
            Row(
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
            ),
            const SizedBox(height: 24),

            // Messages
            if (_errorMessage != null)
              _buildMessageCard(_errorMessage!, true),
            if (_successMessage != null)
              _buildMessageCard(_successMessage!, false),

            // Results
            if (_registrations.isNotEmpty)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        'Registrations (${_registrations.length})',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _registrations.length,
                        itemBuilder: (context, index) {
                          return _buildRegistrationItem(index);
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
      child: Text(
        message,
        style: TextStyle(
          color: isError ? const Color(0xFFFF6B6B) : const Color(0xFF4CAF50),
        ),
      ),
    );
  }

  Widget _buildRegistrationItem(int index) {
    final reg = _registrations[index];
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
          reg['email'] ?? 'No email',
          style: const TextStyle(color: Colors.white),
        ),
        subtitle: Text(
          reg['course'] ?? 'Unknown course',
          style: const TextStyle(color: Colors.white70),
        ),
        trailing: Text(
          DateFormat.yMMMd().format(reg['date']),
          style: const TextStyle(color: Colors.white54),
        ),
      ),
    );
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