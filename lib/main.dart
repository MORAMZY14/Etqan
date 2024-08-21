import 'package:Etqan/notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'login_page.dart';
import 'admin_login_page.dart';
import 'register_page.dart';
import 'tour_page.dart';
import 'about_page.dart';
import 'user_page.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  try {
    // Initialize Firebase
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    // Initialize notification plugin
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    final InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // Initialize notification service with the notification plugin
    NotificationService notificationService = NotificationService(flutterLocalNotificationsPlugin);

    // Run the app after Firebase and notifications are initialized
    runApp(MyApp(homePage: await getInitialPage(notificationService), notificationService: notificationService));
  } catch (e) {
    print('Error initializing Firebase: $e');
  }
}

Future<Widget> getInitialPage(NotificationService notificationService) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool rememberMe = prefs.getBool('rememberMe') ?? false;
  if (rememberMe) {
    String? email = prefs.getString('email');
    if (email != null) {
      return UserPage(email: email);
    }
  }
  return MyHomePage(notificationService: notificationService);
}

class MyApp extends StatelessWidget {
  final Widget homePage;
  final NotificationService notificationService;

  const MyApp({super.key, required this.homePage, required this.notificationService});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: homePage,
    );
  }
}

class MyHomePage extends StatefulWidget {
  final NotificationService notificationService;

  const MyHomePage({super.key, required this.notificationService});

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final NotificationService _notificationService;
  List<CustomListItem> items = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _notificationService = widget.notificationService;
    fetchDataFromFirestore();
    listenForNewRegistrations();
  }

  Future<void> fetchDataFromFirestore() async {
    try {
      final querySnapshot = await _firestore.collection('Paragraphs').get();
      setState(() {
        items = querySnapshot.docs.map((doc) {
          return CustomListItem(doc['Name'], doc['Content']);
        }).toList();
      });
    } catch (error) {
      print('Error getting documents: $error');
    }
  }

  Future<void> _showPasswordDialog() async {
    final TextEditingController passwordController = TextEditingController();
    String? adminPassword;

    try {
      DocumentSnapshot docSnapshot = await _firestore.collection('Passwords').doc('admin_password').get();
      if (docSnapshot.exists) {
        adminPassword = docSnapshot['password'];
      } else {
        throw Exception('Password document not found');
      }
    } catch (e) {
      print('Error retrieving password: $e');
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enter Admin Password'),
          content: TextField(
            controller: passwordController,
            decoration: const InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final String password = passwordController.text.trim();
                if (adminPassword != null && password == adminPassword) {
                  Navigator.of(context).pop();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AdminLoginPage()),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Incorrect password')),
                  );
                }
              },
              child: const Text('Submit'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void showContentDialog(String name, String content) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(name),
          content: SingleChildScrollView(
            child: Text(content),
          ),
          actions: [
            TextButton(
              child: const Text('Close'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  void _scrollLeft() {
    _scrollController.animateTo(
      _scrollController.offset - 200,
      duration: const Duration(milliseconds: 300),
      curve: Curves.ease,
    );
  }

  void _scrollRight() {
    _scrollController.animateTo(
      _scrollController.offset + 200,
      duration: const Duration(milliseconds: 300),
      curve: Curves.ease,
    );
  }

  void listenForNewRegistrations() {
    _firestore.collection('Courses').snapshots().listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.modified) {
          var courseData = change.doc.data();
          if (courseData != null) {
            var newUser = detectNewUser(courseData);
            if (newUser != null) {
              _notificationService.sendNotification(change.doc.id);
            }
          }
        }
      }
    });
  }

  dynamic detectNewUser(Map<String, dynamic> courseData) {
    // Implement your logic to detect a new user
    // Return the new user details or null
    return null; // Placeholder; implement your actual logic
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/login1.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              Container(
                margin: const EdgeInsets.only(top: 40.0, left: 20.0),
                child: const Text(
                  'Hello, Guest',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'sans-serif-black',
                    fontSize: 24.0,
                  ),
                ),
              ),
              SizedBox(
                height: MediaQuery.of(context).size.height - 35.0,
                child: Column(
                  children: <Widget>[
                    Stack(
                      children: [
                        SingleChildScrollView(
                          controller: _scrollController,
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: <Widget>[
                              buildCard(context, Icons.login, 'Login', const LoginPage()),
                              buildCard(context, Icons.tour, 'Tour', const TourPage()),
                              buildCard(context, Icons.app_registration, 'Register', const RegisterPage()),
                              buildCard(context, Icons.admin_panel_settings, 'Admin', null),
                              buildCard(context, Icons.info, 'About', const AboutPage()),
                            ],
                          ),
                        ),
                        if (kIsWeb)
                          Positioned.fill(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                GestureDetector(
                                  behavior: HitTestBehavior.translucent,
                                  onTap: _scrollLeft,
                                  child: Container(
                                    width: 30.0,
                                    height: double.infinity,
                                    color: Colors.transparent,
                                  ),
                                ),
                                GestureDetector(
                                  behavior: HitTestBehavior.translucent,
                                  onTap: _scrollRight,
                                  child: Container(
                                    width: 30.0,
                                    height: double.infinity,
                                    color: Colors.transparent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 10.0, left: 0.0),
                      child: const Text(
                        'Announcements',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'sans-serif-black',
                          fontSize: 24.0,
                        ),
                      ),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: fetchDataFromFirestore,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(top: 0.0),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                              elevation: 5.0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16.0),
                                title: Text(
                                  items[index].name,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  items[index].content.length > 100
                                      ? '${items[index].content.substring(0, 100)}...'
                                      : items[index].content,
                                  style: const TextStyle(fontSize: 16),
                                ),
                                onTap: () {
                                  showContentDialog(items[index].name, items[index].content);
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  GestureDetector buildCard(BuildContext context, IconData icon, String label, Widget? targetPage) {
    return GestureDetector(
      onTap: () {
        if (targetPage != null) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => targetPage));
        } else if (label == 'Admin') {
          _showPasswordDialog();
        }
      },
      child: Container(
        width: 150.0,
        height: 150.0,
        margin: const EdgeInsets.all(10.0),
        decoration: BoxDecoration(
          color: const Color(0xFF333366),
          borderRadius: BorderRadius.circular(20.0),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              offset: Offset(2.0, 2.0),
              blurRadius: 10.0,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, color: Colors.white, size: 48.0),
            const SizedBox(height: 10.0),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20.0,
                fontFamily: 'Roboto',
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomListItem {
  final String name;
  final String content;

  CustomListItem(this.name, this.content);
}
