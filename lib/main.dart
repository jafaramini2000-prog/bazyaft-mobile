import 'dart:convert';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

const green = Color(0xFF078B65);
const deepGreen = Color(0xFF145541);
const pale = Color(0xFFE4F5EC);
const bg = Color(0xFFF8FAF7);
const coral = Color(0xFFFFB565);
const blue = Color(0xFF4E9FC3);
const ink = Color(0xFF1D2924);

const backendUrl = String.fromEnvironment('SUPABASE_URL');
const backendKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
const serverEnabled = backendUrl != '' && backendKey != '';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (serverEnabled) {
    await Supabase.initialize(url: backendUrl, anonKey: backendKey);
  }
  runApp(const RecyclingApp());
}

class RecyclingApp extends StatelessWidget {
  const RecyclingApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'بازیافت من',
        locale: const Locale('fa', 'IR'),
        supportedLocales: const [Locale('fa', 'IR'), Locale('en', 'US')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        theme: ThemeData(
          fontFamily: GoogleFonts.vazirmatn().fontFamily,
          useMaterial3: true,
          scaffoldBackgroundColor: bg,
          colorScheme: ColorScheme.fromSeed(seedColor: green, primary: green, surface: Colors.white),
          appBarTheme: const AppBarTheme(backgroundColor: bg, centerTitle: true, elevation: 0, foregroundColor: ink),
          textTheme: GoogleFonts.vazirmatnTextTheme(const TextTheme(
            headlineMedium: TextStyle(fontSize: 24, color: ink, fontWeight: FontWeight.w900),
            titleLarge: TextStyle(fontSize: 19, color: ink, fontWeight: FontWeight.w800),
            titleMedium: TextStyle(fontSize: 15, color: ink, fontWeight: FontWeight.w700),
            bodyMedium: TextStyle(fontSize: 13.5, color: ink),
          )),
        ),
        builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
        home: const RecyclingShell(),
      );
}

class RecyclingShell extends StatefulWidget {
  const RecyclingShell({super.key});
  @override
  State<RecyclingShell> createState() => _RecyclingShellState();
}

class _RecyclingShellState extends State<RecyclingShell> {
  SharedPreferences? storage;
  String screen = 'welcome';
  int tab = 0;
  final mobile = TextEditingController();
  final address = TextEditingController();
  final details = TextEditingController();
  final note = TextEditingController();
  final Set<int> materials = {};
  int quantity = 0;
  int dayIndex = 1;
  int timeIndex = 0;
  LatLng pin = const LatLng(31.9992, 51.8681);
  final List<Map<String, dynamic>> records = [];
  String savedAddress = '';
  int wallet = 0;
  int recordIndex = 0;
  bool editingAddressOnly = false;
  int cityFilter = 0;

