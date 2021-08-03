import 'dart:async';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

enum ThemeType {
  cupertino, 
  material
}

typedef ModalRouteBuilder = Route? Function(ThemeType, AppPage);

class NavigationStateRouter extends InheritedWidget {
  final ThemeType themeType;
  final ModalRouteBuilder? _modalRouteBuilder;
  final NavigationState _defaultNavigationState;
  final NavigationState Function(Uri uri)? _notFoundNavigationState;
  final NavigationStateRouteBuilder _navigationStateRouteBuilder;

  NavigationStateRouter({
    required NavigationStateRouteBuilder navigationStateRouteBuilder,
    required NavigationState defaultNavigationState, 
    NavigationState Function(Uri uri)? notFoundNavigationState, 
    this.themeType = ThemeType.material,
    ModalRouteBuilder? modalRouteBuilder,
    required Widget child, 
  }) : 
    _navigationStateRouteBuilder = navigationStateRouteBuilder,
    _defaultNavigationState = defaultNavigationState, 
    _notFoundNavigationState = notFoundNavigationState,
    _modalRouteBuilder = modalRouteBuilder,
    super(child: child) {
      _NavigationManager.shared.registerRoutes(_navigationStateRouteBuilder.routes);
    }

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) {
    return false;
  }

  static NavigationStateRouter of(BuildContext context) {
      final value = context.dependOnInheritedWidgetOfExactType<NavigationStateRouter>();
      assert(value != null, "The NavigationStateRouter is not found in the widget hirarchy. Please Wrap your App with NavigationStateRouter");
      return value!;
  }

  RouteInformationParser<NavigationState> get routeInformationParser => _AppRouteInformationParser(_notFoundNavigationState);

  late final _AppRouteDelegate _routerDelegate = _AppRouteDelegate(_defaultNavigationState);

  RouterDelegate<NavigationState> get routerDelegate => _routerDelegate;

  void push(NavigationState state) => _routerDelegate.pushNavigationState(state);

  NavigationState? pop<T>([T? result]) => _routerDelegate.popNavigationState(result);
}

extension NavigationStateRouterExtension on BuildContext {
  NavigationStateRouter get navigationStateRouter => NavigationStateRouter.of(this);
}

abstract class NavigationStateRouteBuilder {
  List<NavigationStateRoute> get routes;
}

typedef NavigationState NavigationStateBuilder(Map<String, String> groups);

class NavigationStateRoute {
  final String pattern;
  final NavigationStateBuilder builder;

  NavigationStateRoute(this.pattern, this.builder);
}

class _NavigationManager {
  //singleton
  static final _NavigationManager _singleton = _NavigationManager._internal();
  factory _NavigationManager() => _singleton;
  _NavigationManager._internal();
  static _NavigationManager get shared => _singleton;

  List<NavigationState> navigationStateStack = [];
  Map<String, AppPage> pagesCache = {};

  final LinkedHashMap<String, NavigationStateBuilder> _routePatterns = LinkedHashMap<String, NavigationStateBuilder>();

  void registerRoute(NavigationStateRoute route) {
    _routePatterns[route.pattern] = route.builder;
  }

  void registerRoutes(List<NavigationStateRoute> routes) {
    for (var route in routes) {
      registerRoute(route);
    }
  }
  
  NavigationStateBuilder? operator [](String key) => _routePatterns[key];
}


abstract class NavigationState {
  final bool animate;
  String get path;
  AppPage buildPage(BuildContext context);
  AppPage _getPage(BuildContext context) {
    if (!_NavigationManager.shared.pagesCache.containsKey(this.path)) {
      _NavigationManager.shared.pagesCache[this.path] = buildPage(context);
    }
    return _NavigationManager.shared.pagesCache[this.path]!;
  }

  NavigationState({this.animate = true});
}

class _NotFoundNavigationState extends NavigationState {
  final Uri uri;

  _NotFoundNavigationState(this.uri, {bool animate = false}) : super(animate: animate);

  @override
  String get path => uri.path;

  @override
  AppPage buildPage(BuildContext context) => AppPage(state: this, child: Scaffold(body: Center(child: Text("Page not found"))));
}


class _AppRouteInformationParser extends RouteInformationParser<NavigationState> {
  final NavigationState Function(Uri uri)? _notFoundNavigationState;

  _AppRouteInformationParser(this._notFoundNavigationState);

  @override
  Future<NavigationState> parseRouteInformation(RouteInformation routeInformation) async {
    final route = _NavigationManager.shared._routePatterns.keys.firstWhere((_) => RegExp(_).hasMatch(routeInformation.location!), orElse: () => '');
    final uri = Uri.parse(routeInformation.location ?? '/');
    if (route == '' || routeInformation.location == null) {
      if (_notFoundNavigationState != null) {
        return _notFoundNavigationState!(uri);
      }
      return _NotFoundNavigationState(uri);
    }

    final match = RegExp(route).firstMatch(routeInformation.location!);
    if (match != null) {
      final groups = Map<String, String>.fromEntries(match.groupNames.map((key) => MapEntry<String, String>(key, match.namedGroup(key)!)));
      return _NavigationManager.shared[route]!(groups);
    }
    if (_notFoundNavigationState != null) {
        return _notFoundNavigationState!(uri);
      }
      return _NotFoundNavigationState(uri);
  }

