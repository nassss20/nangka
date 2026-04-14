import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

const String apiUrl = 'https://nangka-api.onrender.com/api'; 

// ==========================================
// 1. DATA MODELS
// ==========================================
class Location {
  final int id; final String name; final double defaultPrice;
  Location({required this.id, required this.name, required this.defaultPrice});
  factory Location.fromJson(Map<String, dynamic> json) => Location(id: json['id'], name: json['name'], defaultPrice: double.tryParse(json['default_price'].toString()) ?? 0.0);
}

class InventoryItem {
  final int id; final DateTime date; final String locationName; final double kg; final int totalPacks;
  final int displayPacks; final int rejectedAmount; final String rejectedUnit; final int balancePacks;
  InventoryItem({required this.id, required this.date, required this.locationName, required this.kg, required this.totalPacks, required this.displayPacks, required this.rejectedAmount, required this.rejectedUnit, required this.balancePacks});
  factory InventoryItem.fromJson(Map<String, dynamic> json) => InventoryItem(id: json['id'], date: DateTime.parse(json['date']), locationName: json['location_name'] ?? '-', kg: double.tryParse((json['kg'] ?? 0).toString()) ?? 0.0, totalPacks: int.tryParse(json['total_packs']?.toString() ?? '0') ?? 0, displayPacks: int.tryParse(json['display_packs']?.toString() ?? '0') ?? 0, rejectedAmount: int.tryParse(json['rejected_amount']?.toString() ?? '0') ?? 0, rejectedUnit: json['rejected_unit'] ?? 'Packs', balancePacks: int.tryParse(json['balance_packs']?.toString() ?? '0') ?? 0);
}

class SaleItem {
  final int id; final DateTime date; final String? customLocation; final int productionPacks; final int actualPacks; final double price; final Location? location;
  SaleItem({required this.id, required this.date, this.customLocation, required this.productionPacks, required this.actualPacks, required this.price, this.location});
  factory SaleItem.fromJson(Map<String, dynamic> json) => SaleItem(id: json['id'], date: DateTime.parse(json['date']), customLocation: json['custom_location'], productionPacks: json['production_packs'] ?? 0, actualPacks: json['actual_packs'] ?? 0, price: double.tryParse(json['price'].toString()) ?? 0.0, location: json['location'] != null ? Location.fromJson(json['location']) : null);
  String get locationName => location?.name ?? customLocation ?? '-';
  double get productionRM => productionPacks * price;
  double get actualRM => actualPacks * price;
  double get differenceRM => actualRM - productionRM;
}

class PurchaseItem {
  final int id; final DateTime date; final String itemName; final int quantity; final String unit; final double price;
  PurchaseItem({required this.id, required this.date, required this.itemName, required this.quantity, required this.unit, required this.price});
  factory PurchaseItem.fromJson(Map<String, dynamic> json) => PurchaseItem(id: json['id'], date: DateTime.parse(json['date']), itemName: json['item_name'], quantity: json['quantity'] ?? 1, unit: json['unit'] ?? '-', price: double.tryParse(json['price'].toString()) ?? 0.0);
}

class ClosingItem {
  final int id; final DateTime date; final String itemName; final int? pcs; final double? kg; final int? packs; final double price;
  ClosingItem({required this.id, required this.date, required this.itemName, this.pcs, this.kg, this.packs, required this.price});
  factory ClosingItem.fromJson(Map<String, dynamic> json) => ClosingItem(id: json['id'], date: DateTime.parse(json['date']), itemName: json['item_name'], pcs: json['pcs'], kg: json['kg'] != null ? double.tryParse(json['kg'].toString()) : null, packs: json['packs'], price: double.tryParse(json['price'].toString()) ?? 0.0);
}

class Employee {
  final int id; final String name; final String? position;
  Employee({required this.id, required this.name, this.position});
  factory Employee.fromJson(Map<String, dynamic> json) => Employee(id: json['id'], name: json['name'], position: json['position']);
}

class SalaryItem {
  final int id; final DateTime date; final double amount; final Employee? employee;
  SalaryItem({required this.id, required this.date, required this.amount, this.employee});
  factory SalaryItem.fromJson(Map<String, dynamic> json) => SalaryItem(id: json['id'], date: DateTime.parse(json['date']), amount: double.tryParse(json['amount'].toString()) ?? 0.0, employee: json['employee'] != null ? Employee.fromJson(json['employee']) : null);
}

class ExpenseItem {
  final int id; final DateTime date; final String itemName; final int quantity; final double price;
  ExpenseItem({required this.id, required this.date, required this.itemName, required this.quantity, required this.price});
  factory ExpenseItem.fromJson(Map<String, dynamic> json) => ExpenseItem(id: json['id'], date: DateTime.parse(json['date']), itemName: json['item_name'], quantity: json['quantity'] ?? 1, price: double.tryParse(json['price'].toString()) ?? 0.0);
}

// ==========================================
// 2. STATE MANAGEMENT & SESSION
// ==========================================
class AppState extends ChangeNotifier {
  DateTime summaryStartDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime summaryEndDate = DateTime.now();
  String summaryFilterType = 'Range';
  String summaryDisplayType = 'Stock Entry';

  void updateSummaryFilter(String type, DateTime start, DateTime end) {
    summaryFilterType = type; summaryStartDate = start; summaryEndDate = end; notifyListeners();
  }
  void updateSummaryDisplayType(String type) {
    summaryDisplayType = type; notifyListeners();
  }
}

class SessionWrapper extends StatefulWidget {
  final Widget child;
  const SessionWrapper({Key? key, required this.child}) : super(key: key);
  @override State<SessionWrapper> createState() => _SessionWrapperState();
}

class _SessionWrapperState extends State<SessionWrapper> {
  Timer? _inactivityTimer; Timer? _countdownTimer;

  @override void initState() { super.initState(); _resetInactivityTimer(); }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel(); _countdownTimer?.cancel();
    _inactivityTimer = Timer(const Duration(minutes: 30), _showTimeoutWarning);
  }

  void _showTimeoutWarning() {
    int countdown = 7;
    showDialog(
      context: context, barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            _countdownTimer ??= Timer.periodic(const Duration(seconds: 1), (timer) {
              if (countdown > 0) setState(() => countdown--);
              else { timer.cancel(); Navigator.of(dialogContext).pop(); _performLogout(); }
            });
            return AlertDialog(
              title: const Text('Session Expiring'),
              content: Text('You have been inactive. Automatically logging out in $countdown seconds.'),
              actions: [
                TextButton(onPressed: () { _countdownTimer?.cancel(); Navigator.of(dialogContext).pop(); _performLogout(); }, child: const Text('Log Out', style: TextStyle(color: Colors.red))),
                ElevatedButton(onPressed: () { _countdownTimer?.cancel(); Navigator.of(dialogContext).pop(); _resetInactivityTimer(); }, child: const Text('Keep Logged In')),
              ],
            );
          },
        );
      },
    );
  }

  void _performLogout() async {
    final prefs = await SharedPreferences.getInstance(); await prefs.remove('isLoggedIn');
    if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginPage()), (route) => false);
  }

  @override void dispose() { _inactivityTimer?.cancel(); _countdownTimer?.cancel(); super.dispose(); }
  @override Widget build(BuildContext context) {
    return Listener(behavior: HitTestBehavior.translucent, onPointerDown: (_) => _resetInactivityTimer(), onPointerMove: (_) => _resetInactivityTimer(), child: widget.child);
  }
}