  final materialLabels = const ['پلاستیک', 'کاغذ و مقوا', 'فلزات', 'شیشه', 'لوازم الکترونیکی', 'سایر'];
  final materialIcons = const [Icons.water_drop_rounded, Icons.inventory_2_rounded, Icons.hardware_rounded, Icons.wine_bar_rounded, Icons.devices_rounded, Icons.recycling_rounded];
  final materialColors = const [Color(0xFF48B8F7), Color(0xFFF8BA62), Color(0xFF90A5B6), Color(0xFF61BD95), Color(0xFFAB98E8), Color(0xFF3FC8CA)];
  final quantities = const ['یک کیسه', 'دو تا سه کیسه', 'بیشتر از سه کیسه'];
  final timeRanges = const ['۹ تا ۱۲', '۱۲ تا ۱۵', '۱۵ تا ۱۸'];
  final states = const ['درخواست ثبت شد', 'در برنامه جمع‌آوری', 'مأمور در مسیر است', 'بازیافتی تحویل گرفته شد', 'اعتبار ثبت شد'];

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    storage = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      savedAddress = storage?.getString('address') ?? '';
      address.text = savedAddress;
      wallet = storage?.getInt('wallet') ?? 0;
      final raw = storage?.getString('requests');
      if (raw != null) {
        try {
          records.addAll((jsonDecode(raw) as List).map((x) => Map<String, dynamic>.from(x as Map)));
        } catch (_) {}
      }
      screen = storage?.getBool('introSeen') == true ? 'main' : 'welcome';
    });
  }

  Future<void> _persist() async {
    await storage?.setString('address', savedAddress);
    await storage?.setInt('wallet', wallet);
    await storage?.setString('requests', jsonEncode(records));
  }

  @override
  void dispose() {
    mobile.dispose(); address.dispose(); details.dispose(); note.dispose();
    super.dispose();
  }

  void go(String next) => setState(() => screen = next);
  void goMain(int target) => setState(() {tab = target; screen = 'main';});
  void startRequest() {
    setState(() { editingAddressOnly = false; materials.clear(); quantity = 0; dayIndex = 1; timeIndex = 0; note.clear(); screen = 'materials'; });
  }

  void editSavedAddress() => setState(() { editingAddressOnly = true; screen = 'address'; });

  void back() {
    if (screen == 'address' && editingAddressOnly) { goMain(tab); return; }
    const prev = {'login':'welcome','materials':'main','quantity':'materials','address':'quantity','schedule':'address','review':'schedule','success':'main','tracking':'main','profile':'main'};
    go(prev[screen] ?? 'main');
  }

  String faNum(Object value) => value.toString().replaceAllMapped(RegExp(r'[0-9]'), (m) => '۰۱۲۳۴۵۶۷۸۹'[int.parse(m[0]!)]);
  String money(int n) {
    final s = n.toString();
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i != 0 && (s.length - i) % 3 == 0) b.write('٬');
      b.write(s[i]);
    }
    return faNum(b.toString());
  }

  String dayName(int offset) {
    if (offset == 1) return 'فردا';
    if (offset == 2) return 'دو روز دیگر';
    if (offset == 3) return 'سه روز دیگر';
    return '${faNum(offset)} روز دیگر';
  }

  void _submit() {
    final data = <String, dynamic>{
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'materials': materials.map((x) => materialLabels[x]).toList(),
      'amount': quantities[quantity],
      'address': address.text.trim(),
      'details': details.text.trim(),
      'notes': note.text.trim(),
      'latitude': pin.latitude,
      'longitude': pin.longitude,
      'day': dayName(dayIndex + 1),
      'time': timeRanges[timeIndex],
      'status': 0,
      'created': DateTime.now().toIso8601String(),
    };
    setState(() {savedAddress = address.text.trim(); records.insert(0, data); recordIndex = 0; screen = 'success';});
    _persist();
  }

  void advanceDemoStatus() {
    if (records.isEmpty) return;
    final item = records[recordIndex];
    final current = (item['status'] as int?) ?? 0;
    if (current >= 4) return;
    setState(() {
      item['status'] = current + 1;
      if (current + 1 == 4) wallet += 12500; // مبلغ صرفاً شبیه‌سازی است.
    });
    _persist();
  }

  Widget panel(Widget child, {EdgeInsets padding = const EdgeInsets.all(17), Color color = Colors.white}) =>
      Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: const Color(0xFFE9F0EB), width: 0.7),
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [BoxShadow(color: Color(0x0B1E6C4C), blurRadius: 22, offset: Offset(0, 7))],
        ),
        child: child,
      );

  Widget miniFeature({required String emoji, required String title, required String caption, required Color color, required VoidCallback onTap, String? badge}) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFE9EFED))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 49, height: 49, alignment: Alignment.center, decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(17)), child: Text(emoji, style: const TextStyle(fontSize: 25))),
              const Spacer(), if (badge != null) tag(badge, color: const Color(0xFFFFF1DC), fg: const Color(0xFF9C611F)),
            ]),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: ink), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Text(caption, style: const TextStyle(fontSize: 11.5, color: Colors.black54), maxLines: 2, overflow: TextOverflow.ellipsis),
          ]),
        ),
      );

  Widget sectionHeader(String title, {String? hint, VoidCallback? onMore}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(children: [
      Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: ink))),
      if (onMore != null) TextButton(onPressed: onMore, child: Text(hint ?? 'مشاهده همه', style: const TextStyle(color: green, fontWeight: FontWeight.w800, fontSize: 12))),
    ]),
  );

  Widget header(String title, {String? caption}) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900, color: ink, fontSize: 22)),
          if (caption != null) ...[const SizedBox(height: 7), Text(caption, style: const TextStyle(color: Colors.black54, fontSize: 13))]
        ]),
      );

  Widget button(String label, VoidCallback? onTap, {bool outline = false, IconData? icon}) => SizedBox(
        width: double.infinity, height: 55,
        child: OutlinedButton.icon(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            backgroundColor: outline ? Colors.white : green,
            foregroundColor: outline ? green : Colors.white,
            disabledBackgroundColor: Colors.grey.shade300,
            side: BorderSide(color: outline ? green : Colors.transparent, width: 1.4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          icon: Icon(icon ?? Icons.arrow_back_rounded, size: 19),
          label: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        ),
      );

  Widget footer(String label, VoidCallback? action) => Container(
        padding: const EdgeInsets.fromLTRB(20, 13, 20, 16),
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFE9EFEB)))),
        child: SafeArea(top: false, child: button(label, action)),
      );

  Widget page(Widget content, {String? cta, VoidCallback? action, bool scroll = true}) => Column(children: [
        Expanded(child: scroll
            ? SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 15, 20, 24), child: content)
            : content),
        if (cta != null) footer(cta, action),
      ]);

  Widget tag(String label, {Color color = pale, Color fg = green}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg)),
      );

  Widget _welcome() => Container(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft,
            colors: [Color(0xFFDFF6E7), Color(0xFFF9FFF9), Color(0xFFFFF4E5)])),
        child: SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(24, 12, 24, 16), child: Column(children: [
          const Spacer(),
          Container(width: 98, height: 98, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32),
            boxShadow: const [BoxShadow(color: Color(0x1D178B59), blurRadius: 30, offset: Offset(0, 12))]),
            child: const Icon(Icons.eco_rounded, size: 58, color: green)),
          const SizedBox(height: 22),
          const Text('بازیافت من', style: TextStyle(fontSize: 31, fontWeight: FontWeight.w900, color: deepGreen)),
          const SizedBox(height: 8),
          const Text('از خونه‌مون شروع می‌کنیم 💚', textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: ink)),
          const SizedBox(height: 12),
          const Text('بازیافتی‌هاتو جدا کن؛\nما برای جمع‌آوریش میایم سراغت.', textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.8, color: deepGreen)),
          const Spacer(),
          Container(width: double.infinity, height: 212, clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(color: const Color(0xFFD5F1DE), borderRadius: BorderRadius.circular(35)),
            child: Stack(children: [
              Positioned(top: -55, left: -24, child: Container(width: 205, height: 205, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFEFFCEC)))),
              Positioned(bottom: -90, right: -35, child: Container(width: 245, height: 245, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFB4E5C3)))),
              const Positioned(top: 21, right: 23, child: Text('♻️  بازیافتی کمتر، شهر قشنگ‌تر', style: TextStyle(fontWeight: FontWeight.w900, color: deepGreen, fontSize: 13))),
              const Center(child: Icon(Icons.local_shipping_rounded, size: 144, color: deepGreen)),
              const Positioned(bottom: 20, right: 26, child: Text('🧴  📦  🥫  🍾', style: TextStyle(fontSize: 28))),
              Positioned(bottom: 19, left: 19, child: Container(padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.check_circle_rounded, size: 26, color: green))),
            ])),
          const SizedBox(height: 19),
          tag('پیش‌نمایش آزمایشی • هنوز خدمات واقعی فعال نیست'),
          const SizedBox(height: 16),
          button('شروع کنیم', () => go('login'), icon: Icons.arrow_back_rounded),
          const SizedBox(height: 5),
          TextButton(onPressed: () async { await storage?.setBool('introSeen', true); goMain(0); },
            child: const Text('ورود آزمایشی بدون ثبت‌نام', style: TextStyle(color: green, fontWeight: FontWeight.w800))),
        ]))),
      );

  Widget _login() => page(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 48),
        const Icon(Icons.eco_rounded, color: green, size: 90),
        const SizedBox(height: 22),
        const Text('خوش اومدی!', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 26, color: deepGreen)),
        const SizedBox(height: 12),
        const Text('برای تست نمونه، شماره موبایلت را وارد کن.\nدر این نسخه پیامک واقعی ارسال نمی‌شود.', textAlign: TextAlign.center, style: TextStyle(height: 1.8)),
        const SizedBox(height: 30),
        TextField(controller: mobile, keyboardType: TextInputType.phone, textDirection: TextDirection.ltr, textAlign: TextAlign.center, decoration: InputDecoration(hintText: '09xxxxxxxxx', prefixIcon: const Icon(Icons.phone_android_rounded), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))),
        const SizedBox(height: 14),
        tag('احراز هویت این نمونه شبیه‌سازی شده است'),
      ]), cta: 'ورود به نسخه آزمایشی', action: () async {await storage?.setBool('introSeen', true); goMain(0);});

  Widget _home() => SingleChildScrollView(padding: const EdgeInsets.fromLTRB(19, 12, 19, 27),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        InkWell(onTap: () => go('profile'), borderRadius: BorderRadius.circular(18),
          child: Container(width: 47, height: 47,
            decoration: BoxDecoration(color: pale, borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.person_rounded, color: deepGreen))),
        const SizedBox(width: 10),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [Text('سلام، همراهِ زمین! 👋', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            SizedBox(height: 3), Text('امروز چه کار خوبی برای شهرمون می‌کنیم؟', style: TextStyle(fontSize: 11.5, color: Colors.black54))])),
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.notifications_none_rounded, color: deepGreen, size: 23)),
      ]),
      const SizedBox(height: 19),
      InkWell(onTap: editSavedAddress, borderRadius: BorderRadius.circular(18), child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE9F0EB))),
        child: Row(children: [const Icon(Icons.location_on_rounded, color: green, size: 22), const SizedBox(width: 7),
          Expanded(child: Text(savedAddress.isEmpty ? 'محل جمع‌آوری رو مشخص کن' : savedAddress,
            maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5))),
          const Icon(Icons.keyboard_arrow_down_rounded, color: deepGreen)]))),
      const SizedBox(height: 19),
      Container(width: double.infinity, clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(29),
          gradient: const LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft,
            colors: [Color(0xFF0A926B), Color(0xFF0A6B59)])),
        child: Stack(children: [
          Positioned(top: -52, left: -34, child: Container(height: 205, width: 205,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x1FFFFFFF)))),
          Positioned(bottom: -72, left: 45, child: Container(height: 160, width: 160,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x17FFFFFF)))),
          Padding(padding: const EdgeInsets.all(21), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('بازیافتی داری؟', style: TextStyle(fontSize: 25, color: Colors.white, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                const Text('یه درخواست کافیه؛\nما میایم دم در خونه‌تون.', style: TextStyle(color: Colors.white, height: 1.65, fontSize: 12.5)),
                const SizedBox(height: 12),
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: const Color(0x25FFFFFF), borderRadius: BorderRadius.circular(13)),
                  child: const Text('تفکیک کن، اعتبار بگیر ✨', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800))),
              ])),
              const SizedBox(width: 6),
              SizedBox(width: 110, height: 124, child: Stack(children: [
                Positioned(top: 0, left: 7, child: Container(height: 82, width: 82, decoration: const BoxDecoration(color: Color(0x26FFFFFF), shape: BoxShape.circle))),
                const Align(alignment: Alignment.center, child: Icon(Icons.local_shipping_rounded, color: Color(0xFFE0FBE8), size: 93)),
                const Align(alignment: Alignment.bottomRight, child: Text('♻️', style: TextStyle(fontSize: 31))),
              ])),
            ]),
            const SizedBox(height: 21),
            SizedBox(width: double.infinity, height: 55, child: FilledButton.icon(onPressed: startRequest,
              style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: deepGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('ثبت درخواست جمع‌آوری', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)))),
          ])),
        ])),
      const SizedBox(height: 18),
      if (records.isNotEmpty) ...[
        panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Icon(Icons.local_shipping_outlined, color: green), const SizedBox(width: 8),
            const Expanded(child: Text('آخرین درخواستت', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15))), tag('دمو')]),
          const SizedBox(height: 8),
          Text(states[(records.first['status'] as int?) ?? 0], style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text('${records.first['day']} • ${records.first['time']}', style: const TextStyle(color: Colors.black54, fontSize: 12)),
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () {recordIndex=0; go('tracking');},
            icon: const Icon(Icons.arrow_back_rounded), label: const Text('پیگیری مرحله به مرحله', style: TextStyle(color: green, fontWeight: FontWeight.w800))))
        ])),
        const SizedBox(height: 15),
      ],
      sectionHeader('همه چیز توی یک اپ'),
      Row(children: [
        Expanded(child: miniFeature(emoji: '💳', title: 'اعتبار من', caption: '${money(wallet)} تومان آزمایشی', color: coral,
          onTap: () => goMain(3))),
        const SizedBox(width: 11),
        Expanded(child: miniFeature(emoji: '🚚', title: 'درخواست‌ها', caption: 'پیگیری شفاف و سریع', color: blue,
          onTap: () => goMain(1))),
      ]),
      const SizedBox(height: 6),
      sectionHeader('بازیافت کن، توی شهر خرج کن', hint: 'شهر من', onMore: () => goMain(2)),
      panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Expanded(child: Text('دنیایی از خرید و خدمات شهری 🌟', style: TextStyle(fontWeight: FontWeight.w900, color: deepGreen, fontSize: 15))),
          Icon(Icons.storefront_rounded, color: green, size: 30),
        ]),
        const SizedBox(height: 7),
        const Text('در آینده با اعتبار بازیافت از پذیرندگان طرف قرارداد خرید می‌کنی.',
          style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.7)),
        const SizedBox(height: 13),
        Row(children: [
          Expanded(child: miniFeature(emoji: '🍔', title: 'رستوران‌ها', caption: 'در طرح توسعه', color: const Color(0xFFFF995D), onTap: () => goMain(2), badge: 'به‌زودی')),
          const SizedBox(width: 10),
          Expanded(child: miniFeature(emoji: '🛒', title: 'فروشگاه‌ها', caption: 'در طرح توسعه', color: const Color(0xFF54BE99), onTap: () => goMain(2), badge: 'به‌زودی')),
        ]),
      ])),
      const SizedBox(height: 8),
      sectionHeader('یه نکته برای زمین 🌱'),
      panel(const Row(children: [
        CircleAvatar(radius: 24, backgroundColor: pale, child: Icon(Icons.tips_and_updates_rounded, color: deepGreen)),
        SizedBox(width: 10),
        Expanded(child: Text('قبل از تحویل، ظرف‌ها رو خالی و بازیافتی‌ها رو خشک نگه دار.',
          style: TextStyle(fontSize: 12.5, height: 1.75, fontWeight: FontWeight.w700))),
      ])),
      const SizedBox(height: 21),
      Align(alignment: Alignment.center, child: tag('نسخه نمایشی • هنوز سرور و پذیرنده واقعی وصل نیست')),
    ]));

  Widget _city() => SingleChildScrollView(padding: const EdgeInsets.fromLTRB(19, 15, 19, 30),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      header('شهر من ✨', caption: 'در آینده، اعتبار بازیافت فقط برای پس‌انداز نیست؛ می‌تونی در شهر خرجش کنی.'),
      Container(width: double.infinity, padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(26), gradient: const LinearGradient(colors: [Color(0xFF177D71), Color(0xFF37B298)])),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('از بازیافت تا خرید 💚', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22)),
          const SizedBox(height: 9),
          const Text('رستوران، کافه، فروشگاه و خدمات شهری؛\nهمه در یک تجربه ساده و دلنشین.',
            style: TextStyle(color: Colors.white, height: 1.8, fontSize: 13)),
          const SizedBox(height: 14),
          tag('طرح آینده • بدون پذیرنده واقعی', color: Colors.white, fg: deepGreen),
        ])),
      const SizedBox(height: 14),
      sectionHeader('دسته‌بندی سرویس‌ها'),
      GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2, mainAxisSpacing: 11, crossAxisSpacing: 11, childAspectRatio: 1.02,
        children: [
          miniFeature(emoji: '🍽️', title: 'رستوران و کافه', caption: 'غذا و دورهمی', color: const Color(0xFFFFA657), onTap: () => _demoMerchantInfo('رستوران و کافه')),
          miniFeature(emoji: '🛒', title: 'سوپرمارکت', caption: 'خرید روزانه', color: green, onTap: () => _demoMerchantInfo('سوپرمارکت')),
          miniFeature(emoji: '🛍️', title: 'فروشگاه‌ها', caption: 'کالا و محصولات', color: const Color(0xFFB78DEF), onTap: () => _demoMerchantInfo('فروشگاه‌ها')),
          miniFeature(emoji: '🧰', title: 'خدمات شهری', caption: 'خدمات نزدیک شما', color: blue, onTap: () => _demoMerchantInfo('خدمات شهری')),
        ]),
      const SizedBox(height: 15),
      panel(const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('قرار نیست فقط بازیافت کنیم!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: deepGreen)),
        SizedBox(height: 10),
        Text('شهر من، ویترین آینده پذیرندگان محلی خواهد بود. تا قبل از عقد قرارداد و فعال شدن تسویه امن، خرید واقعی داخل برنامه فعال نمی‌شود.',
          style: TextStyle(height: 1.85, fontSize: 12.5)),
      ])),
    ]));

  void _demoMerchantInfo(String category) => showModalBottomSheet<void>(context: context, showDragHandle: true,
    backgroundColor: Colors.white, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (context) => SafeArea(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.storefront_rounded, size: 58, color: green),
      const SizedBox(height: 10),
      Text(category, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      const Text('این بخش نمایشی است. پس از قرارداد با پذیرندگان و راه‌اندازی سامانه اعتبار، فروشگاه‌های واقعی و گزینه پرداخت امن در اینجا ظاهر می‌شوند.',
        textAlign: TextAlign.center, style: TextStyle(height: 1.8, fontSize: 13)),
      const SizedBox(height: 17),
      button('متوجه شدم', () => Navigator.pop(context)),
    ]))));

  Widget _materials() => page(Column(children: [header('چه چیزهایی برای بازیافت داری؟', caption: 'می‌تونی هم‌زمان چند نوع ماده رو انتخاب کنی.'),
        GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 1.12, crossAxisSpacing: 12, mainAxisSpacing: 12), itemCount: materialLabels.length, itemBuilder: (context, i) {
          final chosen = materials.contains(i);
          final disabled = i == 4;
          return InkWell(onTap: disabled ? null : () => setState(() { if (chosen) {materials.remove(i);} else {materials.add(i);} }), borderRadius: BorderRadius.circular(20), child: Container(
            padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: chosen ? pale : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: chosen ? green : const Color(0xFFE5E9E6), width: chosen ? 2 : 1)),
            child: Stack(children: [Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(materialIcons[i], size: 52, color: disabled ? Colors.grey.shade400 : materialColors[i]),
              const SizedBox(height: 11), Text(materialLabels[i], textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, color: disabled ? Colors.grey : ink)),
              if (disabled) const Text('به‌زودی', style: TextStyle(fontSize: 10, color: Colors.grey)),
            ]), if (chosen) const Align(alignment: Alignment.topLeft, child: Icon(Icons.check_circle_rounded, color: green, size: 24))]),
          ));
        })
      ]), cta: 'ادامه به انتخاب مقدار', action: materials.isEmpty ? null : () => go('quantity'));

  Widget _quantity() => page(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [header('تقریباً چقدر بازیافتی داری؟', caption: 'نیازی نیست وزن دقیق رو بدونی؛ موقع تحویل وزن‌کشی می‌شه.'),
        ...List.generate(3, (i) => Padding(padding: const EdgeInsets.only(bottom: 13), child: InkWell(onTap: () => setState(() => quantity = i), child: Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: quantity == i ? pale : Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: quantity == i ? green : Colors.black12, width: quantity == i ? 2 : 1)), child: Row(children: [Icon(Icons.shopping_bag_rounded, color: quantity == i ? green : Colors.grey, size: 31), const SizedBox(width: 14), Expanded(child: Text(quantities[i], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))), Icon(quantity == i ? Icons.check_circle : Icons.radio_button_unchecked, color: quantity == i ? green : Colors.grey)]))))),
        const SizedBox(height: 12),
        const Text('توضیحات اختیاری', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        TextField(controller: note, maxLines: 3, decoration: InputDecoration(hintText: 'مثلاً کارتن‌های بزرگ یا بسته‌های شیشه‌ای', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none))),
      ]), cta: 'ادامه به انتخاب نشانی', action: () => go('address'));

  Widget _addressPage() => Column(children: [
        Expanded(child: Stack(children: [
          FlutterMap(
            options: MapOptions(initialCenter: pin, initialZoom: 14.8, onPositionChanged: (camera, hasGesture) {if (hasGesture) pin = camera.center;}),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'ir.bazyaftdemo.bazyaft_mobile'),
              RichAttributionWidget(attributions: [TextSourceAttribution('© OpenStreetMap contributors')]),
            ],
          ),
          const IgnorePointer(child: Center(child: Padding(padding: EdgeInsets.only(bottom: 35), child: Icon(Icons.location_pin, size: 59, color: green, shadows: [Shadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 4))])))),
          Positioned(top: 16, right: 16, left: 16, child: panel(const Row(children: [Icon(Icons.map_outlined, color: green), SizedBox(width: 10), Expanded(child: Text('نقشه را حرکت بده تا نشانگر روی محل خانه قرار بگیرد.', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)))]))),
        ])),
        Container(padding: const EdgeInsets.fromLTRB(18, 14, 18, 10), color: Colors.white, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('نشانی جمع‌آوری', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 9),
          TextField(controller: address, onChanged: (_) => setState(() {}), decoration: InputDecoration(hintText: 'شهر، خیابان، کوچه (الزامی)', prefixIcon: const Icon(Icons.location_on_outlined), filled: true, fillColor: bg, isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none))),
          const SizedBox(height: 8),
          TextField(controller: details, decoration: InputDecoration(hintText: 'پلاک، طبقه و واحد', prefixIcon: const Icon(Icons.home_outlined), filled: true, fillColor: bg, isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none))),
          const SizedBox(height: 5),
          const Text('برای نمایش نقشه اینترنت لازم است. بدون نقشه هم می‌توانی نشانی را دستی وارد کنی.', style: TextStyle(color: Colors.black54, fontSize: 10)),
        ])),
        footer('تأیید این نشانی', address.text.trim().isEmpty ? null : () { savedAddress = address.text.trim(); _persist(); if (editingAddressOnly) {goMain(tab);} else {go('schedule');} }),
      ]);

  Widget _schedule() => page(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [header('چه زمانی برای جمع‌آوری مناسب‌تره؟', caption: 'روزها و ساعت‌ها در این نمونه، نمایشی هستند.'),
        const Text('روز جمع‌آوری', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        const SizedBox(height: 13),
        Row(children: List.generate(4, (i) => Expanded(child: Padding(padding: EdgeInsets.only(left: i == 3 ? 0 : 8), child: InkWell(onTap: i == 0 ? null : () => setState(() => dayIndex = i), child: Container(height: 90, decoration: BoxDecoration(color: dayIndex == i ? green : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: dayIndex == i ? green : Colors.black12)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(dayName(i + 1), textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11.3, color: dayIndex == i ? Colors.white : ink)), const SizedBox(height: 7), Text(i == 0 ? 'تکمیل' : 'موجود', style: TextStyle(color: dayIndex == i ? Colors.white70 : (i == 0 ? Colors.red : green), fontSize: 11))]))))))),
        const SizedBox(height: 26),
        const Text('بازه زمانی', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        const SizedBox(height: 12),
        ...List.generate(timeRanges.length, (i) => Padding(padding: const EdgeInsets.only(bottom: 10), child: InkWell(onTap: () => setState(() => timeIndex = i), child: panel(Row(children: [Icon(timeIndex == i ? Icons.check_circle_rounded : Icons.radio_button_unchecked, color: timeIndex == i ? green : Colors.grey), const SizedBox(width: 15), Text(timeRanges[i], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)), const Spacer(), const Icon(Icons.schedule_rounded, color: Colors.black45)]), color: timeIndex == i ? pale : Colors.white)))),
      ]), cta: 'بررسی و ثبت درخواست', action: () => go('review'));

  Widget _summaryRow(String title, String value, String editScreen, IconData icon) => Padding(padding: const EdgeInsets.only(bottom: 12), child: panel(Row(children: [CircleAvatar(backgroundColor: pale, child: Icon(icon, color: green)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.black54, fontSize: 12)), const SizedBox(height: 4), Text(value, style: const TextStyle(fontWeight: FontWeight.w800))])), TextButton(onPressed: () => go(editScreen), child: const Text('ویرایش', style: TextStyle(color: green, fontWeight: FontWeight.bold)))])));

  Widget _review() => page(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [header('خلاصه درخواست شما', caption: 'قبل از ثبت، اطلاعات رو یک بار بررسی کن.'),
        _summaryRow('نوع بازیافتی', materials.map((i) => materialLabels[i]).join('، '), 'materials', Icons.recycling_rounded),
        _summaryRow('مقدار تقریبی', quantities[quantity], 'quantity', Icons.inventory_rounded),
        _summaryRow('نشانی', address.text, 'address', Icons.location_on_outlined),
        _summaryRow('زمان مراجعه', '${dayName(dayIndex + 1)} • ${timeRanges[timeIndex]}', 'schedule', Icons.calendar_today_rounded),
        const SizedBox(height: 13),
        tag('توجه: این درخواست در نسخه آزمایشی ثبت می‌شود و برای جمع‌آوری واقعی ارسال نمی‌شود.'),
      ]), cta: 'ثبت نهایی درخواست آزمایشی', action: _submit);

  Widget _success() => page(Column(children: [const SizedBox(height: 45),
        Container(width: 128, height: 128, decoration: const BoxDecoration(color: pale, shape: BoxShape.circle), child: const Icon(Icons.check_circle_rounded, color: green, size: 95)),
        const SizedBox(height: 27), const Text('درخواستت با موفقیت ثبت شد!', textAlign: TextAlign.center, style: TextStyle(fontSize: 23, color: deepGreen, fontWeight: FontWeight.w900)),
        const SizedBox(height: 13), const Text('یک قدم دیگه برای شهر پاک‌تر 🌱', textAlign: TextAlign.center, style: TextStyle(fontSize: 15)),
        const SizedBox(height: 28), panel(Row(children: [const Icon(Icons.local_shipping_rounded, color: green, size: 36), const SizedBox(width: 12), Expanded(child: Text('${records.first['day']}، ساعت ${records.first['time']}', style: const TextStyle(fontWeight: FontWeight.w900)))])),
        const SizedBox(height: 18), tag('درخواست نمونه است و خودرو واقعی اعزام نمی‌شود.'),
      ]), cta: 'مشاهده وضعیت درخواست', action: () { recordIndex = 0; go('tracking'); });

  Widget _tracking() {
    if (records.isEmpty) return page(const Center(child: Text('درخواستی موجود نیست')));
    final item = records[recordIndex];
    final status = (item['status'] as int?) ?? 0;
    return page(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [header('وضعیت درخواست', caption: 'پیگیری شبیه‌سازی‌شده برای بررسی تجربه کاربری.'),
      panel(Column(children: [for (var i = 0; i < states.length; i++) Row(children: [Column(children: [Icon(i <= status ? Icons.check_circle_rounded : Icons.radio_button_unchecked, color: i <= status ? green : Colors.grey.shade300, size: 30), if (i != states.length - 1) Container(width: 3, height: 43, color: i < status ? green : Colors.grey.shade200)]), const SizedBox(width: 15), Expanded(child: Padding(padding: const EdgeInsets.only(bottom: 14), child: Text(states[i], style: TextStyle(color: i <= status ? deepGreen : Colors.grey, fontWeight: i <= status ? FontWeight.w900 : FontWeight.normal))))])])),
      const SizedBox(height: 15),
      _summaryRow('زمان مراجعه', '${item['day']} • ${item['time']}', 'main', Icons.schedule),
      const SizedBox(height: 12),
      tag('دکمه زیر فقط مراحل نمایشی را جلو می‌برد. اعزام و پرداخت واقعی انجام نمی‌شود.'),
      const SizedBox(height: 18),
      button('نمایش مرحله بعدی (دمو)', status >= 4 ? null : advanceDemoStatus, icon: Icons.play_arrow_rounded),
      const SizedBox(height: 14),
      button('بازگشت به خانه', () => goMain(0), outline: true, icon: Icons.home_rounded),
    ]));
  }

  Widget _requests() => SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [header('درخواست‌های من', caption: 'درخواست‌های نمونه‌ای که در این دستگاه ثبت کرده‌ای.'),
        if (records.isEmpty) panel(Column(children: [const Icon(Icons.inbox_outlined, color: green, size: 60), const SizedBox(height: 12), const Text('هنوز درخواستی ثبت نکرده‌ای.', style: TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 16), button('ثبت اولین درخواست', startRequest)])),
        ...List.generate(records.length, (i) => Padding(padding: const EdgeInsets.only(bottom: 12), child: InkWell(onTap: () {recordIndex = i; go('tracking');}, child: panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [const Icon(Icons.recycling, color: green), const SizedBox(width: 9), Expanded(child: Text((records[i]['materials'] as List).join('، '), style: const TextStyle(fontWeight: FontWeight.w800))), const Icon(Icons.arrow_back_ios_new, color: green, size: 16)]), const SizedBox(height: 10), Text('${records[i]['day']} • ${records[i]['time']}', style: const TextStyle(color: Colors.black54)), const SizedBox(height: 10), tag(states[(records[i]['status'] as int?) ?? 0])]))))),
      ]));

  Widget _wallet() => SingleChildScrollView(padding: const EdgeInsets.fromLTRB(19, 16, 19, 30),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      header('کیف پول من 💚', caption: 'اعتبار بازیافتت در آینده می‌تونه توی شهر به کارت بیاد.'),
      Container(width: double.infinity, padding: const EdgeInsets.all(23),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(28), gradient: const LinearGradient(
          begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Color(0xFF12956A), Color(0xFF08624E)])),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFFDAFBE5), size: 40),
            const Spacer(), tag('نسخه آزمایشی', color: Colors.white, fg: deepGreen)]),
          const SizedBox(height: 18),
          const Text('اعتبار نمایشی', style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 5),
          Text('${money(wallet)} تومان', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 9),
          const Text('موجودی قابل برداشت یا خرج کردن واقعی نیست.', style: TextStyle(color: Color(0xFFDAFBE5), fontSize: 11.5)),
        ])),
      const SizedBox(height: 15),
      sectionHeader('با اعتبارم چه کار می‌تونم بکنم؟'),
      Row(children: [
        Expanded(child: miniFeature(emoji: '🍽️', title: 'رستوران و کافه', caption: 'در آینده', color: const Color(0xFFFFAB71), onTap: () => goMain(2))),
        const SizedBox(width: 11),
        Expanded(child: miniFeature(emoji: '🛍️', title: 'خرید از فروشگاه', caption: 'در آینده', color: const Color(0xFF9DCBD4), onTap: () => goMain(2))),
      ]),
      const SizedBox(height: 16),
      button('دیدن خدمات آینده شهر من', () => goMain(2), icon: Icons.storefront_rounded),
      const SizedBox(height: 17),
      sectionHeader('تراکنش‌های نمایشی'),
      if (!records.any((r) => (r['status'] as int?) == 4))
        panel(const Row(children: [Icon(Icons.receipt_long_rounded, color: green), SizedBox(width: 10),
          Expanded(child: Text('هنوز اعتبار آزمایشی از درخواست‌ها ثبت نشده.', style: TextStyle(fontSize: 12.5)))])),
      ...records.where((r) => (r['status'] as int?) == 4).map((r) => Padding(padding: const EdgeInsets.only(bottom: 10),
        child: panel(const ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.add_circle_outline, color: green),
          title: Text('پاداش جمع‌آوری آزمایشی'), trailing: Text('۱۲٬۵۰۰ +', style: TextStyle(color: green, fontWeight: FontWeight.w900)))))),
    ]));

  Widget _profile() => SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
      const SizedBox(height: 16), const CircleAvatar(radius: 37, backgroundColor: pale, child: Icon(Icons.person_rounded, color: deepGreen, size: 40)),
      const SizedBox(height: 12), const Text('حساب آزمایشی', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)), const SizedBox(height: 25),
      panel(Column(children: [
        ListTile(leading: const Icon(Icons.location_on_outlined, color: green), title: const Text('نشانی من'), subtitle: Text(savedAddress.isEmpty ? 'هنوز نشانی ثبت نشده' : savedAddress, maxLines: 1, overflow: TextOverflow.ellipsis), onTap: editSavedAddress),
        const Divider(height: 8),
        ListTile(leading: const Icon(Icons.history_rounded, color: green), title: const Text('سوابق جمع‌آوری'), trailing: const Icon(Icons.chevron_left), onTap: () => goMain(1)),
        const Divider(height: 8),
        ListTile(leading: const Icon(Icons.wallet_rounded, color: green), title: const Text('کیف پول'), trailing: const Icon(Icons.chevron_left), onTap: () => goMain(3)),
        const Divider(height: 8),
        ListTile(leading: const Icon(Icons.cloud_sync_rounded, color: green), title: const Text('آزمایش اتصال سرور و مانیتورینگ'),
          subtitle: const Text('سامانه مشترک شهروند و مدیر • پایلوت ۰.۴'),
          trailing: const Icon(Icons.chevron_left), onTap: () => go('pilot')),
        const Divider(height: 8),
        const ListTile(leading: Icon(Icons.support_agent_rounded, color: green), title: Text('پشتیبانی'), subtitle: Text('در نسخه آزمایشی فعال نیست')),
      ])),
      const SizedBox(height: 19), tag('نسخه ۰.۴ • سرور فقط در صورت پیکربندی مستقل فعال است'),
      const SizedBox(height: 20),
      button('بازگشت به شروع', () => go('welcome'), outline: true, icon: Icons.logout_rounded),
    ]));

  Widget _mainPage() => Column(children: [
    Expanded(child: IndexedStack(index: tab, children: [_home(), _requests(), _city(), _wallet()])),
    Container(
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFE6EFE9))),
        boxShadow: [BoxShadow(color: Color(0x081A6C4C), blurRadius: 16, offset: Offset(0, -6))]),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 5),
      child: Row(children: [
        _navButton(Icons.home_rounded, 'خانه', 0),
        _navButton(Icons.receipt_long_rounded, 'درخواست‌ها', 1),
        _navButton(Icons.storefront_rounded, 'شهر من', 2),
        _navButton(Icons.account_balance_wallet_rounded, 'کیف پول', 3),
      ]),
    ),
  ]);

  Widget _navButton(IconData icon, String label, int index) {
    final active = tab == index;
    return Expanded(child: InkWell(onTap: () => setState(() => tab = index),
      borderRadius: BorderRadius.circular(18), child: Padding(padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedContainer(duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 5),
            decoration: BoxDecoration(color: active ? pale : Colors.transparent, borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: active ? green : const Color(0xFF8A9D93), size: 23)),
          const SizedBox(height: 2),
          Text(label, maxLines: 1, style: TextStyle(fontSize: 10.5,
            fontWeight: active ? FontWeight.w900 : FontWeight.w600,
            color: active ? green : const Color(0xFF8A9D93))),
        ]))));
  }

  @override
  Widget build(BuildContext context) {
    if (screen == 'welcome') return Scaffold(body: _welcome());
    const names = {'login':'ورود', 'materials':'نوع بازیافتی','quantity':'مقدار بازیافتی','address':'نشانی جمع‌آوری','schedule':'انتخاب زمان','review':'تأیید نهایی','success':'ثبت درخواست','tracking':'پیگیری درخواست','profile':'حساب من','pilot':'پایلوت سرور'};
    final child = switch (screen) {
      'login' => _login(),
      'materials' => _materials(),
      'quantity' => _quantity(),
      'address' => _addressPage(),
      'schedule' => _schedule(),
      'review' => _review(),
      'success' => _success(),
      'tracking' => _tracking(),
      'profile' => _profile(),
      'pilot' => const ServerPilotPanel(),
      _ => _mainPage(),
    };
    return PopScope(canPop: screen == 'main', onPopInvokedWithResult: (didPop, result) { if (!didPop) back(); }, child: Scaffold(
      appBar: screen == 'main' ? null : AppBar(title: Text(names[screen] ?? ''), leading: IconButton(icon: const Icon(Icons.arrow_forward_rounded), onPressed: back)),
      body: SafeArea(child: child),
    ));
  }
}


