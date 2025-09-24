import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PendingUsersPage extends StatefulWidget {
  final String courseId;
  const PendingUsersPage({required this.courseId, super.key});

  @override
  _PendingUsersPageState createState() => _PendingUsersPageState();
}

class _PendingUsersPageState extends State<PendingUsersPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  late Future<List<String>> _pendingUsersFuture;
  final List<String> _selectedUsers = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _pendingUsersFuture = _fetchPendingUsers();
  }

  Future<List<String>> _fetchPendingUsers() async {
    try {
      final courseDoc = await _firestore.collection('Courses').doc(widget.courseId).get();
      final List<dynamic> signedUsers = courseDoc.data()?['signedUsers'] ?? [];
      return List<String>.from(signedUsers);
    } catch (e) {
      print('Error fetching pending users: $e');
      return [];
    }
  }

  void _toggleSelection(String userEmail, bool isSelected) {
    setState(() {
      if (isSelected) {
        _selectedUsers.add(userEmail);
      } else {
        _selectedUsers.remove(userEmail);
      }
    });
  }

  Future<void> _approveSelectedUsers() async {
    if (_selectedUsers.isEmpty) return;

    setState(() => _isLoading = true);
    final courseDocRef = _firestore.collection('Courses').doc(widget.courseId);

    try {
      await courseDocRef.update({
        'ApprovedUsers': FieldValue.arrayUnion(_selectedUsers),
        'signedUsers': FieldValue.arrayRemove(_selectedUsers),
      });

      setState(() {
        _pendingUsersFuture = _fetchPendingUsers();
        _selectedUsers.clear();
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Users approved successfully!'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          backgroundColor: Colors.green.shade800,
        ),
      );
    } catch (e) {
      print('Error approving users: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Error approving users'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          backgroundColor: Colors.red.shade800,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteSelectedUsers() async {
    if (_selectedUsers.isEmpty) return;

    setState(() => _isLoading = true);
    final courseDocRef = _firestore.collection('Courses').doc(widget.courseId);

    try {
      await courseDocRef.update({
        'signedUsers': FieldValue.arrayRemove(_selectedUsers),
      });

      setState(() {
        _pendingUsersFuture = _fetchPendingUsers();
        _selectedUsers.clear();
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Users removed successfully!'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          backgroundColor: Colors.red.shade800,
        ),
      );
    } catch (e) {
      print('Error removing users: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Error removing users'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          backgroundColor: Colors.red.shade800,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Users',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        actions: [
          if (_selectedUsers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${_selectedUsers.length} selected',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search users...',
                prefixIcon: Icon(Icons.search, color: colorScheme.onSurface.withOpacity(0.6)),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: Icon(Icons.clear, color: colorScheme.onSurface.withOpacity(0.6)),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                )
                    : null,
              ),
              onChanged: (query) => setState(() {}),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<String>>(
              future: _pendingUsersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: colorScheme.error),
                        const SizedBox(height: 16),
                        Text(
                          'Failed to load users',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colorScheme.error,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Please try again later',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.tonal(
                          onPressed: () => setState(() {
                            _pendingUsersFuture = _fetchPendingUsers();
                          }),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 48, color: colorScheme.onSurface.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        Text(
                          'No pending users',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'All users are approved or none have signed up yet',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.5),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                final pendingUsers = snapshot.data!
                    .where((userEmail) => userEmail
                    .toLowerCase()
                    .contains(_searchController.text.toLowerCase()))
                    .toList();

                if (pendingUsers.isEmpty) {
                  return Center(
                    child: Text(
                      'No users found for "${_searchController.text}"',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: pendingUsers.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final userEmail = pendingUsers[index];
                    return Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withOpacity(
                            _selectedUsers.contains(userEmail) ? 0.3 : 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: _selectedUsers.contains(userEmail)
                            ? Border.all(color: colorScheme.primary, width: 1.5)
                            : null,
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        title: Text(
                          userEmail,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        trailing: Checkbox(
                          value: _selectedUsers.contains(userEmail),
                          onChanged: (bool? isSelected) {
                            _toggleSelection(userEmail, isSelected ?? false);
                          },
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6)),
                          side: BorderSide(
                            color: colorScheme.onSurface.withOpacity(0.4),
                            width: 1.5,
                          ),
                        ),
                        onTap: () {
                          _toggleSelection(
                              userEmail, !_selectedUsers.contains(userEmail));
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (_selectedUsers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isLoading ? null : _approveSelectedUsers,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Approve'),
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.primaryContainer,
                        foregroundColor: colorScheme.onPrimaryContainer,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isLoading ? null : _deleteSelectedUsers,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Remove'),
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.errorContainer,
                        foregroundColor: colorScheme.onErrorContainer,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}