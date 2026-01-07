import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:eight_express/providers/user_provider.dart';
import 'package:eight_express/widgets/custom_loader.dart';

enum AuthMode { login, register, otpVerify }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _identityController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  AuthMode _authMode = AuthMode.login;
  bool _isLoading = false;
  bool _agreedToTerms = false;
  String? _errorMessage;

  bool get _isPhoneInput => _identityController.text.isNotEmpty && RegExp(r'^\d').hasMatch(_identityController.text);

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_authMode == AuthMode.register && !_agreedToTerms) {
      setState(() => _errorMessage = "Please agree to the terms.");
      return;
    }

    setState(() { _isLoading = true; _errorMessage = null; });
    final prov = Provider.of<UserProvider>(context, listen: false);

    try {
      if (_authMode == AuthMode.otpVerify) {
        await prov.verifyOTPAndLogin(_otpController.text, name: _nameController.text);
      } else if (_isPhoneInput) {
        await prov.sendOTP(_identityController.text, 
          onCodeSent: (id) => setState(() { _authMode = AuthMode.otpVerify; _isLoading = false; }),
          onError: (err) => setState(() { _errorMessage = err; _isLoading = false; }));
      } else {
        if (_authMode == AuthMode.login) {
          await prov.login(_identityController.text, _passwordController.text);
        } else {
          await prov.registerWithEmail(_identityController.text, _passwordController.text, _nameController.text);
          _showEmailVerifyDialog();
        }
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceAll("Exception:", ""));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showEmailVerifyDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("Verify Email"),
        content: const Text("A link was sent to your email. Please verify it to continue."),
        actions: [
          ElevatedButton(
            onPressed: () async {
              bool verified = await Provider.of<UserProvider>(context, listen: false).checkEmailVerified();
              if (verified) Navigator.pop(ctx);
              else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Not verified yet.")));
            },
            child: const Text("I Verified"),
          )
        ],
      ),
    );
  }

  void _showResetDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Reset Password"),
        content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: "Enter Email")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(onPressed: () async {
            await Provider.of<UserProvider>(context, listen: false).resetPassword(ctrl.text);
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reset link sent!")));
          }, child: const Text("Send"))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF0D47A1);
    const accentColor = Color(0xFFFE7F2D);

    return Scaffold(
      body: Container(
        height: double.infinity,
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [primaryColor, Color(0xFF1976D2)],
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 50),
                  const Icon(Icons.local_shipping, size: 80, color: Colors.white),
                  const Text("08Express", style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 40),
                  
                  // Container for the inputs
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Column(
                      children: [
                        if (_authMode != AuthMode.otpVerify)
                        Row(children: [
                          _buildTab("LOGIN", AuthMode.login, accentColor),
                          _buildTab("SIGN UP", AuthMode.register, accentColor),
                        ]),
                        const SizedBox(height: 30),
                        
                        if (_authMode == AuthMode.otpVerify) ...[
                          const Text("Enter SMS Code", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 20),
                          _buildField(_otpController, "6-Digit OTP", Icons.lock, isNumber: true),
                        ] else ...[
                          if (_authMode == AuthMode.register) ...[
                            _buildField(_nameController, "Full Name", Icons.person),
                            const SizedBox(height: 15),
                          ],
                          _buildField(_identityController, "Email or Phone", Icons.email),
                          if (!_isPhoneInput) ...[
                            const SizedBox(height: 15),
                            _buildField(_passwordController, "Password", Icons.lock, isPass: true),
                            if (_authMode == AuthMode.login)
                            Align(alignment: Alignment.centerRight, child: TextButton(onPressed: _showResetDialog, child: const Text("Forgot Password?"))),
                          ],
                        ],
                        
                        if (_authMode == AuthMode.register) 
                        Row(children: [
                          Checkbox(value: _agreedToTerms, onChanged: (v) => setState(() => _agreedToTerms = v!)),
                          const Expanded(child: Text("Agree to Terms & Conditions", style: TextStyle(fontSize: 12))),
                        ]),

                        if (_errorMessage != null) 
                        Padding(padding: const EdgeInsets.only(top: 15), child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13))),

                        const SizedBox(height: 30),
                        _isLoading ? const CustomLoader(size: 50) : ElevatedButton(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor, minimumSize: const Size(double.infinity, 55),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                          ),
                          child: Text(_authMode == AuthMode.otpVerify ? "VERIFY" : (_authMode == AuthMode.login ? "LOGIN" : "SIGN UP"), 
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_authMode == AuthMode.otpVerify)
                    TextButton(onPressed: () => setState(() => _authMode = AuthMode.login), child: const Text("Back", style: TextStyle(color: Colors.white))),
                  
                  if (_authMode == AuthMode.login)
                    TextButton(onPressed: () => Provider.of<UserProvider>(context, listen: false).enterGuestMode(), 
                      child: const Text("Continue as Guest", style: TextStyle(color: Colors.white))),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTab(String label, AuthMode mode, Color color) {
    bool active = _authMode == mode;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _authMode = mode),
        child: Column(children: [
          Text(label, style: TextStyle(color: active ? color : Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Container(height: 3, color: active ? color : Colors.transparent),
        ]),
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String hint, IconData icon, {bool isPass = false, bool isNumber = false}) {
    return TextFormField(
      controller: ctrl,
      obscureText: isPass,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.grey),
        hintText: hint, filled: true, fillColor: Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      ),
      validator: (v) => (v == null || v.isEmpty) ? "Required" : null,
    );
  }
}