// ==========================================
// 3. MAIN & LOGIN
// ==========================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized(); 
  final prefs = await SharedPreferences.getInstance();
  final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  
  runApp(MultiProvider(providers: [ChangeNotifierProvider(create: (_) => AppState())], child: NangkaApp(isLoggedIn: isLoggedIn)));
}

class NangkaApp extends StatelessWidget {
  final bool isLoggedIn;
  const NangkaApp({Key? key, required this.isLoggedIn}) : super(key: key);

  @override Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, title: 'Nangka Inventory',
      theme: ThemeData(
        primaryColor: const Color(0xFF2E7D32), scaffoldBackgroundColor: const Color(0xFFF9FBE7),
        colorScheme: ColorScheme.fromSwatch().copyWith(primary: const Color(0xFF2E7D32), secondary: const Color(0xFFFFCA28)),
        inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 2))),
        elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white, elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 16))),
        cardTheme: CardThemeData(elevation: 3, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), margin: const EdgeInsets.symmetric(vertical: 6)),
      ),
      home: SessionWrapper(child: isLoggedIn ? const MainDashboard() : const LoginPage()),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);
  @override State<LoginPage> createState() => _LoginPageState();
}
class _LoginPageState extends State<LoginPage> {
  final _uCtrl = TextEditingController(); final _pCtrl = TextEditingController();
  void _login() async {
    if (_uCtrl.text == 'admin' && _pCtrl.text == 'admin') {
      final prefs = await SharedPreferences.getInstance(); await prefs.setBool('isLoggedIn', true);
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainDashboard()));
    } else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid Credentials'), backgroundColor: Colors.red)); }
  }
  @override Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 400), child: Padding(padding: const EdgeInsets.all(32.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(padding: const EdgeInsets.all(16), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]), child: Image.asset('assets/nangka-logo.png', height: 100)),
        const SizedBox(height: 32), const Text('Nangka System', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF2E7D32))),
        const SizedBox(height: 32), TextField(controller: _uCtrl, decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.person))),
        const SizedBox(height: 16), TextField(controller: _pCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock))),
        const SizedBox(height: 32), SizedBox(width: double.infinity, height: 55, child: ElevatedButton(onPressed: _login, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFCA28), foregroundColor: const Color(0xFF2E7D32)), child: const Text('LOGIN', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))))
      ])))),
    );
  }
}

class MainDashboard extends StatefulWidget {
  const MainDashboard({Key? key}) : super(key: key);
  @override State<MainDashboard> createState() => _MainDashboardState();
}
class _MainDashboardState extends State<MainDashboard> {
  int _currentIndex = 0;
  void _logout() async { final prefs = await SharedPreferences.getInstance(); await prefs.remove('isLoggedIn'); if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage())); }
  
  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Row(children: [Image.asset('assets/nangka-logo.png', height: 30), const SizedBox(width: 12), const Text('Nangka System', style: TextStyle(fontWeight: FontWeight.bold))]), backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white, elevation: 0, actions: [IconButton(icon: const Icon(Icons.logout), onPressed: _logout)]),
      body: IndexedStack(index: _currentIndex, children: const [EntryPage(), FinancePage(), SummaryPage()]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex, onTap: (index) => setState(() => _currentIndex = index), selectedItemColor: const Color(0xFF2E7D32), unselectedItemColor: Colors.grey, type: BottomNavigationBarType.fixed,
        items: const [BottomNavigationBarItem(icon: Icon(Icons.edit_document), label: 'Entry'), BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'Finance'), BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Summary')],
      ),
    );
  }
}

// ==========================================
// 4. DATA ENTRY PAGE
// ==========================================
class EntryPage extends StatefulWidget { const EntryPage({Key? key}) : super(key: key); @override State<EntryPage> createState() => _EntryPageState(); }
class _EntryPageState extends State<EntryPage> with AutomaticKeepAliveClientMixin {
  @override bool get wantKeepAlive => true;

  DateTime _date = DateTime.now();
  String? _selectedLocation;
  final List<String> _locations = ['Mydin Meru', 'Mydin RTC', 'Giant Tambun', 'Cold Storage Sentra Mall', 'Wholesale', 'Others'];
  final _customLocCtrl = TextEditingController();
  final _kgCtrl = TextEditingController(); final _totalCtrl = TextEditingController(); final _displayCtrl = TextEditingController(); final _rejectCtrl = TextEditingController();
  String _rejectUnit = 'Packs'; int _balance = 0; bool _isLoading = false;

