class TokoModel {
  final int tokoId;
  final int userId;
  final String namaToko;
  final String? deskripsiToko;
  final String? alamatToko;
  final String status; // aktif|nonaktif
  final String? createdAt;

  // ✅ NEW banner
  final String? bannerUrl;
  final int? bannerSize;
  final String? bannerMime;
  final String? bannerUpdatedAt;

  TokoModel({
    required this.tokoId,
    required this.userId,
    required this.namaToko,
    required this.deskripsiToko,
    required this.alamatToko,
    required this.status,
    required this.createdAt,
    required this.bannerUrl,
    required this.bannerSize,
    required this.bannerMime,
    required this.bannerUpdatedAt,
  });

  static int _toInt(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;

  static int? _toIntN(dynamic v) {
    final s = v?.toString();
    if (s == null) return null;
    return int.tryParse(s);
  }

  static String _toLowerStr(dynamic v, String def) {
    final s = (v ?? def).toString().trim();
    return s.isEmpty ? def : s.toLowerCase();
  }

  static String _toStr(dynamic v, String def) {
    final s = (v ?? def).toString();
    return s.isEmpty ? def : s;
  }

  static String? _pick(dynamic a, dynamic b) {
    final v = a ?? b;
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  factory TokoModel.fromJson(Map<String, dynamic> j) {
    return TokoModel(
      tokoId: _toInt(j['toko_id'] ?? j['tokoId']),
      userId: _toInt(j['user_id'] ?? j['userId']),
      namaToko: _toStr(j['nama_toko'] ?? j['namaToko'], ''),
      deskripsiToko: _pick(j['deskripsi_toko'], j['deskripsiToko']),
      alamatToko: _pick(j['alamat_toko'], j['alamatToko']),
      status: _toLowerStr(j['status'], 'nonaktif'),
      createdAt: (j['created_at'] ?? j['createdAt'])?.toString(),

      // banner
      bannerUrl: _pick(j['banner_url'], j['bannerUrl']),
      bannerSize: _toIntN(j['banner_size'] ?? j['bannerSize']),
      bannerMime: _pick(j['banner_mime'], j['bannerMime']),
      bannerUpdatedAt: _pick(j['banner_updated_at'], j['bannerUpdatedAt']),
    );
  }
}
