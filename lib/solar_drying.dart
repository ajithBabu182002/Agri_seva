import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
// import 'package:weather/weather.dart'; // Commented out until API key is provided
// import 'package:geolocator/geolocator.dart';

class SolarDryingPage extends StatefulWidget {
  final Map<String, dynamic> filterCriteria;
  const SolarDryingPage({super.key, required this.filterCriteria});

  @override
  State<SolarDryingPage> createState() => _SolarDryingPageState();
}

class _SolarDryingPageState extends State<SolarDryingPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _activeSessions = [];
  final _cropController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchSessions();
  }

  Future<void> _fetchSessions() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final data = await Supabase.instance.client
          .from('drying_sessions')
          .select()
          .eq('profile_id', user.id)
          .eq('status', 'drying')
          .order('start_time', ascending: false);

      setState(() {
        _activeSessions = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching sessions: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _startDryingSession() async {
    if (_cropController.text.trim().isEmpty) return;

    final user = Supabase.instance.client.auth.currentUser;
    setState(() => _isLoading = true);

    try {
      // Mocked weather for logic demonstration
      // In production, use Geolocator and Weather package
      double mockTemp = 32.5;
      double mockHumidity = 65.0;
      String mockCondition = "Partly Cloudy";
      
      // Drying Efficiency Logic:
      // Efficiency decreases as humidity increases
      double efficiency = (100 - mockHumidity) * (mockTemp / 30);
      if (efficiency > 100) efficiency = 100;
      if (efficiency < 0) efficiency = 0;

      await Supabase.instance.client.from('drying_sessions').insert({
        'profile_id': user!.id,
        'crop_name': _cropController.text.trim(),
        'temp': mockTemp,
        'humidity': mockHumidity,
        'efficiency': efficiency,
        'weather_condition': mockCondition,
        'status': 'drying',
      });

      _cropController.clear();
      await _fetchSessions();
    } catch (e) {
      debugPrint("Error starting session: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _stopSession(dynamic id) async {
    try {
      await Supabase.instance.client
          .from('drying_sessions')
          .update({'status': 'completed'})
          .eq('id', id);
      await _fetchSessions();
    } catch (e) {
      debugPrint("Error stopping session: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF1B5E20)))
        : CustomScrollView(
            slivers: [
              _buildHeader(),
              SliverToBoxAdapter(child: _buildInputCard()),
              _buildSessionsList(),
            ],
          ),
    );
  }

  Widget _buildHeader() {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.only(top: 40, left: 24, right: 24, bottom: 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Solar Drying", style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: const Color(0xFF1B5E20))),
            Text("AI Post-Harvest Workflow Assistant", style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _buildInputCard() {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.wb_sunny_rounded, color: Colors.orange, size: 28),
              const SizedBox(width: 12),
              Text("Start New Drying", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _cropController,
            decoration: InputDecoration(
              hintText: "What are you drying? (e.g. Pepper, Grain)",
              hintStyle: GoogleFonts.outfit(color: Colors.grey),
              filled: true,
              fillColor: const Color(0xFFF1F5F9),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.all(18),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _startDryingSession,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E20),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text("Start Assistant", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionsList() {
    if (_activeSessions.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off_rounded, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text("No active drying sessions", style: GoogleFonts.outfit(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final session = _activeSessions[index];
            return _buildSessionCard(session);
          },
          childCount: _activeSessions.length,
        ),
      ),
    );
  }

  Widget _buildSessionCard(Map<String, dynamic> session) {
    double efficiency = session['efficiency'] ?? 0;
    double humidity = session['humidity'] ?? 0;
    
    // Workflow Logic Recommendations
    String advice = "";
    Color adviceColor = Colors.blue;
    if (humidity > 70) {
      advice = "High Humidity! Turn crops every 1 hour to prevent fungus.";
      adviceColor = Colors.red;
    } else if (humidity > 50) {
      advice = "Moderate humidity. Turn crops every 3 hours for uniform drying.";
      adviceColor = Colors.orange;
    } else {
      advice = "Great drying conditions! Turn twice daily.";
      adviceColor = Colors.green;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
                  Text(session['crop_name']?.toUpperCase() ?? "HARVEST", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF064E3B))),
                  Text("Started: ${DateFormat('hh:mm a').format(DateTime.parse(session['start_time']))}", style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey)),
                ],
              ),
              IconButton(onPressed: () => _stopSession(session['id']), icon: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 30)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _metricTile(Icons.speed_rounded, "Efficiency", "${efficiency.toInt()}%"),
              const SizedBox(width: 12),
              _metricTile(Icons.water_drop_rounded, "Humidity", "${humidity.toInt()}%"),
              const SizedBox(width: 12),
              _metricTile(Icons.thermostat_rounded, "Temp", "${session['temp']}°C"),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: adviceColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: adviceColor.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_rounded, color: adviceColor, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    advice,
                    style: GoogleFonts.outfit(fontSize: 13, color: adviceColor, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: efficiency / 100,
              backgroundColor: const Color(0xFFF1F5F9),
              color: const Color(0xFF1B5E20),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricTile(IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF1B5E20)),
            const SizedBox(height: 4),
            Text(label, style: GoogleFonts.outfit(fontSize: 9, color: Colors.grey)),
            Text(value, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF064E3B))),
          ],
        ),
      ),
    );
  }
}
