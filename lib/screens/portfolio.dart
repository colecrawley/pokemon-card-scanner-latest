import 'package:flutter/material.dart';
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/pokemon_card.dart';
import '../services/database_helper.dart';

class PortfolioPage extends StatefulWidget {
  final List<CardData> cards;
  final Function(CardData) onDeleteCard;

  const PortfolioPage({
    super.key,
    required this.cards,
    required this.onDeleteCard,
  });

  @override
  State<PortfolioPage> createState() => _PortfolioPageState();
}

class _PortfolioPageState extends State<PortfolioPage> {
  late List<CardData> _cards = [];
  Map<String, double> _previousPrices = {};
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _cards = widget.cards;
    for (var card in _cards) {
      _previousPrices[card.id] = card.marketPrice;
    }
    _isLoading = false;
  }

  Future<void> _saveCard(CardData card) async {
    await _dbHelper.insertCard(card);
  }

  Future<void> _deleteCard(String id) async {
    await _dbHelper.deleteCard(id);
  }

  Future<void> _handleRefresh() async {
    try {
      final newPreviousPrices = <String, double>{};
      for (var card in _cards) {
        newPreviousPrices[card.id] = card.marketPrice;
      }

      List<CardData> updatedCards = [];
      for (var card in _cards) {
        final updatedCard = await _fetchUpdatedCardData(card);
        updatedCards.add(updatedCard);
        await _saveCard(updatedCard);
      }

      setState(() {
        _cards = updatedCards;
        _previousPrices = newPreviousPrices;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to refresh prices: ${e.toString()}'),
          duration: const Duration(seconds: 2),
        ),
      );
      rethrow;
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

    if (product == null) {
      return card;
    }

    final pricesUrl = Uri.parse(
        'https://tcgcsv.com/tcgplayer/$pokemonCategory/${card.setCode}/prices');
    final pricesResponse = await http.get(pricesUrl).timeout(const Duration(seconds: 10));

    double latestPrice = 0.0;
    if (pricesResponse.statusCode == 200) {
      final pricesData = json.decode(pricesResponse.body);
      final priceInfo = pricesData['results'].firstWhere(
            (p) => p['productId'] == product['productId'],
        orElse: () => null,
      );
      latestPrice = priceInfo != null
          ? double.tryParse(priceInfo['marketPrice']?.toString() ?? '0') ?? 0.0
          : card.marketPrice;
    }

    final previousPrice = _previousPrices[card.id] ?? card.marketPrice;
    final priceChange = ((latestPrice - previousPrice) / previousPrice) * 100;

    return CardData(
      id: card.id,
      name: card.name,
      imageUrl: card.imageUrl,
      marketPrice: latestPrice,
      priceChange: priceChange,
      setCode: card.setCode,
      cardNumber: card.cardNumber,
    );
  }

  void _showCardDetails(BuildContext context, CardData card) {
    final previousPrice = _previousPrices[card.id] ?? card.marketPrice;
    final priceDifference = card.marketPrice - previousPrice;
    final absoluteChange = priceDifference.abs();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: const EdgeInsets.all(20),
        contentPadding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: card.imageUrl.isNotEmpty
                      ? Image.network(
                    card.imageUrl,
                    width: MediaQuery.of(context).size.width * 0.8,
                    fit: BoxFit.contain,
                  )
                      : Container(
                    width: 200,
                    height: 280,
                    color: Colors.grey[200],
                    child: const Icon(Icons.photo, size: 50),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: CircleAvatar(
                    backgroundColor: Colors.red.withOpacity(0.8),
                    child: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.white),
                      onPressed: () {
                        Navigator.pop(context);
                        _handleDeleteCard(card);
                      },
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildDetailRow('Current Price:', '\$${card.marketPrice.toStringAsFixed(2)}'),
                  _buildDetailRow('Previous Price:', '\$${previousPrice.toStringAsFixed(2)}'),
                  _buildDetailRow(
                    'Price Change:',
                    '${priceDifference >= 0 ? '+' : ''}${priceDifference.toStringAsFixed(2)} (${card.priceChange.toStringAsFixed(2)}%)',
                    color: card.priceChange > 0 ? Colors.green : Colors.red,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    priceDifference >= 0
                        ? '▲ Increased by \$${absoluteChange.toStringAsFixed(2)}'
                        : '▼ Decreased by \$${absoluteChange.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: priceDifference >= 0 ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(color: color),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteCard(CardData card) async {
    try {
      await _deleteCard(card.id);
      widget.onDeleteCard(card);
      setState(() {
        _cards.removeWhere((c) => c.id == card.id);
        _previousPrices.remove(card.id);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete card: ${e.toString()}')),
      );
    }
  }

  Widget _buildPortfolioContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return _cards.isEmpty
        ? const Center(
      child: Text(
        'Your portfolio is empty\nScan cards to add them!',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 18),
      ),
    )
        : Padding(
      padding: const EdgeInsets.all(8.0),
      child: GridView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.65,
          crossAxisSpacing: 10.0,
          mainAxisSpacing: 10.0,
        ),
        itemCount: _cards.length,
        itemBuilder: (context, index) {
          final card = _cards[index];
          final previousPrice = _previousPrices[card.id] ?? card.marketPrice;
          final priceChange = card.marketPrice - previousPrice;

          return GestureDetector(
            onTap: () => _showCardDetails(context, card),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                      child: card.imageUrl.isNotEmpty
                          ? Image.network(
                        card.imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[200],
                            child: const Center(
                              child: Icon(Icons.broken_image, size: 50),
                            ),
                          );
                        },
                      )
                          : Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: Icon(Icons.photo, size: 50),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          card.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Price: \$${card.marketPrice.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${priceChange >= 0 ? '+' : ''}${priceChange.toStringAsFixed(2)} (${card.priceChange.toStringAsFixed(2)}%)',
                          style: TextStyle(
                            fontSize: 12,
                            color: priceChange >= 0 ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LiquidPullToRefresh(
      onRefresh: _handleRefresh,
      color: Colors.blue.shade200,
      backgroundColor: Colors.white,
      height: 150,
      animSpeedFactor: 2.5,
      showChildOpacityTransition: false,
      springAnimationDurationInMilliseconds: 500,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Portfolio'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _handleRefresh,
            ),
          ],
        ),
        body: GridView.builder(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.65,
            crossAxisSpacing: 10.0,
            mainAxisSpacing: 10.0,
          ),
          itemCount: _cards.length,
          itemBuilder: (context, index) {
            final card = _cards[index];
            final previousPrice = _previousPrices[card.id] ?? card.marketPrice;
            final priceChange = card.marketPrice - previousPrice;

            return GestureDetector(
              onTap: () => _showCardDetails(context, card),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                        child: card.imageUrl.isNotEmpty
                            ? Image.network(
                          card.imageUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[200],
                              child: const Center(
                                child: Icon(Icons.broken_image, size: 50),
                              ),
                            );
                          },
                        )
                            : Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: Icon(Icons.photo, size: 50),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            card.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Price: \$${card.marketPrice.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${priceChange >= 0 ? '+' : ''}${priceChange.toStringAsFixed(2)} (${card.priceChange.toStringAsFixed(2)}%)',
                            style: TextStyle(
                              fontSize: 12,
                              color: priceChange >= 0 ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}