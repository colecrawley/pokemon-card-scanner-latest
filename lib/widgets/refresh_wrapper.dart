// In refresh_scaffold.dart
import 'package:flutter/material.dart';
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';

class RefreshScaffold extends StatelessWidget {
  final Widget body;
  final Future<void> Function() onRefresh;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final bool isLoading;

  const RefreshScaffold({
    super.key,
    required this.body,
    required this.onRefresh,
    this.appBar,
    this.floatingActionButton,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      body: LiquidPullToRefresh(
        onRefresh: onRefresh,
        color: Colors.blue.shade100,  // Start color of gradient
        backgroundColor: Colors.green.shade100,  // End color of gradient
        height: 150,
        springAnimationDurationInMilliseconds: 500,
        showChildOpacityTransition: false,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : body,
      ),
    );
  }
}