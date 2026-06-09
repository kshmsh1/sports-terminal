class RosterMeasurementFormatter {
  const RosterMeasurementFormatter();

  int heightInches(String? height) {
    if (height == null) return -1;
    final match = RegExp(r"^(\d+)'\s*(\d+)\"").firstMatch(height.trim());
    if (match == null) return -1;
    return int.parse(match.group(1)!) * 12 + int.parse(match.group(2)!);
  }

  double heightMeters(String? height) {
    final inches = heightInches(height);
    if (inches < 0) return -1;
    return inches * 0.0254;
  }

  String heightLabel(String? height) {
    final meters = heightMeters(height);
    if (height == null || meters < 0) return '—';
    return '$height (${meters.toStringAsFixed(2)} m)';
  }

  double weightKilograms(int? pounds) {
    if (pounds == null) return -1;
    return pounds * 0.45359237;
  }

  String weightLabel(int? pounds) {
    if (pounds == null) return '—';
    return '$pounds lbs (${weightKilograms(pounds).toStringAsFixed(1)} kg)';
  }

  int jerseySortValue(String? jerseyNumber) {
    if (jerseyNumber == null || jerseyNumber.trim().isEmpty) return 999;
    return int.tryParse(jerseyNumber) ?? 999;
  }
}
