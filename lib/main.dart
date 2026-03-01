import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

const String apiUrl = 'https://nangka-api.onrender.com/api/inventories';

void main() async {
  // Required so SharedPreferences can talk to the native code before the app starts
  WidgetsFlutterBinding.ensureInitialized(); 
  final prefs = await SharedPreferences.getInstance();
  final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  
  runApp(NangkaApp(isLoggedIn: isLoggedIn));
}

class NangkaApp extends StatelessWidget {
  final bool isLoggedIn;
  const NangkaApp({Key? key, required this.isLoggedIn}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Nangka Inventory',
      theme: ThemeData(
        // --- NANGKA COLOR PALETTE ---
        primaryColor: const Color(0xFF2E7D32), // Deep Nangka Green
        scaffoldBackgroundColor: const Color(0xFFF9FBE7), // Very light yellow-green tint
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: const Color(0xFF2E7D32),
          secondary: const Color(0xFFFFCA28), // Vibrant Nangka Yellow
        ),
        // --- GLOBAL INPUT DESIGN (PC Friendly) ---
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 2),
          ),
        ),
        // --- GLOBAL BUTTON DESIGN ---
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E7D32),
            foregroundColor: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        // --- GLOBAL CARD DESIGN ---
        cardTheme: CardThemeData(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.symmetric(vertical: 6),
        ),
      ),
      // Automatically route user based on their saved login state
      home: isLoggedIn ? const MainDashboard() : const LoginPage(),
    );
  }
}

// --- DATA MODEL ---
class InventoryItem {
  final int id;
  final DateTime date;
  final double kg;
  final double purchaseKg; 
  final int totalPacks;
  final int displayPacks;
  final int rejectedAmount;
  final String rejectedUnit;
  final int balancePacks;
  final double purchaseRM;
  final double salesRM;

  InventoryItem({
    required this.id, required this.date, required this.kg, required this.purchaseKg, 
    required this.totalPacks, required this.displayPacks, required this.rejectedAmount, 
    required this.rejectedUnit, required this.balancePacks, required this.purchaseRM, required this.salesRM,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: json['id'],
      date: DateTime.parse(json['date']),
      kg: double.parse((json['kg'] ?? 0).toString()),
      purchaseKg: double.parse((json['purchase_kg'] ?? 0).toString()), 
      totalPacks: json['total_packs'] ?? 0,
      displayPacks: json['display_packs'] ?? 0,
      rejectedAmount: json['rejected_amount'] ?? 0,
      rejectedUnit: json['rejected_unit'] ?? 'Packs',
      balancePacks: json['balance_packs'] ?? 0,
      purchaseRM: double.parse((json['purchase_rm'] ?? 0).toString()),
      salesRM: double.parse((json['sales_rm'] ?? 0).toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': DateFormat('yyyy-MM-dd').format(date),
      'kg': kg,
      'purchase_kg': purchaseKg, 
      'total_packs': totalPacks,
      'display_packs': displayPacks,
      'rejected_amount': rejectedAmount,
      'rejected_unit': rejectedUnit,
      'balance_packs': balancePacks,
      'purchase_rm': purchaseRM,
      'sales_rm': salesRM,
    };
  }
}

// --- 1. LOGIN PAGE ---
class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  void _login() async {
    if (_usernameController.text == 'admin' && _passwordController.text == 'admin') {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true); // Save login token
      
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainDashboard()));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Invalid Credentials'), backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        // PC FRIENDLY CONSTRAINT
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 5)],
                  ),
                  child: Image.asset('assets/nangka-logo.png', height: 100),
                ),
                const SizedBox(height: 32),
                const Text('Nangka System', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF2E7D32))),
                const SizedBox(height: 8),
                Text('Inventory & Sales Management Portal', style: TextStyle(fontSize: 16, color: Colors.grey[600]), textAlign: TextAlign.center),
                const SizedBox(height: 32),
                TextField(controller: _usernameController, decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.person))),
                const SizedBox(height: 16),
                TextField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock))),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity, 
                  height: 55, 
                  child: ElevatedButton(
                    onPressed: _login, 
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFCA28), // Yellow Button
                      foregroundColor: const Color(0xFF2E7D32), // Green Text
                    ),
                    child: const Text('LOGIN', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2))
                  )
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('© nsrnshr 2026', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
      ),
    );
  }
}

