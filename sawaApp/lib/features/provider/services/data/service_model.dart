class ServiceModel {
  const ServiceModel({
    required this.id,
    required this.providerId,
    required this.title,
    required this.description,
    this.priceText,
    this.isActive = true,
  });

  final String id;
  final String providerId;
  final String title;
  final String description;
  final String? priceText;
  final bool isActive;

  ServiceModel copyWith({
    String? title,
    String? description,
    String? priceText,
    bool? isActive,
  }) {
    return ServiceModel(
      id: id,
      providerId: providerId,
      title: title ?? this.title,
      description: description ?? this.description,
      priceText: priceText ?? this.priceText,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'provider_id': providerId,
        'title': title,
        'description': description,
        if (priceText != null) 'price_text': priceText,
        'is_active': isActive,
      };

  factory ServiceModel.fromJson(Map<String, dynamic> json) => ServiceModel(
        id: json['id'] as String,
        providerId: json['provider_id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        priceText: json['price_text'] as String?,
        isActive: json['is_active'] as bool? ?? true,
      );
}
