import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../user/data/me_service.dart';
import '../../../models/user_model.dart';
import '../../../models/toko_model.dart';
import '../../data/seller_toko_service.dart';
import '../layout/seller_layout.dart';
import '../../../core/config/app_config.dart';

class SellerProfilePage extends StatefulWidget {
  const SellerProfilePage({super.key});

  @override
  State<SellerProfilePage> createState() => _SellerProfilePageState();
}

class _SellerProfilePageState extends State<SellerProfilePage> {
  static const int _maxBytes = 2 * 1024 * 1024; // aman: 2MB

  bool _loading = true;
  bool _busy = false;

  UserModel? _me;
  TokoModel? _toko;

  // user
  final _nameC = TextEditingController();
  final _phoneC = TextEditingController();
  final _alamatC = TextEditingController();
  String? _photoUrl;
  File? _localPhoto;

  // toko
  final _namaTokoC = TextEditingController();
  final _deskTokoC = TextEditingController();
  final _alamatTokoC = TextEditingController();
  String? _bannerUrl;
  File? _localBanner;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _nameC.dispose();
    _phoneC.dispose();
    _alamatC.dispose();

    _namaTokoC.dispose();
    _deskTokoC.dispose();
    _alamatTokoC.dispose();
    super.dispose();
  }

  void _snack(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  String _absUrl(String raw) {
    if (raw.startsWith('http')) return raw;
    if (raw.startsWith('/')) return '${AppConfig.baseUrl}$raw';
    return '${AppConfig.baseUrl}/$raw';
  }

  String _photoEndpoint(int userId) => '${AppConfig.baseUrl}/me/photo/$userId';

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final me = await MeService.fetchMe();
      final toko = await SellerTokoService.fetchMyToko();

      _me = me;
      _toko = toko;

      if (me != null) {
        _nameC.text = me.name;
        _phoneC.text = (me.nomorUser ?? '');
        _alamatC.text = (me.alamatUser ?? '');
        _photoUrl = me.photoUrl;
      }

      if (toko != null) {
        _namaTokoC.text = toko.namaToko;
        _deskTokoC.text = toko.deskripsiToko ?? '';
        _alamatTokoC.text = toko.alamatToko ?? '';
        _bannerUrl = toko.bannerUrl;
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmtBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      final mb = bytes / (1024 * 1024);
      return '${mb.toStringAsFixed(2)} MB';
    }
    final kb = bytes / 1024;
    return '${kb.toStringAsFixed(0)} KB';
  }

  Future<File?> _pickImageFile() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (x == null) return null;

    final f = File(x.path);
    final len = await f.length();

    if (len > _maxBytes) {
      _snack(
        'Ukuran file terlalu besar (${_fmtBytes(len)}). Maks ${_fmtBytes(_maxBytes)}',
      );
      return null;
    }

    return f;
  }

  Future<void> _changePhoto() async {
    if (_busy) return;

    final f = await _pickImageFile();
    if (f == null) return;

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
      await _loadAll();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeBanner() async {
    if (_busy) return;

    final f = await _pickImageFile();
    if (f == null) return;

    setState(() => _localBanner = f);

    setState(() => _busy = true);
    try {
      final updated = await SellerTokoService.uploadBanner(f);
      if (updated == null) {
        _snack('Gagal upload banner');
        return;
      }

      setState(() {
        _toko = updated;
        _bannerUrl = updated.bannerUrl;
      });

      _snack('Banner berhasil diupdate');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveAll() async {
    if (_busy) return;

    final name = _nameC.text.trim();
    final nomor = _phoneC.text.trim();
    final alamat = _alamatC.text.trim();

    final namaToko = _namaTokoC.text.trim();
    final deskToko = _deskTokoC.text.trim();
    final alamatToko = _alamatTokoC.text.trim();

    if (name.isEmpty) {
      _snack('Nama wajib diisi');
      return;
    }

    // backend /toko/update-my butuh nama_toko saat toko belum ada
    if (namaToko.isEmpty) {
      _snack('Nama toko wajib diisi');
      return;
    }

    setState(() => _busy = true);
    String? errUser;
    String? errToko;

    try {
      final updatedMe = await MeService.updateProfile(
        name: name,
        nomorUser: nomor,
        alamatUser: alamat,
      );
      if (updatedMe == null) errUser = 'Gagal menyimpan profil user';

      final okToko = await SellerTokoService.updateMyToko(
        namaToko: namaToko,
        deskripsi: deskToko,
        alamat: alamatToko,
      );
      if (!okToko) errToko = 'Gagal menyimpan data toko';

      await _loadAll();

      if (errUser == null && errToko == null) {
        _snack('Profil & data toko berhasil disimpan');
      } else {
        _snack(
          '${errUser ?? ''}${(errUser != null && errToko != null) ? ' | ' : ''}${errToko ?? ''}',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _card({required Widget child}) {
    return Container(
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
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = _me;
    final uid = me?.userId ?? 0;
    final email = me?.email ?? '-';

    final avatar = _localPhoto != null
        ? Image.file(_localPhoto!, fit: BoxFit.cover)
        : (_photoUrl != null && _photoUrl!.trim().isNotEmpty && uid > 0)
        ? Image.network(
            _absUrl(_photoUrl!),
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

    final bannerWidget = _localBanner != null
        ? Image.file(_localBanner!, fit: BoxFit.cover)
        : (_bannerUrl != null && _bannerUrl!.trim().isNotEmpty)
        ? Image.network(
            _absUrl(_bannerUrl!),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(Icons.image_rounded),
          )
        : const Icon(Icons.image_rounded);

    return SellerLayout(
      title: 'Profil Penjual',
      child: Container(
        color: const Color(0xFFF6F3FF),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _card(
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
                                onTap: _busy ? null : _changePhoto,
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
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6D28D9).withOpacity(.10),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'ROLE: PENJUAL',
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

                  _card(
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
                          decoration: const InputDecoration(
                            hintText: 'Nomor HP',
                          ),
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
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Data Toko (Penjual)',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 12),

                        // Banner
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            height: 140,
                            width: double.infinity,
                            color: const Color(0xFFEDE9FE),
                            child: bannerWidget,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _busy ? null : _changeBanner,
                            icon: const Icon(Icons.image_rounded),
                            label: const Text('Ubah Banner'),
                          ),
                        ),

                        const SizedBox(height: 14),
                        const Text(
                          'Nama Toko',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _namaTokoC,
                          enabled: !_busy,
                          decoration: const InputDecoration(
                            hintText: 'Nama toko',
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Deskripsi',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _deskTokoC,
                          enabled: !_busy,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            hintText: 'Deskripsi toko',
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Alamat Toko',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _alamatTokoC,
                          enabled: !_busy,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            hintText: 'Alamat toko',
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _busy ? null : _saveAll,
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
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'Simpan Semua',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
