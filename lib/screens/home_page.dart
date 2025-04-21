import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';
import 'package:test_scanner_app/screens/portfolio.dart';
import 'package:test_scanner_app/screens/profile.dart';
import '../services/database_helper.dart';
import 'camera_page.dart';
import '../models/pokemon_card.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'search.dart';

class HomePage extends StatefulWidget {
  final List<CameraDescription> cameras;

  const HomePage({super.key, required this.cameras});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  int _selectedIndex = 2;
  double _valueChangeToday = 0.0;
  List<CardData> _portfolioCards = [];
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  bool _isLoading = true;
  double _totalCollectionValue = 0.0;

  @override
  void initState() {
    super.initState();
    _loadPortfolio();
  }

  Future<void> _loadPortfolio() async {
    try {
      final cards = await _dbHelper.getCards();
      setState(() {
        _portfolioCards = cards;
        _updateTotalCollectionValue();
        _isLoading = false;
      });
      _calculateValueChangeToday();
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackbar('Failed to load portfolio: ${e.toString()}');
    }
  }

  Future<void> _addToPortfolio(CardData card) async {
    try {
      await _dbHelper.insertCard(card);
      setState(() {
        _portfolioCards.add(card);
        _updateTotalCollectionValue();
        _calculateValueChangeToday();
      });
    } catch (e) {
      _showErrorSnackbar('Failed to add card: ${e.toString()}');
    }
  }

  Future<void> _removeFromPortfolio(CardData card) async {
    try {
      await _dbHelper.deleteCard(card.id);
      setState(() {
        _portfolioCards.removeWhere((c) => c.id == card.id);
        _updateTotalCollectionValue();
        _calculateValueChangeToday();
      });
    } catch (e) {
      _showErrorSnackbar('Failed to remove card: ${e.toString()}');
    }
  }

  void _updateTotalCollectionValue() {
    _totalCollectionValue =
        _portfolioCards.fold(0.0, (sum, card) => sum + card.marketPrice);
  }

  void _calculateValueChangeToday() {
    double initialValue = 0.0;
    double currentValue = 0.0;

    for (final card in _portfolioCards) {
      initialValue += card.lastMarketPrice ?? card.marketPrice; // Use lastMarketPrice if available
      currentValue += card.marketPrice;
    }

    setState(() {
      _valueChangeToday = currentValue - initialValue;
    });
  }

  Future<void> _handleRefresh() async {
    try {
      List<CardData> updatedCards = [];
      for (var card in _portfolioCards) {
        final updatedCard = await _fetchUpdatedCardData(card);
        updatedCards.add(updatedCard);
        // Update the card in the database, including saving the current price as lastMarketPrice
        await _dbHelper.updateCard(updatedCard.copyWith(lastMarketPrice: card.marketPrice));
      }
      setState(() {
        _portfolioCards = updatedCards;
        _updateTotalCollectionValue();
        _calculateValueChangeToday();
      });
    } catch (e) {
      _showErrorSnackbar('Failed to refresh prices: ${e.toString()}');
    }
  }

  Future<CardData> _fetchUpdatedCardData(CardData card) async {
    const pokemonCategory = '3';
    final productsUrl = Uri.parse(
        'https://tcgcsv.com/tcgplayer/$pokemonCategory/${card.setCode}/products');

    final response = await http.get(productsUrl).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch updated prices');
    }

    final productsData = json.decode(response.body);
    final product = productsData['results'].firstWhere(
          (p) => p['productId'].toString() == card.id,
      orElse: () => null,
    );

    if (product == null) return card;

    final pricesUrl = Uri.parse(
        'https://tcgcsv.com/tcgplayer/$pokemonCategory/${card.setCode}/prices');
    final pricesResponse = await http.get(pricesUrl).timeout(const Duration(seconds: 10));

    double latestPrice = card.marketPrice;
    if (pricesResponse.statusCode == 200) {
      final pricesData = json.decode(pricesResponse.body);
      final priceInfo = pricesData['results'].firstWhere(
            (p) => p['productId'] == product['productId'],
        orElse: () => null,
      );
      latestPrice = priceInfo != null
          ? double.tryParse(priceInfo['marketPrice']?.toString() ?? '0') ?? card.marketPrice
          : card.marketPrice;
    }

    final priceChange = ((latestPrice - card.marketPrice) / card.marketPrice) * 100;

