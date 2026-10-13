import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 🔴 عدل السطرين ديل من Supabase > Settings > API
  await Supabase.initialize(
    url: 'https://YOUR_PROJECT_ID.supabase.co',
    anonKey: 'YOUR_ANON_KEY_HERE',
  );
  runApp(WusulApp());
}

class WusulApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'وصول',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.green, fontFamily: 'Cairo'),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Database? db;
  List<Map<String, dynamic>> families = [];
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final membersCtrl = TextEditingController(text: '4');
  Position? currentPos;
  bool isSyncing = false;

  @override
  void initState() {
    super.initState();
    initDB();
  }

  Future<void> initDB() async {
    db = await openDatabase(
      join(await getDatabasesPath(), 'wusul.db'),
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE families_local(id TEXT PRIMARY KEY, head_name TEXT, phone TEXT, members INT, lat REAL, lng REAL, synced INT)',
        );
      },
      version: 1,
    );
    loadLocal();
  }

  Future<void> loadLocal() async {
    if (db == null) return;
    final data = await db!.query('families_local', orderBy: 'id DESC');
    setState(() => families = data);
  }

  Future<void> getGPS() async {
    try {
      LocationPermission permission = await Geolocator.requestPermission();
      Position pos = await Geolocator.getCurrentPosition();
      setState(() => currentPos = pos);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم تحديد الموقع: ${pos.latitude.toStringAsFixed(4)}')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فعل GPS')));
    }
  }

  Future<void> addFamily() async {
    if (nameCtrl.text.isEmpty) return;
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    await db!.insert('families_local', {
      'id': id,
      'head_name': nameCtrl.text,
      'phone': phoneCtrl.text,
      'members': int.tryParse(membersCtrl.text)?? 4,
      'lat': currentPos?.latitude?? 15.6445,
      'lng': currentPos?.longitude?? 32.4771,
      'synced': 0,
    });
    nameCtrl.clear(); phoneCtrl.clear();
    loadLocal();
    // مزامنة تلقائية لو في نت
    syncToCloud();
  }

  Future<void> syncToCloud() async {
    var connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('محفوظ محليا - سيتم الرفع عند توفر النت (Offline)')));
      return;
    }
    setState(() => isSyncing = true);
    final unsynced = await db!.query('families_local', where: 'synced = 0');
    int success = 0;
    for (var f in unsynced) {
      try {
        await Supabase.instance.client.from('families').insert({
          'head_name': f['head_name'],
          'phone': f['phone'],
          'members_count': f['members'],
          'lat': f['lat'],
          'lng': f['lng'],
        });
        await db!.update('families_local', {'synced': 1}, where: 'id =?', whereArgs: [f['id']]);
        success++;
      } catch (e) {
        print('خطأ مزامنة: $e');
      }
    }
    setState(() => isSyncing = false);
    loadLocal();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تمت مزامنة $success أسرة مع السيرفر ✅')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('وصول - ${families.length} أسرة'),
        backgroundColor: Color(0xFF1B5E20),
        actions: [
          isSyncing? Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: Colors.white))
          : IconButton(icon: Icon(Icons.cloud_upload), onPressed: syncToCloud),
        ],
      ),
      body: Column(
        children: [
          // نموذج التسجيل
          Container(
            padding: EdgeInsets.all(12),
            color: Color(0xFFF1F8E9),
            child: Column(
              children: [
                TextField(controller: nameCtrl, decoration: InputDecoration(labelText: 'اسم رب الأسرة', border: OutlineInputBorder())),
                SizedBox(height: 8),
                Row(children: [
                  Expanded(child: TextField(controller: phoneCtrl, decoration: InputDecoration(labelText: 'هاتف', border: OutlineInputBorder()))),
                  SizedBox(width: 8),
                  SizedBox(width: 80, child: TextField(controller: membersCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'العدد', border: OutlineInputBorder()))),
                ]),
                SizedBox(height: 8),
                Row(children: [
                  ElevatedButton.icon(onPressed: getGPS, icon: Icon(Icons.location_on), label: Text(currentPos == null? 'تحديد GPS' : 'تم التحديد'), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange)),
                  SizedBox(width: 8),
                  Expanded(child: ElevatedButton.icon(onPressed: addFamily, icon: Icon(Icons.save), label: Text('تسجيل (Offline)'), style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF1B5E20)))),
                ]),
              ],
            ),
          ),
          // القائمة
          Expanded(
            child: families.isEmpty
           ? Center(child: Text('لا توجد أسر - سجل أول أسرة'))
            : ListView.builder(
                itemCount: families.length,
                itemBuilder: (c, i) {
                  final f = families[i];
                  return Card(
                    margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: ListTile(
                      leading: QrImageView(data: f['id'].toString(), size: 50),
                      title: Text(f['head_name']),
                      subtitle: Text('📱 ${f['phone']} - 👥 ${f['members']} - ${f['synced']==1? "✅ متزامن" : "📴 محلي"}'),
                      trailing: Icon(f['synced']==1? Icons.cloud_done : Icons.cloud_off, color: f['synced']==1? Colors.green : Colors.grey),
                    ),
                  );
                },
              ),
          ),
        ],
      ),
    );
  }
}
