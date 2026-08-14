import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/profile_api_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _api = ProfileApiService();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();

  bool _loading = true;
  bool _updating = false;
  String _phone = '';
  String _gender = '';
  String _marital = '';

  static const _genders = ['Male', 'Female', 'Other'];
  static const _maritalOptions = ['Single', 'Married', 'Divorced', 'Widowed'];

  OverlayEntry? _messageOverlayEntry;

  // ---- Welfog brand palette ----
  static const Color brand = Color(0xFFF47504);
  static const Color brandWash = Color(0xFFFFF3E8);
  static const Color ink = Color(0xFF1A1A1A);
  static const Color inkMuted = Color(0xFF666666);
  static const Color inkFaint = Color(0xFF9A9A9A);
  static const Color line = Color(0x14000000);
  static const Color danger = Color(0xFFE0433D);

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(_onNameChanged);
    _load();
  }

  @override
  void dispose() {
    _messageOverlayEntry?.remove();
    _messageOverlayEntry = null;
    _nameCtrl.removeListener(_onNameChanged);
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _dobCtrl.dispose();
    super.dispose();
  }
  // Keeps the avatar initial in sync as the person edits their name.
  void _onNameChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final profile = await _api.fetchProfile();
      if (!mounted) return;
      if (profile == null) {
        setState(() => _loading = false);
        return;
      }
      _nameCtrl.text = profile.name;
      _emailCtrl.text = profile.email;
      _dobCtrl.text = profile.dob;
      setState(() {
        _phone = profile.phone;
        _gender = profile.gender;
        _marital = profile.maritalStatus;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDob() async {
    final existing = _parseDob(_dobCtrl.text.trim());
    final picked = await showDatePicker(
      context: context,
      initialDate: existing ?? DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    final day = picked.day.toString().padLeft(2, '0');
    final month = picked.month.toString().padLeft(2, '0');
    setState(() => _dobCtrl.text = '$day-$month-${picked.year}');
  }

  DateTime? _parseDob(String value) {
    final parts = value.split('-');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    return DateTime(year, month, day);
  }

  Future<void> _update() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _showMessage('Please enter your name');
      return;
    }

    final email = _emailCtrl.text.trim();
    if (email.isNotEmpty) {
      final emailOk = RegExp(r'^[a-zA-Z0-9._+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$')
          .hasMatch(email);
      if (!emailOk) {
        _showMessage('Please enter a valid email address');
        return;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';
    final userId = prefs.getString('user_id') ?? '';
    if (token.isEmpty || userId.isEmpty) {
      _showMessage('User not authenticated');
      return;
    }

    setState(() => _updating = true);
    try {
      final error = await _api.updateProfile(
        userId: userId,
        accessToken: token,
        name: _nameCtrl.text.trim(),
        email: email,
        dobDisplay: _dobCtrl.text.trim(),
        gender: _gender,
        maritalStatus: _marital,
      );
      if (!mounted) return;
      if (error != null) {
        _showMessage(error);
        return;
      }
      await prefs.setString('user_name', _nameCtrl.text.trim());
      await prefs.setString('loginuser', _nameCtrl.text.trim());
      _showMessage('Profile updated successfully.', success: true);
    } catch (_) {
      if (mounted) _showMessage('An unexpected error occurred.');
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  void _showMessage(String message, {bool success = false}) {
    _messageOverlayEntry?.remove();
    _messageOverlayEntry = null;

    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 50,
        left: 20,
        right: 20,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(178),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withAlpha(38),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        success ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                        color: success ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    _messageOverlayEntry = entry;
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 1), () {
      if (_messageOverlayEntry == entry) {
        entry.remove();
        _messageOverlayEntry = null;
      }
    });
  }

  String get _avatarInitial {
    final trimmed = _nameCtrl.text.trim();
    return trimmed.isNotEmpty ? trimmed[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'My Profile',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: ink),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: ink),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(color: line, height: 0.5),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildProfileSummary(),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
                    children: [
                      _fieldLabel('Name', required: true),
                      TextField(
                        controller: _nameCtrl,
                        textCapitalization: TextCapitalization.words,
                        maxLength: 50,
                        buildCounter: (ctx, {required currentLength, required isFocused, maxLength}) => null,
                        decoration: _inputDecoration('Your name'),
                      ),
                      const SizedBox(height: 18),
                      _fieldLabel('Phone Number'),
                      TextFormField(
                        initialValue: _phone,
                        enabled: false,
                        decoration: _inputDecoration('Mobile number'),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          'Verified · linked to your account',
                          style: TextStyle(fontSize: 11.5, color: inkFaint, fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _fieldLabel('Email', optional: true),
                      TextField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        maxLength: 50,
                        buildCounter: (ctx, {required currentLength, required isFocused, maxLength}) => null,
                        decoration: _inputDecoration('Email address'),
                      ),
                      const SizedBox(height: 18),
                      _fieldLabel('Date of Birth', required: true),
                      TextField(
                        controller: _dobCtrl,
                        readOnly: true,
                        onTap: _pickDob,
                        decoration: _inputDecoration('DD-MM-YYYY').copyWith(
                          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 19, color: inkFaint),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _fieldLabel('Gender', required: true),
                      _buildPickerField(
                        value: _gender,
                        hint: 'Select gender',
                        onTap: () async {
                          final result = await _showOptionPicker(
                            title: 'Select gender',
                            options: _genders,
                            current: _gender,
                          );
                          if (result != null) setState(() => _gender = result);
                        },
                      ),
                      const SizedBox(height: 18),
                      _fieldLabel('Marital Status', required: true),
                      _buildPickerField(
                        value: _marital,
                        hint: 'Select status',
                        onTap: () async {
                          final result = await _showOptionPicker(
                            title: 'Select marital status',
                            options: _maritalOptions,
                            current: _marital,
                          );
                          if (result != null) setState(() => _marital = result);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
      // Fixed bottom bar — stays visible while the fields above scroll.
      bottomNavigationBar: _loading
          ? null
          : SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(color: Color(0x0F000000), blurRadius: 20, offset: Offset(0, -8)),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _updating ? null : _update,
                    style: FilledButton.styleFrom(
                      backgroundColor: brand,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _updating
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'Update Profile',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildProfileSummary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: line)),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: brandWash, width: 1.5),
            ),
            alignment: Alignment.center,
            child: Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: brand),
              alignment: Alignment.center,
              child: Text(
                _avatarInitial,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : 'Your Name',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: ink),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Manage your profile details',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: inkFaint),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickerField({
    required String value,
    required String hint,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: InputDecorator(
        decoration: _inputDecoration(''),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value.isEmpty ? hint : value,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: value.isEmpty ? inkFaint : ink,
                ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, color: inkFaint),
          ],
        ),
      ),
    );
  }

  // Opens a small centered dialog sized to match the input fields — avoids
  // the default DropdownButton menu, which stretches edge-to-edge.
  Future<String?> _showOptionPicker({
    required String title,
    required List<String> options,
    required String current,
  }) {
    final fieldWidth = MediaQuery.of(context).size.width - 40; // matches 20px ListView padding on each side

    return showDialog<String>(
      context: context,
      barrierColor: Colors.black.withAlpha(90),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: EdgeInsets.symmetric(
            horizontal: (MediaQuery.of(context).size.width - fieldWidth) / 2,
          ),
          child: SizedBox(
            width: fieldWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: ink),
                    ),
                  ),
                ),
                ...options.map((option) {
                  final isSelected = option == current;
                  return InkWell(
                    onTap: () => Navigator.of(dialogContext).pop(option),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                      color: isSelected ? brandWash : Colors.transparent,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              option,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: ink,
                              ),
                            ),
                          ),
                          if (isSelected) const Icon(Icons.check_rounded, color: brand, size: 18),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 6),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _fieldLabel(String text, {bool required = false, bool optional = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: ink),
          children: [
            TextSpan(text: text),
            if (required)
              const TextSpan(text: ' *', style: TextStyle(color: danger, fontWeight: FontWeight.w700)),
            if (optional)
              const TextSpan(
                text: '  (Optional)',
                style: TextStyle(color: inkFaint, fontWeight: FontWeight.w500, fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: inkFaint, fontWeight: FontWeight.w500),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: line, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: line, width: 1.5),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: line, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: brand, width: 1.5),
      ),
    );
  }
}
