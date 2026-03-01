import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

const String apiUrl = 'https://nangka-api.onrender.com/api/inventories';

void main() {
  runApp(const NangkaApp());
}

class NangkaApp extends StatelessWidget {
  const NangkaApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Nangka Inventory',
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: Colors.grey[100],
      ),
      home: const LoginPage(),
    );
  }
}

// --- DATA MODEL ---
class InventoryItem {
  final int id;
  final DateTime date;
  final double kg;
  final double purchaseKg; // NEW COLUMN
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

  void _login() {
    if (_usernameController.text == 'admin' && _passwordController.text == 'admin') {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainDashboard()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Use admin / admin')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/nangka-logo.png', height: 120),
              const SizedBox(height: 24),
              const Text('Nangka Management System', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),
              TextField(controller: _usernameController, decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              TextField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder())),
              const SizedBox(height: 24),
              SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: _login, child: const Text('Log In', style: TextStyle(fontSize: 18)))),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const Padding(
        padding: EdgeInsets.all(8.0),
        child: Text('© nsrnshr 2026', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),
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
  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      EntryPage(key: UniqueKey()),
      FinancePage(key: UniqueKey()),
      SummaryPage(key: UniqueKey())
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nangka System'),
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage())))],
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.add_box), label: 'Entry'),
          BottomNavigationBarItem(icon: Icon(Icons.attach_money), label: 'Finance'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Summary')
        ],
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

  // Hidden financial variables to preserve data when editing
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
    final DateTime? picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2101));
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
    _kgController.clear();
    _totalController.clear(); 
    _displayController.clear(); 
    _rejectController.clear();
    _currentPurchaseKg = 0.0;
    _currentPurchaseRM = 0.0; 
    _currentSalesRM = 0.0;
    _calculateBalance();
  }

  Future<void> _saveData() async {
    setState(() => _isLoading = true);
    Map<String, dynamic> bodyData = {
      'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
      'kg': double.tryParse(_kgController.text) ?? 0.0,
      'purchase_kg': _currentPurchaseKg, // PRESERVE
      'total_packs': int.tryParse(_totalController.text) ?? 0,
      'display_packs': int.tryParse(_displayController.text) ?? 0,
      'rejected_amount': int.tryParse(_rejectController.text) ?? 0,
      'rejected_unit': _rejectUnit,
      'balance_packs': _balance,
      'purchase_rm': _currentPurchaseRM, // PRESERVE
      'sales_rm': _currentSalesRM, // PRESERVE
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
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_editingId == null ? 'Entry Saved!' : 'Entry Updated!')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connection failed.')));
    } finally { setState(() => _isLoading = false); }
  }

  void _editEntry(InventoryItem item) {
    setState(() {
      _editingId = item.id; _selectedDate = item.date;
      _kgController.text = item.kg == 0 ? '' : item.kg.toString();
      _totalController.text = item.totalPacks.toString(); _displayController.text = item.displayPacks.toString();
      _rejectController.text = item.rejectedAmount.toString(); _rejectUnit = item.rejectedUnit;
      _balance = item.balancePacks;
      
      // Preserve hidden finance data
      _currentPurchaseKg = item.purchaseKg;
      _currentPurchaseRM = item.purchaseRM;
      _currentSalesRM = item.salesRM;
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Date: ${_formatDate(_selectedDate)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(onPressed: () => _pickDate(context), icon: const Icon(Icons.calendar_today), label: const Text('Change')),
            ],
          ),
          const Divider(height: 32, thickness: 2),
          
          if (_editingId != null)
            Container(padding: const EdgeInsets.all(8), margin: const EdgeInsets.only(bottom: 16), color: Colors.orange[100], child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('EDITING MODE', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)), IconButton(icon: const Icon(Icons.close), onPressed: () { setState(() => _editingId = null); _clearForm(); })])),

          TextField(controller: _kgController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (KG)', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _totalController, keyboardType: TextInputType.number, onChanged: (val) => _calculateBalance(), decoration: const InputDecoration(labelText: 'Total Packs', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _displayController, keyboardType: TextInputType.number, onChanged: (val) => _calculateBalance(), decoration: const InputDecoration(labelText: 'Display Packs', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          Row(children: [Expanded(flex: 2, child: TextField(controller: _rejectController, keyboardType: TextInputType.number, onChanged: (val) => _calculateBalance(), decoration: const InputDecoration(labelText: 'Rejected Amount', border: OutlineInputBorder()))), const SizedBox(width: 12), Expanded(flex: 1, child: DropdownButtonFormField<String>(value: _rejectUnit, decoration: const InputDecoration(border: OutlineInputBorder()), items: ['Packs', 'Kg'].map((String value) => DropdownMenuItem<String>(value: value, child: Text(value))).toList(), onChanged: (newValue) => setState(() { _rejectUnit = newValue!; _calculateBalance(); })))]),
          const SizedBox(height: 24),
          Container(padding: const EdgeInsets.all(16), color: Colors.green[50], child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Balance Packs:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), Text('$_balance', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green))])),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: _editingId == null ? Colors.green : Colors.orange), onPressed: _isLoading ? null : _saveData, child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Text(_editingId == null ? 'Save Entry' : 'Update Entry', style: const TextStyle(fontSize: 18)))),
          const SizedBox(height: 32),
          const Text('Today\'s Entries', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _todaysEntries.isEmpty ? const Padding(padding: EdgeInsets.all(16.0), child: Text("No entries for this date yet.", style: TextStyle(fontStyle: FontStyle.italic))) : ListView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: _todaysEntries.length, itemBuilder: (context, index) { 
            final item = _todaysEntries[index]; 
            return Card(
              child: ListTile(
                title: Text('${item.kg} kg | Total: ${item.totalPacks} | Display: ${item.displayPacks} | Balance: ${item.balancePacks}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), 
                subtitle: Text('Rejected: ${item.rejectedAmount} ${item.rejectedUnit}'), 
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _editEntry(item)), IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteEntry(item.id))])
              )
            ); 
          })
        ],
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

  final _kgController = TextEditingController(); // This now explicitly links to purchase_kg
  final _purchaseRmController = TextEditingController();
  final _salesPriceController = TextEditingController(text: '6.99');
  
  int _salesDisplayedPacks = 0;
  double _totalSalesCalculated = 0.0;
  bool _isLoading = false;

  // Track the actual items for the bottom lists
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
    
    InventoryItem? item = await _getFirstEntryForDate(_purchaseDate);
    try {
      if (item != null) {
        Map<String, dynamic> body = item.toJson();
        body['purchase_kg'] = purchaseKg;
        body['purchase_rm'] = purchaseRm;
        await http.put(Uri.parse('$apiUrl/${item.id}'), headers: {'Content-Type': 'application/json'}, body: json.encode(body));
      } else {
        Map<String, dynamic> body = {
          'date': DateFormat('yyyy-MM-dd').format(_purchaseDate), 'kg': 0.0, 
          'purchase_kg': purchaseKg, 'purchase_rm': purchaseRm,
          'total_packs': 0, 'display_packs': 0, 'rejected_amount': 0, 'rejected_unit': 'Packs', 'balance_packs': 0, 'sales_rm': 0
        };
        await http.post(Uri.parse(apiUrl), headers: {'Content-Type': 'application/json'}, body: json.encode(body));
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Purchase Saved!')));
      _fetchPurchaseData(); // Refresh list
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error saving purchase.')));
    } finally { setState(() => _isLoading = false); }
  }

  // Deletes just reset the financial values to 0 to protect daily entry data
  Future<void> _deletePurchase(InventoryItem item) async {
    setState(() => _isLoading = true);
    try {
      Map<String, dynamic> body = item.toJson();
      body['purchase_kg'] = 0.0;
      body['purchase_rm'] = 0.0;
      await http.put(Uri.parse('$apiUrl/${item.id}'), headers: {'Content-Type': 'application/json'}, body: json.encode(body));
      _fetchPurchaseData();
    } catch (e) { print(e); }
    setState(() => _isLoading = false);
  }

  Future<void> _saveSales() async {
    setState(() => _isLoading = true);
    InventoryItem? item = await _getFirstEntryForDate(_salesDate);
    
    if (item != null) {
      try {
        Map<String, dynamic> body = item.toJson();
        body['sales_rm'] = _totalSalesCalculated;
        await http.put(Uri.parse('$apiUrl/${item.id}'), headers: {'Content-Type': 'application/json'}, body: json.encode(body));
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sales Saved!')));
        _fetchSalesData(); // Refresh list
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error saving sales.')));
      }
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No entry found for this date. Please create an entry first.')));
    }
    setState(() => _isLoading = false);
  }

  Future<void> _deleteSales(InventoryItem item) async {
    setState(() => _isLoading = true);
    try {
      Map<String, dynamic> body = item.toJson();
      body['sales_rm'] = 0.0;
      await http.put(Uri.parse('$apiUrl/${item.id}'), headers: {'Content-Type': 'application/json'}, body: json.encode(body));
      _fetchSalesData();
    } catch (e) { print(e); }
    setState(() => _isLoading = false);
  }

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ================= PURCHASE CARD =================
          Card(
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Record Purchase', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Date: ${_formatDate(_purchaseDate)}', style: const TextStyle(fontSize: 16)),
                      TextButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(context: context, initialDate: _purchaseDate, firstDate: DateTime(2020), lastDate: DateTime(2101));
                          if (picked != null) { setState(() => _purchaseDate = picked); _fetchPurchaseData(); }
                        }, 
                        icon: const Icon(Icons.calendar_month), label: const Text('Change')
                      )
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(controller: _kgController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Stock Bought (KG)', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(controller: _purchaseRmController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Purchase Price (RM)', border: OutlineInputBorder())),
                  const SizedBox(height: 16),
                  SizedBox(width: double.infinity, height: 45, child: ElevatedButton(onPressed: _isLoading ? null : _savePurchase, child: const Text('Save Purchase'))),
                  
                  // DISPLAY SAVED PURCHASE BELOW BOX
                  if (_currentPurchaseItem != null && (_currentPurchaseItem!.purchaseKg > 0 || _currentPurchaseItem!.purchaseRM > 0)) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.blueGrey[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blueGrey.shade200)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Stock Bought: ${_currentPurchaseItem!.purchaseKg} KG', style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text('Cost: RM ${_currentPurchaseItem!.purchaseRM.toStringAsFixed(2)}', style: TextStyle(color: Colors.blueGrey[700])),
                            ],
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue, size: 20), 
                                onPressed: () {
                                  setState(() {
                                    _kgController.text = _currentPurchaseItem!.purchaseKg.toString();
                                    _purchaseRmController.text = _currentPurchaseItem!.purchaseRM.toString();
                                  });
                                }
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red, size: 20), 
                                onPressed: () => _deletePurchase(_currentPurchaseItem!)
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
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Record Sales', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Date: ${_formatDate(_salesDate)}', style: const TextStyle(fontSize: 16)),
                      TextButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(context: context, initialDate: _salesDate, firstDate: DateTime(2020), lastDate: DateTime(2101));
                          if (picked != null) { setState(() => _salesDate = picked); _fetchSalesData(); }
                        }, 
                        icon: const Icon(Icons.calendar_month), label: const Text('Change')
                      )
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                    child: Text('Displayed Packs: $_salesDisplayedPacks', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: _salesPriceController, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (val) => _calculateSales(), decoration: const InputDecoration(labelText: 'Price Per Pack (RM)', border: OutlineInputBorder())),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Sales:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('RM ${_totalSalesCalculated.toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(width: double.infinity, height: 45, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green), onPressed: _isLoading ? null : _saveSales, child: const Text('Save Sales'))),

                  // DISPLAY SAVED SALES BELOW BOX
                  if (_currentSalesItem != null && _currentSalesItem!.salesRM > 0) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.shade200)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Sales Recorded', style: TextStyle(fontWeight: FontWeight.bold)),
                              Text('Total: RM ${_currentSalesItem!.salesRM.toStringAsFixed(2)}', style: TextStyle(color: Colors.green[800])),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red, size: 20), 
                            onPressed: () => _deleteSales(_currentSalesItem!)
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
      final DateTimeRange? picked = await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2101), initialDateRange: _selectedRange);
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

  Widget _buildDataRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(fontSize: 15)), Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: valueColor ?? Colors.black87))]),
    );
  }

  Widget _buildSummaryBlock(String title, double kg, int packs, int display, int balance, double purchase, double sales, double profit, {bool isTotal = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: isTotal ? Colors.blueGrey[50] : Colors.white, border: Border.all(color: isTotal ? Colors.blueGrey : Colors.grey.shade300, width: isTotal ? 2 : 1), borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isTotal ? Colors.black : Colors.blueGrey[800])), const Divider(thickness: 1),
          _buildDataRow('Daily Kg', kg.toStringAsFixed(kg == kg.roundToDouble() ? 0 : 2)), 
          _buildDataRow('Packs', '$packs'), 
          _buildDataRow('Display', '$display'),
          _buildDataRow('Balance', '$balance'), 
          if (isTotal) _buildDataRow('Purchase Cost', purchase.toStringAsFixed(0)), 
          _buildDataRow('Sales', sales.toStringAsFixed(0)),
          if (isTotal) _buildDataRow('Profit/Loss', profit >= 0 ? '+${profit.toStringAsFixed(0)}' : profit.toStringAsFixed(0), valueColor: profit >= 0 ? Colors.green : Colors.red),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<InventoryItem>>(
      future: _fetchData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('Error connecting to Database: ${snapshot.error}', textAlign: TextAlign.center));

        List<InventoryItem> filteredData = _filterData(snapshot.data ?? []);
        
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

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Text('Filter By: ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  DropdownButton<String>(value: _filterType, items: ['Day', 'Month', 'Range'].map((String value) => DropdownMenuItem<String>(value: value, child: Text(value))).toList(), onChanged: (newValue) => setState(() { _filterType = newValue!; })),
                  const Spacer(),
                  ElevatedButton(onPressed: _pickFilterDate, child: const Text('Select Date(s)')),
                ],
              ),
              const SizedBox(height: 16),
              const Text('SUMMARY OF NANGKA SALES', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              if (filteredData.isEmpty)
                const Center(child: Padding(padding: EdgeInsets.all(32.0), child: Text('No data found in database for this period.')))
              else
                ...dailyTotals.entries.map((e) {
                  double dProfit = e.value['sales'] - e.value['purchase'];
                  return _buildSummaryBlock(e.key, e.value['kg'], e.value['packs'], e.value['display'], e.value['balance'], e.value['purchase'], e.value['sales'], dProfit);
                }).toList(),

              if (filteredData.isNotEmpty) _buildSummaryBlock('TOTAL', tKg, tPacks, tDisplay, tBalance, tPurchase, tSales, tProfit, isTotal: true),
              
              const SizedBox(height: 24),
              if (filteredData.isNotEmpty)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                  onPressed: () {
                    _generatePdf(dailyTotals, tKg, tPacks, tDisplay, tBalance, tPurchase, tSales, tProfit);
                  }, 
                  icon: const Icon(Icons.picture_as_pdf), 
                  label: const Text('Export & Download PDF', style: TextStyle(fontSize: 16))
                ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }
}