// --- 2. MAIN DASHBOARD ---
class MainDashboard extends StatefulWidget {
  const MainDashboard({Key? key}) : super(key: key);
  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  int _currentIndex = 0;

  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('isLoggedIn'); // Delete login token
    
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      EntryPage(key: UniqueKey()),
      FinancePage(key: UniqueKey()),
      SummaryPage(key: UniqueKey())
    ];
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/nangka-logo.png', height: 30),
            const SizedBox(width: 12),
            const Text('Nangka System', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout)
        ],
      ),
      body: Column(
        children: [
          Expanded(child: screens[_currentIndex]),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            color: Colors.white,
            child: const Text('© nsrnshr 2026', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
          )
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          selectedItemColor: const Color(0xFF2E7D32),
          unselectedItemColor: Colors.grey[500],
          backgroundColor: Colors.white,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.edit_document), label: 'Entry'),
            BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'Finance'),
            BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Summary')
          ],
        ),
      ),
    );
  }
}

// --- 3. DATA ENTRY PAGE ---
class EntryPage extends StatefulWidget {
  const EntryPage({Key? key}) : super(key: key);
  @override
  State<EntryPage> createState() => _EntryPageState();
}

class _EntryPageState extends State<EntryPage> {
  DateTime _selectedDate = DateTime.now();
  final _kgController = TextEditingController();
  final _totalController = TextEditingController();
  final _displayController = TextEditingController();
  final _rejectController = TextEditingController();
  String _rejectUnit = 'Packs';
  int _balance = 0;
  bool _isLoading = false;
  int? _editingId;
  List<InventoryItem> _todaysEntries = [];

