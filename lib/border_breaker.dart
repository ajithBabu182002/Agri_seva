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

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final lotsResponse = await Supabase.instance.client
          .from('export_lots')
          .select('*, profiles(*), export_pledges(*)');

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
      _cropController.text = demand['crop_needed'];
      _targetController.text = demand['quantity_required_kg'].toString();
      _marketController.text = demand['country'];
      _gradeController.text = demand['quality_specs'] ?? "Grade A";
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Auto-filled from ${demand['buyer_name']}"),
        backgroundColor: const Color(0xFF1E3A8A),
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
    try {
      await Supabase.instance.client.from('export_lots').insert({
        'creator_id': user.id,
        'crop_name': _cropController.text.trim(),
        'target_quantity_kg': double.tryParse(_targetController.text) ?? 1000.0,
        'quality_grade': _gradeController.text.trim().isEmpty ? "Grade A" : _gradeController.text.trim(),
        'destination_market': _marketController.text.trim().isEmpty ? "Global Market" : _marketController.text.trim(),
        'status': 'open',
      });

      _cropController.clear();
      _targetController.clear();
      _gradeController.clear();
      _marketController.clear();

      if (!mounted) return;
      await _fetchData();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Global Export Lot Created!"), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pledgeStock(Map<String, dynamic> lot) async {
    final quantityController = TextEditingController();
    final user = Supabase.instance.client.auth.currentUser;

    if (user?.id == lot['creator_id']) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("You are the lot creator. Add stock during creation.")));
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
              Navigator.pop(context);
              
              setState(() => _isLoading = true);
              try {
                await Supabase.instance.client.from('export_pledges').insert({
                  'lot_id': lot['id'],
                  'farmer_id': user!.id,
                  'pledged_quantity_kg': quantity,
                });
                if (!mounted) return;
                await _fetchData();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Stock Pledged to Global Lot!"), backgroundColor: Colors.green));
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
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

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        top: false,
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E3A8A)))
          : CustomScrollView(
              slivers: [
                _buildHeader(topPadding),
                SliverToBoxAdapter(child: _buildDemandFeed()),
                SliverToBoxAdapter(child: _buildCreateLotSection()),
                _buildLotsGrid(),
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
            Text("Border-Breaker", style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
            Text("Connect directly with Global Buyers", style: GoogleFonts.outfit(fontSize: 14, color: Colors.white70)),
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
          child: Text("Live Global Demands", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
        ),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _demands.length,
            itemBuilder: (context, index) {
              final demand = _demands[index];
              return GestureDetector(
                onTap: () => _fillFromDemand(demand),
                child: Container(
                  width: 280,
                  margin: const EdgeInsets.only(right: 16, bottom: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text(demand['crop_needed'], style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF1E3A8A)))),
                          Text(demand['offered_price_usd'] ?? "N/A", style: GoogleFonts.outfit(color: Colors.green[700], fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text("Buyer: ${demand['buyer_name']}", style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey[600])),
                      Text("Market: ${demand['country']}", style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey[600])),
                      const Spacer(),
                      Row(
                        children: [
                          Icon(Icons.shopping_basket_outlined, size: 14, color: Colors.blue[800]),
                          const SizedBox(width: 4),
                          Text("Goal: ${demand['quantity_required_kg']}kg", style: GoogleFonts.outfit(fontSize: 12, color: Colors.blue[800], fontWeight: FontWeight.bold)),
                          const Spacer(),
                          Text("TAP TO SUPPLY", style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange[800])),
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
          const SizedBox(height: 16),
          _inputField(_cropController, "Crop (e.g. Ginger)", Icons.grass),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _inputField(_targetController, "Target Quantity (kg)", Icons.bolt, isNumeric: true)),
              const SizedBox(width: 12),
              Expanded(child: _inputField(_marketController, "Market (e.g. Dubai)", Icons.public)),
            ],
          ),
          const SizedBox(height: 12),
          _inputField(_gradeController, "Quality Grade (e.g. Organic, Grade A)", Icons.verified_user_outlined),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _createLot,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text("Start Consolidation", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputField(TextEditingController controller, String hint, IconData icon, {bool isNumeric = false}) {
    return TextField(
      controller: controller,
      keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF3B82F6), size: 20),
        filled: true,
        fillColor: const Color(0xFFF1F5F9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildLotsGrid() {
    if (_lots.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(Icons.airplanemode_active, size: 60, color: Colors.blue[100]),
              const SizedBox(height: 12),
              Text("No active consolidation lots", style: GoogleFonts.outfit(color: Colors.grey)),
            ],
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildLotCard(_lots[index]),
          childCount: _lots.length,
        ),
      ),
    );
  }

  Widget _buildLotCard(Map<String, dynamic> lot) {
    double target = (lot['target_quantity_kg'] as num).toDouble();
    double current = (lot['export_pledges'] as List).fold(0.0, (sum, item) => sum + (item['pledged_quantity_kg'] as num).toDouble());
    double progress = (current / target).clamp(0.0, 1.0);
    double remaining = target - current;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue[50]!),
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
                  Text(lot['crop_name'], style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text("Market: ${lot['destination_market']}", style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey)),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFE0F2FE), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.flight_takeoff, color: Colors.blue[800], size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text("Grade: ${lot['quality_grade']}", style: GoogleFonts.outfit(fontSize: 13, color: Colors.blue[900], fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Consolidation Progress", style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600)),
              Text("${(progress * 100).toStringAsFixed(1)}%", style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue[800])),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: Colors.blue[50],
              color: const Color(0xFF3B82F6),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Collected: ${current.toStringAsFixed(0)}kg", style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey[600])),
              Text("Need: ${remaining.toStringAsFixed(0)}kg", style: GoogleFonts.outfit(fontSize: 11, color: Colors.orange[800], fontWeight: FontWeight.bold)),
            ],
          ),
          const Divider(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: progress < 1.0 ? () => _pledgeStock(lot) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(progress < 1.0 ? "Pledge My Stock" : "READY FOR EXPORT", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
