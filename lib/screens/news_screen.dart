import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'dart:async';

class NewsArticle {
  final String title;
  final String description;
  final String url;
  final String imageUrl;
  final String source;
  final DateTime publishedAt;

  NewsArticle({
    required this.title,
    required this.description,
    required this.url,
    required this.imageUrl,
    required this.source,
    required this.publishedAt,
  });

  factory NewsArticle.fromJson(Map<String, dynamic> json) {
    return NewsArticle(
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      url: json['url'] ?? '',
      imageUrl: json['urlToImage'] ?? '',
      source: json['source']['name'] ?? '',
      publishedAt: DateTime.parse(json['publishedAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> with SingleTickerProviderStateMixin {
  static const String _newsApiKey = '86cf54b70f4341219a3ee9a7779ae2dd';

  List<NewsArticle> _articles = [];
  bool _isLoading = false;
  String? _error;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _loadNews();
    _startPeriodicRefresh();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startPeriodicRefresh() {
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (mounted) {
        _loadNews(showLoader: false);
      }
    });
  }

  Future<void> _loadNews({bool showLoader = true}) async {
    if (showLoader) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final response = await http.get(
        Uri.parse(
            'https://newsapi.org/v2/top-headlines?'
                'country=us&'
                'category=business&'
                'pageSize=20&'
                'apiKey=$_newsApiKey'
        ),
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

        if (showLoader) {
          _animationController.forward();
        }
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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.surface,
        title: Text(
          'Financial News',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        actions: [
          IconButton(
            icon: AnimatedRotation(
              turns: _isLoading ? 1 : 0,
              duration: const Duration(milliseconds: 1000),
              child: Icon(
                Icons.refresh_rounded,
                color: colorScheme.primary,
              ),
            ),
            onPressed: _isLoading ? null : () => _loadNews(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _articles.isEmpty) {
      return _buildLoadingState();
    }

    if (_error != null && _articles.isEmpty) {
      return _buildErrorState();
    }

    if (_articles.isEmpty) {
      return _buildEmptyState();
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: RefreshIndicator(
        onRefresh: () => _loadNews(),
        color: Theme.of(context).colorScheme.primary,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16.0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    final article = _articles[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: _NewsCard(
                        article: article,
                        index: index,
                      ),
                    );
                  },
                  childCount: _articles.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading latest news...',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 80,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Unable to load news',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please check your internet connection and try again',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _loadNews(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.article_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No News Available',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Pull to refresh for the latest financial news',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  final NewsArticle article;
  final int index;

  const _NewsCard({
    required this.article,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index * 100)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: colorScheme.outline.withOpacity(0.1),
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _launchUrl(article.url),
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image with gradient overlay
              if (article.imageUrl.isNotEmpty)
                Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.network(
                        article.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  colorScheme.surfaceVariant,
                                  colorScheme.surfaceVariant.withOpacity(0.8),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Icon(
                              Icons.image_not_supported_rounded,
                              size: 48,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          );
                        },
                      ),
                    ),
                    // Gradient overlay
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.1),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

              // Content
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Source and Date Row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            article.source,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _formatDate(article.publishedAt),
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Title
                    Text(
                      article.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    // Description
                    if (article.description.isNotEmpty)
                      Text(
                        article.description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.7),
                          height: 1.4,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}