  double _currentPurchaseKg = 0.0;
  double _currentPurchaseRM = 0.0;
  double _currentSalesRM = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchTodaysEntries();
  }

  Future<void> _fetchTodaysEntries() async {
    try {
      final response = await http.get(Uri.parse(apiUrl)).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        List<InventoryItem> allData = data.map((json) => InventoryItem.fromJson(json)).toList();
        setState(() {
          _todaysEntries = allData.where((item) => item.date.year == _selectedDate.year && item.date.month == _selectedDate.month && item.date.day == _selectedDate.day).toList();
        });
      }
    } catch (e) { print("Error fetching list: $e"); }
  }

  Future<void> _pickDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context, 
      initialDate: _selectedDate, 
      firstDate: DateTime(2020), 
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF2E7D32), onPrimary: Colors.white, onSurface: Colors.black),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() { _selectedDate = picked; _editingId = null; });
      _clearForm(); _fetchTodaysEntries();
    }
  }

  void _calculateBalance() {
    int total = int.tryParse(_totalController.text) ?? 0;
    int display = int.tryParse(_displayController.text) ?? 0;
    int reject = int.tryParse(_rejectController.text) ?? 0;
    int calculatedBalance = total - display;
    if (_rejectUnit == 'Packs') calculatedBalance -= reject;
    setState(() => _balance = calculatedBalance < 0 ? 0 : calculatedBalance);
  }

  void _clearForm() {
    _kgController.clear(); _totalController.clear(); _displayController.clear(); _rejectController.clear();
    _currentPurchaseKg = 0.0; _currentPurchaseRM = 0.0; _currentSalesRM = 0.0;
    _calculateBalance();
  }

  Future<void> _saveData() async {
    setState(() => _isLoading = true);
    Map<String, dynamic> bodyData = {
      'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
      'kg': double.tryParse(_kgController.text) ?? 0.0,
      'purchase_kg': _currentPurchaseKg,
      'total_packs': int.tryParse(_totalController.text) ?? 0,
      'display_packs': int.tryParse(_displayController.text) ?? 0,
      'rejected_amount': int.tryParse(_rejectController.text) ?? 0,
      'rejected_unit': _rejectUnit,
      'balance_packs': _balance,
      'purchase_rm': _currentPurchaseRM,
      'sales_rm': _currentSalesRM,
    };

    try {
      http.Response response;
      if (_editingId == null) {
        response = await http.post(Uri.parse(apiUrl), headers: {'Content-Type': 'application/json', 'Accept': 'application/json'}, body: json.encode(bodyData)).timeout(const Duration(seconds: 5));
      } else {
        response = await http.put(Uri.parse('$apiUrl/$_editingId'), headers: {'Content-Type': 'application/json', 'Accept': 'application/json'}, body: json.encode(bodyData)).timeout(const Duration(seconds: 5));
      }
      if (response.statusCode == 201 || response.statusCode == 200) {
        _clearForm(); setState(() => _editingId = null); _fetchTodaysEntries();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_editingId == null ? 'Entry Saved!' : 'Entry Updated!'), backgroundColor: const Color(0xFF2E7D32)));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connection failed.'), backgroundColor: Colors.red));
    } finally { setState(() => _isLoading = false); }
  }

  void _editEntry(InventoryItem item) {
    setState(() {
      _editingId = item.id; _selectedDate = item.date;
      _kgController.text = item.kg == 0 ? '' : item.kg.toString();
      _totalController.text = item.totalPacks.toString(); _displayController.text = item.displayPacks.toString();
      _rejectController.text = item.rejectedAmount.toString(); _rejectUnit = item.rejectedUnit;
      _balance = item.balancePacks;
      _currentPurchaseKg = item.purchaseKg; _currentPurchaseRM = item.purchaseRM; _currentSalesRM = item.salesRM;
    });
  }

  Future<void> _deleteEntry(int id) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Entry?'), content: const Text('Are you sure you want to permanently delete this record?'),
        actions: [ TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))) ],
      ),
    ) ?? false;

    if (confirm) {
      try {
        final response = await http.delete(Uri.parse('$apiUrl/$id')).timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) { _fetchTodaysEntries(); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Entry Deleted'))); }
      } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Delete failed.'))); }
    }
  }

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Center(
      // PC FRIENDLY CONSTRAINT
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Date: ${_formatDate(_selectedDate)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF2E7D32))),
                  OutlinedButton.icon(
                    onPressed: () => _pickDate(context), 
                    icon: const Icon(Icons.calendar_today, size: 18), 
                    label: const Text('Change'),
                    style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF2E7D32), side: const BorderSide(color: Color(0xFF2E7D32))),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              if (_editingId != null)
                Container(padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: const Color(0xFFFFCA28).withOpacity(0.3), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFFCA28))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('EDITING MODE', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFB00020))), IconButton(icon: const Icon(Icons.close), onPressed: () { setState(() => _editingId = null); _clearForm(); })])),

              TextField(controller: _kgController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Daily Processed (KG)', prefixIcon: Icon(Icons.scale))),
              const SizedBox(height: 16),
              TextField(controller: _totalController, keyboardType: TextInputType.number, onChanged: (val) => _calculateBalance(), decoration: const InputDecoration(labelText: 'Total Packs Created', prefixIcon: Icon(Icons.inventory_2))),
              const SizedBox(height: 16),
              TextField(controller: _displayController, keyboardType: TextInputType.number, onChanged: (val) => _calculateBalance(), decoration: const InputDecoration(labelText: 'Displayed Packs', prefixIcon: Icon(Icons.storefront))),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(flex: 2, child: TextField(controller: _rejectController, keyboardType: TextInputType.number, onChanged: (val) => _calculateBalance(), decoration: const InputDecoration(labelText: 'Rejected Amount', prefixIcon: Icon(Icons.delete_outline)))), 
                const SizedBox(width: 12), 
                Expanded(flex: 1, child: DropdownButtonFormField<String>(value: _rejectUnit, decoration: const InputDecoration(labelText: 'Unit'), items: ['Packs', 'Kg'].map((String value) => DropdownMenuItem<String>(value: value, child: Text(value))).toList(), onChanged: (newValue) => setState(() { _rejectUnit = newValue!; _calculateBalance(); })))
              ]),
              const SizedBox(height: 24),
              
              Container(
                padding: const EdgeInsets.all(20), 
                decoration: BoxDecoration(color: const Color(0xFF2E7D32), borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: const Color(0xFF2E7D32).withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))]), 
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                  children: [
                    const Text('Balance Packs:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)), 
                    Text('$_balance', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFFFFCA28)))
                  ]
                )
              ),
              const SizedBox(height: 24),
              
              SizedBox(width: double.infinity, height: 55, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: _editingId == null ? const Color(0xFF2E7D32) : const Color(0xFFF57C00)), onPressed: _isLoading ? null : _saveData, child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Text(_editingId == null ? 'SAVE DAILY ENTRY' : 'UPDATE ENTRY', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)))),
              const SizedBox(height: 32),
              
              const Text('Today\'s Records', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
              const Divider(thickness: 2),
              const SizedBox(height: 8),
              
              _todaysEntries.isEmpty ? const Padding(padding: EdgeInsets.all(16.0), child: Text("No entries for this date yet.", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey))) : ListView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: _todaysEntries.length, itemBuilder: (context, index) { 
                final item = _todaysEntries[index]; 
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: const CircleAvatar(backgroundColor: Color(0xFFF9FBE7), child: Icon(Icons.check_circle, color: Color(0xFF2E7D32))),
                    title: Text('${item.kg} kg | Total: ${item.totalPacks} | Display: ${item.displayPacks}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), 
                    subtitle: Text('Balance: ${item.balancePacks} | Rejected: ${item.rejectedAmount} ${item.rejectedUnit}'), 
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _editEntry(item)), IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteEntry(item.id))])
                  )
                ); 
              })
            ],
          ),
        ),
      ),
    );
  }
}

