import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FarmerServicePage extends StatelessWidget {
  const FarmerServicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Text(
          "Farmer Service Screen",
          style: GoogleFonts.outfit(
            fontSize: 20,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }
}
