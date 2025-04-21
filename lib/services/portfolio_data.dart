import '../models/pokemon_card.dart'; // Importing CardData class

class PortfolioData {
  static final PortfolioData _instance = PortfolioData._internal();

  List<CardData> cards = [];

  PortfolioData._internal();

  factory PortfolioData() {
    return _instance;
  }

  // Calculate the total market value of all cards in the portfolio
  double getTotalValue() {
    return cards.fold(0.0, (sum, card) => sum + card.marketPrice);
  }

  // Get the valuable cards sorted by their market price
  List<CardData> getValuableCards() {
    return List.from(cards)
      ..sort((a, b) => b.marketPrice.compareTo(a.marketPrice));
  }

  // Add a card to the portfolio
  void addCard(CardData card) {
    cards.add(card);
  }

  // Remove a card from the portfolio
  void removeCard(CardData card) {
    cards.remove(card);
  }
}
