class Media {
  final String id;
  final String logoUrl;
  final String subLogoUrl;

  Media({
    required this.id,
    required this.logoUrl,
    required this.subLogoUrl,
  });

  factory Media.fromFirestore(doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Media(
      id: doc.id,
      logoUrl: data['logoUrl'] ?? '',
      subLogoUrl: data['subLogoUrl'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'logoUrl': logoUrl,
    'subLogoUrl': subLogoUrl,
  };
}