// --- 4. FINANCE PAGE ---
class FinancePage extends StatefulWidget {
  const FinancePage({Key? key}) : super(key: key);
  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> {
  DateTime _purchaseDate = DateTime.now();
  DateTime _salesDate = DateTime.now();

  final _kgController = TextEditingController(); 
  final _purchaseRmController = TextEditingController();
  final _salesPriceController = TextEditingController(text: '6.99');
  
  int _salesDisplayedPacks = 0;
  double _totalSalesCalculated = 0.0;
  bool _isLoading = false;

  InventoryItem? _currentPurchaseItem;
  InventoryItem? _currentSalesItem;

  @override
  void initState() {
    super.initState();
    _fetchPurchaseData();
    _fetchSalesData();
  }

  Future<InventoryItem?> _getFirstEntryForDate(DateTime date) async {
    try {
      final response = await http.get(Uri.parse(apiUrl)).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        List<InventoryItem> allData = data.map((json) => InventoryItem.fromJson(json)).toList();
        var dailyEntries = allData.where((item) => item.date.year == date.year && item.date.month == date.month && item.date.day == date.day).toList();
        if (dailyEntries.isNotEmpty) return dailyEntries.first;
      }
    } catch (e) { print(e); }
    return null;
  }

  Future<void> _fetchPurchaseData() async {
    InventoryItem? item = await _getFirstEntryForDate(_purchaseDate);
    setState(() {
      _currentPurchaseItem = item;
      _clearPurchaseForm();
    });
  }

  void _clearPurchaseForm() {
    _kgController.clear();
    _purchaseRmController.clear();
  }

  Future<void> _fetchSalesData() async {
    InventoryItem? item = await _getFirstEntryForDate(_salesDate);
    setState(() {
      _currentSalesItem = item;
      _salesDisplayedPacks = item?.displayPacks ?? 0;
      _calculateSales();
    });
  }

  void _calculateSales() {
    double price = double.tryParse(_salesPriceController.text) ?? 0.0;
    setState(() {
      _totalSalesCalculated = _salesDisplayedPacks * price;
    });
  }

  Future<void> _savePurchase() async {
    setState(() => _isLoading = true);
    double purchaseKg = double.tryParse(_kgController.text) ?? 0.0;
    double purchaseRm = double.tryParse(_purchaseRmController.text) ?? 0.0;
    
    try {
      if (_currentPurchaseItem != null) {
        Map<String, dynamic> body = _currentPurchaseItem!.toJson();
        body['purchase_kg'] = purchaseKg;
        body['purchase_rm'] = purchaseRm;
        await http.put(Uri.parse('$apiUrl/${_currentPurchaseItem!.id}'), headers: {'Content-Type': 'application/json'}, body: json.encode(body));
      } else {
        Map<String, dynamic> body = {
          'date': DateFormat('yyyy-MM-dd').format(_purchaseDate), 'kg': 0.0, 
          'purchase_kg': purchaseKg, 'purchase_rm': purchaseRm,
          'total_packs': 0, 'display_packs': 0, 'rejected_amount': 0, 'rejected_unit': 'Packs', 'balance_packs': 0, 'sales_rm': 0
        };
        await http.post(Uri.parse(apiUrl), headers: {'Content-Type': 'application/json'}, body: json.encode(body));
      }

      // Force UI to show new data immediately before fetching
      setState(() {
        if (_currentPurchaseItem != null) {
          _currentPurchaseItem = InventoryItem(
            id: _currentPurchaseItem!.id, date: _currentPurchaseItem!.date, kg: _currentPurchaseItem!.kg, purchaseKg: purchaseKg, totalPacks: _currentPurchaseItem!.totalPacks, displayPacks: _currentPurchaseItem!.displayPacks, rejectedAmount: _currentPurchaseItem!.rejectedAmount, rejectedUnit: _currentPurchaseItem!.rejectedUnit, balancePacks: _currentPurchaseItem!.balancePacks, purchaseRM: purchaseRm, salesRM: _currentPurchaseItem!.salesRM
          );
        }
      });

      await _fetchPurchaseData(); 
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Purchase Saved!'), backgroundColor: Color(0xFF2E7D32)));
    } catch (e) {
      print(e);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error saving purchase.'), backgroundColor: Colors.red));
    } finally { setState(() => _isLoading = false); }
  }