  void _calc() {
    int t = int.tryParse(_totalCtrl.text) ?? 0; int d = int.tryParse(_displayCtrl.text) ?? 0; int r = int.tryParse(_rejectCtrl.text) ?? 0;
    int bal = t - d; if (_rejectUnit == 'Packs') bal -= r;
    setState(() => _balance = bal < 0 ? 0 : bal);
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    String locName = _selectedLocation == 'Others' ? _customLocCtrl.text : (_selectedLocation ?? '-');
    Map<String, dynamic> body = {
      'date': DateFormat('yyyy-MM-dd').format(_date), 'location_name': locName, 'kg': double.tryParse(_kgCtrl.text) ?? 0.0,
      'total_packs': int.tryParse(_totalCtrl.text) ?? 0, 'display_packs': int.tryParse(_displayCtrl.text) ?? 0,
      'rejected_amount': int.tryParse(_rejectCtrl.text) ?? 0, 'rejected_unit': _rejectUnit, 'balance_packs': _balance,
      // ADDED THESE TWO FIELDS TO PASS LARAVEL VALIDATION
      'purchase_rm': 0.0, 'sales_rm': 0.0,
    };
    try {
      await http.post(Uri.parse('$apiUrl/inventories'), headers: {'Content-Type': 'application/json'}, body: json.encode(body));
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved!'), backgroundColor: Color(0xFF2E7D32))); _kgCtrl.clear(); _totalCtrl.clear(); _displayCtrl.clear(); _rejectCtrl.clear(); _customLocCtrl.clear(); setState(() { _balance = 0; }); }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed.'), backgroundColor: Colors.red)); } 
    finally { setState(() => _isLoading = false); }
  }

  @override Widget build(BuildContext context) {
    super.build(context);
    return Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 800), child: SingleChildScrollView(padding: const EdgeInsets.all(16.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Date: ${DateFormat('dd/MM/yyyy').format(_date)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF2E7D32))), OutlinedButton.icon(onPressed: () async { final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(2101)); if (d != null) setState(() => _date = d); }, icon: const Icon(Icons.calendar_today, size: 18), label: const Text('Change Date'))]),
      const SizedBox(height: 24),
      DropdownButtonFormField<String>(decoration: const InputDecoration(labelText: 'Location', prefixIcon: Icon(Icons.location_on)), value: _selectedLocation, items: _locations.map((loc) => DropdownMenuItem(value: loc, child: Text(loc))).toList(), onChanged: (val) => setState(() => _selectedLocation = val)),
      if (_selectedLocation == 'Others') ...[const SizedBox(height: 16), TextField(controller: _customLocCtrl, decoration: const InputDecoration(labelText: 'Enter Custom Location', prefixIcon: Icon(Icons.edit_location)))],
      const SizedBox(height: 16), TextField(controller: _kgCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Processed (KG)', prefixIcon: Icon(Icons.scale))),
      const SizedBox(height: 16), TextField(controller: _totalCtrl, keyboardType: TextInputType.number, onChanged: (_) => _calc(), decoration: const InputDecoration(labelText: 'Total Packs', prefixIcon: Icon(Icons.inventory_2))),
      const SizedBox(height: 16), TextField(controller: _displayCtrl, keyboardType: TextInputType.number, onChanged: (_) => _calc(), decoration: const InputDecoration(labelText: 'Displayed Packs', prefixIcon: Icon(Icons.storefront))),
      const SizedBox(height: 16), Row(children: [Expanded(flex: 2, child: TextField(controller: _rejectCtrl, keyboardType: TextInputType.number, onChanged: (_) => _calc(), decoration: const InputDecoration(labelText: 'Rejected', prefixIcon: Icon(Icons.delete_outline)))), const SizedBox(width: 12), Expanded(flex: 1, child: DropdownButtonFormField<String>(value: _rejectUnit, decoration: const InputDecoration(labelText: 'Unit'), items: ['Packs', 'Kg'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() { _rejectUnit = v!; _calc(); }))) ]),
      const SizedBox(height: 24), Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: const Color(0xFF2E7D32), borderRadius: BorderRadius.circular(12)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Balance Packs:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)), Text('$_balance', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFFFFCA28)))])),
      const SizedBox(height: 24), SizedBox(width: double.infinity, height: 55, child: ElevatedButton(onPressed: _isLoading ? null : _save, child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('SAVE ENTRY', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))))
    ]))));
  }
}

// ==========================================
// 5. FINANCE PAGE
// ==========================================
class FinancePage extends StatefulWidget { const FinancePage({Key? key}) : super(key: key); @override State<FinancePage> createState() => _FinancePageState(); }
class _FinancePageState extends State<FinancePage> with SingleTickerProviderStateMixin {
  late TabController _tCtrl;
  @override void initState() { super.initState(); _tCtrl = TabController(length: 5, vsync: this); }
  @override Widget build(BuildContext context) {
    return Column(children: [
      Container(color: Colors.white, child: TabBar(controller: _tCtrl, isScrollable: true, labelColor: const Color(0xFF2E7D32), indicatorColor: const Color(0xFFFFCA28), tabs: const [Tab(icon: Icon(Icons.point_of_sale), text: 'Sales'), Tab(icon: Icon(Icons.shopping_cart), text: 'Purchase'), Tab(icon: Icon(Icons.assignment_turned_in), text: 'Closing'), Tab(icon: Icon(Icons.people), text: 'Salary'), Tab(icon: Icon(Icons.receipt_long), text: 'Expenses')])),
      Expanded(child: TabBarView(controller: _tCtrl, children: const [SalesTab(), PurchaseTab(), ClosingTab(), SalaryTab(), ExpensesTab()]))
    ]);
  }
}

String formatVal(dynamic val) => (val == null || val == 0 || val == 0.0 || val == '') ? '-' : val.toString();

// -- SHARED WIDGET FOR DATE ROW --
Widget buildDateRow(BuildContext context, DateTime date, Function(DateTime) onDateChanged) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text('Date: ${DateFormat('dd/MM/yyyy').format(date)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
      OutlinedButton.icon(onPressed: () async { final d = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime(2101)); if (d != null) onDateChanged(d); }, icon: const Icon(Icons.calendar_today, size: 16), label: const Text('Change')),
    ],
  );
}

// -- SHARED WIDGET FOR TABLE FILTER --
Widget buildTableFilterRow(BuildContext context, DateTime start, DateTime end, Function(DateTime, DateTime) onDateFiltered) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text('Showing: ${DateFormat('dd/MM').format(start)} - ${DateFormat('dd/MM').format(end)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
      TextButton.icon(
        onPressed: () async { final picked = await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2101), initialDateRange: DateTimeRange(start: start, end: end)); if (picked != null) onDateFiltered(picked.start, picked.end); },
        icon: const Icon(Icons.filter_alt, size: 18), label: const Text('Filter Dates'),
      ),
    ],
  );
}

// -- SALES TAB --
class SalesTab extends StatefulWidget { const SalesTab({Key? key}) : super(key: key); @override State<SalesTab> createState() => _SalesTabState(); }
class _SalesTabState extends State<SalesTab> with AutomaticKeepAliveClientMixin {
  @override bool get wantKeepAlive => true;

  DateTime _date = DateTime.now(); 
  DateTime _filterStart = DateTime.now().subtract(const Duration(days: 7)); DateTime _filterEnd = DateTime.now();
  int? _locId; 
  List<Location> _locs = [
    Location(id: 1, name: 'Mydin Meru', defaultPrice: 6.99), Location(id: 2, name: 'Mydin RTC', defaultPrice: 6.99),
    Location(id: 3, name: 'Giant Tambun', defaultPrice: 6.99), Location(id: 4, name: 'Cold Storage Sentra Mall', defaultPrice: 6.99),
    Location(id: 5, name: 'Wholesale', defaultPrice: 6.99),
  ]; 
  List<SaleItem> _sales = [];
  final _customCtrl = TextEditingController(); final _prodCtrl = TextEditingController(); final _actCtrl = TextEditingController(); final _priceCtrl = TextEditingController(text: '6.99');
  
