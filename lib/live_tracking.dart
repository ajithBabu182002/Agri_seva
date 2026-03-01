import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';

class LiveTrackingPage extends StatefulWidget {
  final Map<String, dynamic> filterCriteria;
  const LiveTrackingPage({super.key, required this.filterCriteria});

  @override
  State<LiveTrackingPage> createState() => _LiveTrackingPageState();
}

class _LiveTrackingPageState extends State<LiveTrackingPage> {
  String? _selectedVehicle;
  bool _isTracking = false;
  final MapController _mapController = MapController();
  
  final _startController = TextEditingController();
  final _destController = TextEditingController();
  
  List<String> _startPredictions = [];
  List<String> _destPredictions = [];

  final List<Map<String, dynamic>> _vehicles = [
    {'name': 'Car', 'icon': Icons.directions_car_rounded, 'eta_factor': 0.8},
    {'name': 'Bike', 'icon': Icons.directions_bike_rounded, 'eta_factor': 0.6},
    {'name': 'Tractor', 'icon': Icons.agriculture_rounded, 'eta_factor': 1.5},
    {'name': 'Truck', 'icon': Icons.local_shipping_rounded, 'eta_factor': 1.2},
    {'name': 'Pickup', 'icon': Icons.local_shipping_outlined, 'eta_factor': 1.0},
  ];

  final LatLng _startPos = const LatLng(12.9716, 77.5946); // Bangalore
  final LatLng _destPos = const LatLng(13.0827, 80.2707);  // Chennai
  
  LatLng? _ghostPosition;
  Timer? _ghostTimer;
  Duration _timeRemaining = const Duration(hours: 5, minutes: 45, seconds: 30);

  // Global Address Search Simulation (Open Source approach)
  void _searchAddress(String query, bool isStart) {
    if (query.isEmpty) {
      setState(() {
        if (isStart) _startPredictions = []; else _destPredictions = [];
      });
      return;
    }
    
    // Simulating OpenStreetMap Nominatim behavior (Global)
    setState(() {
      final results = [
        "$query - Global Center, International Hub",
        "$query - National Gateway, Sector 7",
        "$query - North Terminal, Airport Road",
        "$query - Downtown District, City Square",
        "$query - Landmark Point, Heritage Zone",
      ];
      if (isStart) _startPredictions = results; else _destPredictions = results;
    });
  }

