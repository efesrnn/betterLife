import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_screen.dart';

class UsernameSelectionScreen extends StatefulWidget {
  final String selectedHabit;
  final String selectedGoal;

  const UsernameSelectionScreen({
    super.key,
    required this.selectedHabit,
    required this.selectedGoal,
  });

  @override
  State<UsernameSelectionScreen> createState() => _UsernameSelectionScreenState();
}

class _UsernameSelectionScreenState extends State<UsernameSelectionScreen> {
  final TextEditingController _usernameController = TextEditingController();
  bool _isReadyToProceed = false;
  bool _isLoading = false;

  final supabase = Supabase.instance.client;

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _saveUsernameAndProceed() async {
    final username = _usernameController.text.trim();

    setState(() => _isLoading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('User not found');

      await supabase.auth.updateUser(
        UserAttributes(
          data: {
            'username': username,
            'habit': widget.selectedHabit,
            'goal': widget.selectedGoal,
            'is_setup_complete': true,
          },
        ),
      );

      await supabase.from('profiles').upsert({
        'id': user.id,
        'username': username,
        'habit': widget.selectedHabit,
        'goal': widget.selectedGoal,
      });

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
              (route) => false,
        );
      }
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'WHAT SHOULD WE\nCALL YOU?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 1.2),
              ),
              const SizedBox(height: 50),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black87, width: 2),
                ),
                child: TextField(
                  controller: _usernameController,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  onChanged: (text) {
                    setState(() {
                      _isReadyToProceed = text.trim().length >= 3;
                    });
                  },
                  decoration: const InputDecoration(
                    hintText: 'Enter username...',
                    hintStyle: TextStyle(fontWeight: FontWeight.bold, color: Colors.black38),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "You need at least 3 characters.",
                style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 60),
              _isLoading
                  ? const CircularProgressIndicator(color: Colors.black)
                  : IconButton(
                iconSize: 60,
                icon: const Icon(Icons.arrow_circle_right_outlined),
                color: _isReadyToProceed ? Colors.red : Colors.grey.shade300,
                onPressed: _isReadyToProceed ? _saveUsernameAndProceed : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}