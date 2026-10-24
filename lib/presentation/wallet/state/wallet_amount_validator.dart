/// Converts user-entered rupees to integer paise without floating-point math.
/// Returns null if invalid. Server accepts 100..5,000,000 paise (₹1..₹50,000).
int? rupeesToPaise(String input) {
  final normalized = input.trim().replaceAll(',', '');
  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(normalized)) return null;

  final parts = normalized.split('.');
  final wholeRupees = int.tryParse(parts[0]);
  if (wholeRupees == null) return null;
  final fraction = parts.length == 1 ? '' : parts[1];
  final paisePart = int.tryParse(fraction.padRight(2, '0')) ?? 0;
  final totalPaise = wholeRupees * 100 + paisePart;
  if (totalPaise < 100 || totalPaise > 5000000) return null;
  return totalPaise;
}
