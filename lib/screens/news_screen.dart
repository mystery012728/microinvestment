import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'dart:convert';
import 'dart:async';

class NewsArticle {
  final String title, description, url, imageUrl, source;
  final DateTime publishedAt;

  NewsArticle({
    required this.title,
    required this.description,
    required this.url,
    required this.imageUrl,
    required this.source,
    required this.publishedAt,
  });

  factory NewsArticle.fromJson(Map<String, dynamic> json) => NewsArticle(
    title: json['title'] ?? '',
    description: json['description'] ?? '',
    url: json['url'] ?? '',
    imageUrl: json['urlToImage'] ?? '',
    source: json['source']['name'] ?? '',
    publishedAt: DateTime.parse(json['publishedAt'] ?? DateTime.now().toIso8601String()),
  );
}

class NewsNotificationService {
  static const String _newsApiKey = '86cf54b70f4341219a3ee9a7779ae2dd';

  static Future<void> initialize() async {
    await AwesomeNotifications().initialize(
      'resource://drawable/app_icon',
      [
        NotificationChannel(
          channelKey: 'news_channel',
          channelName: 'News Notifications',
          channelDescription: 'Latest financial news updates',
          defaultColor: Colors.blue,
          ledColor: Colors.blue,
          importance: NotificationImportance.High,
        )
      ],
    );

    await AwesomeNotifications().isNotificationAllowed().then((isAllowed) {
      if (!isAllowed) AwesomeNotifications().requestPermissionToSendNotifications();
    });

    _schedulePeriodicNotifications();
  }

  static void _schedulePeriodicNotifications() {
    AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: 1,
        channelKey: 'news_channel',
        title: 'Getting latest news...',
        body: 'Fetching financial updates',
        notificationLayout: NotificationLayout.Default,
      ),
      schedule: NotificationInterval(
        interval: const Duration(hours: 2), // Fixed: Use Duration instead of int
        repeats: true,
      ),
    );
  }

  static Future<void> sendNewsNotification() async {
    try {
      final response = await http.get(
        Uri.parse('https://newsapi.org/v2/top-headlines?country=us&category=business&pageSize=1&apiKey=$_newsApiKey'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final articles = (data['articles'] as List)
            .map((article) => NewsArticle.fromJson(article))
            .where((article) => article.title.isNotEmpty)
            .toList();

        if (articles.isNotEmpty) {
          final article = articles.first;
          await AwesomeNotifications().createNotification(
            content: NotificationContent(
              id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
              channelKey: 'news_channel',
              title: '📰 Latest News',
              body: article.title,
              bigPicture: article.imageUrl.isNotEmpty ? article.imageUrl : null,
              notificationLayout: article.imageUrl.isNotEmpty
                  ? NotificationLayout.BigPicture
                  : NotificationLayout.Default,
              payload: {'url': article.url},
            ),
          );
        }
      }
    } catch (e) {
      print('Error sending notification: $e');
    }
  }
}

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});
  @override State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> with SingleTickerProviderStateMixin {
  static const String _newsApiKey = '86cf54b70f4341219a3ee9a7779ae2dd';
  List<NewsArticle> _articles = [];
  bool _isLoading = false;
  String? _error;
  late AnimationController _animationController;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
    _initializeNotifications();
    _loadNews();
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) => mounted ? _loadNews(showLoader: false) : null);
  }

  static Future<bool> _onActionReceivedMethod(ReceivedAction receivedAction) async {
    final url = receivedAction.payload?['url'];
    if (url != null) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
    return true;
  }

  Future<void> _initializeNotifications() async {
    await NewsNotificationService.initialize();

    // Listen for notification taps
    AwesomeNotifications().setListeners(
      onActionReceivedMethod: _onActionReceivedMethod,
    );

    // Schedule periodic notifications
    Timer.periodic(const Duration(hours: 2), (_) {
      NewsNotificationService.sendNewsNotification();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadNews({bool showLoader = true}) async {
    if (showLoader) setState(() => _isLoading = true);

    try {
      final response = await http.get(
        Uri.parse('https://newsapi.org/v2/top-headlines?country=us&category=business&pageSize=20&apiKey=$_newsApiKey'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final articles = (data['articles'] as List)
            .map((article) => NewsArticle.fromJson(article))
            .where((article) => article.title.isNotEmpty && article.url.isNotEmpty)
            .toList();

        setState(() {
          _articles = articles;
          _isLoading = false;
          _error = null;
        });
        if (showLoader) _animationController.forward();
      } else {
        throw Exception('Failed to load news: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Financial News', style: TextStyle(fontWeight: FontWeight.w700)),
            backgroundColor: Theme.of(context).colorScheme.surface,
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ],
          ),
          if (_isLoading && _articles.isEmpty)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else if (_error != null && _articles.isEmpty)
            SliverFillRemaining(child: _buildErrorState())
          else if (_articles.isEmpty)
              const SliverFillRemaining(child: Center(child: Text('No news available')))
            else
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList.builder(
                  itemCount: _articles.length,
                  itemBuilder: (context, index) => _NewsCard(article: _articles[index], index: index),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildErrorState() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(Icons.error_outline_rounded, size: 48, color: Theme.of(context).colorScheme.error),
        ),
        const SizedBox(height: 24),
        Text('Unable to load news', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text('Check your connection and try again', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 24),
        FilledButton.icon(onPressed: _loadNews, icon: const Icon(Icons.refresh), label: const Text('Retry')),
      ],
    ),
  );

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _NewsCard extends StatelessWidget {
  final NewsArticle article;
  final int index;
  const _NewsCard({required this.article, required this.index});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index * 50)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) => Transform.translate(
        offset: Offset(0, 30 * (1 - value)),
        child: Opacity(opacity: value, child: child),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _launchUrl(article.url),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (article.imageUrl.isNotEmpty)
                  Stack(
                    children: [
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.network(
                          article.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Theme.of(context).colorScheme.primaryContainer,
                                  Theme.of(context).colorScheme.secondaryContainer,
                                ],
                              ),
                            ),
                            child: const Icon(Icons.image_not_supported_rounded, size: 48),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 16,
                        left: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            article.source,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        article.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (article.description.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          article.description,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            height: 1.4,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(Icons.schedule, size: 16, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            _formatDate(article.publishedAt),
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inDays > 0) return '${difference.inDays}d ago';
    if (difference.inHours > 0) return '${difference.inHours}h ago';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m ago';
    return 'Just now';
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}