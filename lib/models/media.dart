class Media {
  final String id;
  final String logoUrl;
  final String subLogoUrl;

  Media({required this.id, required this.logoUrl, required this.subLogoUrl});

  factory Media.fromJson(Map<String, dynamic> json) {
    return Media(
      id: json['id'].toString(),
      logoUrl: json['logo_url'] ?? '',
      subLogoUrl: json['sub_logo_url'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'logo_url': logoUrl,
    'sub_logo_url': subLogoUrl,
  };
}