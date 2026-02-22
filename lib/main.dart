import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:country_state_city_picker/country_state_city_picker.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://iuixlyxzwtmmucnsxcyl.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml1aXhseXh6d3RtbXVjbnN4Y3lsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE2NjY4NTcsImV4cCI6MjA4NzI0Mjg1N30.D40oj4naA3NVzb7KI8cHFkGH9hZpsKAyDf6KNKZF0HQ',
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  runApp(const MyApp());
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Global listener for auth events like Password Recovery
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        navigatorKey.currentState?.pushNamed('/reset-password');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Agrovia Global',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
          primary: const Color(0xFF2E7D32),
        ),
        textTheme: GoogleFonts.outfitTextTheme(),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[50],
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 1)),
          labelStyle: GoogleFonts.outfit(color: Colors.grey[600]),
        ),
      ),
      home: Supabase.instance.client.auth.currentSession == null
          ? const LoginPage()
          : const HomePage(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignUpPage(),
        '/home': (context) => const HomePage(),
        '/forgot-password': (context) => const ForgotPasswordPage(),
        '/reset-password': (context) => const UpdatePasswordPage(),
      },
    );
  }
}

// --- COMMON COMPONENTS ---
class AuthBackground extends StatelessWidget {
  final Widget child;
  const AuthBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1B5E20), // Solid Deep Green
      ),
      child: child,
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  const PrimaryButton({super.key, required this.text, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 58,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E7D32).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2E7D32),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
        ),
        child: Text(
          text,
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

// --- LOGIN PAGE ---
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        Navigator.pushNamed(context, '/reset-password');
      }
    });
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(email: email, password: password);
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      _showError("Login Error", "Invalid credentials. Please try again.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : 'io.supabase.agri://login-callback',
      );
    } catch (e) {
      _showError("Login Error", "Failed to sign in with Google.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String title, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.outfit()),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuthBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      // Animated Logo Container
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(0.2)),
                        ),
                        child: Hero(
                          tag: 'app_logo',
                          child: Image.asset('assets/logo.png', height: 120),
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // Title Section
                      Text(
                        "Agrovia Global",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.5,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.2),
                              offset: const Offset(0, 4),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Empowering Agriculture Internationally",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.8),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 48),

                      // Login Form Card
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(35),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 30,
                              offset: const Offset(0, 15),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Welcome Back",
                              style: GoogleFonts.outfit(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1B5E20),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Please sign in to your account",
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 32),
                            Form(
                              key: _formKey,
                              autovalidateMode: AutovalidateMode.onUserInteraction,
                              child: Column(
                                children: [
                                  _buildInputField(
                                    controller: _emailController,
                                    label: "Email ID",
                                    icon: Icons.alternate_email_rounded,
                                    hintText: "example@agrovia.com",
                                  ),
                                  const SizedBox(height: 20),
                                  _buildInputField(
                                    controller: _passwordController,
                                    label: "Password",
                                    icon: Icons.lock_open_rounded,
                                    isPassword: true,
                                    hintText: "••••••••",
                                  ),
                                ],
                              ),
                            ),
                            
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => Navigator.pushNamed(context, '/forgot-password'),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                ),
                                child: Text(
                                  "Forgot Password?",
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFF2E7D32),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            
                            if (_isLoading)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
                                ),
                              )
                            else
                              PrimaryButton(text: "SIGN IN", onPressed: _signIn),
                            
                            const SizedBox(height: 30),
                            
                            // Separator
                            Row(
                              children: [
                                Expanded(child: Divider(color: Colors.grey[200], thickness: 1)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(
                                    "OR CONNECT WITH",
                                    style: GoogleFonts.outfit(
                                      color: Colors.grey[400],
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                                Expanded(child: Divider(color: Colors.grey[200], thickness: 1)),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Google Login Button
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: OutlinedButton(
                                onPressed: _signInWithGoogle,
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  side: BorderSide(color: Colors.grey[200]!),
                                  backgroundColor: Colors.white,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Image.network(
                                      'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1200px-Google_%22G%22_logo.svg.png',
                                      height: 22,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      "Google Account",
                                      style: GoogleFonts.outfit(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Footer
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account?",
                            style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pushNamed(context, '/signup'),
                            child: Text(
                              "Join Us",
                              style: GoogleFonts.outfit(
                                color: const Color(0xFFFFD54F), // Yellow accent
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    String? hintText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          obscureText: isPassword,
          style: GoogleFonts.outfit(fontSize: 15, color: Colors.black87),
          validator: (v) => (v == null || v.isEmpty) ? 'Please enter this field' : null,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: GoogleFonts.outfit(color: Colors.grey[400], fontSize: 14),
            prefixIcon: Icon(icon, color: const Color(0xFF2E7D32), size: 20),
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

// --- SIGN UP PAGE ---
class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _addressController = TextEditingController();
  final _pinController = TextEditingController();
  String _selectedCountry = "India";
  final _stateController = TextEditingController();
  final _districtController = TextEditingController();
  final _talukController = TextEditingController();
  final _villageController = TextEditingController();
  String _countryCode = '+91';
  bool _isLoading = false;
  bool _isPhoneDuplicate = false;
  bool _isEmailDuplicate = false;
  Timer? _debounce;
  
  final List<String> _countries = [
    "Afghanistan", "Albania", "Algeria", "Andorra", "Angola", "Antigua and Barbuda", "Argentina", "Armenia", "Australia", "Austria", "Azerbaijan",
    "Bahamas", "Bahrain", "Bangladesh", "Barbados", "Belarus", "Belgium", "Belize", "Benin", "Bhutan", "Bolivia", "Bosnia and Herzegovina", "Botswana", "Brazil", "Brunei", "Bulgaria", "Burkina Faso", "Burundi",
    "Cabo Verde", "Cambodia", "Cameroon", "Canada", "Central African Republic", "Chad", "Chile", "China", "Colombia", "Comoros", "Congo", "Costa Rica", "Croatia", "Cuba", "Cyprus", "Czech Republic",
    "Denmark", "Djibouti", "Dominica", "Dominican Republic",
    "Ecuador", "Egypt", "El Salvador", "Equatorial Guinea", "Eritrea", "Estonia", "Eswatini", "Ethiopia",
    "Fiji", "Finland", "France",
    "Gabon", "Gambia", "Georgia", "Germany", "Ghana", "Greece", "Grenada", "Guatemala", "Guinea", "Guinea-Bissau", "Guyana",
    "Haiti", "Honduras", "Hungary",
    "Iceland", "India", "Indonesia", "Iran", "Iraq", "Ireland", "Israel", "Italy", "Ivory Coast",
    "Jamaica", "Japan", "Jordan",
    "Kazakhstan", "Kenya", "Kiribati", "Kuwait", "Kyrgyzstan",
    "Laos", "Latvia", "Lebanon", "Lesotho", "Liberia", "Libya", "Liechtenstein", "Lithuania", "Luxembourg",
    "Madagascar", "Malawi", "Malaysia", "Maldives", "Mali", "Malta", "Marshall Islands", "Mauritania", "Mauritius", "Mexico", "Micronesia", "Moldova", "Monaco", "Mongolia", "Montenegro", "Morocco", "Mozambique", "Myanmar",
    "Namibia", "Nauru", "Nepal", "Netherlands", "New Zealand", "Nicaragua", "Niger", "Nigeria", "North Korea", "North Macedonia", "Norway",
    "Oman",
    "Pakistan", "Palau", "Palestine", "Panama", "Papua New Guinea", "Paraguay", "Peru", "Philippines", "Poland", "Portugal",
    "Qatar",
    "Romania", "Russia", "Rwanda",
    "Saint Kitts and Nevis", "Saint Lucia", "Saint Vincent and the Grenadines", "Samoa", "San Marino", "Sao Tome and Principe", "Saudi Arabia", "Senegal", "Serbia", "Seychelles", "Sierra Leone", "Singapore", "Slovakia", "Slovenia", "Solomon Islands", "Somalia", "South Africa", "South Korea", "South Sudan", "Spain", "Sri Lanka", "Sudan", "Suriname", "Sweden", "Switzerland", "Syria",
    "Taiwan", "Tajikistan", "Tanzania", "Thailand", "Timor-Leste", "Togo", "Tonga", "Trinidad and Tobago", "Tunisia", "Turkey", "Turkmenistan", "Tuvalu",
    "Uganda", "Ukraine", "United Arab Emirates", "United Kingdom", "United States", "Uruguay", "Uzbekistan",
    "Vanuatu", "Vatican City", "Venezuela", "Vietnam",
    "Yemen",
    "Zambia", "Zimbabwe"
  ];

  final List<String> _indianStates = [
    "Andhra Pradesh", "Arunachal Pradesh", "Assam", "Bihar", "Chhattisgarh", "Goa", "Gujarat", "Haryana",
    "Himachal Pradesh", "Jharkhand", "Karnataka", "Kerala", "Madhya Pradesh", "Maharashtra", "Manipur",
    "Meghalaya", "Mizoram", "Nagaland", "Odisha", "Punjab", "Rajasthan", "Sikkim", "Tamil Nadu",
    "Telangana", "Tripura", "Uttar Pradesh", "Uttarakhand", "West Bengal",
    "Andaman and Nicobar Islands", "Chandigarh", "Dadra and Nagar Haveli and Daman and Diu",
    "Delhi", "Jammu and Kashmir", "Ladakh", "Lakshadweep", "Puducherry"
  ];

  @override
  void dispose() {
    _debounce?.cancel();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _addressController.dispose();
    _pinController.dispose();
    _stateController.dispose();
    _districtController.dispose();
    _talukController.dispose();
    _villageController.dispose();
    super.dispose();
  }

  Future<void> _checkPhoneDuplicate(String phoneNumber) async {
    if (phoneNumber.length < 5) { // Minimum length to avoid false positives
      setState(() => _isPhoneDuplicate = false);
      _formKey.currentState?.validate();
      return;
    }
    
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final check = await Supabase.instance.client
          .from('profiles')
          .select('id')
          .eq('phone_number', phoneNumber)
          .maybeSingle();
      
      if (mounted) {
        setState(() {
          _isPhoneDuplicate = check != null;
        });
        // CRITICAL: We call validate() every time to ensure the error text 
        // appears when a duplicate is found AND disappears when the number is fixed.
        _formKey.currentState?.validate();
      }
    });
  }

  Future<void> _checkEmailDuplicate(String email) async {
    if (email.isEmpty || !email.contains('@')) return;
    
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final check = await Supabase.instance.client
          .from('profiles')
          .select('id')
          .eq('email_id', email)
          .maybeSingle();
      
      if (mounted) {
        setState(() {
          _isEmailDuplicate = check != null;
        });
        // Ensures the email error disappears instantly when the user fixes it
        _formKey.currentState?.validate();
      }
    });
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final email = _emailController.text.trim();
      final phone = _phoneController.text.trim();

      // Both flags are checked here as a final safety measure
      if (_isEmailDuplicate || _isPhoneDuplicate) {
        setState(() => _isLoading = false);
        return;
      }

      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: _passwordController.text.trim(),
        data: {
          'full_name': _nameController.text.trim(),
          'country_code': _countryCode,
          'phone_number': _phoneController.text.trim(),
          'email_id': email,
          'address': _addressController.text.trim(),
          'country': _selectedCountry,
          'state': _stateController.text.trim(),
          'district': _districtController.text.trim(),
          'taluk': _talukController.text.trim(),
          'village': _villageController.text.trim(),
          'pin_code': _pinController.text.trim(),
        },
      );
      
      // If the user is created (and signed in, depending on email confirmation)
      if (response.user != null) {
        // We attempt to update the profiles table. 
        // NOTE: If you get a 401 Unauthorized, ensure your RLS policy allows inserts 
        // for authenticated or public users, or use a Supabase Trigger instead.
        try {
          await Supabase.instance.client.from('profiles').upsert({
            'id': response.user!.id,
            'full_name': _nameController.text.trim(),
            'country_code': _countryCode,
            'phone_number': _phoneController.text.trim(),
            'email_id': _emailController.text.trim(),
            'address': _addressController.text.trim(),
            'country': _selectedCountry,
            'state': _stateController.text.trim(),
            'district': _districtController.text.trim(),
            'taluk': _talukController.text.trim(),
            'village': _villageController.text.trim(),
            'pin_code': _pinController.text.trim(),
            'updated_at': DateTime.now().toIso8601String(),
          });
        } catch (profileError) {
          debugPrint("Profile insertion error: $profileError");
          // Even if profile insert fails in code, the user is still created in Auth.
        }
      }

      if (mounted) _showSuccess();
    } on AuthException catch (e) {
      debugPrint("Auth Error Details: ${e.message}, Code: ${e.code}, Status: ${e.statusCode}");
      String message = 'Registration error: ${e.message}';
      if (e.statusCode == '422') {
        message = "Invalid registration data. Please check your details (like email format or password complexity) and try again.";
      }
      if (e.code == 'over_email_send_rate_limit') {
        message = "Too many attempts. Please wait a few minutes before trying again or check your email for a verification link.";
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message, style: GoogleFonts.outfit()),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint("Unexpected Registration Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unexpected error: $e', style: GoogleFonts.outfit()),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Hurray! 🎉", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text("Account created! Please verify your email to continue.", style: GoogleFonts.outfit()),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/login');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text("Go to Login", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuthBackground(
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  "Create Account",
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                centerTitle: true,
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(35),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: Column(
                        children: [
                          _buildAuthField(_nameController, "Full Name", Icons.person_outline_rounded),
                          const SizedBox(height: 16),
                          IntlPhoneField(
                            autovalidateMode: AutovalidateMode.onUserInteraction,
                            decoration: InputDecoration(
                              labelText: 'Phone Number',
                              labelStyle: GoogleFonts.outfit(fontSize: 14),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: Colors.grey[200]!)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: Colors.grey[200]!)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFF2E7D32))),
                              errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Colors.redAccent)),
                              focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            initialCountryCode: 'IN',
                            onChanged: (phone) {
                              _countryCode = phone.countryCode;
                              _phoneController.text = phone.number;
                              _checkPhoneDuplicate(phone.number);
                            },
                            validator: (phone) {
                              if (phone == null || phone.number.isEmpty) {
                                return 'Please enter your phone number';
                              }
                              if (_isPhoneDuplicate) {
                                return 'Phone number already registered';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildAuthField(_emailController, "Email Address", Icons.alternate_email_rounded, type: TextInputType.emailAddress),
                          const SizedBox(height: 16),
                          _buildAuthField(_passwordController, "Strong Password", Icons.lock_outline_rounded, obscure: true),
                          const SizedBox(height: 16),
                          const SizedBox(height: 16),
                          _buildAuthField(_addressController, "Full Address", Icons.home_outlined, lines: 2),
                          const SizedBox(height: 16),
                          
                          // Country Dropdown
                          DropdownButtonFormField<String>(
                            value: _selectedCountry,
                            style: GoogleFonts.outfit(fontSize: 15, color: Colors.black),
                            decoration: InputDecoration(
                              labelText: "Select Country",
                              labelStyle: GoogleFonts.outfit(fontSize: 14),
                              prefixIcon: const Icon(Icons.public_rounded, size: 20, color: Color(0xFF2E7D32)),
                              filled: true,
                              fillColor: Colors.grey[50],
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: Colors.grey[200]!)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: Colors.grey[200]!)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFF2E7D32))),
                            ),
                            items: _countries.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                            onChanged: (v) => setState(() => _selectedCountry = v!),
                          ),
                          
                          if (_selectedCountry == "India") ...[
                            const SizedBox(height: 16),
                            _buildAuthField(_stateController, "State", Icons.map_outlined, isOptional: false, 
                              suffixIcon: IconButton(icon: const Icon(Icons.list_rounded, color: Color(0xFF2E7D32)), 
                                onPressed: () => _showSearchablePicker(_stateController, "Select State", _indianStates))),
                            const SizedBox(height: 16),
                            _buildAuthField(_districtController, "District", Icons.location_city_rounded, isOptional: false,
                              suffixIcon: IconButton(icon: const Icon(Icons.list_rounded, color: Color(0xFF2E7D32)), 
                                onPressed: () => _showSearchablePicker(_districtController, "Select District", []))),
                            const SizedBox(height: 16),
                            _buildAuthField(_talukController, "Taluk", Icons.holiday_village_rounded, isOptional: false,
                              suffixIcon: IconButton(icon: const Icon(Icons.list_rounded, color: Color(0xFF2E7D32)), 
                                onPressed: () => _showSearchablePicker(_talukController, "Select Taluk", []))),
                            const SizedBox(height: 16),
                            _buildAuthField(_villageController, "Village", Icons.vignette_rounded, isOptional: false,
                              suffixIcon: IconButton(icon: const Icon(Icons.list_rounded, color: Color(0xFF2E7D32)), 
                                onPressed: () => _showSearchablePicker(_villageController, "Select Village", []))),
                          ],
                          const SizedBox(height: 16),
                          _buildAuthField(_pinController, "Pin Code", Icons.pin_drop_outlined, type: TextInputType.number),
                          const SizedBox(height: 32),
                          if (_isLoading)
                            const CircularProgressIndicator(color: Color(0xFF2E7D32))
                          else
                            PrimaryButton(text: "Register Now", onPressed: _register),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAuthField(TextEditingController controller, String label, IconData icon, {bool obscure = false, TextInputType type = TextInputType.text, int lines = 1, bool isOptional = false, Widget? suffixIcon}) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: type,
      maxLines: lines,
      style: GoogleFonts.outfit(fontSize: 15),
      onChanged: (v) {
        if (label == "Email Address") {
          _checkEmailDuplicate(v.trim());
        }
      },
      decoration: InputDecoration(
        labelText: label + (isOptional ? " (Optional)" : ""),
        labelStyle: GoogleFonts.outfit(fontSize: 14),
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF2E7D32)),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: Colors.grey[200]!)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: Colors.grey[200]!)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFF2E7D32))),
      ),
      validator: (v) {
        if (!isOptional && (v == null || v.isEmpty)) return 'This field is required';
        if (label == "Email Address" && _isEmailDuplicate) return 'Email already registered';
        return null;
      },
    );
  }

  void _showSearchablePicker(TextEditingController controller, String title, List<String> items) {
    showDialog(
      context: context,
      builder: (context) {
        String searchQuery = "";
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredItems = items.where((item) => item.toLowerCase().contains(searchQuery.toLowerCase())).toList();
            return AlertDialog(
              title: Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (items.isNotEmpty)
                    TextField(
                      onChanged: (v) => setDialogState(() => searchQuery = v),
                      decoration: InputDecoration(
                        hintText: "Search...",
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text("No suggestions available.\nPlease type manually.", textAlign: TextAlign.center, style: GoogleFonts.outfit(color: Colors.grey)),
                      )
                    else
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: filteredItems.length,
                          itemBuilder: (context, index) {
                            return ListTile(
                              title: Text(filteredItems[index], style: GoogleFonts.outfit()),
                              onTap: () {
                                controller.text = filteredItems[index];
                                Navigator.pop(context);
                                setState(() {});
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
              ],
            );
          },
        );
      },
    );
  }
}