  @override void initState() { super.initState(); _fetch(); }
  Future<void> _fetch() async {
    final r1 = await http.get(Uri.parse('$apiUrl/locations')); 
    if (r1.statusCode == 200) {
      var fetched = (json.decode(r1.body) as List).map((j) => Location.fromJson(j)).toList();
      if (fetched.isNotEmpty) setState(() => _locs = fetched);
    }
    final r2 = await http.get(Uri.parse('$apiUrl/sales')); if (r2.statusCode == 200) setState(() => _sales = (json.decode(r2.body) as List).map((j) => SaleItem.fromJson(j)).toList());
  }
  
  Future<void> _save() async {
    double p = double.tryParse(_priceCtrl.text) ?? 6.99;
    Location? selectedLoc = _locs.where((l) => l.id == _locId).firstOrNull;

    if (selectedLoc != null && p != selectedLoc.defaultPrice) {
      bool update = await showDialog(context: context, builder: (c) => AlertDialog(title: const Text('Update Default?'), content: Text('Save RM $p as default for ${selectedLoc.name}?'), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No')), ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Yes'))])) ?? false;
      if (update) await http.put(Uri.parse('$apiUrl/locations/${selectedLoc.id}'), headers: {'Content-Type': 'application/json'}, body: json.encode({'default_price': p}));
    }
    
    await http.post(Uri.parse('$apiUrl/sales'), headers: {'Content-Type': 'application/json'}, body: json.encode({'date': DateFormat('yyyy-MM-dd').format(_date), 'location_id': _locId == 0 ? null : _locId, 'custom_location': _locId == 0 ? _customCtrl.text : null, 'production_packs': int.tryParse(_prodCtrl.text) ?? 0, 'actual_packs': int.tryParse(_actCtrl.text) ?? 0, 'price': p}));
    _prodCtrl.clear(); _actCtrl.clear(); _customCtrl.clear(); _fetch();
  }

  // ADDED DELETE FUNCTION
  Future<void> _delete(int id) async {
    await http.delete(Uri.parse('$apiUrl/sales/$id'));
    _fetch();
  }
  
  @override Widget build(BuildContext context) {
    super.build(context);
    var filtered = _sales.where((s) => s.date.isAfter(_filterStart.subtract(const Duration(days: 1))) && s.date.isBefore(_filterEnd.add(const Duration(days: 1)))).toList();
    
    return Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 800), child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      buildDateRow(context, _date, (d) => setState(() => _date = d)), const SizedBox(height: 24),
      DropdownButtonFormField<int>(
        decoration: const InputDecoration(labelText: 'Location', prefixIcon: Icon(Icons.location_on)), value: _locId, 
        items: _locs.map((l) => DropdownMenuItem(value: l.id, child: Text(l.name))).toList()..add(const DropdownMenuItem(value: 0, child: Text('Others'))), 
        onChanged: (v) { setState(() => _locId = v); if (v != null && v != 0) _priceCtrl.text = _locs.firstWhere((l) => l.id == v).defaultPrice.toString(); }
      ),
      if (_locId == 0) Padding(padding: const EdgeInsets.only(top: 16), child: TextField(controller: _customCtrl, decoration: const InputDecoration(labelText: 'Enter Custom Location', prefixIcon: Icon(Icons.edit_location)))),
      const SizedBox(height: 16), TextField(controller: _priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price per Pack (RM)', prefixIcon: Icon(Icons.attach_money))),
      const SizedBox(height: 16), Row(children: [Expanded(child: TextField(controller: _prodCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Production Packs', prefixIcon: Icon(Icons.inventory)))), const SizedBox(width: 12), Expanded(child: TextField(controller: _actCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Actual Packs', prefixIcon: Icon(Icons.check_circle))))]),
      const SizedBox(height: 24), SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _save, child: const Text('SAVE SALE RECORD'))),
      const SizedBox(height: 32), const Text('Sales Table', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 8),
      buildTableFilterRow(context, _filterStart, _filterEnd, (s, e) => setState(() { _filterStart = s; _filterEnd = e; })),
      Card(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(columns: const [DataColumn(label: Text('Date')), DataColumn(label: Text('Location')), DataColumn(label: Text('Prod(RM)')), DataColumn(label: Text('Actual(RM)')), DataColumn(label: Text('Diff(RM)')), DataColumn(label: Text('Action'))], rows: filtered.map((s) => DataRow(cells: [DataCell(Text(DateFormat('dd/MM').format(s.date))), DataCell(Text(s.locationName)), DataCell(Text(formatVal(s.productionRM))), DataCell(Text(formatVal(s.actualRM))), DataCell(Text(formatVal(s.differenceRM), style: TextStyle(color: s.differenceRM < 0 ? Colors.red : Colors.green, fontWeight: FontWeight.bold))), DataCell(IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _delete(s.id)))])).toList())))
    ]))));
  }
}

// -- PURCHASE TAB --
class PurchaseTab extends StatefulWidget { const PurchaseTab({Key? key}) : super(key: key); @override State<PurchaseTab> createState() => _PurchaseTabState(); }
class _PurchaseTabState extends State<PurchaseTab> with AutomaticKeepAliveClientMixin {
  @override bool get wantKeepAlive => true;

  DateTime _date = DateTime.now(); DateTime _filterStart = DateTime.now().subtract(const Duration(days: 7)); DateTime _filterEnd = DateTime.now();
  String? _item; final _items = ['Grade A Honey Jackfruit', 'Grade B Honey Jackfruit', 'Packing Material', 'Transportation', 'Others'];
  final _customCtrl = TextEditingController(); final _qtyCtrl = TextEditingController(); final _unitCtrl = TextEditingController(); final _priceCtrl = TextEditingController(); List<PurchaseItem> _purchases = [];
  @override void initState() { super.initState(); _fetch(); }
  Future<void> _fetch() async { final res = await http.get(Uri.parse('$apiUrl/purchases')); if (res.statusCode == 200) setState(() => _purchases = (json.decode(res.body) as List).map((j) => PurchaseItem.fromJson(j)).toList()); }
  Future<void> _save() async { await http.post(Uri.parse('$apiUrl/purchases'), headers: {'Content-Type': 'application/json'}, body: json.encode({'date': DateFormat('yyyy-MM-dd').format(_date), 'item_name': _item == 'Others' ? _customCtrl.text : _item ?? '', 'quantity': int.tryParse(_qtyCtrl.text) ?? 1, 'unit': _unitCtrl.text.isEmpty ? '-' : _unitCtrl.text, 'price': double.tryParse(_priceCtrl.text) ?? 0.0})); _priceCtrl.clear(); _qtyCtrl.clear(); _unitCtrl.clear(); _customCtrl.clear(); _fetch(); }
  
  // ADDED DELETE FUNCTION
  Future<void> _delete(int id) async {
    await http.delete(Uri.parse('$apiUrl/purchases/$id'));
    _fetch();
  }

