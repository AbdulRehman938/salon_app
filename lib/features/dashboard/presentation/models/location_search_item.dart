class LocationSearchItem {
  const LocationSearchItem({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  String get fullLocation => '$title, $subtitle';
}
