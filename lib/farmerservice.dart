import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FarmerServicePage extends StatelessWidget {
  final Map<String, dynamic> filterCriteria;
  const FarmerServicePage({super.key, required this.filterCriteria});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.engineering_rounded, size: 64, color: Color(0xFF1B5E20)),
            const SizedBox(height: 16),
            Text(
              "Farmer Service coming soon",
              style: GoogleFonts.outfit(
                fontSize: 20,
                color: const Color(0xFF064E3B),
                fontWeight: FontWeight.bold,
              ),
            ),
            if (filterCriteria['field'] != 'All' && filterCriteria['field'] != 'Farmer Service')
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text("Switch filter field to see services", style: GoogleFonts.outfit(color: Colors.grey)),
              ),
          ],
        ),
      ),
    );
  }
}
