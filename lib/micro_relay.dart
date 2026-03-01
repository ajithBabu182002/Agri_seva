import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class MicroRelayPage extends StatefulWidget {
  final Map<String, dynamic> filterCriteria;
  const MicroRelayPage({super.key, required this.filterCriteria});

  @override
  State<MicroRelayPage> createState() => _MicroRelayPageState();
}

class _MicroRelayPageState extends State<MicroRelayPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _trips = [];
  final _destinationController = TextEditingController();
  final _spaceController = TextEditingController();
  final _priceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchTrips();
  }

  Future<void> _fetchTrips() async {
    try {
      var query = Supabase.instance.client
          .from('transport_relay')
          .select('*, profiles(*)');

      // Use filter criteria if provided (Localized Network)
      if (widget.filterCriteria['village']?.isNotEmpty ?? false) {
        query = query.eq('profiles.village', widget.filterCriteria['village']);
      }

      final data = await query
          .eq('status', 'open')
          .order('departure_time', ascending: true);

      if (!mounted) return;
      setState(() {
        _trips = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching trips: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showFarmerProfile(String profileId) async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', profileId)
          .single();
      
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 120,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [Color(0xFF064E3B), Color(0xFF059669)]),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  ),
                  child: Center(
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white,
                      child: CircleAvatar(
                        radius: 37,
                        backgroundImage: response['avatar_url'] != null ? NetworkImage(response['avatar_url']) : null,
                        child: response['avatar_url'] == null ? const Icon(Icons.person, size: 40) : null,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(response['full_name'] ?? "Farmer", style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.verified_rounded, color: Colors.blue, size: 16),
                          const SizedBox(width: 4),
                          Text("Verified Agrovia Driver", style: GoogleFonts.outfit(fontSize: 12, color: Colors.blue)),
                        ],
                      ),
                      const Divider(height: 32),
                      _profileInfoRow(Icons.location_on_rounded, "Village", response['village'] ?? "Unknown"),
                      _profileInfoRow(Icons.map_rounded, "Taluk", response['taluk'] ?? "Unknown"),
                      _profileInfoRow(Icons.phone_android_rounded, "Contact", response['phone_number'] ?? "Protected"),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF064E3B),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        child: Text("Close Profile", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error fetching profile: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _profileInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.grey),
              const SizedBox(width: 8),
              Text(label, style: GoogleFonts.outfit(color: Colors.grey)),
            ],
          ),
          Text(value, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _postTrip() async {
    if (_destinationController.text.isEmpty || _spaceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all required fields")));
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please login to post a trip")));
      }
      return;
    }
    
    setState(() => _isLoading = true);

    try {
      int availableSacks = int.tryParse(_spaceController.text) ?? 0;
      double price = double.tryParse(_priceController.text) ?? 0.0;

      if (availableSacks <= 0) {
        throw Exception("Sacks must be greater than 0");
      }

      await Supabase.instance.client.from('transport_relay').insert({
        'profile_id': user.id,
        'destination': _destinationController.text.trim(),
        'available_sacks': availableSacks,
        'price_per_sack': price,
        'departure_time': DateTime.now().add(const Duration(hours: 12)).toIso8601String(),
        'status': 'open',
      });

      _destinationController.clear();
      _spaceController.clear();
      _priceController.clear();
      
      if (!mounted) return;
      await _fetchTrips();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Trip posted successfully!", style: GoogleFonts.outfit()), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _bookSlot(Map<String, dynamic> trip) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user?.id == trip['profile_id']) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("You cannot book your own trip")));
      return;
    }

    final sacksController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Book Slot", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("How many sacks do you want to send?", style: GoogleFonts.outfit(fontSize: 14)),
              const SizedBox(height: 16),
              TextField(
                controller: sacksController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: "Number of Sacks",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                  hintText: "Max: ${trip['available_sacks']}",
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              int sacks = int.tryParse(sacksController.text) ?? 0;
              if (sacks <= 0 || sacks > trip['available_sacks']) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid number of sacks")));
                return;
              }
              
              Navigator.pop(context);
              setState(() => _isLoading = true);
              
              try {
                final currentUser = Supabase.instance.client.auth.currentUser;
                if (currentUser == null) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please login to book")));
                  }
                  return;
                }

                // 1. Log the booking in transport_bookings table
                await Supabase.instance.client
                    .from('transport_bookings')
                    .insert({
                      'trip_id': trip['id'],
                      'booker_id': currentUser.id,
                      'sacks_booked': sacks,
                      'total_price': sacks * (trip['price_per_sack'] ?? 0.0),
                    });

                // 2. Update available sacks in transport_relay table
                int remaining = trip['available_sacks'] - sacks;
                String newStatus = remaining == 0 ? 'full' : 'open';
                
                await Supabase.instance.client
                    .from('transport_relay')
                    .update({
                      'available_sacks': remaining,
                      'status': newStatus,
                    })
                    .eq('id', trip['id']);
                
                if (!mounted) return;
                await _fetchTrips();
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Slot booked successfully!"), backgroundColor: Colors.green));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Booking failed: $e"), backgroundColor: Colors.red));
                }
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF064E3B), foregroundColor: Colors.white),
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
  }

  Future<void> _showBookingHistory(String tripId) async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('transport_bookings')
          .select('*, profiles(*)')
          .eq('trip_id', tripId);
      
      if (!mounted) return;
      
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Farmers Joined Your Trip", style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
              const Divider(height: 32),
              if (response.isEmpty)
                Text("No farmers have booked yet", style: GoogleFonts.outfit(color: Colors.grey)),
              if (response.isNotEmpty)
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: response.length,
                    itemBuilder: (context, index) {
                      final booking = response[index];
                      final booker = booking['profiles'];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundImage: booker['avatar_url'] != null ? NetworkImage(booker['avatar_url']) : null,
                              child: booker['avatar_url'] == null ? const Icon(Icons.person) : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(booker['full_name'] ?? "Neighbor", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                                  Text("Village: ${booker['village']}", style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[600])),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text("${booking['sacks_booked']} Sacks", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFF10B981))),
                                Text("₹${booking['total_price']}", style: GoogleFonts.outfit(fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error fetching bookings: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        top: false, // Let the gradient hit the top, but children will be safe
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1B5E20)))
          : CustomScrollView(
              slivers: [
                _buildHeader(),
                SliverToBoxAdapter(child: _buildPostTripUI()),
                _buildTripsList(),
              ],
            ),
      ),
    );
  }

  Widget _buildHeader() {
    final topPadding = MediaQuery.of(context).padding.top;
    return SliverToBoxAdapter(
      child: Container(
        padding: EdgeInsets.only(top: topPadding + 20, left: 24, right: 24, bottom: 24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF064E3B), Color(0xFF065F46)]),
          borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Micro-Relay", style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
            Text("Peer-to-Peer Transport Sharing", style: GoogleFonts.outfit(fontSize: 14, color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  Widget _buildPostTripUI() {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Post Your Trip", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF064E3B))),
          const SizedBox(height: 16),
          _inputField(_destinationController, "Destination (e.g. City Market)", Icons.location_on_rounded),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _inputField(_spaceController, "Free Sacks", Icons.inventory_2_rounded, type: TextInputType.number, isNumeric: true, isDigitsOnly: true)),
              const SizedBox(width: 12),
              Expanded(child: _inputField(_priceController, "Price/Sack", Icons.payments_rounded, type: TextInputType.number, isNumeric: true)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _postTrip,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text("Post Sack-Sharing", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputField(TextEditingController controller, String hint, IconData icon, {TextInputType type = TextInputType.text, bool isNumeric = false, bool isDigitsOnly = false}) {
    return TextField(
      controller: controller,
      keyboardType: type,
      inputFormatters: [
        if (isDigitsOnly) FilteringTextInputFormatter.digitsOnly,
        if (isNumeric && !isDigitsOnly) FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ],
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF10B981), size: 20),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.all(14),
      ),
    );
  }

  Widget _buildTripsList() {
    if (_trips.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          height: 300,
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.local_shipping_outlined, size: 60, color: Colors.grey[300]),
              const SizedBox(height: 12),
              Text("No active trips nearby", style: GoogleFonts.outfit(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildTripCard(_trips[index]),
          childCount: _trips.length,
        ),
      ),
    );
  }

  Widget _buildTripCard(Map<String, dynamic> trip) {
    if (trip['profiles'] == null) return const SizedBox();
    final farmer = trip['profiles'];
    final departure = DateTime.parse(trip['departure_time']);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => _showFarmerProfile(farmer['id']),
            child: Row(
              children: [
                Hero(
                  tag: "avatar_${trip['id']}",
                  child: CircleAvatar(
                    radius: 25,
                    backgroundImage: farmer['avatar_url'] != null ? NetworkImage(farmer['avatar_url']) : null,
                    child: farmer['avatar_url'] == null ? const Icon(Icons.person) : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(farmer['full_name'] ?? "Farmer", style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text("Village: ${farmer['village'] ?? 'Unknown'}", style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(100)),
                  child: Text("₹${trip['price_per_sack']}/sack", style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF065F46))),
                ),
              ],
            ),
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _tripInfo(Icons.location_on_rounded, "Destination", trip['destination']),
              _tripInfo(Icons.inventory_2_rounded, "Free Space", "${trip['available_sacks']} Sacks"),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Departure: ${DateFormat('MMM dd, hh:mm a').format(departure)}", style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange[800])),
              ElevatedButton(
                onPressed: (Supabase.instance.client.auth.currentUser?.id == trip['profile_id'])
                    ? () => _showBookingHistory(trip['id'])
                    : (trip['available_sacks'] > 0 ? () => _bookSlot(trip) : null),
                style: ElevatedButton.styleFrom(
                  backgroundColor: (Supabase.instance.client.auth.currentUser?.id == trip['profile_id']) 
                      ? const Color(0xFF10B981) 
                      : const Color(0xFF064E3B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                ),
                child: Text(
                  (Supabase.instance.client.auth.currentUser?.id == trip['profile_id'])
                      ? "View Bookers"
                      : (trip['available_sacks'] > 0 ? "Book Slot" : "Full"),
                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tripInfo(IconData icon, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: const Color(0xFF10B981)),
            const SizedBox(width: 4),
            Text(label, style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey)),
          ],
        ),
        Text(value, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
