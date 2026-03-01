import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class SoilPulsePage extends StatefulWidget {
  final Map<String, dynamic> filterCriteria;
  const SoilPulsePage({super.key, required this.filterCriteria});

  @override
  State<SoilPulsePage> createState() => _SoilPulsePageState();
}

class _SoilPulsePageState extends State<SoilPulsePage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _reports = [];
  Map<String, List<String>> _trends = {
    'Nitrogen': [],
    'Phosphorus': [],
    'Potassium': [],
  };

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  Future<void> _fetchReports() async {
    try {
      var query = Supabase.instance.client
          .from('soil_health_reports')
          .select('*, profiles(*)');

      if (widget.filterCriteria['village']?.isNotEmpty ?? false) {
        query = query.eq('village', widget.filterCriteria['village']);
      } else if (widget.filterCriteria['taluk']?.isNotEmpty ?? false) {
        query = query.eq('taluk', widget.filterCriteria['taluk']);
      }

      final data = await query.order('created_at', ascending: false).limit(50);

      if (mounted) {
        _calculateTrends(data);
        setState(() {
          _reports = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching soil reports: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _calculateTrends(List<dynamic> data) {
    _trends = {
      'Nitrogen': data.map((e) => e['nitrogen_level'].toString()).toList(),
      'Phosphorus': data.map((e) => e['phosphorus_level'].toString()).toList(),
      'Potassium': data.map((e) => e['potassium_level'].toString()).toList(),
    };
  }

  String _getDominantState(List<String> levels) {
    if (levels.isEmpty) return "No Data";
    Map<String, int> counts = {'Low': 0, 'Medium': 0, 'High': 0};
    for (var level in levels) {
      if (counts.containsKey(level)) counts[level] = counts[level]! + 1;
    }
    return counts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  Color _getStatusColor(String level) {
    switch (level) {
      case 'Low': return Colors.redAccent;
      case 'Medium': return Colors.orangeAccent;
      case 'High': return Colors.greenAccent;
      default: return Colors.grey;
    }
  }

  Future<void> _addReport() async {
    String? nitrogen;
    String? phosphorus;
    String? potassium;
    final phController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          title: Text("Upload Lab Report", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dropdownField("Nitrogen (N)", (v) => setDialogState(() => nitrogen = v)),
                _dropdownField("Phosphorus (P)", (v) => setDialogState(() => phosphorus = v)),
                _dropdownField("Potassium (K)", (v) => setDialogState(() => potassium = v)),
                const SizedBox(height: 12),
                TextField(
                  controller: phController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: "pH Level (Optional)",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                if (nitrogen == null || phosphorus == null || potassium == null) return;
                Navigator.pop(context);
                await _submitReport(nitrogen!, phosphorus!, potassium!, phController.text);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D9488),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: const Text("Share Pulse"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dropdownField(String label, Function(String?) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        ),
        items: ['Low', 'Medium', 'High'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Future<void> _submitReport(String n, String p, String k, String ph) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('village, taluk')
          .eq('id', user.id)
          .single();

      await Supabase.instance.client.from('soil_health_reports').insert({
        'profile_id': user.id,
        'village': profile['village'] ?? "Unknown",
        'taluk': profile['taluk'] ?? "Unknown",
        'nitrogen_level': n,
        'phosphorus_level': p,
        'potassium_level': k,
        'ph_level': double.tryParse(ph),
      });

      if (!mounted) return;
      await _fetchReports();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Soul Pulse Shared!"), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      body: SafeArea(
        top: false,
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D9488)))
          : CustomScrollView(
              slivers: [
                _buildHeader(topPadding),
                SliverToBoxAdapter(child: _buildHeatmapGrid()),
                _buildReportsList(),
              ],
            ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addReport,
        backgroundColor: const Color(0xFF0D9488),
        icon: const Icon(Icons.add_chart_rounded, color: Colors.white),
        label: Text("Upload Report", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }

  Widget _buildHeader(double topPadding) {
    return SliverToBoxAdapter(
      child: Container(
        padding: EdgeInsets.only(top: topPadding + 20, left: 24, right: 24, bottom: 30),
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF0D9488), Color(0xFF14B8A6)]),
          borderRadius: BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Village Soil Pulse", style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
            Text("Collective health data for your land", style: GoogleFonts.outfit(fontSize: 14, color: Colors.white.withOpacity(0.8))),
          ],
        ),
      ),
    );
  }

  Widget _buildHeatmapGrid() {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: Colors.teal.withOpacity(0.05), blurRadius: 20)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Collective Fertility Map", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _nutrientStat("Nitrogen", _getDominantState(_trends['Nitrogen']!)),
              _nutrientStat("Phosphorus", _getDominantState(_trends['Phosphorus']!)),
              _nutrientStat("Potassium", _getDominantState(_trends['Potassium']!)),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.amber[50], borderRadius: BorderRadius.circular(15)),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Colors.amber[800], size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Insight: Most neighbors report '${_getDominantState(_trends['Nitrogen']!)}' Nitrogen. Adjust your fertilizer accordingly.",
                    style: GoogleFonts.outfit(fontSize: 12, color: Colors.amber[900]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _nutrientStat(String label, String status) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: _getStatusColor(status).withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(color: _getStatusColor(status), width: 2),
          ),
          child: Center(
            child: Text(label[0], style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: _getStatusColor(status).withOpacity(0.8), fontSize: 24)),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
        Text(status, style: GoogleFonts.outfit(fontSize: 10, color: _getStatusColor(status), fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildReportsList() {
    if (_reports.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(Icons.analytics_outlined, size: 60, color: Colors.teal[100]),
              const SizedBox(height: 12),
              Text("No reports contributed yet", style: GoogleFonts.outfit(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _reportCard(_reports[index]),
          childCount: _reports.length,
        ),
      ),
    );
  }

  Widget _reportCard(Map<String, dynamic> report) {
    final date = DateTime.parse(report['created_at']);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.teal[50]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Sample #${report['id'].toString().substring(0, 5)}", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              Text(DateFormat('MMM dd').format(date), style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _miniTag("N: ${report['nitrogen_level']}", _getStatusColor(report['nitrogen_level'])),
              const SizedBox(width: 8),
              _miniTag("P: ${report['phosphorus_level']}", _getStatusColor(report['phosphorus_level'])),
              const SizedBox(width: 8),
              _miniTag("K: ${report['potassium_level']}", _getStatusColor(report['potassium_level'])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }
}
