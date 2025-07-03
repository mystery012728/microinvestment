import 'package:flutter/material.dart';

import '../models/news_article.dart';
import '../services/real_time_api_service.dart';

class NewsProvider with ChangeNotifier {
  List<NewsArticle> _articles = [];
  bool _isLoading = false;
  String? _error;

  List<NewsArticle> get articles => _articles;
  bool get isLoading => _isLoading;
  String? get error => _error;

  NewsProvider() {
    refreshNews();
    _startPeriodicRefresh();
  }

  void _startPeriodicRefresh() {
    // Refresh news every 5 minutes
    Future.delayed(const Duration(minutes: 5), () {
      if (!_isLoading) {
        refreshNews();
      }
      _startPeriodicRefresh();
    });
  }

  Future<void> refreshNews() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _articles = await RealTimeApiService.getFinancialNews();
    } catch (e) {
      _error = 'Failed to load news: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