  @override
  RouteInformation restoreRouteInformation(NavigationState configuration) {
    return RouteInformation(location: configuration.path);
  }
}

class _AppRouteDelegate extends RouterDelegate<NavigationState> with ChangeNotifier, PopNavigatorRouterDelegateMixin<NavigationState> {
  final NavigationState _defaultNavigationState;

  final GlobalKey<NavigatorState> _routerDelegateNavigatorKey =
    GlobalKey<NavigatorState>();

  NavigationState? _currentState;

  _AppRouteDelegate(this._defaultNavigationState);

  @override
  NavigationState get currentConfiguration {
    return _currentState ?? _defaultNavigationState;
  }

  void pushNavigationState(NavigationState state) {
    _NavigationManager.shared.navigationStateStack.add(currentConfiguration);
    setNewRoutePath(state);
  }

  NavigationState? popNavigationState<T>([T? result]) {
    return _NavigationManager.shared.navigationStateStack.last;
    navigatorKey.currentState?.pop(result);
  }

  @override
  Widget build(BuildContext context) {
    List<Page<dynamic>> pages = [];
    final configuration = currentConfiguration;

    // Add previous pages in the history
    for (var item in _NavigationManager.shared.navigationStateStack) {
      pages.add(item._getPage(context));
    }
    

    // Add current page
    pages.add(configuration._getPage(context));
    
    return Navigator(
      key: navigatorKey,
      pages: pages,
      onPopPage: (_, __) {
        if (!_.didPop(__)) {
          return false;
        }
        pages.removeLast();
        final oldState = _NavigationManager.shared.navigationStateStack.removeLast();
        _NavigationManager.shared.pagesCache.remove(oldState.path);
        final page = pages.last;
        if (page is AppPage) {
          _currentState = page.state;
          SystemNavigator.routeInformationUpdated(location: page.state.path);
        }
        return true;
      },
    );
  }

  @override
  GlobalKey<NavigatorState> get navigatorKey => _routerDelegateNavigatorKey;

  @override
  Future<void> setNewRoutePath(NavigationState configuration) async {
    _currentState = configuration;
    notifyListeners();
    SystemNavigator.routeInformationUpdated(location: _currentState?.path ?? '/');
  }
  
}

class AppPage<T> extends MaterialPage<T> {
  AppPage({required this.state, required Widget child, String? name, Object? arguments, bool fullscreenDialog = false, bool maintainState = true}) : super(key: ValueKey(state.path), child: child, name: name, arguments: arguments, fullscreenDialog: fullscreenDialog, maintainState: maintainState);

  final NavigationState state;

  @override
  Route<T> createRoute(BuildContext context) {
    dynamic result;
    ModalRouteBuilder? modalRouteBuilder = NavigationStateRouter.of(context)._modalRouteBuilder;
    if (this.fullscreenDialog && modalRouteBuilder != null) {
      result = modalRouteBuilder(NavigationStateRouter.of(context).themeType, this);
    }
    if (result != null) {
      return result;
    }
    switch (NavigationStateRouter.of(context).themeType) {
      case ThemeType.material:
        return _AppPageBasedMaterialPageRoute(page: this);   
      case ThemeType.cupertino:
        return _AppPageBasedCupertinoPageRoute(page: this);   
    }
    throw Exception("Unsupported type");
  }
}

class _AppPageBasedMaterialPageRoute<T> extends PageRoute<T> with MaterialRouteTransitionMixin<T> {
  _AppPageBasedMaterialPageRoute({
    required AppPage<T> page,
  }) : super(settings: page) {
    assert(opaque);
  }

  AppPage<T> get _page => settings as AppPage<T>;

  @override
  Widget buildContent(BuildContext context) {
    return _page.child;
  }

  @override
  Duration get transitionDuration => _page.state.animate ? super.transitionDuration : Duration.zero;

  @override
  bool get maintainState => _page.maintainState;

  @override
  bool get fullscreenDialog => _page.fullscreenDialog;

  @override
  String get debugLabel => '${super.debugLabel}(${_page.name})';
}

class _AppPageBasedCupertinoPageRoute<T> extends PageRoute<T> with CupertinoRouteTransitionMixin<T> {
  _AppPageBasedCupertinoPageRoute({
    required AppPage<T> page,
  }) : super(settings: page) {
    assert(opaque);
  }

  AppPage<T> get _page => settings as AppPage<T>;

  @override
  Widget buildContent(BuildContext context) {
    return _page.child;
  }

  @override
  String? get title => _page.name;

  @override
  Duration get transitionDuration => _page.state.animate ? super.transitionDuration : Duration.zero;

  @override
  bool get maintainState => _page.maintainState;

  @override
  bool get fullscreenDialog => _page.fullscreenDialog;

  @override
  String get debugLabel => '${super.debugLabel}(${_page.name})';
}