// --- FORGOT PASSWORD PAGE ---
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleRecovery() async {
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();

    if (email.isEmpty || phone.isEmpty) {
      _showSnack("Please enter both email and phone number", Colors.orange);
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 1. Verify credentials in profiles table
      final data = await Supabase.instance.client
          .from('profiles')
          .select('id')
          .eq('email_id', email)
          .eq('phone_number', phone)
          .maybeSingle();

      if (data == null) {
        _showSnack("Credentials didn't match our records.", Colors.red);
        setState(() => _isLoading = false);
        return;
      }

      // 2. If correct, trigger password reset email (Supabase standard for security)
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      
      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      _showSnack("Recovery error: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg, style: GoogleFonts.outfit()), backgroundColor: color),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Verification Success! ✅", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text(
          "Your identity has been verified. A secure password reset link has been sent to your email address.",
          style: GoogleFonts.outfit(),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text("Back to Login", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.green)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuthBackground(
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  "Recover Account",
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                centerTitle: true,
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(35),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F8E9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.security_rounded, size: 60, color: Color(0xFF2E7D32)),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          "Identity Verification",
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1B5E20),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Both email and phone number must match our records to proceed.",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(color: Colors.grey[600], fontSize: 13),
                        ),
                        const SizedBox(height: 40),
                        
                        // Email Field
                        _buildRecoveryField(
                          _emailController, 
                          "Registered Email", 
                          Icons.email_outlined,
                          type: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 20),
                        
                        // Phone Field
                        _buildRecoveryField(
                          _phoneController, 
                          "Registered Phone", 
                          Icons.phone_android_rounded,
                          type: TextInputType.phone,
                        ),
                        
                        const SizedBox(height: 40),
                        if (_isLoading)
                          const CircularProgressIndicator(color: Color(0xFF2E7D32))
                        else
                          PrimaryButton(text: "Verify Identity", onPressed: _handleRecovery),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecoveryField(TextEditingController controller, String label, IconData icon, {TextInputType type = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey[700]),
          ),
        ),
        TextField(
          controller: controller,
          keyboardType: type,
          style: GoogleFonts.outfit(fontSize: 15),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: const Color(0xFF2E7D32), size: 20),
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: Colors.grey[200]!)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: Colors.grey[200]!)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFF2E7D32))),
          ),
        ),
      ],
    );
  }
}

