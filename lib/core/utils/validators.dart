class Validators {
  static String? required(String? v, {String label = 'Field'}) {
    if (v == null || v.trim().isEmpty) return '$label is required';
    return null;
  }

  static String? maxLen(String? v, int max, {String label = 'Field'}) {
    if (v == null) return null;
    if (v.trim().length > max) return '$label must be ≤ $max characters';
    return null;
  }

  static String? minLen(String? v, int min, {String label = 'Field'}) {
    if (v == null || v.trim().length < min) {
      return '$label must be ≥ $min characters';
    }
    return null;
  }

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required';
    final re = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!re.hasMatch(v.trim())) return 'Invalid email format';
    return null;
  }

  static String? positiveInt(String? v, {String label = 'Number'}) {
    if (v == null || v.trim().isEmpty) return '$label is required';
    final n = int.tryParse(v.trim());
    if (n == null) return '$label must be a number';
    if (n <= 0) return '$label must be > 0';
    return null;
  }

  static String? positiveDouble(String? v, {String label = 'Amount'}) {
    if (v == null || v.trim().isEmpty) return '$label is required';
    final n = double.tryParse(v.trim().replaceAll(',', '.'));
    if (n == null) return '$label must be a number';
    if (n <= 0) return '$label must be > 0';
    return null;
  }

  static String? clubName(String? v) {
    final r = required(v, label: 'Club name');
    if (r != null) return r;
    return maxLen(v, 60, label: 'Club name');
  }

  static String? city(String? v) {
    final r = required(v, label: 'City');
    if (r != null) return r;
    return maxLen(v, 40, label: 'City');
  }

  static String? description(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    return maxLen(v, 500, label: 'Description');
  }

  static String? playerName(String? v) {
    final r = required(v, label: 'Name');
    if (r != null) return r;
    return maxLen(v, 50, label: 'Name');
  }

  static String? jerseyNumber(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final n = int.tryParse(v.trim());
    if (n == null) return 'Number must be numeric';
    if (n < 0 || n > 99) return 'Number must be 0–99';
    return null;
  }
}