  @override Widget build(BuildContext context) {
    super.build(context);
    var filtered = _purchases.where((p) => p.date.isAfter(_filterStart.subtract(const Duration(days: 1))) && p.date.isBefore(_filterEnd.add(const Duration(days: 1)))).toList(); double sum = filtered.fold(0, (prev, el) => prev + el.price);
    
    return Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 800), child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      buildDateRow(context, _date, (d) => setState(() => _date = d)), const SizedBox(height: 24),
      DropdownButtonFormField<String>(decoration: const InputDecoration(labelText: 'Item', prefixIcon: Icon(Icons.shopping_bag)), value: _item, items: _items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(), onChanged: (v) => setState(() => _item = v)),
      if (_item == 'Others') Padding(padding: const EdgeInsets.only(top: 16), child: TextField(controller: _customCtrl, decoration: const InputDecoration(labelText: 'Custom Item Name', prefixIcon: Icon(Icons.edit)))),
      const SizedBox(height: 16), Row(children: [Expanded(child: TextField(controller: _qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity', prefixIcon: Icon(Icons.numbers)))), const SizedBox(width: 12), Expanded(child: TextField(controller: _unitCtrl, decoration: const InputDecoration(labelText: 'Unit (e.g. Kg, Box)', prefixIcon: Icon(Icons.category))))]),
      const SizedBox(height: 16), TextField(controller: _priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Total Price (RM)', prefixIcon: Icon(Icons.attach_money))),
      const SizedBox(height: 24), SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _save, child: const Text('SAVE PURCHASE'))),
      const SizedBox(height: 32), const Text('Purchase Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 8),
      buildTableFilterRow(context, _filterStart, _filterEnd, (s, e) => setState(() { _filterStart = s; _filterEnd = e; })),
      Card(child: Padding(padding: const EdgeInsets.all(16.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Total Purchase for Period:'), Text('RM ${sum.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red))]))),
      const SizedBox(height: 16),
      Card(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(columns: const [DataColumn(label: Text('Date')), DataColumn(label: Text('Item')), DataColumn(label: Text('Qty/Unit')), DataColumn(label: Text('Price(RM)')), DataColumn(label: Text('Action'))], rows: filtered.map((p) => DataRow(cells: [DataCell(Text(DateFormat('dd/MM').format(p.date))), DataCell(Text(p.itemName)), DataCell(Text('${p.quantity} ${p.unit}')), DataCell(Text(p.price.toStringAsFixed(2))), DataCell(IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _delete(p.id)))])).toList())))
    ]))));
  }
}

// -- CLOSING TAB --
class ClosingTab extends StatefulWidget { const ClosingTab({Key? key}) : super(key: key); @override State<ClosingTab> createState() => _ClosingTabState(); }
class _ClosingTabState extends State<ClosingTab> with AutomaticKeepAliveClientMixin {
  @override bool get wantKeepAlive => true;

  DateTime _date = DateTime.now(); DateTime _filterStart = DateTime.now().subtract(const Duration(days: 7)); DateTime _filterEnd = DateTime.now();
  String? _item; final _items = ['Grade A Honey Jackfruit', 'Grade B Honey Jackfruit', '400gm Honey Jackfruit', '350gm Honey Jackfruit', 'Packing Material', 'Others'];
  final _customCtrl = TextEditingController(); final _pcsCtrl = TextEditingController(); final _kgCtrl = TextEditingController(); final _packsCtrl = TextEditingController(); final _priceCtrl = TextEditingController(); List<ClosingItem> _closings = [];
  @override void initState() { super.initState(); _fetch(); }
  Future<void> _fetch() async { final res = await http.get(Uri.parse('$apiUrl/closing-statements')); if (res.statusCode == 200) setState(() => _closings = (json.decode(res.body) as List).map((j) => ClosingItem.fromJson(j)).toList()); }
  Future<void> _save() async { await http.post(Uri.parse('$apiUrl/closing-statements'), headers: {'Content-Type': 'application/json'}, body: json.encode({'date': DateFormat('yyyy-MM-dd').format(_date), 'item_name': _item == 'Others' ? _customCtrl.text : _item ?? '', 'price': double.tryParse(_priceCtrl.text) ?? 0.0, 'pcs': int.tryParse(_pcsCtrl.text), 'kg': double.tryParse(_kgCtrl.text), 'packs': int.tryParse(_packsCtrl.text)})); _priceCtrl.clear(); _pcsCtrl.clear(); _kgCtrl.clear(); _packsCtrl.clear(); _customCtrl.clear(); _fetch(); }
  
  // ADDED DELETE FUNCTION
  Future<void> _delete(int id) async {
    await http.delete(Uri.parse('$apiUrl/closing-statements/$id'));
    _fetch();
  }

  @override Widget build(BuildContext context) {
    super.build(context);
    var filtered = _closings.where((c) => c.date.isAfter(_filterStart.subtract(const Duration(days: 1))) && c.date.isBefore(_filterEnd.add(const Duration(days: 1)))).toList(); double sum = filtered.fold(0, (prev, el) => prev + el.price);
    
    return Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 800), child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      buildDateRow(context, _date, (d) => setState(() => _date = d)), const SizedBox(height: 24),
      DropdownButtonFormField<String>(decoration: const InputDecoration(labelText: 'Item', prefixIcon: Icon(Icons.inventory_2)), value: _item, items: _items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(), onChanged: (v) => setState(() => _item = v)),
      if (_item == 'Others') Padding(padding: const EdgeInsets.only(top: 16), child: TextField(controller: _customCtrl, decoration: const InputDecoration(labelText: 'Custom Item Name', prefixIcon: Icon(Icons.edit)))),
      if (_item == 'Grade A Honey Jackfruit' || _item == 'Grade B Honey Jackfruit') Padding(padding: const EdgeInsets.only(top: 16), child: Row(children: [Expanded(child: TextField(controller: _pcsCtrl, decoration: const InputDecoration(labelText: 'Pcs', prefixIcon: Icon(Icons.widgets)))), const SizedBox(width: 12), Expanded(child: TextField(controller: _kgCtrl, decoration: const InputDecoration(labelText: 'KG', prefixIcon: Icon(Icons.scale))))])),
      if (_item == 'Packing Material') Padding(padding: const EdgeInsets.only(top: 16), child: TextField(controller: _packsCtrl, decoration: const InputDecoration(labelText: 'Packs', prefixIcon: Icon(Icons.view_in_ar)))),
      const SizedBox(height: 16), TextField(controller: _priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Total Price (RM)', prefixIcon: Icon(Icons.attach_money))),
      const SizedBox(height: 24), SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _save, child: const Text('SAVE CLOSING STATEMENT'))),
      const SizedBox(height: 32), const Text('Closing Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 8),
      buildTableFilterRow(context, _filterStart, _filterEnd, (s, e) => setState(() { _filterStart = s; _filterEnd = e; })),
      Card(child: Padding(padding: const EdgeInsets.all(16.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Total Closing Value:'), Text('RM ${sum.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)))]))),
      const SizedBox(height: 16),
      Card(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(columns: const [DataColumn(label: Text('Date')), DataColumn(label: Text('Item')), DataColumn(label: Text('Pcs/Kg/Pcks')), DataColumn(label: Text('Price(RM)')), DataColumn(label: Text('Action'))], rows: filtered.map((c) => DataRow(cells: [DataCell(Text(DateFormat('dd/MM').format(c.date))), DataCell(Text(c.itemName)), DataCell(Text('${formatVal(c.pcs)} pcs / ${formatVal(c.kg)} kg / ${formatVal(c.packs)} pcks')), DataCell(Text(c.price.toStringAsFixed(2))), DataCell(IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _delete(c.id)))])).toList())))
    ]))));
  }
}

