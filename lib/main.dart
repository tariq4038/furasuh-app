import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_windows/webview_windows.dart';
import 'package:window_manager/window_manager.dart';

const String kHomeUrl = 'https://furasuh-sa.com';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  if (!kIsWeb && _isDesktopPlatform) {
    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      size: Size(1280, 860),
      minimumSize: Size(900, 650),
      center: true,
      title: 'Furasuh',
      backgroundColor: Colors.white,
      skipTaskbar: false,
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en', 'US'), Locale('ar', 'SA')],
      path: 'assets/langs',
      fallbackLocale: const Locale('en', 'US'),
      child: const MyApp(),
    ),
  );
}

bool get _isDesktopPlatform {
  switch (defaultTargetPlatform) {
    case TargetPlatform.windows:
    case TargetPlatform.macOS:
    case TargetPlatform.linux:
      return true;
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.fuchsia:
      return false;
  }
}

bool get _isWindowsPlatform =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Furasuh',
      localizationsDelegates: [
        ...context.localizationDelegates,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0E8CA8),
        ),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
        ),
      ),
      home: _isWindowsPlatform
          ? const WindowsWebViewScreen()
          : const AppWebViewScreen(),
    );
  }
}

class AppWebViewScreen extends StatefulWidget {
  const AppWebViewScreen({super.key});

  @override
  State<AppWebViewScreen> createState() => _AppWebViewScreenState();
}

class _AppWebViewScreenState extends State<AppWebViewScreen> {
  late final WebViewController _controller;

  bool _isLoading = true;
  bool _hasFatalError = false;
  bool _pageLoadedSuccessfully = false;
  bool _canGoBack = false;
  bool _canGoForward = false;
  int _progress = 0;

  @override
  void initState() {
    super.initState();
    _initMobileWebView();
  }

  Future<void> _initMobileWebView() async {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000));

    await _controller.clearCache();
    await _controller.clearLocalStorage();

    _controller
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (!mounted) return;
            setState(() {
              _progress = progress;
            });
          },
          onPageStarted: (url) {
            if (!mounted) return;
            setState(() {
              _isLoading = true;
              _hasFatalError = false;
            });
          },
          onPageFinished: (url) async {
            if (!mounted) return;
            setState(() {
              _isLoading = false;
              _progress = 100;
              _pageLoadedSuccessfully = true;
              _hasFatalError = false;
            });
            await _syncNavState();
          },
          onWebResourceError: (error) async {
            if (!mounted) return;

            final isMainFrame = error.isForMainFrame ?? true;

            if (isMainFrame && !_pageLoadedSuccessfully) {
              setState(() {
                _isLoading = false;
                _hasFatalError = true;
              });
            }

            await _syncNavState();
          },
        ),
      )
      ..loadRequest(Uri.parse(kHomeUrl));
  }

  Future<void> _syncNavState() async {
    try {
      final canGoBack = await _controller.canGoBack();
      final canGoForward = await _controller.canGoForward();

      if (!mounted) return;
      setState(() {
        _canGoBack = canGoBack;
        _canGoForward = canGoForward;
      });
    } catch (_) {}
  }

  Future<void> _reload() async {
    try {
      if (!mounted) return;
      setState(() {
        _isLoading = true;
        _hasFatalError = false;
      });
      await _controller.reload();
      await _syncNavState();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasFatalError = true;
      });
    }
  }

  Future<void> _goHome() async {
    try {
      if (!mounted) return;
      setState(() {
        _isLoading = true;
        _hasFatalError = false;
        _pageLoadedSuccessfully = false;
      });
      await _controller.loadRequest(Uri.parse(kHomeUrl));
      await _syncNavState();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasFatalError = true;
      });
    }
  }

  Future<void> _goBack() async {
    try {
      if (await _controller.canGoBack()) {
        await _controller.goBack();
        await _syncNavState();
      }
    } catch (_) {}
  }

  Future<void> _goForward() async {
    try {
      if (await _controller.canGoForward()) {
        await _controller.goForward();
        await _syncNavState();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _TopBar(
        title: '',
        canGoBack: _canGoBack,
        canGoForward: _canGoForward,
        onBack: _goBack,
        onForward: _goForward,
        onReload: _reload,
        progress: _isLoading ? _progress : null,
      ),
      body: SafeArea(
        child: _hasFatalError
            ? ErrorView(
                message:
                    'تعذر تحميل الصفحة. تأكد من الاتصال بالإنترنت ثم أعد المحاولة.',
                onRetry: _goHome,
              )
            : Stack(
                children: [
                  WebViewWidget(controller: _controller),
                  if (_isLoading)
                    const Positioned.fill(
                      child: _LoadingOverlay(),
                    ),
                ],
              ),
      ),
    );
  }
}

class WindowsWebViewScreen extends StatefulWidget {
  const WindowsWebViewScreen({super.key});