// --- Server pilot: deliberately separate from the current local demo flow. ---
// The public mobile app NEVER holds server secret/service-role keys.
class ServerPilotPanel extends StatefulWidget {
  const ServerPilotPanel({super.key});
  @override
  State<ServerPilotPanel> createState() => _ServerPilotPanelState();
}

class _ServerPilotPanelState extends State<ServerPilotPanel> {
  final email = TextEditingController();
  final password = TextEditingController();
  final location = TextEditingController();
  String material = 'plastic';
  String bags = 'one';
  bool busy = false;
  bool registeredManager = false;
  String? cityId;
  String? cityName;
  String? issue;
  bool showLogin = true;

  SupabaseClient get client => Supabase.instance.client;
  User? get signedIn => serverEnabled ? client.auth.currentUser : null;

  @override
  void initState() {
    super.initState();
    if (serverEnabled && signedIn != null) {
      showLogin = false;
      _loadUserState();
    }
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    location.dispose();
    super.dispose();
  }

  Future<void> _loadUserState() async {
    try {
      final cities = await client.from('recycling_cities').select('id,name').eq('active',true).limit(1);
      if (!mounted) return;
      if (cities.isEmpty) {
        setState(() => issue = 'هیچ شهر فعالی در سرور تعریف نشده است.');
        return;
      }
      final role = await client.from('recycling_staff').select('role').eq('user_id',signedIn!.id).eq('active',true).maybeSingle();
      if (!mounted) return;
      setState(() {
        cityId = cities.first['id'] as String;
        cityName = cities.first['name'] as String;
        registeredManager = role != null && (role['role'] == 'manager' || role['role'] == 'dispatcher');
        issue = null;
      });
    } catch (e) {
      if (mounted) setState(() => issue = 'خطای ارتباط با سرور: $e');
    }
  }