  Future<void> _deleteFin(int id, bool isPurchase) async {
    setState(() => _isLoading = true);
    var item = isPurchase ? _currentPurchaseItem : _currentSalesItem;
    if (item != null) {
      try {
        Map<String, dynamic> body = item.toJson();
        if (isPurchase) { body['purchase_kg'] = 0.0; body['purchase_rm'] = 0.0; } else { body['sales_rm'] = 0.0; }
        await http.put(Uri.parse('$apiUrl/${item.id}'), headers: {'Content-Type': 'application/json'}, body: json.encode(body));
        isPurchase ? await _fetchPurchaseData() : await _fetchSalesData();
      } catch (e) { print(e); }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveSales() async {
    if (_currentSalesItem == null) return;
    setState(() => _isLoading = true);
    
    try {
      Map<String, dynamic> body = _currentSalesItem!.toJson();
      body['sales_rm'] = _totalSalesCalculated;
      await http.put(Uri.parse('$apiUrl/${_currentSalesItem!.id}'), headers: {'Content-Type': 'application/json'}, body: json.encode(body));
      
      // Force UI to show new data immediately before fetching
      setState(() {
        _currentSalesItem = InventoryItem(
            id: _currentSalesItem!.id, date: _currentSalesItem!.date, kg: _currentSalesItem!.kg, purchaseKg: _currentSalesItem!.purchaseKg, totalPacks: _currentSalesItem!.totalPacks, displayPacks: _currentSalesItem!.displayPacks, rejectedAmount: _currentSalesItem!.rejectedAmount, rejectedUnit: _currentSalesItem!.rejectedUnit, balancePacks: _currentSalesItem!.balancePacks, purchaseRM: _currentSalesItem!.purchaseRM, salesRM: _totalSalesCalculated
        );
      });

      await _fetchSalesData(); 
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sales Saved!'), backgroundColor: Color(0xFF2E7D32)));
    } catch (e) {
      print(e);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error saving sales.'), backgroundColor: Colors.red));
    } finally { setState(() => _isLoading = false); }
  }

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ================= PURCHASE CARD =================
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.shopping_cart, color: Color(0xFF2E7D32)),
                          const SizedBox(width: 8),
                          const Text('Record Bulk Purchase', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
                        ],
                      ),
                      const Divider(height: 32, thickness: 1.5),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Date: ${_formatDate(_purchaseDate)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          TextButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(context: context, initialDate: _purchaseDate, firstDate: DateTime(2020), lastDate: DateTime(2101));
                              if (picked != null) { setState(() => _purchaseDate = picked); _fetchPurchaseData(); }
                            }, 
                            icon: const Icon(Icons.calendar_month, color: Color(0xFF2E7D32)), label: const Text('Change', style: TextStyle(color: Color(0xFF2E7D32)))
                          )
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(controller: _kgController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Stock Bought (KG)', prefixIcon: Icon(Icons.scale))),
                      const SizedBox(height: 16),
                      TextField(controller: _purchaseRmController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Total Cost (RM)', prefixIcon: Icon(Icons.attach_money))),
                      const SizedBox(height: 24),
                      SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: _isLoading ? null : _savePurchase, child: const Text('SAVE PURCHASE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))),
                      
                      if (_currentPurchaseItem != null && (_currentPurchaseItem!.purchaseKg > 0 || _currentPurchaseItem!.purchaseRM > 0)) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: const Color(0xFFF9FBE7), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF2E7D32).withOpacity(0.3))),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Stock: ${_currentPurchaseItem!.purchaseKg} KG', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 4),
                                  Text('Cost: RM ${_currentPurchaseItem!.purchaseRM.toStringAsFixed(2)}', style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.w600)),
                                ],
                              ),
                              Row(
                                children: [
                                  // REMOVED EDIT BUTTON HERE
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red), 
                                    onPressed: () => _deleteFin(_currentPurchaseItem!.id, true)
                                  ),
                                ],
                              )
                            ],
                          )
                        )
                      ]
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // ================= SALES CARD =================
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.trending_up, color: Color(0xFF2E7D32)),
                          const SizedBox(width: 8),
                          const Text('Record Daily Sales', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
                        ],
                      ),
                      const Divider(height: 32, thickness: 1.5),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Date: ${_formatDate(_salesDate)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          TextButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(context: context, initialDate: _salesDate, firstDate: DateTime(2020), lastDate: DateTime(2101));
                              if (picked != null) { setState(() => _salesDate = picked); _fetchSalesData(); }
                            }, 
                            icon: const Icon(Icons.calendar_month, color: Color(0xFF2E7D32)), label: const Text('Change', style: TextStyle(color: Color(0xFF2E7D32)))
                          )
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: const Color(0xFFFFCA28).withOpacity(0.2), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFFCA28))),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Packs Displayed:', style: TextStyle(fontSize: 16)),
                            Text('$_salesDisplayedPacks', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF2E7D32))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(controller: _salesPriceController, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (val) => _calculateSales(), decoration: const InputDecoration(labelText: 'Price Per Pack (RM)', prefixIcon: Icon(Icons.sell))),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Revenue:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('RM ${_totalSalesCalculated.toStringAsFixed(2)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF2E7D32))),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFCA28), foregroundColor: const Color(0xFF2E7D32)), onPressed: _isLoading ? null : _saveSales, child: const Text('SAVE SALES', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))),

                      if (_currentSalesItem != null && _currentSalesItem!.salesRM > 0) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF2E7D32).withOpacity(0.3))),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Recorded Revenue', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 4),
                                  Text('Total: RM ${_currentSalesItem!.salesRM.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.w600)),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red), 
                                onPressed: () => _deleteFin(_currentSalesItem!.id, false)
                              ),
                            ],
                          )
                        )
                      ]
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- 5. SUMMARY PAGE ---
class SummaryPage extends StatefulWidget {
  const SummaryPage({Key? key}) : super(key: key);
  @override
  State<SummaryPage> createState() => _SummaryPageState();
}

