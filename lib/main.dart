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
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF4CAF50), // Vibrant Green
            Color(0xFF2E7D32), // Deep Forest Green
            Color(0xFF1B5E20), // Darkest Green
          ],
        ),
      ),
      child: Stack(
        children: [
          // Subtle background texture or shapes
          Positioned(
            top: -100,
            left: -100,
            child: CircleAvatar(
              radius: 200,
              backgroundColor: Colors.white.withOpacity(0.05),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: CircleAvatar(
              radius: 150,
              backgroundColor: const Color(0xFFFFD54F).withOpacity(0.05), // Sun Yellow hint
            ),
          ),
          child,
        ],
      ),
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
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError("Missing Info", "Please enter your email and password.");
      return;
    }

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
        TextField(
          controller: controller,
          obscureText: isPassword,
          style: GoogleFonts.outfit(fontSize: 15, color: Colors.black87),
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
  String? _selectedCountry;
  String? _selectedState;
  bool _isLoading = false;

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        data: {
          'full_name': _nameController.text.trim(),
          'phone_number': _phoneController.text.trim(),
          'email_id': _emailController.text.trim(),
          'address': _addressController.text.trim(),
          'country': _selectedCountry,
          'state': _selectedState,
          'pin_code': _pinController.text.trim(),
        },
      );
      if (mounted) _showSuccess();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
                      child: Column(
                        children: [
                          _buildAuthField(_nameController, "Full Name", Icons.person_outline_rounded),
                          const SizedBox(height: 16),
                          IntlPhoneField(
                            decoration: InputDecoration(
                              labelText: 'Phone Number',
                              labelStyle: GoogleFonts.outfit(fontSize: 14),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: Colors.grey[200]!)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: Colors.grey[200]!)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFF2E7D32))),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            initialCountryCode: 'IN',
                            onChanged: (phone) => _phoneController.text = phone.completeNumber,
                          ),
                          const SizedBox(height: 16),
                          _buildAuthField(_emailController, "Email Address", Icons.alternate_email_rounded, type: TextInputType.emailAddress),
                          const SizedBox(height: 16),
                          _buildAuthField(_passwordController, "Strong Password", Icons.lock_outline_rounded, obscure: true),
                          const SizedBox(height: 16),
                          _buildAuthField(_addressController, "Full Address", Icons.home_outlined, lines: 2),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: SelectState(
                              onCountryChanged: (v) => setState(() => _selectedCountry = v),
                              onStateChanged: (v) => setState(() => _selectedState = v),
                              onCityChanged: (v) {},
                            ),
                          ),
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

  Widget _buildAuthField(TextEditingController controller, String label, IconData icon, {bool obscure = false, TextInputType type = TextInputType.text, int lines = 1}) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: type,
      maxLines: lines,
      style: GoogleFonts.outfit(fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.outfit(fontSize: 14),
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF2E7D32)),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: Colors.grey[200]!)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: Colors.grey[200]!)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFF2E7D32))),
      ),
      validator: (v) => v!.isEmpty ? 'This field is required' : null,
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
