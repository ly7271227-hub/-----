import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:uuid/uuid.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const AbdulhadiApp());
}

class AbdulhadiApp extends StatelessWidget {
  const AbdulhadiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'عبدالهادي الحبابي',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFD4A574)),
        scaffoldBackgroundColor: const Color(0xFF101010),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF17120E),
          foregroundColor: Colors.white,
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('عبدالهادي الحبابي'),
          actions: [
            IconButton(
              tooltip: 'لوحة الأدمن',
              icon: const Icon(Icons.admin_panel_settings),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminLoginPage()),
                );
              },
            ),
          ],
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('nasheeds')
              .where('published', isEqualTo: true)
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'تعذر تحميل الشيلات. تأكد من إعداد Firebase وقواعد Firestore.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return const Center(
                child: Text(
                  'لا توجد شيلات منشورة حالياً',
                  style: TextStyle(color: Colors.white70, fontSize: 18),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: docs.length,
              itemBuilder: (_, i) {
                return NasheedCard(data: docs[i].data());
              },
            );
          },
        ),
      ),
    );
  }
}

class NasheedCard extends StatefulWidget {
  final Map<String, dynamic> data;
  const NasheedCard({super.key, required this.data});

  @override
  State<NasheedCard> createState() => _NasheedCardState();
}

