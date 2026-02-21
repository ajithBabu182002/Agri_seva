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
      title: 'Agri Seva',
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
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF004D40), // Deep Teal
            Color(0xFF00695C), // Teal
            Color(0xFF2E7D32), // Forest Green
          ],
        ),
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
          BoxShadow(color: const Color(0xFF2E7D32).withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 8))
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1B5E20),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
        ),
        child: Text(text, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
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
        child: Stack(
          children: [
            // Decorative shapes for a more impressive look
            Positioned(
              top: -50,
              right: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.eco_rounded, size: 60, color: Colors.white),
                          ),
                          const SizedBox(height: 20),
                          Text("Agri Seva", style: GoogleFonts.outfit(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)),
                          Text("Connecting Farmers to the Future", style: GoogleFonts.outfit(fontSize: 16, color: Colors.white.withOpacity(0.8))),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(topLeft: Radius.circular(50), topRight: Radius.circular(50)),
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -10))],
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Welcome Back", style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: const Color(0xFF1B5E20))),
                            Text("Sign in to continue your journey", style: GoogleFonts.outfit(fontSize: 15, color: Colors.grey[500])),
                            const SizedBox(height: 40),
                            _buildInputField(
                              controller: _emailController,
                              label: "Email Address",
                              icon: Icons.alternate_email_rounded,
                            ),
                            const SizedBox(height: 24),
                            _buildInputField(
                              controller: _passwordController,
                              label: "Password",
                              icon: Icons.lock_outline_rounded,
                              isPassword: true,
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => Navigator.pushNamed(context, '/forgot-password'),
                                child: Text("Forgot Password?", style: GoogleFonts.outfit(color: const Color(0xFF2E7D32), fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(height: 24),
                            if (_isLoading)
                              const Center(child: CircularProgressIndicator(color: Colors.green))
                            else
                              PrimaryButton(text: "LOGIN", onPressed: _signIn),
                            
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(child: Divider(color: Colors.grey[300])),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Text("OR", style: GoogleFonts.outfit(color: Colors.grey, fontWeight: FontWeight.bold)),
                                ),
                                Expanded(child: Divider(color: Colors.grey[300])),
                              ],
                            ),
                            const SizedBox(height: 24),
                            
                            // Premium Google Button
                            SizedBox(
                              width: double.infinity,
                              height: 58,
                              child: OutlinedButton(
                                onPressed: _signInWithGoogle,
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  side: BorderSide(color: Colors.grey[200]!, width: 1.5),
                                  backgroundColor: Colors.white,
                                  elevation: 0,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Image.network(
                                      'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1200px-Google_%22G%22_logo.svg.png',
                                      height: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Text("Sign in with Google", style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
                                  ],
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 30),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text("New user?", style: GoogleFonts.outfit(color: Colors.grey[600])),
                                TextButton(
                                  onPressed: () => Navigator.pushNamed(context, '/signup'),
                                  child: Text("Create Account", style: GoogleFonts.outfit(color: const Color(0xFF2E7D32), fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({required TextEditingController controller, required String label, required IconData icon, bool isPassword = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[700])),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isPassword,
          style: GoogleFonts.outfit(fontSize: 16, color: Colors.black87),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: const Color(0xFF2E7D32), size: 22),
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: const EdgeInsets.symmetric(vertical: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 1.5)),
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
      backgroundColor: Colors.white,
      appBar: AppBar(title: Text("Create Account", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildAuthField(_nameController, "Full Name", Icons.person_outline),
              const SizedBox(height: 16),
              IntlPhoneField(
                decoration: InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
                initialCountryCode: 'IN',
                onChanged: (phone) => _phoneController.text = phone.completeNumber,
              ),
              const SizedBox(height: 16),
              _buildAuthField(_emailController, "Email Address", Icons.alternate_email, type: TextInputType.emailAddress),
              const SizedBox(height: 16),
              _buildAuthField(_passwordController, "Strong Password", Icons.lock_outline, obscure: true),
              const SizedBox(height: 16),
              _buildAuthField(_addressController, "Full Address", Icons.home_outlined, lines: 2),
              const SizedBox(height: 16),
              SelectState(
                onCountryChanged: (v) => setState(() => _selectedCountry = v),
                onStateChanged: (v) => setState(() => _selectedState = v),
                onCityChanged: (v) {},
              ),
              const SizedBox(height: 16),
              _buildAuthField(_pinController, "Pin Code", Icons.pin_drop_outlined, type: TextInputType.number),
              const SizedBox(height: 32),
              if (_isLoading) const CircularProgressIndicator() else PrimaryButton(text: "Create My Account", onPressed: _register),
              const SizedBox(height: 20),
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
      style: GoogleFonts.outfit(),
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 20)),
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Account Recovery", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            const Icon(Icons.security_rounded, size: 80, color: Colors.green),
            const SizedBox(height: 20),
            Text(
              "Identify yourself to recover your account. Both email and phone number must match.",
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: Colors.grey[600]),
            ),
            const SizedBox(height: 40),
            
            // Email Field
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: "Registered Email",
                prefixIcon: Icon(Icons.email_outlined, color: Colors.green[700]),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
            const SizedBox(height: 20),
            
            // Phone Field
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: "Registered Phone Number",
                prefixIcon: Icon(Icons.phone_android_rounded, color: Colors.green[700]),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
            
            const SizedBox(height: 40),
            if (_isLoading)
              const CircularProgressIndicator(color: Colors.green)
            else
              PrimaryButton(text: "VERIFY & RECOVER", onPressed: _handleRecovery),
          ],
        ),
      ),
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
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 60),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.security_update_good_rounded, size: 50, color: Colors.white),
                ),
                const SizedBox(height: 24),
                Text("Secure Your Account", style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 8),
                Text("Create a strong new password", style: GoogleFonts.outfit(color: Colors.white70)),
                
                const SizedBox(height: 40),
                
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(50), topRight: Radius.circular(50)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("New Password", style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF1B5E20))),
                      const SizedBox(height: 30),
                      
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        style: GoogleFonts.outfit(),
                        decoration: InputDecoration(
                          labelText: "Enter New Password",
                          prefixIcon: const Icon(Icons.lock_reset_rounded, color: Color(0xFF2E7D32)),
                          filled: true,
                          fillColor: Colors.grey[50],
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                        ),
                      ),
                      
                      const SizedBox(height: 40),
                      if (_isLoading)
                        const Center(child: CircularProgressIndicator(color: Colors.green))
                      else
                        PrimaryButton(text: "UPDATE PASSWORD", onPressed: _updatePassword),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