  void _startTracking() {
    setState(() {
      _isTracking = true;
      _ghostPosition = _startPos;
    });

    final selectedFactor = _vehicles.firstWhere((v) => v['name'] == _selectedVehicle)['eta_factor'] as double;

    _ghostTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _isTracking) {
        setState(() {
          if (_timeRemaining.inSeconds > 0) {
            _timeRemaining = _timeRemaining - const Duration(seconds: 1);
          }

          double progress = 1.0 - (_timeRemaining.inSeconds / (5 * 3600));
          _ghostPosition = LatLng(
            _startPos.latitude + (_destPos.latitude - _startPos.latitude) * progress * (1.1/selectedFactor),
            _startPos.longitude + (_destPos.longitude - _startPos.longitude) * progress * (1.1/selectedFactor),
          );
        });
      }
    });
  }

  String _formatDuration(Duration d) {
    String h = d.inHours.toString().padLeft(2, '0');
    String m = (d.inMinutes % 60).toString().padLeft(2, '0');
    String s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return "$h:$m:$s";
  }

  @override
  void dispose() {
    _ghostTimer?.cancel();
    _startController.dispose();
    _destController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: !_isTracking ? _buildSetupScreen() : _buildMapScreen(),
    );
  }

  Widget _buildSetupScreen() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.blue.shade50, Colors.white],
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 50),
          Text(
            "Hyper-Precision Track",
            style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: const Color(0xFF1A237E)),
          ),
          const SizedBox(height: 30),
          
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildLocationInput("Starting Location (Global)", _startController, Icons.my_location, true),
                  if (_startPredictions.isNotEmpty) _buildPredictionList(_startPredictions, true),
                  const SizedBox(height: 12),
                  _buildLocationInput("Destination (Global)", _destController, Icons.near_me, false),
                  if (_destPredictions.isNotEmpty) _buildPredictionList(_destPredictions, false),
                  
                  const SizedBox(height: 32),
                  Text("Vehicle Profile", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildVehicleGrid(),
                  
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 65,
                    child: ElevatedButton(
                      onPressed: _selectedVehicle != null ? _startTracking : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A237E),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 10,
                      ),
                      child: Text("START LIVE MONITORING", style: GoogleFonts.outfit(fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationInput(String hint, TextEditingController controller, IconData icon, bool isStart) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15)],
      ),
      child: TextField(
        controller: controller,
        onChanged: (v) => _searchAddress(v, isStart),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.outfit(fontSize: 14),
          prefixIcon: Icon(icon, color: const Color(0xFF1A237E)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 20),
        ),
      ),
    );
  }

  Widget _buildPredictionList(List<String> list, bool isStart) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: list.length,
        separatorBuilder: (ctx, i) => const Divider(height: 1),
        itemBuilder: (ctx, i) => ListTile(
          leading: const Icon(Icons.place_outlined, size: 20, color: Colors.blueAccent),
          title: Text(list[i], style: GoogleFonts.outfit(fontSize: 14)),
          onTap: () {
            setState(() {
              if (isStart) {
                _startController.text = list[i];
                _startPredictions = [];
              } else {
                _destController.text = list[i];
                _destPredictions = [];
              }
            });
          },
        ),
      ),
    );
  }

  Widget _buildVehicleGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.0,
      ),
      itemCount: _vehicles.length,
      itemBuilder: (context, index) {
        final v = _vehicles[index];
        bool isSelected = _selectedVehicle == v['name'];
        return GestureDetector(
          onTap: () => setState(() => _selectedVehicle = v['name']),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF1A237E) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isSelected ? Colors.transparent : Colors.grey.shade200),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(v['icon'], color: isSelected ? Colors.white : Colors.black54, size: 30),
                const SizedBox(height: 8),
                Text(
                  v['name'],
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.white : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMapScreen() {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _startPos,
            initialZoom: 12,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.my_flutter_app',
            ),
            PolylineLayer(
              polylines: [
                Polyline(
                  points: [_startPos, LatLng((_startPos.latitude + _destPos.latitude)/2, (_startPos.longitude + _destPos.longitude)/2)],
                  color: Colors.blueAccent,
                  strokeWidth: 6,
                ),
                Polyline(
                  points: [LatLng((_startPos.latitude + _destPos.latitude)/2, (_startPos.longitude + _destPos.longitude)/2), _destPos],
                  color: Colors.redAccent,
                  strokeWidth: 8,
                ),
              ],
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: _startPos,
                  width: 40,
                  height: 40,
                  child: const Icon(Icons.location_on, color: Colors.blue, size: 40),
                ),
                Marker(
                  point: _destPos,
                  width: 40,
                  height: 40,
                  child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                ),
                if (_ghostPosition != null)
                  Marker(
                    point: _ghostPosition!,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.rocket_launch, color: Colors.cyan, size: 30),
                  ),
              ],
            ),
          ],
        ),
        
        // Heads-Up Display (H:M:S)
        Positioned(top: 60, left: 15, right: 15, child: _buildHUD()),

        // Map Actions
        Positioned(
          right: 20,
          top: 250,
          child: Column(
            children: [
              _mapFab(Icons.my_location, () => _mapController.move(_startPos, 12)),
            ],
          ),
        ),

        // Traffic Warning & Progress Card
        Positioned(bottom: 30, left: 15, right: 15, child: _buildProgressCard()),
      ],
    );
  }

  Widget _buildHUD() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.9),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.gps_fixed, color: Colors.blueAccent, size: 28),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("HYPER-PRECISION ETA", style: GoogleFonts.outfit(color: Colors.white70, fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.bold)),
                Text(
                  _formatDuration(_timeRemaining),
                  style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.power_settings_new, color: Colors.redAccent, size: 30),
            onPressed: () => setState(() => _isTracking = false),
          )
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 40)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.traffic_outlined, color: Colors.orange, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Real-time OpenSource Map data loaded. Route adjusted for Global scale.",
                  style: GoogleFonts.outfit(fontSize: 13, color: Colors.black87),
                ),
              ),
            ],
          ),
          const Divider(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statGroup("DISTANCE", "32.4 km"),
              _statGroup("VEHICLE", _selectedVehicle?.toUpperCase() ?? "CAR"),
              _statGroup("MAP", "OSM"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statGroup(String label, String value) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.outfit(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
        Text(value, style: GoogleFonts.outfit(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _mapFab(IconData icon, VoidCallback onTap) {
    return FloatingActionButton.small(
      heroTag: icon.toString(),
      onPressed: onTap,
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF1A237E),
      child: Icon(icon, size: 20),
    );
  }
}
