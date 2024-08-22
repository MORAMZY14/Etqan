import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AnnouncementsPage extends StatelessWidget {
  final CollectionReference announcementsRef = FirebaseFirestore.instance.collection('Paragraphs');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Announcements'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: announcementsRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final announcements = snapshot.data!.docs;

          return ListView.builder(
            itemCount: announcements.length,
            itemBuilder: (context, index) {
              final announcement = announcements[index];
              return Card(
                margin: EdgeInsets.all(10.0),
                child: ListTile(
                  title: Text(announcement['Name']),
                  subtitle: Text(announcement['Content']),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit),
                        onPressed: () => _editAnnouncement(context, announcement),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () => _deleteAnnouncement(announcement.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addAnnouncement(context),
        backgroundColor: Colors.red,
        child: Icon(Icons.add),
      ),
    );
  }

  void _addAnnouncement(BuildContext context) {
    _showAnnouncementDialog(context, isEditing: false);
  }

  void _editAnnouncement(BuildContext context, DocumentSnapshot announcement) {
    _showAnnouncementDialog(context, isEditing: true, announcement: announcement);
  }

  void _deleteAnnouncement(String id) {
    announcementsRef.doc(id).delete();
  }

  void _showAnnouncementDialog(BuildContext context, {bool isEditing = false, DocumentSnapshot? announcement}) {
    final TextEditingController nameController = TextEditingController(text: isEditing ? announcement!['Name'] : '');
    final TextEditingController contentController = TextEditingController(text: isEditing ? announcement!['Content'] : '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEditing ? 'Edit Announcement' : 'Add Announcement'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: contentController,
                decoration: InputDecoration(labelText: 'Content'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final String name = nameController.text;
                final String content = contentController.text;

                if (name.isNotEmpty && content.isNotEmpty) {
                  if (isEditing) {
                    // Update the existing announcement
                    await announcementsRef.doc(announcement!.id).update({
                      'Name': name,
                      'Content': content,
                    });
                  } else {
                    // Add a new announcement
                    await announcementsRef.add({
                      'Name': name,
                      'Content': content,
                    });
                  }

                  Navigator.of(context).pop();
                }
              },
              child: Text(isEditing ? 'Save' : 'Add'),
            ),
          ],
        );
      },
    );
  }
}