// -- SALARY TAB --
class SalaryTab extends StatefulWidget { const SalaryTab({Key? key}) : super(key: key); @override State<SalaryTab> createState() => _SalaryTabState(); }
class _SalaryTabState extends State<SalaryTab> with AutomaticKeepAliveClientMixin {
  @override bool get wantKeepAlive => true;

  DateTime _date = DateTime.now(); DateTime _filterStart = DateTime.now().subtract(const Duration(days: 7)); DateTime _filterEnd = DateTime.now();
  int? _empId; List<Employee> _emps = []; List<SalaryItem> _sals = []; final _amtCtrl = TextEditingController();
  @override void initState() { super.initState(); _fetch(); }
  Future<void> _fetch() async { final r1 = await http.get(Uri.parse('$apiUrl/employees')); if(r1.statusCode==200) setState(()=>_emps=(json.decode(r1.body) as List).map((j)=>Employee.fromJson(j)).toList()); final r2 = await http.get(Uri.parse('$apiUrl/salaries')); if(r2.statusCode==200) setState(()=>_sals=(json.decode(r2.body) as List).map((j)=>SalaryItem.fromJson(j)).toList()); }
  Future<void> _save() async { if (_empId != null) { await http.post(Uri.parse('$apiUrl/salaries'), headers: {'Content-Type': 'application/json'}, body: json.encode({'date': DateFormat('yyyy-MM-dd').format(_date), 'employee_id': _empId, 'amount': double.tryParse(_amtCtrl.text) ?? 0})); _amtCtrl.clear(); _fetch(); } }
  Future<void> _addEmp() async { final name = TextEditingController(); final pos = TextEditingController(); await showDialog(context: context, builder: (c) => AlertDialog(title: const Text('New Employee'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')), const SizedBox(height:12), TextField(controller: pos, decoration: const InputDecoration(labelText: 'Position'))]), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Save'))])) == true ? () async { if (name.text.isNotEmpty) { await http.post(Uri.parse('$apiUrl/employees'), headers: {'Content-Type': 'application/json'}, body: json.encode({'name': name.text, 'position': pos.text})); _fetch(); } }() : null; }
  
  // ADDED DELETE FUNCTION
  Future<void> _delete(int id) async {
    await http.delete(Uri.parse('$apiUrl/salaries/$id'));
    _fetch();
  }

  @override Widget build(BuildContext context) {
    super.build(context);
    var filtered = _sals.where((s) => s.date.isAfter(_filterStart.subtract(const Duration(days: 1))) && s.date.isBefore(_filterEnd.add(const Duration(days: 1)))).toList(); double sum = filtered.fold(0, (p, e) => p + e.amount);
    
    return Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 800), child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      buildDateRow(context, _date, (d) => setState(() => _date = d)), const SizedBox(height: 24),
      Row(children: [Expanded(child: DropdownButtonFormField<int>(decoration: const InputDecoration(labelText: 'Employee', prefixIcon: Icon(Icons.person)), value: _empId, items: _emps.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name))).toList(), onChanged: (v) => setState(() => _empId = v))), const SizedBox(width: 8), FloatingActionButton(onPressed: _addEmp, backgroundColor: const Color(0xFF2E7D32), child: const Icon(Icons.person_add, color: Colors.white))]),
      const SizedBox(height: 16), TextField(controller: _amtCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Salary Amount (RM)', prefixIcon: Icon(Icons.attach_money))),
      const SizedBox(height: 24), SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _save, child: const Text('SAVE SALARY'))),
      const SizedBox(height: 32), const Text('Salary Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 8),
      buildTableFilterRow(context, _filterStart, _filterEnd, (s, e) => setState(() { _filterStart = s; _filterEnd = e; })),
      Card(child: Padding(padding: const EdgeInsets.all(16.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Total Salary Payout:'), Text('RM ${sum.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red))]))),
      const SizedBox(height: 16),
      Card(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(columns: const [DataColumn(label: Text('Date')), DataColumn(label: Text('Employee')), DataColumn(label: Text('Amount(RM)')), DataColumn(label: Text('Action'))], rows: filtered.map((s) => DataRow(cells: [DataCell(Text(DateFormat('dd/MM').format(s.date))), DataCell(Text(s.employee?.name ?? '-')), DataCell(Text(s.amount.toStringAsFixed(2))), DataCell(IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _delete(s.id)))])).toList())))
    ]))));
  }
}

// -- EXPENSES TAB --
class ExpensesTab extends StatefulWidget { const ExpensesTab({Key? key}) : super(key: key); @override State<ExpensesTab> createState() => _ExpensesTabState(); }
class _ExpensesTabState extends State<ExpensesTab> with AutomaticKeepAliveClientMixin {
  @override bool get wantKeepAlive => true;

  DateTime _date = DateTime.now(); DateTime _filterStart = DateTime.now().subtract(const Duration(days: 7)); DateTime _filterEnd = DateTime.now();
  final _itemCtrl = TextEditingController(); final _qtyCtrl = TextEditingController(text: '1'); final _priceCtrl = TextEditingController(); List<ExpenseItem> _exps = [];
  @override void initState() { super.initState(); _fetch(); }
  Future<void> _fetch() async { final r = await http.get(Uri.parse('$apiUrl/expenses')); if(r.statusCode==200) setState(()=>_exps=(json.decode(r.body) as List).map((j)=>ExpenseItem.fromJson(j)).toList()); }
  Future<void> _save() async { await http.post(Uri.parse('$apiUrl/expenses'), headers: {'Content-Type': 'application/json'}, body: json.encode({'date': DateFormat('yyyy-MM-dd').format(_date), 'item_name': _itemCtrl.text, 'quantity': int.tryParse(_qtyCtrl.text) ?? 1, 'price': double.tryParse(_priceCtrl.text) ?? 0})); _itemCtrl.clear(); _priceCtrl.clear(); _fetch(); }
  
