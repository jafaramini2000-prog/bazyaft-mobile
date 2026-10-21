import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

const green = Color(0xFF078B65);
const deepGreen = Color(0xFF145541);
const pale = Color(0xFFE4F5EC);
const bg = Color(0xFFF7F9F8);
const ink = Color(0xFF1D2924);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
          useMaterial3: true,
          scaffoldBackgroundColor: bg,
          colorScheme: ColorScheme.fromSeed(seedColor: green, primary: green, surface: Colors.white),
          appBarTheme: const AppBarTheme(backgroundColor: bg, centerTitle: true, elevation: 0, foregroundColor: ink),
          textTheme: const TextTheme(
            headlineMedium: TextStyle(fontSize: 24, color: ink, fontWeight: FontWeight.w900),
            titleLarge: TextStyle(fontSize: 19, color: ink, fontWeight: FontWeight.w800),
            titleMedium: TextStyle(fontSize: 15, color: ink, fontWeight: FontWeight.w700),
            bodyMedium: TextStyle(fontSize: 13.5, color: ink),
          ),
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
    const prev = {'login':'welcome','materials':'main','quantity':'materials','address':'quantity','schedule':'address','review':'schedule','success':'main','tracking':'main'};
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

  Widget panel(Widget child, {EdgeInsets padding = const EdgeInsets.all(16), Color color = Colors.white}) =>
      Container(padding: padding, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(22), boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 18, offset: Offset(0, 6))]), child: child);

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
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Color(0xFFE0F7E8), Colors.white, Color(0xFFB3ECD0)])),
        child: SafeArea(child: Padding(padding: const EdgeInsets.all(23), child: Column(children: [
          const Spacer(),
          Container(width: 118, height: 118, decoration: const BoxDecoration(color: green, shape: BoxShape.circle), child: const Icon(Icons.recycling_rounded, size: 74, color: Colors.white)),
          const SizedBox(height: 24),
          const Text('بازیافت من', style: TextStyle(fontSize: 31, fontWeight: FontWeight.w900, color: deepGreen)),
          const SizedBox(height: 15),
          const Text('تفکیک از مبدأ، آینده‌ای پاک‌تر', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: ink)),
          const SizedBox(height: 12),
          const Text('ما بازیافتی‌ها را از درِ خانه جمع می‌کنیم.\nساده، سریع و دوستدار زمین.', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, height: 1.8, color: deepGreen)),
          const SizedBox(height: 20),
          Expanded(child: Center(child: Container(width: double.infinity, constraints: const BoxConstraints(maxWidth: 360), padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.77), borderRadius: BorderRadius.circular(28)), child: const Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.local_shipping_rounded, color: green, size: 125), SizedBox(height: 8), Text('خودروی بازیافت، در مسیر خانه شما', style: TextStyle(fontWeight: FontWeight.w800, color: deepGreen))])))),
          tag('نسخه آزمایشی • هنوز به ناوگان واقعی متصل نیست'),
          const SizedBox(height: 20),
          button('شروع کنیم', () => go('login'), icon: Icons.arrow_back_rounded),
          const SizedBox(height: 12),
          TextButton(onPressed: () async { await storage?.setBool('introSeen', true); goMain(0); }, child: const Text('ورود آزمایشی بدون ثبت‌نام', style: TextStyle(color: green, fontWeight: FontWeight.bold))),
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

  Widget _home() => SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 26), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('سلام، دوست خوب زمین 👋', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)), SizedBox(height: 6), Text('امروز هم یک قدم برای شهر پاک‌تر', style: TextStyle(fontSize: 12, color: Colors.black54))]),
          CircleAvatar(radius: 23, backgroundColor: pale, child: IconButton(onPressed: () => goMain(3), icon: const Icon(Icons.person_outline_rounded, color: deepGreen))),
        ]),
        const SizedBox(height: 18),
        InkWell(onTap: editSavedAddress, child: Row(children: [const Icon(Icons.location_on_rounded, color: green, size: 20), const SizedBox(width: 5), Expanded(child: Text(savedAddress.isEmpty ? 'افزودن نشانی جمع‌آوری' : savedAddress, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold))), const Icon(Icons.keyboard_arrow_down_rounded)])),
        const SizedBox(height: 20),
        Container(width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF008F62), Color(0xFF41B98B)], begin: Alignment.topRight, end: Alignment.bottomLeft), borderRadius: BorderRadius.circular(26)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.recycling_rounded, size: 70, color: Colors.white), Spacer(), Icon(Icons.local_shipping_rounded, size: 76, color: Color(0xFFCAF5E0))]),
          const SizedBox(height: 14),
          const Text('بازیافتی داری؟', style: TextStyle(fontSize: 26, color: Colors.white, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text('ما برای جمع‌آوریش میایم درِ خونه!', style: TextStyle(color: Colors.white, fontSize: 14)),
          const SizedBox(height: 21),
          SizedBox(width: double.infinity, height: 52, child: ElevatedButton(onPressed: startRequest, style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: deepGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: const Text('ثبت درخواست جمع‌آوری ←', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)))),
        ])),
        const SizedBox(height: 17),
        if (records.isNotEmpty) ...[
          panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [const Icon(Icons.local_shipping_outlined, color: green), const SizedBox(width: 8), const Text('آخرین درخواست', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)), const Spacer(), tag('آزمایشی')]),
            const SizedBox(height: 9),
            Text(states[(records.first['status'] as int?) ?? 0], style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('${records.first['day']} • ${records.first['time']}', style: const TextStyle(color: Colors.black54)),
            Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: () {recordIndex=0; go('tracking');}, child: const Text('پیگیری درخواست ←', style: TextStyle(color: green, fontWeight: FontWeight.bold))))
          ])), const SizedBox(height: 15),
        ],
        Row(children: [
          Expanded(child: panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFFECA631), size: 27), const SizedBox(height: 10), const Text('کیف پول نمایشی', style: TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 5), Text('${money(wallet)} تومان', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18))]))),
          const SizedBox(width: 12),
          Expanded(child: panel(const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.eco_rounded, color: green, size: 27), SizedBox(height: 10), Text('زمین پاک‌تر', style: TextStyle(fontWeight: FontWeight.w700)), SizedBox(height: 5), Text('از خانه ما شروع می‌شود', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))]))),
        ]),
        const SizedBox(height: 20),
        const Text('با هم بهتر بازیافت کنیم', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
        const SizedBox(height: 12),
        panel(const ListTile(contentPadding: EdgeInsets.zero, leading: CircleAvatar(backgroundColor: pale, child: Icon(Icons.lightbulb_outline_rounded, color: deepGreen)), title: Text('تفکیک درست از خانه آغاز می‌شود', style: TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('بازیافتی‌های تمیز و خشک را جدا نگه دارید.'))),
        const SizedBox(height: 18),
        Align(alignment: Alignment.center, child: tag('نسخه نمونه بومی • داده‌ها و پرداخت‌ها آزمایشی‌اند')),
      ]));

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

  Widget _wallet() => SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [header('کیف پول', caption: 'اعتبار و تراکنش‌ها در نسخه فعلی فقط آزمایشی هستند.'),
      Container(width: double.infinity, padding: const EdgeInsets.all(24), decoration: BoxDecoration(gradient: const LinearGradient(colors: [green, deepGreen]), borderRadius: BorderRadius.circular(26)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 45), const SizedBox(height: 18), const Text('موجودی نمایشی', style: TextStyle(color: Colors.white70)), const SizedBox(height: 7), Text('${money(wallet)} تومان', style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 28))])),
      const SizedBox(height: 20),
      panel(const ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.info_rounded, color: green), title: Text('کیف پول دمو است', style: TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('هیچ مبلغ واقعی واریز یا برداشت نمی‌شود. اعتبار فقط با پیشبرد شبیه‌سازی درخواست افزایش می‌یابد.'))),
      const SizedBox(height: 22),
      const Text('تراکنش‌های نمایشی', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
      const SizedBox(height: 10),
      ...records.where((r) => (r['status'] as int?) == 4).map((r) => Padding(padding: const EdgeInsets.only(bottom: 10), child: panel(const ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.add_circle_outline, color: green), title: Text('جمع‌آوری آزمایشی تکمیل شد'), trailing: Text('۱۲٬۵۰۰ +', style: TextStyle(color: green, fontWeight: FontWeight.w900)))))),
    ]));

  Widget _profile() => SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
      const SizedBox(height: 16), const CircleAvatar(radius: 37, backgroundColor: pale, child: Icon(Icons.person_rounded, color: deepGreen, size: 40)),
      const SizedBox(height: 12), const Text('حساب آزمایشی', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)), const SizedBox(height: 25),
      panel(Column(children: [
        ListTile(leading: const Icon(Icons.location_on_outlined, color: green), title: const Text('نشانی من'), subtitle: Text(savedAddress.isEmpty ? 'هنوز نشانی ثبت نشده' : savedAddress, maxLines: 1, overflow: TextOverflow.ellipsis), onTap: editSavedAddress),
        const Divider(height: 8),
        ListTile(leading: const Icon(Icons.history_rounded, color: green), title: const Text('سوابق جمع‌آوری'), trailing: const Icon(Icons.chevron_left), onTap: () => goMain(1)),
        const Divider(height: 8),
        ListTile(leading: const Icon(Icons.wallet_rounded, color: green), title: const Text('کیف پول'), trailing: const Icon(Icons.chevron_left), onTap: () => goMain(2)),
        const Divider(height: 8),
        const ListTile(leading: Icon(Icons.support_agent_rounded, color: green), title: Text('پشتیبانی'), subtitle: Text('در نسخه آزمایشی فعال نیست')),
      ])),
      const SizedBox(height: 19), tag('نسخه آزمایشی موبایل ۰.۲ • بدون سرور واقعی'),
      const SizedBox(height: 20),
      button('بازگشت به شروع', () => go('welcome'), outline: true, icon: Icons.logout_rounded),
    ]));

  Widget _mainPage() => Column(children: [Expanded(child: IndexedStack(index: tab, children: [_home(), _requests(), _wallet(), _profile()])),
        NavigationBar(backgroundColor: Colors.white, selectedIndex: tab, onDestinationSelected: (i) => setState(() => tab = i), indicatorColor: pale, destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded, color: green), label: 'خانه'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long_rounded, color: green), label: 'درخواست‌ها'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet_rounded, color: green), label: 'کیف پول'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded, color: green), label: 'حساب من'),
        ])]);

  @override
  Widget build(BuildContext context) {
    if (screen == 'welcome') return Scaffold(body: _welcome());
    const names = {'login':'ورود', 'materials':'نوع بازیافتی','quantity':'مقدار بازیافتی','address':'نشانی جمع‌آوری','schedule':'انتخاب زمان','review':'تأیید نهایی','success':'ثبت درخواست','tracking':'پیگیری درخواست'};
    final child = switch (screen) {
      'login' => _login(),
      'materials' => _materials(),
      'quantity' => _quantity(),
      'address' => _addressPage(),
      'schedule' => _schedule(),
      'review' => _review(),
      'success' => _success(),
      'tracking' => _tracking(),
      _ => _mainPage(),
    };
    return PopScope(canPop: screen == 'main', onPopInvokedWithResult: (didPop, result) { if (!didPop) back(); }, child: Scaffold(
      appBar: screen == 'main' ? null : AppBar(title: Text(names[screen] ?? ''), leading: IconButton(icon: const Icon(Icons.arrow_forward_rounded), onPressed: back)),
      body: SafeArea(child: child),
    ));
  }
}