  @override
  State<WindowsWebViewScreen> createState() => _WindowsWebViewScreenState();
}

class _WindowsWebViewScreenState extends State<WindowsWebViewScreen> {
  final WebviewController _controller = WebviewController();

  StreamSubscription<LoadingState>? _loadingSub;
  StreamSubscription<HistoryChanged>? _historySub;
  StreamSubscription<String>? _urlSub;

  bool _initialized = false;
  bool _isLoading = true;
  bool _hasFatalError = false;
  bool _pageLoadedSuccessfully = false;
  bool _canGoBack = false;
  bool _canGoForward = false;

  @override
  void initState() {
    super.initState();
    _initWindowsWebView();
  }

  Future<void> _initWindowsWebView() async {
    try {
      await _controller.initialize();
      await _controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);

      _loadingSub = _controller.loadingState.listen((state) {
        if (!mounted) return;
        setState(() {
          _isLoading = state == LoadingState.loading;
        });
      });

      _historySub = _controller.historyChanged.listen((history) {
        if (!mounted) return;
        setState(() {
          _canGoBack = history.canGoBack;
          _canGoForward = history.canGoForward;
        });
      });

      _urlSub = _controller.url.listen((url) {
        if (!mounted) return;
        setState(() {
          _hasFatalError = false;
          _pageLoadedSuccessfully = true;
        });
      });

      await _controller.loadUrl(kHomeUrl);

      if (!mounted) return;
      setState(() {
        _initialized = true;
        _isLoading = false;
        _hasFatalError = false;
      });

      await _syncNavState();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _initialized = true;
        _isLoading = false;
        _hasFatalError = true;
      });
    }
  }

  Future<void> _syncNavState() async {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _reload() async {
    try {
      setState(() {
        _isLoading = true;
        _hasFatalError = false;
      });
      await _controller.reload();
      await _syncNavState();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasFatalError = !_pageLoadedSuccessfully;
      });
    }
  }

  Future<void> _goHome() async {
    try {
      setState(() {
        _isLoading = true;
        _hasFatalError = false;
        _pageLoadedSuccessfully = false;
      });
      await _controller.loadUrl(kHomeUrl);
      await _syncNavState();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasFatalError = true;
      });
    }
  }

  Future<void> _goBack() async {
    try {
      if (_canGoBack) {
        await _controller.goBack();
        await _syncNavState();
      }
    } catch (_) {}
  }

  Future<void> _goForward() async {
    try {
      if (_canGoForward) {
        await _controller.goForward();
        await _syncNavState();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _loadingSub?.cancel();
    _historySub?.cancel();
    _urlSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _TopBar(
        title: '',
        canGoBack: _canGoBack,
        canGoForward: _canGoForward,
        onBack: _goBack,
        onForward: _goForward,
        onReload: _reload,
      ),
      body: SafeArea(
        child: !_initialized
            ? const _LoadingOverlay()
            : _hasFatalError
                ? ErrorView(
                    message:
                        'تعذر تحميل الصفحة. تأكد من الاتصال بالإنترنت ثم أعد المحاولة.',
                    onRetry: _goHome,
                  )
                : Stack(
                    children: [
                      Webview(_controller),
                      if (_isLoading)
                        const Positioned.fill(
                          child: _LoadingOverlay(),
                        ),
                    ],
                  ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget implements PreferredSizeWidget {
  const _TopBar({
    required this.title,
    required this.canGoBack,
    required this.canGoForward,
    required this.onBack,
    required this.onForward,
    required this.onReload,
    this.progress,
  });

  final String title;
  final bool canGoBack;
  final bool canGoForward;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onReload;
  final int? progress;

  @override
  Size get preferredSize => Size.fromHeight(progress != null ? 60 : 56);

  @override
  Widget build(BuildContext context) {
    double? indicatorValue;

    if (progress != null) {
      if (progress! > 0 && progress! < 100) {
        indicatorValue = progress! / 100;
      } else {
        indicatorValue = null;
      }
    }

    return AppBar(
      title: Text(title),
      bottom: progress != null
          ? PreferredSize(
              preferredSize: const Size.fromHeight(4),
              child: LinearProgressIndicator(
                value: indicatorValue,
                minHeight: 3,
              ),
            )
          : null,
      actions: [
        IconButton(
          tooltip: 'تحديث',
          onPressed: onReload,
          icon: const Icon(Icons.refresh_rounded),
        ),
        IconButton(
          tooltip: 'التالي',
          onPressed: canGoForward ? onForward : null,
          icon: const Icon(Icons.arrow_forward_rounded),
        ),
        IconButton(
          tooltip: 'رجوع',
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xAAFFFFFF),
      child: Center(
        child: _LoadingCard(),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            blurRadius: 18,
            color: Color(0x14000000),
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          SizedBox(height: 12),
          Text(
            'جارٍ التحميل...',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                size: 58,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 16),
              const Text(
                'فشل الاتصال',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}