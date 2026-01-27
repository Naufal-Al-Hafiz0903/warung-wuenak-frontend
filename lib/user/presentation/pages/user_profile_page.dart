import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../data/me_service.dart';
import '../../../core/config/app_config.dart';
import 'user_location_picker_page.dart';

class UserProfilePage extends StatefulWidget {
  final Map<String, dynamic> user;
  const UserProfilePage({super.key, required this.user});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  static const int _maxPhotoBytes = 2 * 1024 * 1024;

  bool _loading = true;
  bool _busy = false;

  late Map<String, dynamic> _u;

  final _nameC = TextEditingController();
  final _phoneC = TextEditingController();
  final _alamatC = TextEditingController();

  String? _photoUrl;
  File? _localPhoto;

  // ✅ lokasi terbaru
  double? _lat;
  double? _lng;
  String? _locUpdatedAt;

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

      // ✅ ambil lokasi terbaru dari server
      final loc = await MeService.fetchMyLocation();
      if (loc != null) {
        _lat = double.tryParse('${loc['lat']}');
        _lng = double.tryParse('${loc['lng']}');
        _locUpdatedAt = (loc['updated_at'] ?? '').toString();
      } else {
        _lat = null;
        _lng = null;
        _locUpdatedAt = null;
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

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
      final res = await MeService.uploadPhotoResult(f);

      if (res['ok'] != true) {
        _snack((res['message'] ?? 'Gagal upload foto profil').toString());
        return;
      }

      final url = res['photo_url']?.toString();
      if (url == null || url.trim().isEmpty) {
        _snack('Upload sukses tapi photo_url kosong');
        return;
      }

      setState(() => _photoUrl = url);
      _snack('Foto profil tersimpan');

      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openMapsPicker() async {
    if (_busy) return;

    final initial = (_lat != null && _lng != null)
        ? LatLng(_lat!, _lng!)
        : null;

    final res = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserLocationPickerPage(initial: initial),
      ),
    );

    if (res is Map) {
      await _load();
    }
  }

  Future<void> _save() async {
    if (_busy) return;

    final name = _nameC.text.trim();
    final nomor = _phoneC.text.trim();
    final alamat = _alamatC.text.trim(); // teks opsional

    if (name.isEmpty) {
      _snack('Nama wajib diisi');
      return;
    }

    setState(() => _busy = true);
    try {
      final me = await MeService.fetchMe();
      if (me == null) {
        _snack('Session tidak valid. Silakan login ulang.');
        return;
      }

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

    final haveLoc = _lat != null && _lng != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F3FF),
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('Batal'),
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
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ✅ lokasi map
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
                        'Lokasi Pengiriman',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        haveLoc
                            ? 'Lat: ${_lat!.toStringAsFixed(6)}\nLng: ${_lng!.toStringAsFixed(6)}'
                            : 'Belum ada lokasi tersimpan.',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if ((_locUpdatedAt ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Update: $_locUpdatedAt',
                          style: const TextStyle(
                            color: Colors.black45,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _openMapsPicker,
                          icon: const Icon(Icons.map_outlined),
                          label: const Text(
                            'Atur Lokasi di Maps',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // profile data
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
                        'Alamat (teks opsional)',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _alamatC,
                        enabled: !_busy,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Catatan alamat (opsional)',
                        ),
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