class _NasheedCardState extends State<NasheedCard> {
  final AudioPlayer player = AudioPlayer();
  bool loading = false;

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  Future<void> play() async {
    final url = widget.data['audioUrl'] as String?;
    if (url == null || url.isEmpty) return;

    setState(() => loading = true);
    try {
      await player.setUrl(url);
      await player.play();

      final id = widget.data['id'];
      if (id != null) {
        await FirebaseFirestore.instance.collection('nasheeds').doc(id).update({
          'plays': FieldValue.increment(1),
        });
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.data['title'] ?? 'بدون عنوان';
    final cover = widget.data['coverUrl'] ?? '';
    final plays = widget.data['plays'] ?? 0;

    return Card(
      color: const Color(0xFF1C1713),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(10),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: cover.toString().isEmpty
              ? Container(
                  width: 64,
                  height: 64,
                  color: const Color(0xFF30251D),
                  child: const Icon(Icons.music_note, color: Colors.white),
                )
              : CachedNetworkImage(
                  imageUrl: cover,
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                ),
        ),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'التشغيلات: $plays',
          style: const TextStyle(color: Colors.white60),
        ),
        trailing: IconButton(
          onPressed: loading ? null : play,
          icon: loading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.play_circle_fill, size: 38, color: Color(0xFFD4A574)),
        ),
      ),
    );
  }
}

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  String? error;

  Future<void> login() async {
    setState(() {
      busy = true;
      error = null;
    });

    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.text.trim(),
        password: password.text,
      );

      final uid = credential.user!.uid;
      final doc = await FirebaseFirestore.instance.collection('admins').doc(uid).get();

      if (!doc.exists || doc.data()?['role'] != 'admin') {
        await FirebaseAuth.instance.signOut();
        throw Exception('هذا الحساب ليس حساب أدمن.');
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminPage()),
      );
    } catch (e) {
      setState(() => error = 'بيانات الدخول غير صحيحة أو الحساب ليس أدمن.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('دخول الأدمن')),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Column(
                children: [
                  const Icon(
                    Icons.admin_panel_settings,
                    size: 90,
                    color: Color(0xFFD4A574),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'لوحة تحكم عبدالهادي الحبابي',
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 25),
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'البريد الإلكتروني',
                      labelStyle: TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: password,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'كلمة المرور',
                      labelStyle: TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(error!, style: const TextStyle(color: Colors.redAccent)),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: busy ? null : login,
                      child: busy
                          ? const CircularProgressIndicator()
                          : const Text('دخول لوحة التحكم'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  Future<void> logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) Navigator.pop(context);
  }

  Future<void> deleteNasheed(BuildContext context, String id, Map<String, dynamic> data) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف الشيلة'),
        content: Text('هل تريد حذف "${data['title'] ?? ''}" نهائياً؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
        ],
      ),
    );

    if (ok != true) return;

    await FirebaseFirestore.instance.collection('nasheeds').doc(id).delete();
  }

  Future<void> editNasheed(BuildContext context, String id, Map<String, dynamic> data) async {
    final title = TextEditingController(text: data['title'] ?? '');
    final description = TextEditingController(text: data['description'] ?? '');
    final poet = TextEditingController(text: data['poet'] ?? '');
    final audioUrl = TextEditingController(text: data['audioUrl'] ?? '');
    final coverUrl = TextEditingController(text: data['coverUrl'] ?? '');

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تعديل الشيلة'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: title, decoration: const InputDecoration(labelText: 'اسم الشيلة')),
              TextField(controller: poet, decoration: const InputDecoration(labelText: 'الشاعر')),
              TextField(controller: description, decoration: const InputDecoration(labelText: 'الوصف')),
              TextField(controller: audioUrl, decoration: const InputDecoration(labelText: 'رابط MP3 المباشر')),
              TextField(controller: coverUrl, decoration: const InputDecoration(labelText: 'رابط صورة الغلاف')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('nasheeds').doc(id).update({
                'title': title.text.trim(),
                'poet': poet.text.trim(),
                'description': description.text.trim(),
                'audioUrl': audioUrl.text.trim(),
                'coverUrl': coverUrl.text.trim(),
              });
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Future<void> togglePublish(String id, bool value) async {
    await FirebaseFirestore.instance.collection('nasheeds').doc(id).update({
      'published': !value,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('لوحة التحكم'),
          actions: [
            IconButton(
              tooltip: 'تسجيل الخروج',
              onPressed: () => logout(context),
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddNasheedPage()),
            );
          },
          icon: const Icon(Icons.add),
          label: const Text('إضافة شيلة'),
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('nasheeds')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return const Center(child: Text('لم تضف أي شيلة بعد.'));
            }

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: docs.length,
              itemBuilder: (_, index) {
                final doc = docs[index];
                final data = doc.data();
                final published = data['published'] == true;

                return Card(
                  child: ListTile(
                    title: Text(data['title'] ?? 'بدون عنوان'),
                    subtitle: Text(
                      '${published ? "منشورة" : "مخفية"} • التشغيلات: ${data['plays'] ?? 0}',
                    ),
                    leading: const Icon(Icons.music_note),
                    trailing: PopupMenuButton<String>(
                      onSelected: (action) {
                        if (action == 'edit') editNasheed(context, doc.id, data);
                        if (action == 'toggle') togglePublish(doc.id, published);
                        if (action == 'delete') deleteNasheed(context, doc.id, data);
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'edit', child: Text('تعديل')),
                        PopupMenuItem(
                          value: 'toggle',
                          child: Text(published ? 'إخفاء' : 'نشر'),
                        ),
                        const PopupMenuItem(value: 'delete', child: Text('حذف')),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class AddNasheedPage extends StatefulWidget {
  const AddNasheedPage({super.key});

  @override
  State<AddNasheedPage> createState() => _AddNasheedPageState();
}

class _AddNasheedPageState extends State<AddNasheedPage> {
  final title = TextEditingController();
  final description = TextEditingController();
  final poet = TextEditingController();
  final audioUrl = TextEditingController();
  final coverUrl = TextEditingController();
  bool busy = false;

  bool isHttpUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;
  }

  Future<void> save() async {
    final audio = audioUrl.text.trim();
    final cover = coverUrl.text.trim();

    if (title.text.trim().isEmpty || !isHttpUrl(audio)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اكتب اسم الشيلة وضع رابط MP3 مباشر صحيح.')),
      );
      return;
    }

    if (cover.isNotEmpty && !isHttpUrl(cover)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('رابط صورة الغلاف غير صحيح.')),
      );
      return;
    }

    setState(() => busy = true);

    try {
      final id = const Uuid().v4();
      final uid = FirebaseAuth.instance.currentUser!.uid;

      await FirebaseFirestore.instance.collection('nasheeds').doc(id).set({
        'id': id,
        'title': title.text.trim(),
        'description': description.text.trim(),
        'poet': poet.text.trim(),
        'audioUrl': audio,
        'coverUrl': cover,
        'published': true,
        'plays': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': uid,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت إضافة الشيلة بنجاح بدون Firebase Storage.')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء الحفظ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    poet.dispose();
    audioUrl.dispose();
    coverUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('إضافة شيلة')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF241C16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'هذه النسخة مجانية ولا تستخدم Firebase Storage. ارفع ملف MP3 والصورة في خدمة تخزين توفر لك رابطًا مباشرًا، ثم الصق الرابطين هنا.',
                style: TextStyle(color: Colors.white70, height: 1.5),
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: title,
              decoration: const InputDecoration(
                labelText: 'اسم الشيلة *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: poet,
              decoration: const InputDecoration(
                labelText: 'الشاعر',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: description,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'الوصف',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: audioUrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'رابط ملف MP3 المباشر *',
                hintText: 'https://example.com/nasheed.mp3',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.music_note),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: coverUrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'رابط صورة الغلاف',
                hintText: 'https://example.com/cover.jpg',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.image),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: busy ? null : save,
                icon: const Icon(Icons.save),
                label: Text(busy ? 'جارٍ الحفظ...' : 'حفظ ونشر الشيلة'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}