    return CardData(
      id: card.id,
      name: card.name,
      imageUrl: card.imageUrl,
      marketPrice: latestPrice,
      priceChange: priceChange,
      setCode: card.setCode,
      cardNumber: card.cardNumber,
      lastMarketPrice: card.marketPrice, // Temporarily set for the current update
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _selectedIndex == 2
          ? LiquidPullToRefresh(
        onRefresh: _handleRefresh,
        color: Colors.blue,
        backgroundColor: Colors.white,
        height: 150,
        animSpeedFactor: 2,
        showChildOpacityTransition: false,
        child: _buildHomePage(),
      )
          : _getSelectedPage(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.pie_chart),
            label: 'Portfolio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt),
            label: 'Camera',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        onTap: _onItemTapped,
      ),
    );
  }

  Widget _getSelectedPage(int index) {
    switch (index) {
      case 0:
        return PortfolioPage(
          cards: _portfolioCards,
          onDeleteCard: _removeFromPortfolio,
        );
      case 1:
        return CameraPage(
          cameras: widget.cameras,
          onCardConfirmed: _addToPortfolio,
        );
      case 2:
        return _buildHomePage();
      case 3:
        return const SearchPage();
      case 4:
        return ProfilePage(portfolio: _portfolioCards);
      default:
        return _buildHomePage();
    }
  }

  Widget _buildHomePage() {
    final topGainers = _getTopCards(5);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        children: [
          const SizedBox(height: 20),
          _buildCollectionHeader(_totalCollectionValue, _valueChangeToday),
          const SizedBox(height: 20),
          _buildValueTrendCard(),
          const SizedBox(height: 20),
          _buildTopPerformersCard(topGainers, 'Top Gainers'),
        ],
      ),
    );
  }

  List<CardData> _getTopCards(int count, {bool ascending = false}) {
    final sorted = List<CardData>.from(_portfolioCards)
      ..sort((a, b) => ascending
          ? a.priceChange.compareTo(b.priceChange)
          : b.priceChange.compareTo(a.priceChange));
    return sorted.take(count).toList();
  }

  Widget _buildCollectionHeader(double totalValue, double valueChangeToday) {
    return Column(
      children: [
        const Text(
          'Your Pokémon Collection',
          style: TextStyle(fontSize: 18, color: Colors.black45),
        ),
        const SizedBox(height: 10),
        Text(
          '\$${totalValue.toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '${valueChangeToday >= 0 ? '+' : ''}\$${valueChangeToday.abs().toStringAsFixed(2)} '
              '${valueChangeToday >= 0 ? 'increase' : 'decrease'} today',
          style: TextStyle(
            fontSize: 16,
            color: valueChangeToday >= 0 ? Colors.green : Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildValueTrendCard() {
    return Container(
      height: 150,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade100, Colors.green.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Center(
        child: _portfolioCards.isEmpty
            ? const Text(
          'Scan cards to see value trends',
          style: TextStyle(fontSize: 16),
        )
            : const Text(
          'Collection Value Trend',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildTopPerformersCard(List<CardData> cards, String title, {bool isGainer = true}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          _buildTopPerformersList(cards, isGainer),
        ],
      ),
    );
  }

  Widget _buildTopPerformersList(List<CardData> cards, bool isGainer) {
    if (_portfolioCards.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            'Scan cards to build your portfolio',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Column(
      children: cards.map((card) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: ListTile(
          contentPadding: const EdgeInsets.all(8),
          leading: _buildCardImage(card),
          title: Text(
            card.name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            '\$${card.marketPrice.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 16),
          ),
          trailing: _buildPerformanceIndicator(card, isGainer),
          onTap: () => setState(() => _selectedIndex = 0),
        ),
      )).toList(),
    );
  }

  Widget _buildCardImage(CardData card) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: card.imageUrl.isNotEmpty
          ? Image.network(
        card.imageUrl,
        width: 50,
        height: 70,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 50,
            height: 70,
            color: Colors.grey[200],
            child: const Icon(Icons.broken_image),
          );
        },
      )
          : Container(
        width: 50,
        height: 70,
        color: Colors.grey[200],
        child: const Icon(Icons.photo),
      ),
    );
  }

  Widget _buildPerformanceIndicator(CardData card, bool isGainer) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '${card.priceChange > 0 ? '+' : ''}${card.priceChange.toStringAsFixed(2)}%',
          style: TextStyle(
            color: isGainer
                ? (card.priceChange > 0 ? Colors.green : Colors.red)
                : (card.priceChange < 0 ? Colors.green : Colors.red),
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          card.setCode,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }
}