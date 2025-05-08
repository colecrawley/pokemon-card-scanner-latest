import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'dart:convert';
import '../models/pokemon_card.dart';
import '../services/database_helper.dart';
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';

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
      await _fetchPokemonCards();
      _filterCards();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load cards: ${e.toString()}';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _allCards.clear();
      _filteredCards.clear();
      _setCodes = ['All Sets'];
      _selectedSetCode = 'All Sets';
    });

    try {
      await _fetchPokemonCards();
      _filterCards();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to refresh cards: ${e.toString()}';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ✅ ALWAYS trust the certificate (debug + release)
  Future<http.Client> _getHttpClient() async {
    final ioClient = HttpClient()
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
    return IOClient(ioClient);
  }

  Future<void> _fetchPokemonCards() async {
    try {
      const pokemonCategory = '3';
      List<String> allProductIds = [];

      final client = await _getHttpClient();

      for (final setCode in allowedSetCodes) {
        final productsUrl = Uri.parse('https://tcgcsv.com/tcgplayer/$pokemonCategory/$setCode/products');
        final response = await client.get(
          productsUrl,
          headers: {
            'User-Agent': 'Mozilla/5.0',
            'Accept': 'application/json',
          },
        ).timeout(const Duration(seconds: 15));

// Log response status and headers
        print('Status Code: ${response.statusCode}');
        print('Response Headers: ${response.headers}');
        print('Response Body: ${response.body}');

        if (response.statusCode != 200) {
          throw Exception('API returned ${response.statusCode}');
        }

        // Check for HTML content (error page)
        if (response.body.contains('DOCTYPE html')) {
          throw Exception('Received HTML response. Possible API error or unexpected page.');
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
            marketPrice: 0.0,
            priceChange: 0.0,
            setCode: json['setCode'] ?? 'Unknown',
            cardNumber: json['cardNumber'] ?? 'N/A',
          );
        }).toList();

        _allCards.addAll(newCards);
      }

      _allCards = _allCards.toSet().toList();

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

      for (final setCode in allowedSetCodes) {
        final priceUrl = Uri.parse('https://tcgcsv.com/tcgplayer/$pokemonCategory/$setCode/prices');
        final priceResponse = await http.get(
          priceUrl,
          headers: {
            'User-Agent': 'Mozilla/5.0',
            'Accept': 'application/json',
          },
        ).timeout(const Duration(seconds: 15));

        // Log the raw response body
        print('Price Response Body: ${priceResponse.body}');

        if (priceResponse.statusCode == 200) {
          // Check for HTML content (error page)
          if (priceResponse.body.contains('DOCTYPE html')) {
            throw Exception('Received HTML response. Possible API error or unexpected page.');
          }

          final priceData = json.decode(priceResponse.body);
          final priceMap = Map<String, dynamic>.from(priceData['results'] ?? {});

          for (var card in _allCards) {
            final priceInfo = priceMap[card.id];
            if (priceInfo != null && priceInfo['marketPrice'] != null) {
              card.marketPrice = double.tryParse(priceInfo['marketPrice'].toString()) ?? 0.0;
            }
          }
        } else {
          throw Exception('API returned ${priceResponse.statusCode}');
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
    return LiquidPullToRefresh(
      onRefresh: _handleRefresh,
      color: Colors.blue.shade100,
      backgroundColor: Colors.green.shade100,
      height: 100,
      animSpeedFactor: 1.5,
      showChildOpacityTransition: true,
      springAnimationDurationInMilliseconds: 500,
      child: Scaffold(
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
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _filteredCards.length,
                itemBuilder: (context, index) {
                  final card = _filteredCards[index];

                  return ListTile(
                    leading: Image.network(card.imageUrl, width: 50, height: 70),
                    title: Text(card.name),
                    subtitle: const Text('Price: Hidden'),
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
      ),
    );
  }
}
