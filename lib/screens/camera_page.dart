import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import '../models/pokemon_card.dart';
import '../services/tflite_helper.dart';
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';

class CameraPage extends StatefulWidget {
  final List<CameraDescription> cameras;
  final Function(CardData) onCardConfirmed;

  const CameraPage({
    super.key,
    required this.cameras,
    required this.onCardConfirmed,
  });

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  bool _isTakingPicture = false;
  bool _isCameraInitialized = false;
  bool _apiTestComplete = false;
  String _apiTestResult = 'Initializing...';
  bool _modelsLoaded = false;
  bool _isProcessing = false;
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey();
  final ImagePicker _picker = ImagePicker();
  final GlobalKey _cameraOverlayKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _initializeControllerFuture = _initializeCamera();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _testApiConnection();
    await _loadTfLiteModels();
  }

  Future<void> _handleRefresh() async {
    try {
      setState(() {
        _apiTestComplete = false;
        _modelsLoaded = false;
        _apiTestResult = 'Refreshing...';
      });

      TFLiteHelper.disposeModels();
      await _testApiConnection();
      await _loadTfLiteModels();
    } catch (e) {
      if (mounted) {
        setState(() {
          _apiTestResult = 'Refresh failed';
        });
      }
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final firstCamera = widget.cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => widget.cameras.first,
      );

      _controller = CameraController(
        firstCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _controller.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _apiTestResult = 'Camera error';
        });
      }
      rethrow;
    }
  }

  Future<void> _testApiConnection() async {
    try {
      const testUrl = 'https://tcgcsv.com/tcgplayer/3/23237/products';
      final response = await http.get(Uri.parse(testUrl)).timeout(const Duration(seconds: 10));

      setState(() {
        _apiTestComplete = true;
        _apiTestResult = response.statusCode == 200
            ? 'API Connected'
            : 'API Error: ${response.statusCode}';
      });
    } catch (e) {
      setState(() {
        _apiTestComplete = true;
        _apiTestResult = 'API Connection Failed';
      });
    }
  }

  Future<void> _loadTfLiteModels() async {
    try {
      await TFLiteHelper.loadModels();
      if (mounted) {
        setState(() => _modelsLoaded = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _apiTestResult = 'Model loading failed';
          _modelsLoaded = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    TFLiteHelper.disposeModels();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildCameraPreview(),
          Positioned.fill(
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollUpdateNotification &&
                    notification.metrics.pixels <= 0 &&
                    notification.scrollDelta! > 0) {
                  _handleRefresh();
                  return true;
                }
                return false;
              },
              child: LiquidPullToRefresh(
                key: _refreshIndicatorKey,
                onRefresh: _handleRefresh,
                color: Colors.blue.shade100,  // Start color of gradient
                backgroundColor: Colors.green.shade100,  // End color of gradient
                height: 100,
                animSpeedFactor: 1.5,
                showChildOpacityTransition: false,
                springAnimationDurationInMilliseconds: 500,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height,
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildListDelegate([
                        _buildStatusOverlay(),
                        if (_isProcessing) _buildProcessingIndicator(),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    return SizedBox(
      height: MediaQuery.of(context).size.height,
      child: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            if (snapshot.hasError) {
              return Center(child: Text('Camera error: ${snapshot.error}'));
            }
            return Stack(
              key: _cameraOverlayKey,
              children: [
                Positioned.fill(child: CameraPreview(_controller)),
                Center(
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.7,
                    height: MediaQuery.of(context).size.width * 1.1,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.red.withOpacity(0.7),
                        width: 2.0,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.transparent,
                    ),
                  ),
                ),
              ],
            );
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }

  Widget _buildActionButtons() {
    return Positioned(
      bottom: 20,
      right: 20,
      child: Row(
        children: [
          FloatingActionButton(
            onPressed: (_isTakingPicture || !_modelsLoaded || _isProcessing)
                ? null
                : () => _pickImageFromGallery(context),
            tooltip: 'Pick from Gallery',
            heroTag: 'galleryButton',
            child: const Icon(Icons.photo_library),
          ),
          const SizedBox(width: 20),
          FloatingActionButton(
            onPressed: (_isTakingPicture || !_modelsLoaded || !_isCameraInitialized || _isProcessing)
                ? null
                : () => _takePicture(context),
            tooltip: 'Take Picture',
            heroTag: 'cameraButton',
            child: _isTakingPicture
                ? const CircularProgressIndicator(color: Colors.white)
                : const Icon(Icons.camera_alt),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusOverlay() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.black.withOpacity(0.5),
      child: Column(
        children: [
          if (!_modelsLoaded)
            const Text('Loading models...',
                style: TextStyle(color: Colors.white)),
          Text(_apiTestResult,
              style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildProcessingIndicator() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
      ),
    );
  }

  Future<void> _pickImageFromGallery(BuildContext context) async {
    if (_isTakingPicture || !_modelsLoaded || _isProcessing) return;

    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1800,
        maxHeight: 1800,
      );

      if (pickedFile != null && mounted) {
        setState(() => _isProcessing = true);
        final processedImagePath = await _preprocessImageForModel(pickedFile.path);
        if (mounted) {
          _showCardConfirmationDialog(context, processedImagePath);
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _takePicture(BuildContext context) async {
    if (_isTakingPicture || !_modelsLoaded || !_isCameraInitialized) return;

    setState(() => _isTakingPicture = true);

    try {
      final image = await _controller.takePicture();
      final imageFile = File(image.path);

      if (!mounted) return;

      setState(() => _isProcessing = true);

      final croppedImagePath = await _cropImageToRedBox(imageFile.path);
      final processedImagePath = await _preprocessImageForModel(croppedImagePath);
      if (mounted) {
        _showCardConfirmationDialog(context, processedImagePath);
      }
    } catch (e) {
      debugPrint('Error taking picture: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isTakingPicture = false;
          _isProcessing = false;
        });
      }
    }
  }

  Future<String> _cropImageToRedBox(String imagePath) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      var image = img.decodeImage(bytes);
      if (image == null) throw Exception("Invalid image");

      final boxWidth = (MediaQuery.of(context).size.width * 0.7).toInt();
      final boxHeight = (boxWidth * 1.1).toInt();
      final offsetX = (image.width - boxWidth) ~/ 2;
      final offsetY = (image.height - boxHeight) ~/ 2;

      final croppedImage = img.copyCrop(
        image,
        offsetX,
        offsetY,
        boxWidth,
        boxHeight,
      );

      final croppedFile = File('${imagePath}_cropped.jpg');
      await croppedFile.writeAsBytes(img.encodeJpg(croppedImage));

      return croppedFile.path;
    } catch (e) {
      debugPrint('Image cropping error: $e');
      return imagePath;
    }
  }

  Future<String> _preprocessImageForModel(String filePath) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      var image = img.decodeImage(bytes);
      if (image == null) throw Exception("Invalid image");

      final resized = img.copyResize(image, width: 224, height: 224);
      final processedFile = File('${filePath}_processed.jpg');
      await processedFile.writeAsBytes(img.encodeJpg(resized));

      return processedFile.path;
    } catch (e) {
      debugPrint('Image preprocessing error: $e');
      return filePath;
    }
  }

  Future<CardData?> _fetchCardData(String imagePath) async {
    if (!_apiTestComplete || !_modelsLoaded) return null;

    try {
      // 1. Predict set
      final setPrediction = await TFLiteHelper.predictSet(File(imagePath));
      if (setPrediction == null) {
        throw Exception("Could not predict set");
      }

      debugPrint('Predicted set: $setPrediction');

      // 2. Get set code
      final setCode = _getSetCode(setPrediction);
      if (setCode == null) {
        throw Exception("Unknown set: $setPrediction");
      }

      // 3. Predict card ID
      final cardIdPrediction = await TFLiteHelper.predictCardId(
          File(imagePath),
          setPrediction
      );
      if (cardIdPrediction == null) {
        throw Exception("Could not predict card ID");
      }

      debugPrint('Predicted card ID: $cardIdPrediction');

      // 4. Extract card number
      final cardNumber = _extractCardNumber(cardIdPrediction);
      if (cardNumber == null) {
        throw Exception("Could not extract card number from: $cardIdPrediction");
      }

      debugPrint('Extracted card number: $cardNumber');

      // 5. Fetch from API
      return await _fetchCardFromApi(setCode, cardNumber);
    } catch (e) {
      debugPrint('Card detection error: $e');
      return null;
    }
  }

  String? _extractCardNumber(String cardIdPrediction) {
    final fullNumberPattern = RegExp(r'(\d+/\d+)$');
    final fullNumberMatch = fullNumberPattern.firstMatch(cardIdPrediction);
    if (fullNumberMatch != null) {
      return fullNumberMatch.group(1)?.split('/').first;
    }

    final numberPattern = RegExp(r'(\d+)$');
    final numberMatch = numberPattern.firstMatch(cardIdPrediction);
    return numberMatch?.group(1);
  }

  int? _getSetCode(String setName) {
    const setMapping = {
      '151': 23237,
      'base': 604,
      'fossil': 630,
      'jungle': 635,
      'wizards black star promos': 1418,
      'base set': 604,
      'fossil set': 630,
      'jungle set': 635,
    };
    return setMapping[setName.toLowerCase()];
  }

  Future<CardData?> _fetchCardFromApi(int setCode, String cardNumber) async {
    try {
      const pokemonCategory = '3';
      final productsUrl = Uri.parse(
          'https://tcgcsv.com/tcgplayer/$pokemonCategory/$setCode/products'
      );
      final productsResponse = await http.get(productsUrl)
          .timeout(const Duration(seconds: 10));

      if (productsResponse.statusCode != 200) {
        throw Exception('API returned ${productsResponse.statusCode}');
      }

      final productsData = json.decode(productsResponse.body);
      if (productsData['results'].isEmpty) {
        throw Exception('No products found for set $setCode');
      }

      final numberVariations = _generateNumberVariations(cardNumber);

      dynamic targetProduct;
      for (var product in productsData['results']) {
        final name = product['name']?.toString() ?? '';
        if (_matchesAnyNumberVariation(name, numberVariations)) {
          targetProduct = product;
          break;
        }

        final extendedData = product['extendedData'] as List?;
        if (extendedData != null) {
          final numberData = extendedData.firstWhere(
                (data) => data['name'] == 'Number',
            orElse: () => null,
          );

          if (numberData != null) {
            final fullNumber = numberData['value']?.toString() ?? '';
            if (_matchesAnyNumberVariation(fullNumber, numberVariations)) {
              targetProduct = product;
              break;
            }
          }
        }
      }

      if (targetProduct == null) {
        throw Exception('Card $cardNumber not found in set $setCode');
      }

      final pricesUrl = Uri.parse(
          'https://tcgcsv.com/tcgplayer/$pokemonCategory/$setCode/prices'
      );
      final pricesResponse = await http.get(pricesUrl)
          .timeout(const Duration(seconds: 10));

      final marketPrice = pricesResponse.statusCode == 200
          ? _parsePriceFromResponse(pricesResponse.body, targetProduct['productId'])
          : 0.0;

      return CardData(
        id: targetProduct['productId'].toString(),
        name: targetProduct['name'],
        imageUrl: targetProduct['imageUrl'] ?? '',
        marketPrice: marketPrice,
        priceChange: 0.0,
        setCode: setCode.toString(),
        cardNumber: _extractCardNumberFromProduct(targetProduct) ?? cardNumber,
      );
    } catch (e) {
      debugPrint('API error: $e');
      return null;
    }
  }

  List<String> _generateNumberVariations(String number) {
    final variations = <String>[number];

    if (number.length == 1 && int.tryParse(number) != null) {
      variations.add('0$number');
      variations.add('00$number');
    }
    else if (number.length == 2 && int.tryParse(number) != null) {
      variations.add('0$number');
    }

    return variations;
  }

  bool _matchesAnyNumberVariation(String text, List<String> variations) {
    for (final variation in variations) {
      if (text.contains(' - $variation/') || text.contains('- $variation/')) {
        return true;
      }
      final parts = text.split('/');
      if (parts.isNotEmpty && variations.contains(parts[0])) {
        return true;
      }
    }
    return false;
  }

  String? _extractCardNumberFromProduct(dynamic product) {
    final extendedData = product['extendedData'] as List?;
    if (extendedData != null) {
      final numberData = extendedData.firstWhere(
            (data) => data['name'] == 'Number',
        orElse: () => null,
      );

      if (numberData != null) {
        final fullNumber = numberData['value']?.toString() ?? '';
        return fullNumber.split('/').first;
      }
    }

    final name = product['name']?.toString() ?? '';
    final pattern = RegExp(r'(\d+)/\d+$');
    final match = pattern.firstMatch(name);
    return match?.group(1);
  }

  double _parsePriceFromResponse(String responseBody, dynamic productId) {
    try {
      final pricesData = json.decode(responseBody);
      final cardPrice = pricesData['results'].firstWhere(
            (price) => price['productId'] == productId,
        orElse: () => null,
      );
      return double.tryParse(cardPrice?['marketPrice']?.toString() ?? '0') ?? 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  void _showCardConfirmationDialog(BuildContext context, String imagePath) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return FutureBuilder<CardData?>(
          future: _fetchCardData(imagePath),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AlertDialog(
                title: Text('Identifying Card...'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(child: CircularProgressIndicator()),
                    SizedBox(height: 16),
                    Text('Analyzing card image...'),
                  ],
                ),
              );
            }

            final card = snapshot.data;
            return AlertDialog(
              title: Text(card != null ? 'Is this your card?' : 'Card Not Found'),
              content: _buildDialogContent(card, imagePath),
              actions: _buildDialogActions(card),
            );
          },
        );
      },
    );
  }

  Widget _buildDialogContent(CardData? card, String imagePath) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (card != null && card.imageUrl.isNotEmpty)
            Image.network(card.imageUrl, height: 250, fit: BoxFit.contain)
          else
            Image.file(File(imagePath), height: 250),
          if (card != null) ...[
            const SizedBox(height: 20),
            _buildInfoRow('Name:', card.name),
            _buildInfoRow('Set:', card.setCode),
            _buildInfoRow('Price:', '\$${card.marketPrice.toStringAsFixed(2)}'),
          ] else
            const Text('Could not identify this card'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Text(value),
        ],
      ),
    );
  }

  List<Widget> _buildDialogActions(CardData? card) {
    return [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('No', style: TextStyle(color: Colors.red)),
      ),
      if (card != null)
        TextButton(
          onPressed: () {
            widget.onCardConfirmed(card);
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Card added to portfolio!')),
            );
          },
          child: const Text('Yes', style: TextStyle(color: Colors.green)),
        ),
    ];
  }
}