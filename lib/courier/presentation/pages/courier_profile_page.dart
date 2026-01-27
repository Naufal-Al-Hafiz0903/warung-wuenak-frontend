import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../user/data/me_service.dart';
import '../../../features/data/auth_service.dart';
import '../../../core/config/app_config.dart';
import '../../../models/user_model.dart';

class CourierProfilePage extends StatefulWidget {
  final Map<String, dynamic> user;
  const CourierProfilePage({super.key, required this.user});

  @override
  State<CourierProfilePage> createState() => _CourierProfilePageState();
}

class _CourierProfilePageState extends State<CourierProfilePage> {
  static const int _maxPhotoBytes = 2 * 1024 * 1024;

  bool _loading = true;
  bool _busy = false;

  late Map<String, dynamic> _u;

  final _nameC = TextEditingController();
  final _phoneC = TextEditingController();
  final _alamatC = TextEditingController();

  String? _photoUrl;
  File? _localPhoto;

  @override
  void initState() {
    super.initState();
    _u = Map<String, dynamic>.from(widget.user);

    _nameC.text = (_u['name'] ?? '').toString();
    _phoneC.text = (_u['nomor_user'] ?? _u['nomorUser'] ?? '').toString();
    _alamatC.text = (_u['alamat_user'] ?? _u['alamatUser'] ?? '').toString();

    _load();
  }

  @override
  void dispose() {
    _nameC.dispose();
    _phoneC.dispose();
    _alamatC.dispose();
    super.dispose();
  }

  void _snack(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  String _photoEndpoint(int userId) => '${AppConfig.baseUrl}/me/photo/$userId';

  int _userId() {
    final v = _u['user_id'] ?? _u['userId'];
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }

  String _fmtBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      final mb = bytes / (1024 * 1024);
      return '${mb.toStringAsFixed(2)} MB';
    }
    final kb = bytes / 1024;
    return '${kb.toStringAsFixed(0)} KB';
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final me = await MeService.fetchMe();
      if (me != null) {
        final m = me.toJson();
        _u = m;
        _nameC.text = (m['name'] ?? '').toString();
        _phoneC.text = (m['nomor_user'] ?? m['nomorUser'] ?? '').toString();
        _alamatC.text = (m['alamat_user'] ?? m['alamatUser'] ?? '').toString();
        _photoUrl = (m['photo_url'] ?? m['photoUrl'])?.toString();
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickPhoto() async {
    if (_busy) return;

    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (x == null) return;

    final f = File(x.path);

    final len = await f.length();
    if (len > _maxPhotoBytes) {
      _snack(
        'Ukuran foto terlalu besar (${_fmtBytes(len)}). Maksimal ${_fmtBytes(_maxPhotoBytes)}.',
      );
      return;
    }

    setState(() => _localPhoto = f);

    setState(() => _busy = true);
    try {
      final url = await MeService.uploadPhoto(f);
      if (url == null) {
        _snack('Gagal upload foto profil');
        return;
      }

      setState(() => _photoUrl = url);
      _snack('Foto profil tersimpan');
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_busy) return;

    final name = _nameC.text.trim();
    final nomor = _phoneC.text.trim();
    final alamat = _alamatC.text.trim();

    if (name.isEmpty) {
      _snack('Nama wajib diisi');
      return;
    }

    setState(() => _busy = true);
    try {
      final updated = await MeService.updateProfile(
        name: name,
        nomorUser: nomor,
        alamatUser: alamat,
      );

      if (updated == null) {
        _snack('Gagal menyimpan profil');
        return;
      }

      _u = updated.toJson();
      _photoUrl = (_u['photo_url'] ?? _u['photoUrl'])?.toString();

      _snack('Profil berhasil disimpan');
      if (!mounted) return;
      setState(() {});
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar'),
        content: const Text('Yakin ingin logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final uid = _userId();
    final email = (_u['email'] ?? '-').toString();

    final avatar = _localPhoto != null
        ? Image.file(_localPhoto!, fit: BoxFit.cover)
        : (_photoUrl != null && _photoUrl!.trim().isNotEmpty && uid > 0)
        ? Image.network(
            _photoUrl!.startsWith('http')
                ? _photoUrl!
                : (_photoUrl!.startsWith('/')
                      ? '${AppConfig.baseUrl}${_photoUrl!}'
                      : '${AppConfig.baseUrl}/${_photoUrl!}'),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(Icons.person_rounded),
          )
        : (uid > 0
              ? Image.network(
                  _photoEndpoint(uid),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.person_rounded),
                )
              : const Icon(Icons.person_rounded));

    return Scaffold(
      backgroundColor: const Color(0xFFF6F3FF),
      appBar: AppBar(
        title: const Text('Profil Kurir'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: _busy ? null : _logout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFEDE9FE)),
                    boxShadow: const [
                      BoxShadow(
                        blurRadius: 18,
                        offset: Offset(0, 10),
                        color: Color(0x14000000),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          ClipOval(
                            child: Container(
                              width: 92,
                              height: 92,
                              color: const Color(0xFFEDE9FE),
                              child: avatar,
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: InkWell(
                              onTap: _busy ? null : _pickPhoto,
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6D28D9),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  size: 18,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        email,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F3FF),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFFE9D5FF)),
                        ),
                        child: const Text(
                          'ROLE: KURIR',
                          style: TextStyle(
                            color: Color(0xFF6D28D9),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFEDE9FE)),
                    boxShadow: const [
                      BoxShadow(
                        blurRadius: 18,
                        offset: Offset(0, 10),
                        color: Color(0x14000000),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Data Profil',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Nama',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _nameC,
                        enabled: !_busy,
                        decoration: const InputDecoration(hintText: 'Nama'),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Nomor HP',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _phoneC,
                        enabled: !_busy,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(hintText: 'Nomor HP'),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Alamat',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _alamatC,
                        enabled: !_busy,
                        maxLines: 3,
                        decoration: const InputDecoration(hintText: 'Alamat'),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _busy ? null : _save,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Simpan',
                                  style: TextStyle(fontWeight: FontWeight.w900),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
