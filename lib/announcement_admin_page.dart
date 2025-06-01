import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

class AnnouncementsPage extends StatelessWidget {
  final CollectionReference announcementsRef =
  FirebaseFirestore.instance.collection('Paragraphs');

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final SystemUiOverlayStyle overlayStyle = isDarkMode
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text('Announcements',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 24,
                  color: isDarkMode ? Colors.white : Colors.black)),
          centerTitle: false,
          elevation: 0,
          backgroundColor: Colors.transparent,
          systemOverlayStyle: overlayStyle,
          actions: [
            IconButton(
              icon: Icon(Icons.add, size: 28),
              onPressed: () => _addAnnouncement(context),
              tooltip: 'Add New Announcement',
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDarkMode
                  ? [
                Color(0xFF0D1B2A),
                Color(0xFF1B263B),
                Color(0xFF415A77),
              ]
                  : [
                Color(0xFFF5F7FA),
                Color(0xFFE4EDF5),
                Color(0xFFD9E8F5),
              ],
            ),
          ),
          child: StreamBuilder<QuerySnapshot>(
            stream: announcementsRef.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.announcement,
                          size: 64,
                          color: isDarkMode
                              ? Colors.blueGrey.shade400
                              : Colors.blueGrey.shade300),
                      SizedBox(height: 20),
                      Text('No announcements yet',
                          style: Theme.of(context).textTheme.titleLarge),
                      SizedBox(height: 10),
                      Text('Tap + to create your first announcement',
                          style: Theme.of(context).textTheme.bodyLarge),
                    ],
                  ),
                );
              }

              final announcements = snapshot.data!.docs;

              return ListView.builder(
                padding: EdgeInsets.only(top: 100, bottom: 100),
                itemCount: announcements.length,
                itemBuilder: (context, index) {
                  final announcement = announcements[index];
                  return _buildAnnouncementCard(
                      context, announcement, isDarkMode);
                },
              );
            },
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _addAnnouncement(context),
          backgroundColor:
          isDarkMode ? Color(0xFF5E72E4) : Color(0xFF4361EE),
          foregroundColor: Colors.white,
          elevation: 4,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Icon(Icons.add, size: 28),
        ),
      ),
    );
  }

  Widget _buildAnnouncementCard(
      BuildContext context, DocumentSnapshot announcement, bool isDarkMode) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _editAnnouncement(context, announcement),
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: isDarkMode
                  ? Colors.white.withOpacity(0.08)
                  : Colors.white.withOpacity(0.7),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        announcement['Name'],
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: isDarkMode
                              ? Colors.white
                              : Color(0xFF1D3557),
                        ),
                      ),
                    ),
                    PopupMenuButton(
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          child: Text('Edit'),
                          onTap: () => Future.delayed(
                              Duration.zero,
                                  () =>
                                  _editAnnouncement(context, announcement)),
                        ),
                        PopupMenuItem(
                          child: Text('Delete',
                              style: TextStyle(color: Colors.red)),
                          onTap: () => Future.delayed(
                              Duration.zero,
                                  () => _deleteAnnouncement(announcement.id)),
                        ),
                      ],
                      child: Icon(Icons.more_vert,
                          color: isDarkMode
                              ? Colors.white54
                              : Colors.blueGrey),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Text(
                  announcement['Content'],
                  style: TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: isDarkMode
                          ? Colors.white70
                          : Colors.blueGrey),
                ),
                SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Tap to edit',
                    style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode
                            ? Colors.white54
                            : Colors.blueGrey.shade400),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _addAnnouncement(BuildContext context) {
    _showAnnouncementDialog(context, isEditing: false);
  }

  void _editAnnouncement(
      BuildContext context, DocumentSnapshot announcement) {
    _showAnnouncementDialog(context,
        isEditing: true, announcement: announcement);
  }

  void _deleteAnnouncement(String id) {
    announcementsRef.doc(id).delete();
  }

  void _showAnnouncementDialog(BuildContext context,
      {bool isEditing = false, DocumentSnapshot? announcement}) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final TextEditingController nameController = TextEditingController(
        text: isEditing ? announcement!['Name'] : '');
    final TextEditingController contentController = TextEditingController(
        text: isEditing ? announcement!['Content'] : '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDarkMode ? Color(0xFF1B263B) : Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                spreadRadius: 5,
              )
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 60,
                    height: 4,
                    margin: EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.blueGrey.shade700
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  isEditing ? 'Edit Announcement' : 'New Announcement',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: isDarkMode ? Colors.white : Color(0xFF1D3557),
                  ),
                ),
                SizedBox(height: 24),
                TextField(
                  controller: nameController,
                  style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    labelText: 'Title',
                    labelStyle: TextStyle(
                        color: isDarkMode ? Colors.white70 : Colors.blueGrey),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: isDarkMode
                        ? Colors.blueGrey.shade800.withOpacity(0.4)
                        : Colors.grey.shade100,
                    prefixIcon: Icon(Icons.title,
                        color: isDarkMode ? Colors.white70 : Colors.blueGrey),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: contentController,
                  style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: 'Content',
                    labelStyle: TextStyle(
                        color: isDarkMode ? Colors.white70 : Colors.blueGrey),
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: isDarkMode
                        ? Colors.blueGrey.shade800.withOpacity(0.4)
                        : Colors.grey.shade100,
                    prefixIcon: Padding(
                      padding: EdgeInsets.only(bottom: 80),
                      child: Icon(Icons.description,
                          color: isDarkMode ? Colors.white70 : Colors.blueGrey),
                    ),
                  ),
                ),
                SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDarkMode ? Colors.white : Colors.black,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          side: BorderSide(
                              color: isDarkMode
                                  ? Colors.blueGrey.shade600
                                  : Colors.grey.shade400),
                        ),
                        child: Text('Cancel', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final String name = nameController.text;
                          final String content = contentController.text;

                          if (name.isNotEmpty && content.isNotEmpty) {
                            if (isEditing) {
                              await announcementsRef
                                  .doc(announcement!.id)
                                  .update({
                                'Name': name,
                                'Content': content,
                              });
                            } else {
                              await announcementsRef.add({
                                'Name': name,
                                'Content': content,
                              });
                            }
                            Navigator.pop(context);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDarkMode
                              ? Color(0xFF5E72E4)
                              : Color(0xFF4361EE),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(isEditing ? 'Save' : 'Create',
                            style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
              ],
            ),
          ),
        );
      },
    );
  }
}