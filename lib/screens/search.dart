import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/pokemon_card.dart';
import '../services/database_helper.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  List<CardData> _allCards = [];
  List<CardData> _filteredCards = [];
  List<String> _setCodes = ['All Sets'];

  String _selectedSetCode = 'All Sets';
  bool _isLoading = false;
  String _errorMessage = '';

  // Set of allowed set codes
  final List<String> allowedSetCodes = ['23237', '604', '630', '635', '1418'];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      await _fetchPokemonCards();  // No need to pass CardData card anymore
      _filterCards();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load cards: ${e.toString()}';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchPokemonCards() async {
    try {
      const pokemonCategory = '3';
      List<String> allProductIds = [];

      for (final setCode in allowedSetCodes) {
        final productsUrl = Uri.parse('https://tcgcsv.com/tcgplayer/$pokemonCategory/$setCode/products');
        final response = await http.get(productsUrl).timeout(const Duration(seconds: 15));

        if (response.statusCode != 200) {
          throw Exception('API returned ${response.statusCode}');
        }

        final data = json.decode(response.body);
        if (data['results'] == null || data['results'].isEmpty) {
          continue;
        }

        final newCards = (data['results'] as List).map((json) {
          final productId = json['productId'].toString();
          allProductIds.add(productId);
          return CardData(
            id: productId,
            name: json['name'] ?? 'Unknown',
            imageUrl: json['imageUrl'] ?? 'https://via.placeholder.com/150',
            marketPrice: 0.0, // Will be updated later
            priceChange: 0.0,
            setCode: json['setCode'] ?? 'Unknown',
            cardNumber: json['cardNumber'] ?? 'N/A',
          );
        }).toList();

        _allCards.addAll(newCards);
      }

      // Remove duplicates
      _allCards = _allCards.toSet().toList();

      // Fetch prices in bulk for all cards
      await _fetchCardPrices();

      final newSetCodes = _allCards
          .map((card) => card.setCode)
          .toSet()
          .toList()
        ..sort();

      setState(() {
        _setCodes = ['All Sets', ...newSetCodes];
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to fetch cards: ${e.toString()}';
      });
    }
  }

  Future<void> _fetchCardPrices() async {
    try {
      const pokemonCategory = '3';

      // Fetch prices for each set
      for (final setCode in allowedSetCodes) {
        final priceUrl = Uri.parse(
            'https://tcgcsv.com/tcgplayer/$pokemonCategory/$setCode/prices');
        final priceResponse = await http.get(priceUrl).timeout(const Duration(seconds: 15));

        if (priceResponse.statusCode == 200) {
          final priceData = json.decode(priceResponse.body);
          final priceMap = Map<String, dynamic>.from(priceData['results'] ?? {});

          // Update prices in _allCards
          for (var card in _allCards) {
            final priceInfo = priceMap[card.id];
            if (priceInfo != null && priceInfo['marketPrice'] != null) {
              card.marketPrice = double.tryParse(priceInfo['marketPrice'].toString()) ?? 0.0;
            }
          }
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to fetch prices: ${e.toString()}';
      });
    }
  }

  void _filterCards() {
    final searchTerm = _searchController.text.toLowerCase();

    setState(() {
      _filteredCards = _allCards.where((card) {
        final matchesSearch = searchTerm.isEmpty ||
            card.name.toLowerCase().contains(searchTerm);
        final matchesSet = _selectedSetCode == 'All Sets' ||
            card.setCode == _selectedSetCode;
        return matchesSearch && matchesSet;
      }).toList();
    });
  }

  Future<void> _addToPortfolio(CardData card) async {
    try {
      await _dbHelper.insertCard(card);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${card.name} added to portfolio!'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add card: ${e.toString()}'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Pokémon Cards'),
        centerTitle: true,
      ),
      body: _isLoading && _allCards.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty && _allCards.isEmpty
          ? Center(
        child: Text(_errorMessage, textAlign: TextAlign.center),
      )
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search by name...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => _filterCards(),
            ),
          ),
          DropdownButton<String>(
            value: _selectedSetCode,
            onChanged: (newValue) {
              setState(() {
                _selectedSetCode = newValue!;
              });
              _filterCards();
            },
            items: _setCodes.map((setCode) {
              return DropdownMenuItem<String>(
                value: setCode,
                child: Text(setCode),
              );
            }).toList(),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _filteredCards.length,
              itemBuilder: (context, index) {
                final card = _filteredCards[index];

                return ListTile(
                  leading: Image.network(card.imageUrl, width: 50, height: 70),
                  title: Text(card.name),
                  subtitle: const Text('Price: Hidden'),  // Hide price on the search page
                  trailing: IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => _addToPortfolio(card),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
