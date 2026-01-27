class Money {
  static String rupiah(num v) {
    final s = v.toStringAsFixed(0);
    final r = s.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
    return "Rp $r";
  }
}
