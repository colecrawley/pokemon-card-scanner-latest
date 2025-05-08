import 'dart:io';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class TFLiteHelper {
  static Interpreter? _setModel;
  static final Map<String, Interpreter> _cardModels = {};
  static List<String> _setLabels = [];
  static final Map<String, List<String>> _cardLabels = {};

  static Future<void> loadModels() async {
    try {
      // Load set model and labels
      _setModel = await loadModel('assets/models/setmodel.tflite');
      _setLabels = await loadLabels('assets/models/set_labels.txt');

      // Load card models and labels for each set
      final sets = ['151', 'base', 'fossil', 'jungle', 'wizards_black_star_promos'];
      for (final set in sets) {
        try {
          final model = await loadModel('assets/models/${set}_model.tflite');
          final labels = await loadLabels('assets/models/${set}_labels.txt');
          _cardModels[set] = model;
          _cardLabels[set] = labels;
        } catch (e) {
          print('Failed to load model for set $set: $e');
        }
      }
    } catch (e) {
      print('Error loading models: $e');
      rethrow;
    }
  }

  static Future<Interpreter> loadModel(String assetPath) async {
    try {

      final modelData = await rootBundle.load(assetPath);


      final tempDir = await getTemporaryDirectory();
      final modelFile = File('${tempDir.path}/${assetPath.split('/').last}');


      await modelFile.writeAsBytes(modelData.buffer.asUint8List());


      return Interpreter.fromFile(modelFile);
    } catch (e) {
      print('Error loading model from $assetPath: $e');
      rethrow;
    }
  }

  static Future<List<String>> loadLabels(String assetPath) async {
    try {

      final labelsData = await rootBundle.loadString(assetPath);
      return labelsData.split('\n').map((label) => label.trim()).toList();
    } catch (e) {
      print('Error loading labels from $assetPath: $e');
      return [];
    }
  }

  static void disposeModels() {
    _setModel?.close();
    for (final model in _cardModels.values) {
      model.close();
    }
    _setModel = null;
    _cardModels.clear();
    _setLabels.clear();
    _cardLabels.clear();
  }

  static Future<String?> predictSet(File imageFile) async {
    if (_setModel == null || _setLabels.isEmpty) return null;

    try {
      final imageBytes = await imageFile.readAsBytes();
      final image = img.decodeImage(imageBytes);
      if (image == null) return null;

      final resized = img.copyResize(image, width: 224, height: 224);
      final input = _imageToTensor(resized);


      final outputShape = _setModel!.getOutputTensor(0).shape;
      final output = List.filled(outputShape.reduce((a, b) => a * b), 0.0)
          .reshape(outputShape);

      _setModel!.run(input, output);


      final index = _findMaxIndex(output[0]);
      return _setLabels.isNotEmpty && index < _setLabels.length
          ? _setLabels[index]
          : null;
    } catch (e) {
      print('Set prediction error: $e');
      return null;
    }
  }

  static Future<String?> predictCardId(File imageFile, String set) async {

    final normalizedSet = set.toLowerCase().replaceAll(' ', '_');
    final model = _cardModels[normalizedSet];
    final labels = _cardLabels[normalizedSet];

    if (model == null) {
      print('Model not found for set: $normalizedSet');
      print('Available sets: ${_cardModels.keys.join(', ')}');
      return null;
    }
    if (labels == null || labels.isEmpty) {
      print('Labels not loaded for set: $normalizedSet');
      return null;
    }

    try {
      final imageBytes = await imageFile.readAsBytes();
      final image = img.decodeImage(imageBytes);
      if (image == null) return null;

      final resized = img.copyResize(image, width: 224, height: 224);
      final input = _imageToTensor(resized);

      final outputShape = model.getOutputTensor(0).shape;
      final output = List.filled(outputShape.reduce((a, b) => a * b), 0.0)
          .reshape(outputShape);

      model.run(input, output);

      final index = _findMaxIndex(output[0]);
      if (index >= labels.length) {
        print('Index out of range: $index >= ${labels.length}');
        return null;
      }

      final prediction = labels[index];
      print('Predicted card: $prediction');
      return prediction;
    } catch (e) {
      print('Card ID prediction error for $normalizedSet: $e');
      return null;
    }
  }

  static int _findMaxIndex(List<double> list) {
    double max = list[0];
    int index = 0;
    for (int i = 1; i < list.length; i++) {
      if (list[i] > max) {
        max = list[i];
        index = i;
      }
    }
    return index;
  }

  static List<List<List<List<double>>>> _imageToTensor(img.Image image) {
    return [
      List.generate(224, (y) {
        return List.generate(224, (x) {
          final pixel = image.getPixel(x, y);
          return [
            (img.getRed(pixel) / 127.5) - 1.0,
            (img.getGreen(pixel) / 127.5) - 1.0,
            (img.getBlue(pixel) / 127.5) - 1.0,
          ];
        });
      })
    ];
  }
}
