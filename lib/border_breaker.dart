import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class BorderBreakerPage extends StatefulWidget {
  final Map<String, dynamic> filterCriteria;
  const BorderBreakerPage({super.key, required this.filterCriteria});

  @override
  State<BorderBreakerPage> createState() => _BorderBreakerPageState();
}

class _BorderBreakerPageState extends State<BorderBreakerPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _lots = [];
  List<Map<String, dynamic>> _demands = [];
  
  final _cropController = TextEditingController();
  final _targetController = TextEditingController();
  final _gradeController = TextEditingController();
  final _marketController = TextEditingController();
  
  // New Controllers for Buyer details
  final _buyerNameController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _buyerPhoneController = TextEditingController();
  final _deadlineController = TextEditingController(text: "14"); // Default 14 days

  final _scrollController = ScrollController();
  final GlobalKey _formKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final lotsResponse = await Supabase.instance.client
          .from('export_lots')
          .select('*, profiles(*), export_pledges(*, profiles(*))')
          .order('created_at', ascending: false);

      final demandsResponse = await Supabase.instance.client
          .from('global_demands')
          .select('*')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _lots = List<Map<String, dynamic>>.from(lotsResponse);
          _demands = List<Map<String, dynamic>>.from(demandsResponse);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _fillFromDemand(Map<String, dynamic> demand) {
    setState(() {
      _cropController.text = demand['crop_needed'] ?? "";
      _targetController.text = demand['quantity_required_kg']?.toString() ?? "";
      _marketController.text = demand['country'] ?? "";
      _gradeController.text = demand['quality_specs'] ?? "Grade A";
      
      // Auto-fill buyer details from the demand
      _buyerNameController.text = demand['buyer_name'] ?? "";
      _companyNameController.text = demand['company_name'] ?? "";
      _buyerPhoneController.text = demand['phone'] ?? "";
    });
    
    // Smooth scroll to the form
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _formKey.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(seconds: 1),
          curve: Curves.easeInOut,
        );
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Auto-filled buyer & demand from ${demand['company_name']}"),
        backgroundColor: const Color(0xFF1E3A8A),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _createLot() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    if (_cropController.text.isEmpty || _targetController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all required fields")));
      return;
    }

    setState(() => _isLoading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final int days = int.tryParse(_deadlineController.text) ?? 7;
      final deadline = DateTime.now().add(Duration(days: days));

      await Supabase.instance.client.from('export_lots').insert({
        'creator_id': user.id,
        'crop_name': _cropController.text.trim(),
        'target_quantity_kg': double.tryParse(_targetController.text) ?? 1000.0,
        'quality_grade': _gradeController.text.trim().isEmpty ? "Grade A" : _gradeController.text.trim(),
        'destination_market': _marketController.text.trim().isEmpty ? "Global Market" : _marketController.text.trim(),
        'buyer_name': _buyerNameController.text.trim(),
        'company_name': _companyNameController.text.trim(),
        'buyer_phone': _buyerPhoneController.text.trim(),
        'deadline': deadline.toIso8601String(),
        'status': 'open',
      });

      _cropController.clear();
      _targetController.clear();
      _gradeController.clear();
      _marketController.clear();
      _buyerNameController.clear();
      _companyNameController.clear();
      _buyerPhoneController.clear();

      if (!mounted) return;
      await _fetchData();
      messenger.showSnackBar(const SnackBar(content: Text("Global Export Lot Created!"), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) messenger.showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _editTarget(Map<String, dynamic> lot) async {
    final editController = TextEditingController(text: lot['target_quantity_kg'].toString());
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Adjust Export Target", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: editController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          decoration: InputDecoration(
            labelText: "New Target (kg)",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              double newVal = double.tryParse(editController.text) ?? 0.0;
              if (newVal <= 0) return;
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(context);
              
              setState(() => _isLoading = true);
              try {
                await Supabase.instance.client
                    .from('export_lots')
                    .update({'target_quantity_kg': newVal})
                    .eq('id', lot['id']);
                if (!mounted) return;
                await _fetchData();
              } catch (e) {
                if (mounted) messenger.showSnackBar(SnackBar(content: Text("Update error: $e"), backgroundColor: Colors.red));
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A), foregroundColor: Colors.white),
            child: const Text("Update"),
          ),
        ],
      ),
    );
  }

  void _generatePass(Map<String, dynamic> lot) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        child: Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0xFF1E3A8A), width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.verified_rounded, color: Colors.green, size: 80),
              const SizedBox(height: 16),
              Text("Digital Export Pass", style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF1E3A8A))),
              Text("VERIFIED BY AGROVIA GLOBAL", style: GoogleFonts.outfit(fontSize: 10, letterSpacing: 2, color: Colors.grey)),
              const Divider(height: 40),
              _passRow("Lot ID", lot['id'].toString().substring(0, 8).toUpperCase()),
              _passRow("Crop", lot['crop_name']),
              _passRow("Market", lot['destination_market']),
              _passRow("Weight", "${lot['target_quantity_kg']} kg"),
              _passRow("Exporters", "${(lot['export_pledges'] as List).length} Farmers"),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(15)),
                child: Row(
                  children: [
                    const Icon(Icons.qr_code_2_rounded, size: 50),
                    const SizedBox(width: 12),
                    Expanded(child: Text("This pass is digitally signed and valid for international customs clearance.", style: GoogleFonts.outfit(fontSize: 10))),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: const Text("Download PDF Pass"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _passRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.outfit(color: Colors.grey[600], fontSize: 13)),
          Text(value, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Future<void> _showPostDemandDialog() async {
    final buyerNameController = TextEditingController();
    final companyNameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final cropController = TextEditingController();
    final qtyController = TextEditingController();
    final priceController = TextEditingController();
    final countryController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Post Global Demand", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _inputField(buyerNameController, "Your Name", Icons.person),
              const SizedBox(height: 8),
              _inputField(companyNameController, "Company Name", Icons.business),
              const SizedBox(height: 8),
              _inputField(phoneController, "Contact Phone", Icons.phone),
              const SizedBox(height: 8),
              _inputField(emailController, "Contact Email", Icons.email),
              const SizedBox(height: 8),
              _inputField(cropController, "Crop Needed", Icons.grass),
              const SizedBox(height: 8),
              _inputField(qtyController, "Quantity (kg)", Icons.bolt, isNumeric: true),
              const SizedBox(height: 8),
              _inputField(priceController, "Offered Price (e.g. \$2/kg)", Icons.payments),
              const SizedBox(height: 8),
              _inputField(countryController, "Target Market (e.g. Dubai)", Icons.public),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (buyerNameController.text.isEmpty || cropController.text.isEmpty) return;
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(context);
              setState(() => _isLoading = true);
              try {
                await Supabase.instance.client.from('global_demands').insert({
                  'buyer_name': buyerNameController.text.trim(),
                  'company_name': companyNameController.text.trim(),
                  'phone': phoneController.text.trim(),
                  'email': emailController.text.trim(),
                  'crop_needed': cropController.text.trim(),
                  'quantity_required_kg': double.tryParse(qtyController.text) ?? 1000,
                  'offered_price_usd': priceController.text.trim(),
                  'country': countryController.text.trim(),
                });
                await _fetchData();
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
                }
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A), foregroundColor: Colors.white),
            child: const Text("Post Demand"),
          ),
        ],
      ),
    );
  }

  Future<void> _pledgeStock(Map<String, dynamic> lot) async {
    final quantityController = TextEditingController();
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please login to pledge"), backgroundColor: Colors.orange));
       return;
    }

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: Text("Pledge Your Stock", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("How much ${lot['crop_name']} do you have ready?", style: GoogleFonts.outfit(fontSize: 14)),
            const SizedBox(height: 16),
            TextField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: InputDecoration(
                labelText: "Quantity (kg)",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              double quantity = double.tryParse(quantityController.text) ?? 0.0;
              if (quantity <= 0) return;
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(context);
              
              setState(() => _isLoading = true);
              try {
                await Supabase.instance.client.from('export_pledges').insert({
                  'lot_id': lot['id'],
                  'farmer_id': user.id,
                  'pledged_quantity_kg': quantity,
                });
                if (!mounted) return;
                await _fetchData();
                messenger.showSnackBar(const SnackBar(content: Text("Stock Pledged to Global Lot!"), backgroundColor: Colors.green));
              } catch (e) {
                if (mounted) messenger.showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A), foregroundColor: Colors.white),
            child: const Text("Confirm Pledge"),
          ),
        ],
      ),
    );
  }

  Future<void> _editPledge(Map<String, dynamic> pledge) async {
    final quantityController = TextEditingController(text: pledge['pledged_quantity_kg'].toString());
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: Text("Edit Your Pledge", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: quantityController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          decoration: InputDecoration(
            labelText: "New Quantity (kg)",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _removePledge(pledge);
            }, 
            child: const Text("Remove Pledge", style: TextStyle(color: Colors.red))
          ),
          ElevatedButton(
            onPressed: () async {
              double newVal = double.tryParse(quantityController.text) ?? 0.0;
              if (newVal <= 0) return;
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(context);
              
              setState(() => _isLoading = true);
              try {
                await Supabase.instance.client
                    .from('export_pledges')
                    .update({'pledged_quantity_kg': newVal})
                    .eq('id', pledge['id']);
                if (!mounted) return;
                await _fetchData();
                messenger.showSnackBar(const SnackBar(content: Text("Pledge Updated!"), backgroundColor: Colors.blue));
              } catch (e) {
                if (mounted) messenger.showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A), foregroundColor: Colors.white),
            child: const Text("Update"),
          ),
        ],
      ),
    );
  }

  Future<void> _removePledge(Map<String, dynamic> pledge) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client
          .from('export_pledges')
          .delete()
          .eq('id', pledge['id']);
      if (!mounted) return;
      await _fetchData();
      messenger.showSnackBar(const SnackBar(content: Text("Pledge Removed"), backgroundColor: Colors.orange));
    } catch (e) {
      if (mounted) messenger.showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showPostDemandDialog,
        backgroundColor: const Color(0xFF1E3A8A),
        icon: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white),
        label: Text("Post Demand", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        top: false,
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E3A8A)))
          : CustomScrollView(
              controller: _scrollController,
              slivers: [
                _buildHeader(topPadding),
                SliverToBoxAdapter(child: _buildDemandFeed()),
                SliverToBoxAdapter(key: _formKey, child: _buildCreateLotSection()),
                _buildLotsGrid(),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
      ),
    );
  }

  Widget _buildHeader(double topPadding) {
    return SliverToBoxAdapter(
      child: Container(
        padding: EdgeInsets.only(top: topPadding + 20, left: 24, right: 24, bottom: 30),
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)]),
          borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Border-Breaker", style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                    Text("Collective Export Power", style: GoogleFonts.outfit(fontSize: 14, color: Colors.white70)),
                  ],
                ),
                const Icon(Icons.public_rounded, color: Colors.white, size: 40),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDemandFeed() {
    if (_demands.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 24, top: 24, bottom: 12),
          child: Row(
            children: [
              Text("Live Global Demands", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
              const SizedBox(width: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)), child: Text("LIVE", style: GoogleFonts.outfit(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
            ],
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _demands.length,
            itemBuilder: (context, index) {
              final demand = _demands[index];
              return InkWell(
                onTap: () => _fillFromDemand(demand),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 320,
                  margin: const EdgeInsets.only(right: 16, bottom: 12),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: Colors.blue.withOpacity(0.2)),
                    boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 8))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text(demand['company_name'] ?? "Buyer", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 17, color: const Color(0xFF1E3A8A)))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(10)),
                            child: Text(demand['offered_price_usd'] ?? "N/A", style: GoogleFonts.outfit(color: const Color(0xFF059669), fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      Text("Crop: ${demand['crop_needed']}", style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.call, size: 12, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              demand['phone'] ?? "Hidden", 
                              style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey[600]),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.email, size: 12, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              demand['email'] ?? "Hidden", 
                              style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey[600]),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Market: ${demand['country']}", style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.bold)),
                          Text("TAP TO SUPPLY", style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange[800])),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCreateLotSection() {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Open a New Export Lot", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1E3A8A))),
          Text("Link Global Demand (Select Lead)", style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButtonFormField<Map<String, dynamic>>(
            isExpanded: true,
            decoration: InputDecoration(
              hintText: "Select an existing buyer demand",
              prefixIcon: const Icon(Icons.hub_outlined, color: Color(0xFF1E3A8A)),
              filled: true,
              fillColor: const Color(0xFFF1F5F9),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
            ),
            items: _demands.map((d) => DropdownMenuItem(
              value: d,
              child: Text("${d['company_name']} (${d['crop_needed']})", style: GoogleFonts.outfit(fontSize: 14)),
            )).toList(),
            onChanged: (val) {
              if (val != null) _fillFromDemand(val);
            },
          ),
          const SizedBox(height: 20),
          _inputField(_cropController, "Crop Name", Icons.grass, readOnly: _buyerNameController.text.isNotEmpty),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _inputField(_targetController, "Target Quantity (kg)", Icons.bolt, isNumeric: true, readOnly: _buyerNameController.text.isNotEmpty)),
              const SizedBox(width: 12),
              Expanded(child: _inputField(_marketController, "Target Market", Icons.public, readOnly: _buyerNameController.text.isNotEmpty)),
            ],
          ),
          const SizedBox(height: 12),
          Text("Buyer Information (Verified Lead)", style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 8),
          Row(
             children: [
               Expanded(child: _inputField(_buyerNameController, "Buyer Name", Icons.person_outline, readOnly: true)),
               const SizedBox(width: 12),
               Expanded(child: _inputField(_buyerPhoneController, "Buyer Phone", Icons.phone_android_outlined, readOnly: true)),
             ],
          ),
          const SizedBox(height: 12),
          _inputField(_companyNameController, "Buyer Company", Icons.business_outlined, readOnly: true),
          const SizedBox(height: 12),
          Row(
             children: [
                Expanded(child: _inputField(_gradeController, "Quality Specs", Icons.verified_outlined, readOnly: _buyerNameController.text.isNotEmpty)),
                const SizedBox(width: 12),
                Expanded(child: _inputField(_deadlineController, "Deadline (Days)", Icons.timer_outlined, isNumeric: true)),
             ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _createLot,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 5,
                shadowColor: Colors.blue.withOpacity(0.4),
              ),
              child: Text("Start Community Consolidation", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputField(TextEditingController controller, String hint, IconData icon, {bool isNumeric = false, bool readOnly = false}) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
      inputFormatters: isNumeric ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))] : null,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: readOnly ? Colors.grey : const Color(0xFF3B82F6), size: 20),
        filled: true,
        fillColor: readOnly ? const Color(0xFFE2E8F0) : const Color(0xFFF1F5F9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _buildLotsGrid() {
    if (_lots.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(60),
          child: Column(
            children: [
              Icon(Icons.airplanemode_active, size: 80, color: Colors.blue[100]),
              const SizedBox(height: 16),
              Text("No active export slots", style: GoogleFonts.outfit(color: Colors.grey[400], fontSize: 16)),
            ],
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildEnhancedLotCard(_lots[index]),
          childCount: _lots.length,
        ),
      ),
    );
  }

  Widget _buildEnhancedLotCard(Map<String, dynamic> lot) {
    final user = Supabase.instance.client.auth.currentUser;
    bool isOwner = user?.id == lot['creator_id'];
    
    double target = (lot['target_quantity_kg'] as num).toDouble();
    List pledges = lot['export_pledges'] as List;
    double current = pledges.fold(0.0, (sum, item) => sum + (item['pledged_quantity_kg'] as num).toDouble());
    double progress = (current / target).clamp(0.0, 1.0);

    // Calculate Deadline Timer
    DateTime deadline = DateTime.parse(lot['deadline'] ?? DateTime.now().add(const Duration(days: 7)).toIso8601String());
    Duration remaining = deadline.difference(DateTime.now());
    int daysLeft = remaining.inDays;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                             children: [
                               Text(lot['crop_name'], style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
                               const SizedBox(width: 8),
                               Container(
                                 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                 decoration: BoxDecoration(
                                   color: daysLeft > 2 ? Colors.blue[50] : Colors.red[50],
                                   borderRadius: BorderRadius.circular(10),
                                 ),
                                 child: Text(
                                   daysLeft > 0 ? "$daysLeft Days Left" : "Expired",
                                   style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: daysLeft > 2 ? Colors.blue[700] : Colors.red[700]),
                                 ),
                               ),
                             ],
                          ),
                          Text("Goal: ${target.toStringAsFixed(0)}kg for ${lot['destination_market']}", style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey[600])),
                        ],
                      ),
                    ),
                    if (isOwner)
                      IconButton(
                        onPressed: () => _editTarget(lot),
                        icon: const Icon(Icons.edit_note_rounded, color: Colors.blue),
                        tooltip: "Adjust Target",
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                // Buyer Details at high level
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(15)),
                  child: Row(
                    children: [
                      const Icon(Icons.handshake_outlined, size: 20, color: Color(0xFF1E3A8A)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(lot['company_name'] ?? "Private Buyer", style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold)),
                            Text("Buyer: ${lot['buyer_name'] ?? 'Verified'} | ${lot['buyer_phone'] ?? 'Protected'}", style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey[600])),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Consolidation", style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue[800])),
                        Text("${(progress * 100).toStringAsFixed(1)}%", style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue[800])),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text("Expected Revenue", style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green[700])),
                        Text("\$${(target * 2.1).toStringAsFixed(0)} Potential", style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green[700])),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 14,
                    backgroundColor: Colors.blue[50],
                    color: const Color(0xFF3B82F6),
                  ),
                ),
                const SizedBox(height: 12),
                Text("${current.toStringAsFixed(0)}kg collected | ${(target - current).clamp(0, double.infinity).toStringAsFixed(0)}kg remaining", 
                  style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[600])),
                const SizedBox(height: 20),
                
                // Contributors Section
                Text("Joined Farmers (${pledges.length})", style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
                const SizedBox(height: 12),
                if (pledges.isEmpty)
                  Text("Be the first to pledge!", style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey[400], fontStyle: FontStyle.italic))
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: pledges.length,
                    itemBuilder: (context, pIndex) {
                      final p = pledges[pIndex];
                      final farmer = p['profiles'];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(15)),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundImage: farmer['avatar_url'] != null ? NetworkImage(farmer['avatar_url']) : null,
                              child: farmer['avatar_url'] == null ? const Icon(Icons.person, size: 20) : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(farmer['full_name'] ?? "Progressive Farmer", style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold)),
                                  Row(
                                    children: [
                                      Flexible(child: Text(farmer['phone_number'] ?? "No Phone", style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey[600]), overflow: TextOverflow.ellipsis)),
                                      const SizedBox(width: 8),
                                      if (farmer['email'] != null)
                                        Flexible(child: Text(farmer['email'], style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey[600]), overflow: TextOverflow.ellipsis)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: Colors.blue[100], borderRadius: BorderRadius.circular(10)),
                              child: Text("+${p['pledged_quantity_kg']}kg", style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue[900])),
                            ),
                            if (p['farmer_id'] == user?.id)
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blue),
                                onPressed: () => _editPledge(p),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
          
          // Action Area
          GestureDetector(
            onTap: daysLeft <= 0 ? null : (progress < 1.0 
              ? () => _pledgeStock(lot) 
              : () => _generatePass(lot)),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: daysLeft <= 0 ? Colors.grey : (progress < 1.0 ? const Color(0xFF1E3A8A) : Colors.green[700]),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
              ),
              child: Center(
                child: Text(
                  daysLeft <= 0 ? "EXPIRED" : (progress < 1.0 ? "PLEDGE MY STOCK" : "GENERATE EXPORT PASS"), 
                  style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