  // ADDED DELETE FUNCTION
  Future<void> _delete(int id) async {
    await http.delete(Uri.parse('$apiUrl/expenses/$id'));
    _fetch();
  }

  @override Widget build(BuildContext context) {
    super.build(context);
    var filtered = _exps.where((e) => e.date.isAfter(_filterStart.subtract(const Duration(days: 1))) && e.date.isBefore(_filterEnd.add(const Duration(days: 1)))).toList(); double sum = filtered.fold(0, (p, e) => p + e.price);
    
    return Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 800), child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      buildDateRow(context, _date, (d) => setState(() => _date = d)), const SizedBox(height: 24),
      TextField(controller: _itemCtrl, decoration: const InputDecoration(labelText: 'Item Name', prefixIcon: Icon(Icons.receipt_long))),
      const SizedBox(height: 16), Row(children: [Expanded(child: TextField(controller: _qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity', prefixIcon: Icon(Icons.numbers)))), const SizedBox(width: 12), Expanded(child: TextField(controller: _priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Total Price (RM)', prefixIcon: Icon(Icons.attach_money))))]),
      const SizedBox(height: 24), SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _save, child: const Text('SAVE EXPENSE'))),
      const SizedBox(height: 32), const Text('Expenses Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 8),
      buildTableFilterRow(context, _filterStart, _filterEnd, (s, e) => setState(() { _filterStart = s; _filterEnd = e; })),
      Card(child: Padding(padding: const EdgeInsets.all(16.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Total Expenses:'), Text('RM ${sum.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red))]))),
      const SizedBox(height: 16),
      Card(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(columns: const [DataColumn(label: Text('Date')), DataColumn(label: Text('Item')), DataColumn(label: Text('Qty')), DataColumn(label: Text('Price(RM)')), DataColumn(label: Text('Action'))], rows: filtered.map((e) => DataRow(cells: [DataCell(Text(DateFormat('dd/MM').format(e.date))), DataCell(Text(e.itemName)), DataCell(Text(e.quantity.toString())), DataCell(Text(e.price.toStringAsFixed(2))), DataCell(IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _delete(e.id)))])).toList())))
    ]))));
  }
}

// ==========================================
// 6. SUMMARY PAGE (PDF Export Only)
// ==========================================
class SummaryPage extends StatefulWidget { const SummaryPage({Key? key}) : super(key: key); @override State<SummaryPage> createState() => _SummaryPageState(); }
class _SummaryPageState extends State<SummaryPage> {
  bool _isLoading = false;

  List<InventoryItem> _invs = []; List<SaleItem> _sales = []; List<PurchaseItem> _purchases = []; 
  List<ClosingItem> _closings = []; List<SalaryItem> _salaries = []; List<ExpenseItem> _expenses = [];

  @override void initState() { super.initState(); _fetchAllData(); }

  Future<void> _fetchAllData() async {
    setState(() => _isLoading = true);
    try {
      var futures = await Future.wait([
        http.get(Uri.parse('$apiUrl/inventories')), http.get(Uri.parse('$apiUrl/sales')),
        http.get(Uri.parse('$apiUrl/purchases')), http.get(Uri.parse('$apiUrl/closing-statements')),
        http.get(Uri.parse('$apiUrl/salaries')), http.get(Uri.parse('$apiUrl/expenses')),
      ]);
      setState(() {
        if(futures[0].statusCode==200) _invs = (json.decode(futures[0].body) as List).map((j)=>InventoryItem.fromJson(j)).toList();
        if(futures[1].statusCode==200) _sales = (json.decode(futures[1].body) as List).map((j)=>SaleItem.fromJson(j)).toList();
        if(futures[2].statusCode==200) _purchases = (json.decode(futures[2].body) as List).map((j)=>PurchaseItem.fromJson(j)).toList();
        if(futures[3].statusCode==200) _closings = (json.decode(futures[3].body) as List).map((j)=>ClosingItem.fromJson(j)).toList();
        if(futures[4].statusCode==200) _salaries = (json.decode(futures[4].body) as List).map((j)=>SalaryItem.fromJson(j)).toList();
        if(futures[5].statusCode==200) _expenses = (json.decode(futures[5].body) as List).map((j)=>ExpenseItem.fromJson(j)).toList();
      });
    } catch(e) { debugPrint(e.toString()); } 
    finally { setState(() => _isLoading = false); }
  }

