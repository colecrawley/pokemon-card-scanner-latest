// pokemon_card.dart
class CardData {
  final String id;
  final String name;
  final String imageUrl;
  double marketPrice; // Changed to non-final
  double priceChange; // Changed to non-final
  final String setCode;
  final String cardNumber;
  final double? lastMarketPrice;

  CardData({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.marketPrice,
    required this.priceChange,
    required this.setCode,
    required this.cardNumber,
    this.lastMarketPrice,
  });

  CardData copyWith({
    String? id,
    String? name,
    String? imageUrl,
    double? marketPrice,
    double? priceChange,
    String? setCode,
    String? cardNumber,
    double? lastMarketPrice,
  }) {
    return CardData(
      id: id ?? this.id,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      marketPrice: marketPrice ?? this.marketPrice,
      priceChange: priceChange ?? this.priceChange,
      setCode: setCode ?? this.setCode,
      cardNumber: cardNumber ?? this.cardNumber,
      lastMarketPrice: lastMarketPrice ?? this.lastMarketPrice,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'imageUrl': imageUrl,
    'marketPrice': marketPrice,
    'priceChange': priceChange,
    'setCode': setCode,
    'cardNumber': cardNumber,
    'lastMarketPrice': lastMarketPrice,
  };

  factory CardData.fromJson(Map<String, dynamic> json) => CardData(
    id: json['id'],
    name: json['name'],
    imageUrl: json['imageUrl'] ?? '',
    marketPrice: json['marketPrice'] != null ? json['marketPrice'].toDouble() : 0.0,
    priceChange: json['priceChange'] != null ? json['priceChange'].toDouble() : 0.0,
    setCode: json['setCode'],
    cardNumber: json['cardNumber'],
    lastMarketPrice: json['lastMarketPrice']?.toDouble(),
  );
}
