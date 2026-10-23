String? validateKycDocument(String type, String value) {
  final normalized = value.trim().toUpperCase();
  switch (type) {
    case 'pan':
      return RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(normalized) ? null : 'Enter a valid PAN (e.g. ABCDE1234F).';
    case 'aadhaar':
      return RegExp(r'^\d{12}$').hasMatch(normalized) ? null : 'Aadhaar must contain exactly 12 digits.';
    case 'passport':
      return RegExp(r'^[A-Z][0-9]{7}$').hasMatch(normalized) ? null : 'Passport must be 1 letter followed by 7 digits(e.g. A2345678).';
    default:
      return 'Select a valid document type.';
  }
}