  Future<void> _pickDate(AppState state) async {
    if (state.summaryFilterType == 'Range') {
      final picked = await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2101), initialDateRange: DateTimeRange(start: state.summaryStartDate, end: state.summaryEndDate));
      if (picked != null) state.updateSummaryFilter('Range', picked.start, picked.end);
    } else {
      final picked = await showDatePicker(context: context, initialDate: state.summaryStartDate, firstDate: DateTime(2020), lastDate: DateTime(2101));
      if (picked != null) {
        if (state.summaryFilterType == 'Day') state.updateSummaryFilter('Day', picked, picked);
        else state.updateSummaryFilter('Month', DateTime(picked.year, picked.month, 1), DateTime(picked.year, picked.month + 1, 0));
      }
    }
  }

  Future<void> _exportPdf(AppState state, Map<String, dynamic> data) async {
    final pdf = pw.Document();
    String title = 'Nangka ${state.summaryDisplayType} Report\n(${DateFormat('dd/MM/yyyy').format(state.summaryStartDate)} - ${DateFormat('dd/MM/yyyy').format(state.summaryEndDate)})';
    
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4, margin: const pw.EdgeInsets.all(32),
      build: (pw.Context context) {
        List<pw.Widget> content = [ pw.Center(child: pw.Text(title, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold))), pw.SizedBox(height: 20) ];
        
        if (state.summaryDisplayType == 'Stock Entry') {
          data['locations'].forEach((loc, vals) {
            content.add(pw.Text('Location: $loc', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)));
            content.add(pw.Divider());
            content.add(pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Daily Processed (KG)'), pw.Text('${vals['kg']}')]));
            content.add(pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Total Packs'), pw.Text('${vals['total']}')]));
            content.add(pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Displayed Packs'), pw.Text('${vals['display']}')]));
            content.add(pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Balance Packs'), pw.Text('${vals['balance']}')]));
            content.add(pw.SizedBox(height: 15));
          });
        } else {
          content.add(pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Total Sales'), pw.Text('RM ${data['sales'].toStringAsFixed(2)}')]));
          content.add(pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Total Purchase'), pw.Text('RM ${data['purchases'].toStringAsFixed(2)}')]));
          content.add(pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Total Closing Stmt'), pw.Text('RM ${data['closing'].toStringAsFixed(2)}')]));
          content.add(pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Total Salary'), pw.Text('RM ${data['salary'].toStringAsFixed(2)}')]));
          content.add(pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Total Expenses'), pw.Text('RM ${data['expenses'].toStringAsFixed(2)}')]));
          content.add(pw.Divider(thickness: 2));
          content.add(pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('GROSS PROFIT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.Text('RM ${data['gross'].toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))]));
          content.add(pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('NETT PROFIT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.Text('RM ${data['nett'].toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))]));
        }
        return content;
      }
    ));
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save(), name: 'Nangka_Report.pdf');
  }

  @override Widget build(BuildContext context) {
    var state = Provider.of<AppState>(context);
    bool inRange(DateTime d) => d.isAfter(state.summaryStartDate.subtract(const Duration(days: 1))) && d.isBefore(state.summaryEndDate.add(const Duration(days: 1)));

    var fInvs = _invs.where((i) => inRange(i.date)).toList();
    Map<String, Map<String, dynamic>> locData = {};
    for (var i in fInvs) {
      if (!locData.containsKey(i.locationName)) locData[i.locationName] = {'kg': 0.0, 'total': 0, 'display': 0, 'balance': 0};
      locData[i.locationName]!['kg'] += i.kg; locData[i.locationName]!['total'] += i.totalPacks;
      locData[i.locationName]!['display'] += i.displayPacks; locData[i.locationName]!['balance'] += i.balancePacks;
    }
    double tKg = fInvs.fold(0, (s, i) => s + i.kg); int tTot = fInvs.fold(0, (s, i) => s + i.totalPacks);
    int tDisp = fInvs.fold(0, (s, i) => s + i.displayPacks); int tBal = fInvs.fold(0, (s, i) => s + i.balancePacks);

    double tSales = _sales.where((s) => inRange(s.date)).fold(0, (s, i) => s + i.actualRM);
    double tPurch = _purchases.where((p) => inRange(p.date)).fold(0, (s, i) => s + i.price);
    double tClos = _closings.where((c) => inRange(c.date)).fold(0, (s, i) => s + i.price);
    double tSal = _salaries.where((s) => inRange(s.date)).fold(0, (s, i) => s + i.amount);
    double tExp = _expenses.where((e) => inRange(e.date)).fold(0, (s, i) => s + i.price);
    double gross = tSales - tPurch + tClos - tSal;
    double nett = gross - tExp;

    Map<String, dynamic> exportData = state.summaryDisplayType == 'Stock Entry' 
      ? {'locations': locData, 'totalKg': tKg, 'totalPacks': tTot, 'display': tDisp, 'balance': tBal}
      : {'sales': tSales, 'purchases': tPurch, 'closing': tClos, 'salary': tSal, 'expenses': tExp, 'gross': gross, 'nett': nett};

    return _isLoading ? const Center(child: CircularProgressIndicator()) : Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 800), child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Summary Report', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
        ElevatedButton.icon(icon: const Icon(Icons.refresh, size: 18), label: const Text('Refresh'), onPressed: _fetchAllData)
      ]),
      const SizedBox(height: 16),
      Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)), child: Column(children: [
        Row(children: [Expanded(child: DropdownButtonFormField<String>(value: state.summaryDisplayType, decoration: const InputDecoration(labelText: 'Report Type'), items: ['Stock Entry', 'Finance'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v) => state.updateSummaryDisplayType(v!))), const SizedBox(width: 12), Expanded(child: DropdownButtonFormField<String>(value: state.summaryFilterType, decoration: const InputDecoration(labelText: 'Filter By'), items: ['Day', 'Month', 'Range'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v) => state.updateSummaryFilter(v!, DateTime.now(), DateTime.now())))]),
        const SizedBox(height: 16), OutlinedButton.icon(onPressed: () => _pickDate(state), icon: const Icon(Icons.date_range), label: const Text('Set Date Filter')),
        const SizedBox(height: 8), Text('${DateFormat('dd/MM/yyyy').format(state.summaryStartDate)} to ${DateFormat('dd/MM/yyyy').format(state.summaryEndDate)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))
      ])),
      const SizedBox(height: 24),
      
      if (state.summaryDisplayType == 'Stock Entry') ...[
        ...locData.entries.map((e) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(e.key, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))), const Divider(), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Daily Processed (KG)'), Text(formatVal(e.value['kg']))]), const SizedBox(height: 4), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Total Packs'), Text(formatVal(e.value['total']))]), const SizedBox(height: 4), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Displayed Packs'), Text(formatVal(e.value['display']))]), const SizedBox(height: 4), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Balance Packs'), Text(formatVal(e.value['balance']))]) ])))),
        Card(color: const Color(0xFFE8F5E9), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('GRAND TOTAL', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))), const Divider(), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Total KG'), Text(formatVal(tKg), style: const TextStyle(fontWeight: FontWeight.bold))]), const SizedBox(height: 4), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Total Packs'), Text(formatVal(tTot), style: const TextStyle(fontWeight: FontWeight.bold))]), const SizedBox(height: 4), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Displayed Packs'), Text(formatVal(tDisp), style: const TextStyle(fontWeight: FontWeight.bold))]), const SizedBox(height: 4), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Balance Packs'), Text(formatVal(tBal), style: const TextStyle(fontWeight: FontWeight.bold))]) ])))
      ] else ...[
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Total Sales', style: TextStyle(fontSize: 16)), Text('RM ${tSales.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, color: Colors.green, fontWeight: FontWeight.bold))]), const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Total Purchase', style: TextStyle(fontSize: 16)), Text('RM ${tPurch.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, color: Colors.red))]), const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Total Closing Stmt', style: TextStyle(fontSize: 16)), Text('RM ${tClos.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, color: Colors.green))]), const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Total Salary', style: TextStyle(fontSize: 16)), Text('RM ${tSal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, color: Colors.red))]), const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Total Expenses', style: TextStyle(fontSize: 16)), Text('RM ${tExp.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, color: Colors.red))]), 
          const Divider(thickness: 2, height: 32),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('GROSS PROFIT', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), Text('RM ${gross.toStringAsFixed(2)}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: gross >= 0 ? Colors.green : Colors.red))]), const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('NETT PROFIT', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), Text('RM ${nett.toStringAsFixed(2)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: nett >= 0 ? Colors.green : Colors.red))]),
        ])))
      ],
      const SizedBox(height: 24),
      SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () => _exportPdf(state, exportData), icon: const Icon(Icons.picture_as_pdf), label: const Text('Export to PDF', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16))))
    ]))));
  }
}