  Future<void> _authenticate({required bool createAccount}) async {
    if (email.text.trim().isEmpty || password.text.isEmpty) {
      setState(() => issue = 'ایمیل و رمز عبور را وارد کن.');
      return;
    }
    setState(() { busy = true; issue = null; });
    try {
      if (createAccount) {
        final response = await client.auth.signUp(email: email.text.trim(), password: password.text);
        if (!mounted) return;
        if (response.session == null) {
          setState(() => issue = 'حساب ایجاد شد؛ اگر تأیید ایمیل فعال است، ایمیل را تأیید کن و سپس وارد شو.');
          return;
        }
      } else {
        await client.auth.signInWithPassword(email: email.text.trim(), password: password.text);
      }
      if (!mounted) return;
      setState(() => showLogin = false);
      await _loadUserState();
    } catch (e) {
      if (mounted) setState(() => issue = 'ورود انجام نشد: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String _uuid4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final h = bytes.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0,8)}-${h.substring(8,12)}-${h.substring(12,16)}-${h.substring(16,20)}-${h.substring(20)}';
  }

  Future<void> _submitLive() async {
    if (cityId == null || location.text.trim().isEmpty) {
      setState(() => issue = 'نشانی یا شهر فعال مشخص نشده است.');
      return;
    }
    setState(() { busy = true; issue = null; });
    try {
      await client.rpc('recycling_submit_pickup', params: {
        'p_city_id': cityId,
        'p_address': location.text.trim(),
        'p_title': 'خانه',
        'p_details': '',
        'p_materials': [material],
        'p_amount': bags,
        'p_note': 'ثبت از نسخه آزمایشی ۰.۴',
        'p_idempotency_key': _uuid4(),
      });
      if (mounted) {
        location.clear();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('درخواست روی سرور ثبت شد.')));
      }
    } catch (e) {
      if (mounted) setState(() => issue = 'ثبت روی سرور انجام نشد: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  static const statusTitles = {
    'submitted': 'ثبت شد', 'approved': 'تأیید شد', 'scheduled': 'زمان‌بندی شد',
    'assigned': 'به راننده واگذار شد', 'en_route': 'مأمور در مسیر است',
    'collected': 'جمع‌آوری شد', 'weighed': 'وزن‌کشی شد',
    'credited': 'اعتبار تأیید شد', 'cancelled': 'لغو شد',
  };

  Future<void> _advanceStatus(String id, String status) async {
    const following = {'submitted':'approved'}; // بعد از تأیید، مراحل نیازمند زمان‌بندی و راننده واقعی هستند.
    final next = following[status];
    if (next == null) return;
    setState(() { busy = true; issue = null; });
    try {
      await client.rpc('recycling_update_pickup_status', params: {
        'p_pickup_id': id, 'p_new_status': next,
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('وضعیت به «${statusTitles[next]}» تغییر کرد.')));
    } catch (e) {
      if (mounted) setState(() => issue = 'امکان تغییر وضعیت وجود ندارد: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget _card(Widget child) => Container(
    margin: const EdgeInsets.only(bottom: 14), padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFFE5ECE7))), child: child);

  @override
  Widget build(BuildContext context) {
    if (!serverEnabled) {
      return ListView(padding: const EdgeInsets.all(20), children: [
        _card(const Column(children: [Icon(Icons.cloud_off_rounded, size: 64, color: green),
          SizedBox(height: 12), Text('ارتباط با سرور هنوز پیکربندی نشده',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          SizedBox(height: 9), Text('این قسمت آماده اتصال به پروژه مستقل بازیافت است. داده‌های برنامه فعلاً فقط نمایشی و محلی‌اند.',
            textAlign: TextAlign.center, style: TextStyle(height: 1.8))])),
        const Text('برای فعال‌سازی سرور، SQL بسته را روی پروژه جدید بازیافت اجرا کن و آدرس پروژه و Publishable Key را در GitHub Actions Variables قرار بده. هرگز کلید Secret یا Service Role را داخل اپ قرار نده.',
          style: TextStyle(height: 1.9, color: deepGreen)),
      ]);
    }
    if (showLogin || signedIn == null) {
      return ListView(padding: const EdgeInsets.all(20), children: [
        _card(Column(children: [
          const Icon(Icons.verified_user_rounded, size: 58, color: green),
          const SizedBox(height: 12), const Text('ورود به پایلوت سرور', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8), const Text('ورود آزمایشی با ایمیل و رمز عبور؛ پیامک هنوز فعال نیست.', textAlign: TextAlign.center),
          const SizedBox(height: 18),
          TextField(controller: email, keyboardType: TextInputType.emailAddress,
            textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'ایمیل', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: password, obscureText: true, textDirection: TextDirection.ltr,
            decoration: const InputDecoration(labelText: 'رمز عبور', border: OutlineInputBorder())),
          const SizedBox(height: 14),
          FilledButton(onPressed: busy ? null : () => _authenticate(createAccount:false), child: const Text('ورود به سرور')),
          TextButton(onPressed: busy ? null : () => _authenticate(createAccount:true), child: const Text('ساخت حساب شهروند آزمایشی')),
        ])),
        if (issue != null) _card(Text(issue!, style: const TextStyle(color: Colors.deepOrange))),
      ]);
    }
    return ListView(padding: const EdgeInsets.all(19), children: [
      _card(Row(children: [const Icon(Icons.cloud_done_rounded, size: 28, color: green),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('سامانه مرکزی متصل است', style: TextStyle(fontWeight: FontWeight.w900)),
          Text('${cityName ?? 'شهر فعال'} • ${registeredManager ? 'مدیر / پشتیبانی' : 'شهروند'}', style: const TextStyle(fontSize: 12)),
        ])),
        TextButton(onPressed: busy ? null : () async {
          await client.auth.signOut(); if (mounted) setState(() {showLogin=true; registeredManager=false;});
        }, child: const Text('خروج')),
      ])),
      if (!registeredManager) _card(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('ثبت درخواست روی سرور', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        TextField(controller: location, maxLines: 2,
          decoration: const InputDecoration(labelText: 'نشانی جمع‌آوری', border: OutlineInputBorder())),
        const SizedBox(height: 13),
        DropdownButtonFormField<String>(initialValue: material, decoration: const InputDecoration(labelText: 'نوع بازیافتی', border: OutlineInputBorder()),
          items: const [
            DropdownMenuItem(value:'plastic', child:Text('پلاستیک')),
            DropdownMenuItem(value:'paper',child:Text('کاغذ و مقوا')),
            DropdownMenuItem(value:'metal',child:Text('فلز')),
            DropdownMenuItem(value:'glass',child:Text('شیشه')),
            DropdownMenuItem(value:'other',child:Text('سایر')),
          ], onChanged:(v) {if (v != null) setState(() => material=v);}),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(initialValue: bags, decoration: const InputDecoration(labelText: 'مقدار تقریبی', border: OutlineInputBorder()),
          items: const [
            DropdownMenuItem(value:'one',child:Text('یک کیسه')),
            DropdownMenuItem(value:'two_or_three',child:Text('دو تا سه کیسه')),
            DropdownMenuItem(value:'more_than_three',child:Text('بیشتر از سه کیسه')),
          ], onChanged: (v) {if (v != null) setState(() => bags=v);}),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed:busy ? null : _submitLive, icon:const Icon(Icons.send_rounded),label:const Text('ثبت درخواست واقعی روی سرور')),
      ])),
      const Padding(padding: EdgeInsets.only(bottom: 12),child:Text('پیگیری زنده درخواست‌ها', style:TextStyle(fontSize:19,fontWeight:FontWeight.w900))),
      const Text('شهروند فقط درخواست‌های خودش را می‌بیند. مدیر مجاز درخواست‌های همان شهر را می‌بیند. در این پایلوت فقط تأیید اولیه روی سرور فعال است؛ زمان‌بندی، اعزام و اعتبار نیازمند سامانه عملیاتی‌اند.',
        style: TextStyle(fontSize:12,height:1.6,color:Colors.black54)),
      const SizedBox(height: 12),
      if (issue != null) _card(Text(issue!,style:const TextStyle(color:Colors.deepOrange))),
      if (cityId == null) _card(const Text('در حال خواندن شهر فعال و دسترسی حساب...')),
      if (cityId != null)
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: client.from('recycling_pickups').stream(primaryKey:['id']).eq('city_id',cityId!).order('created_at',ascending:false),
          builder:(context,snapshot) {
            if (snapshot.hasError) return _card(Text('خطا در دریافت وضعیت: ${snapshot.error}'));
            if (!snapshot.hasData) return const Center(child:Padding(padding:EdgeInsets.all(25), child:CircularProgressIndicator()));
            final rows=snapshot.data!;
            if (rows.isEmpty) return _card(const Text('هنوز درخواستی روی سرور ثبت نشده است.'));
            final pending = rows.where((r) => r['status'] == 'submitted').length;
            return Column(children: [
              if (registeredManager) _card(Row(children: [
                const Icon(Icons.monitor_heart_rounded, color: green),
                const SizedBox(width: 10),
                Expanded(child: Text('کل درخواست‌ها: ${rows.length}   |   منتظر تأیید: $pending',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
              ])),
              ...rows.map((row) {
              final status=(row['status'] ?? 'submitted').toString();
              final key=(row['id'] ?? '').toString();
              final label=statusTitles[status] ?? status;
              const next={'submitted':'approved'};
              return _card(Column(crossAxisAlignment:CrossAxisAlignment.stretch, children:[
                Row(children:[const Icon(Icons.recycling_rounded,color:green),const SizedBox(width:9),
                  Expanded(child:Text('درخواست ${key.length>8 ? key.substring(0,8) : key}',style:const TextStyle(fontWeight:FontWeight.w900))),
                  Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:5),
                    decoration:BoxDecoration(color:pale,borderRadius:BorderRadius.circular(12)),
                    child:Text(label,style:const TextStyle(color:deepGreen,fontSize:12,fontWeight:FontWeight.bold)))]),
                const SizedBox(height:9),Text('ثبت: ${row['created_at'] ?? ''}',style:const TextStyle(fontSize:11,color:Colors.black54)),
                const SizedBox(height:10),
                ...['submitted','approved','scheduled','assigned','en_route','collected','weighed','credited'].asMap().entries.map((stage) {
                  const stages = ['submitted','approved','scheduled','assigned','en_route','collected','weighed','credited'];
                  final currentIndex = stages.indexOf(status);
                  final done = currentIndex >= stage.key;
                  return Padding(padding: const EdgeInsets.symmetric(vertical:3),child:Row(children:[
                    Icon(done ? Icons.check_circle_rounded : Icons.circle_outlined,
                      size:16,color:done ? green:Colors.grey.shade300),
                    const SizedBox(width:8),
                    Text(statusTitles[stage.value] ?? stage.value,style: TextStyle(fontSize:11,
                      color:done ? deepGreen:Colors.black45,
                      fontWeight:done ? FontWeight.w800:FontWeight.normal)),
                  ]));
                }),
                if (registeredManager && next[status] != null) ...[
                  const SizedBox(height:11),
                  OutlinedButton(onPressed:busy ? null:()=>_advanceStatus(key,status),
                    child:Text('ثبت مرحله بعد: ${statusTitles[next[status]]}')),
                ],
              ]));
            }).toList(),
            ]);
          },
        ),
    ]);
  }
}