// --- UPDATE PASSWORD PAGE ---
class UpdatePasswordPage extends StatefulWidget {
  const UpdatePasswordPage({super.key});

  @override
  State<UpdatePasswordPage> createState() => _UpdatePasswordPageState();
}

class _UpdatePasswordPageState extends State<UpdatePasswordPage> {
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _updatePassword() async {
    final password = _passwordController.text.trim();
    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Password must be at least 6 characters", style: GoogleFonts.outfit()), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.updateUser(UserAttributes(password: password));
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text("Password Updated! 🛡️", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            content: Text("Your account is now secure. Please login with your new password.", style: GoogleFonts.outfit()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                child: Text("Continue to Login", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.green)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Update error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuthBackground(
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  "Reset Password",
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                centerTitle: true,
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(35),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F8E9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.lock_reset_rounded, size: 60, color: Color(0xFF2E7D32)),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          "New Password",
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1B5E20),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Create a secure password to protect your account.",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(color: Colors.grey[600], fontSize: 13),
                        ),
                        const SizedBox(height: 40),
                        
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          style: GoogleFonts.outfit(fontSize: 15),
                          decoration: InputDecoration(
                            labelText: "Enter Password",
                            labelStyle: GoogleFonts.outfit(fontSize: 14),
                            prefixIcon: const Icon(Icons.vpn_key_rounded, color: Color(0xFF2E7D32), size: 20),
                            filled: true,
                            fillColor: Colors.grey[50],
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: Colors.grey[200]!)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: Colors.grey[200]!)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFF2E7D32))),
                          ),
                        ),
                        
                        const SizedBox(height: 40),
                        if (_isLoading)
                          const CircularProgressIndicator(color: Color(0xFF2E7D32))
                        else
                          PrimaryButton(text: "Update Password", onPressed: _updatePassword),
                        const SizedBox(height: 10),
                      ],
                    ),
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