class _SummaryPageState extends State<SummaryPage> {
  String _filterType = 'Range'; 
  DateTime _selectedDate = DateTime.now();
  DateTimeRange? _selectedRange = DateTimeRange(start: DateTime.now().subtract(const Duration(days: 7)), end: DateTime.now());

  Future<List<InventoryItem>> _fetchData() async {
    final response = await http.get(Uri.parse(apiUrl)).timeout(const Duration(seconds: 5));
    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      return data.map((json) => InventoryItem.fromJson(json)).toList();
    } else { throw Exception('Failed to load data'); }
  }

  String _formatShortDate(DateTime d) => '${d.day} ${_getMonthString(d.month)}';
  String _getMonthString(int month) => const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][month - 1];

  Future<void> _pickFilterDate() async {
    if (_filterType == 'Day' || _filterType == 'Month') {
      final DateTime? picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2101));
      if (picked != null) setState(() => _selectedDate = picked);
    } else if (_filterType == 'Range') {
      final DateTimeRange? picked = await showDateRangePicker(
        context: context, 
        firstDate: DateTime(2020), 
        lastDate: DateTime(2101), 
        initialDateRange: _selectedRange,
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(primary: Color(0xFF2E7D32), onPrimary: Colors.white, onSurface: Colors.black),
            ),
            child: child!,
          );
        },
      );
      if (picked != null) setState(() => _selectedRange = picked);
    }
  }

  List<InventoryItem> _filterData(List<InventoryItem> allData) {
    return allData.where((item) {
      if (_filterType == 'Day') return item.date.year == _selectedDate.year && item.date.month == _selectedDate.month && item.date.day == _selectedDate.day;
      else if (_filterType == 'Month') return item.date.year == _selectedDate.year && item.date.month == _selectedDate.month;
      else if (_filterType == 'Range' && _selectedRange != null) {
        DateTime itemDay = DateTime(item.date.year, item.date.month, item.date.day);
        DateTime start = DateTime(_selectedRange!.start.year, _selectedRange!.start.month, _selectedRange!.start.day);
        DateTime end = DateTime(_selectedRange!.end.year, _selectedRange!.end.month, _selectedRange!.end.day);
        return (itemDay.isAtSameMomentAs(start) || itemDay.isAfter(start)) && (itemDay.isAtSameMomentAs(end) || itemDay.isBefore(end));
      }
      return false;
    }).toList();
  }

  Future<void> _generatePdf(Map<String, Map<String, dynamic>> dailyTotals, double tKg, int tPacks, int tDisplay, int tBalance, double tPurchase, double tSales, double tProfit) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Center(child: pw.Text('SUMMARY OF NANGKA SALES', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold))),
            pw.SizedBox(height: 20),
            ...dailyTotals.entries.map((e) {
              double dProfit = e.value['sales'] - e.value['purchase'];
              return _buildPdfBlock(e.key, e.value['kg'], e.value['packs'], e.value['display'], e.value['balance'], e.value['purchase'], e.value['sales'], dProfit);
            }).toList(),
            pw.SizedBox(height: 20),
            _buildPdfBlock('TOTAL', tKg, tPacks, tDisplay, tBalance, tPurchase, tSales, tProfit, isTotal: true),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Nangka_Summary.pdf'
    );
  }

  pw.Widget _buildPdfBlock(String title, double kg, int packs, int display, int balance, double purchase, double sales, double profit, {bool isTotal = false}) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: isTotal ? PdfColors.grey200 : PdfColors.white,
        border: pw.Border.all(color: isTotal ? PdfColors.blueGrey : PdfColors.grey400, width: isTotal ? 2 : 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.Divider(),
          _buildPdfRow('Daily Kg', kg.toStringAsFixed(kg == kg.roundToDouble() ? 0 : 2)),
          _buildPdfRow('Packs', '$packs'),
          _buildPdfRow('Display', '$display'),
          _buildPdfRow('Balance', '$balance'),
          if (isTotal) _buildPdfRow('Purchase Cost', purchase.toStringAsFixed(0)),
          _buildPdfRow('Sales', sales.toStringAsFixed(0)),
          if (isTotal) _buildPdfRow('Profit/Loss', profit >= 0 ? '+${profit.toStringAsFixed(0)}' : profit.toStringAsFixed(0), isProfit: true, profitValue: profit),
        ],
      ),
    );
  }

  pw.Widget _buildPdfRow(String label, String value, {bool isProfit = false, double profitValue = 0}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 12)),
          pw.Text(
            value, 
            style: pw.TextStyle(
              fontSize: 12, 
              fontWeight: pw.FontWeight.bold,
              color: isProfit ? (profitValue >= 0 ? PdfColors.green700 : PdfColors.red700) : PdfColors.black,
            )
          ),
        ],
      ),
    );
  }

  Widget _buildDataRow(String label, String value, {Color? valueColor, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween, 
        children: [
          Text(label, style: TextStyle(fontSize: 15, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: Colors.grey[700])), 
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: valueColor ?? Colors.black87))
        ]
      ),
    );
  }

  Widget _buildSummaryBlock(String title, double kg, int packs, int display, int balance, double purchase, double sales, double profit, {bool isTotal = false}) {
    return Card(
      elevation: isTotal ? 6 : 2,
      color: isTotal ? const Color(0xFFF9FBE7) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isTotal ? const Color(0xFF2E7D32) : Colors.transparent, width: isTotal ? 2 : 0)
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isTotal ? Icons.stars : Icons.insert_chart, color: const Color(0xFF2E7D32)),
                const SizedBox(width: 8),
                Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isTotal ? const Color(0xFF2E7D32) : Colors.black87)),
              ],
            ),
            const Divider(height: 24, thickness: 1.5),
            _buildDataRow('Daily Kg processed', kg.toStringAsFixed(kg == kg.roundToDouble() ? 0 : 2)), 
            _buildDataRow('Total Packs', '$packs'), 
            _buildDataRow('Displayed Packs', '$display'),
            _buildDataRow('Balance Packs', '$balance'), 
            if (isTotal) _buildDataRow('Total Purchase Cost', 'RM ${purchase.toStringAsFixed(2)}', valueColor: Colors.red[700]), 
            _buildDataRow('Total Sales Revenue', 'RM ${sales.toStringAsFixed(2)}', valueColor: const Color(0xFF2E7D32)),
            if (isTotal) ...[
              const Divider(height: 24, thickness: 1.5),
              _buildDataRow('NET PROFIT / LOSS', profit >= 0 ? '+RM ${profit.toStringAsFixed(2)}' : 'RM ${profit.toStringAsFixed(2)}', valueColor: profit >= 0 ? const Color(0xFF2E7D32) : Colors.red, isBold: true),
            ]
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<InventoryItem>>(
      future: _fetchData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)));
        if (snapshot.hasError) return Center(child: Text('Database Error.\nPlease check your connection.', textAlign: TextAlign.center, style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.bold)));

        List<InventoryItem> filteredData = _filterData(snapshot.data ?? []);
        
        // --- ADDED SORTING: Forces Chronological Order ---
        filteredData.sort((a, b) => a.date.compareTo(b.date));
        
        Map<String, Map<String, dynamic>> dailyTotals = {};
        for (var item in filteredData) {
          String dStr = _formatShortDate(item.date);
          if (!dailyTotals.containsKey(dStr)) dailyTotals[dStr] = {'kg': 0.0, 'packs': 0, 'display': 0, 'balance': 0, 'purchase': 0.0, 'sales': 0.0};
          dailyTotals[dStr]!['kg'] += item.kg; dailyTotals[dStr]!['packs'] += item.totalPacks; dailyTotals[dStr]!['display'] += item.displayPacks;
          dailyTotals[dStr]!['balance'] += item.balancePacks; dailyTotals[dStr]!['purchase'] += item.purchaseRM; dailyTotals[dStr]!['sales'] += item.salesRM;
        }

        double tKg = filteredData.fold(0, (sum, item) => sum + item.kg);
        int tPacks = filteredData.fold(0, (sum, item) => sum + item.totalPacks);
        int tDisplay = filteredData.fold(0, (sum, item) => sum + item.displayPacks);
        int tBalance = filteredData.fold(0, (sum, item) => sum + item.balancePacks);
        double tPurchase = filteredData.fold(0, (sum, item) => sum + item.purchaseRM);
        double tSales = filteredData.fold(0, (sum, item) => sum + item.salesRM);
        double tProfit = tSales - tPurchase;

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
                    child: Row(
                      children: [
                        const Icon(Icons.filter_alt, color: Color(0xFF2E7D32)),
                        const SizedBox(width: 12),
                        const Text('Filter:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _filterType, 
                              isExpanded: true,
                              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF2E7D32)),
                              items: ['Day', 'Month', 'Range'].map((String value) => DropdownMenuItem<String>(value: value, child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(), 
                              onChanged: (newValue) => setState(() { _filterType = newValue!; })
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _pickFilterDate, 
                          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), backgroundColor: const Color(0xFFFFCA28), foregroundColor: const Color(0xFF2E7D32)),
                          child: const Text('Set Date')
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  if (filteredData.isEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 40),
                      padding: const EdgeInsets.all(32.0), 
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        children: [
                          Icon(Icons.inbox, size: 60, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          const Text('No records found for this period.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                        ],
                      )
                    )
                  else
                    ...dailyTotals.entries.map((e) {
                      double dProfit = e.value['sales'] - e.value['purchase'];
                      return _buildSummaryBlock(e.key, e.value['kg'], e.value['packs'], e.value['display'], e.value['balance'], e.value['purchase'], e.value['sales'], dProfit);
                    }).toList(),

                  if (filteredData.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildSummaryBlock('GRAND TOTAL', tKg, tPacks, tDisplay, tBalance, tPurchase, tSales, tProfit, isTotal: true),
                    const SizedBox(height: 32),
                    SizedBox(
                      height: 55,
                      child: ElevatedButton.icon(
                        onPressed: () => _generatePdf(dailyTotals, tKg, tPacks, tDisplay, tBalance, tPurchase, tSales, tProfit), 
                        icon: const Icon(Icons.picture_as_pdf), 
                        label: const Text('EXPORT AS PDF', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1))
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}