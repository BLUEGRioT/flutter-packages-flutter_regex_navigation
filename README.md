# flutter_regex_navigation

A flutter package to easier handle route navigation

## Configuration

You first must implement subclasses of NavigationState that represent the routes

```dart
class HomeNavigationState extends NavigationState {
    HomeNavigationState({bool animate = true}) : super(animate: animate);

    @override
    String get path => "/";

    @override
    AppPage getPage(BuildContext context) => AppPage(state: this, child: HomePage());
}
```
The getter `path` is used to build the url of the route. The fonction `getPage` must return a material page. 

Then you will implement a subclass of NavigationStateRouteBuilder
```dart
class AppNavigationStateRouteBuilder extends NavigationStateRouteBuilder {
  @override
  List<NavigationStateRoute> get routes => [
    NavigationStateRoute(r"^/$", (groups) => HomeNavigationState()), 
    NavigationStateRoute(r"^/references/(?<referenceId>.+)$", (groups) => ReferenceNavigationState(id: groups["referenceId"] ?? ""))
  ];
}
```

## Utilisation

```dart
import 'package:flutter_regex_navigation/flutter_regex_navigation.dart';

void main() {
  runApp(NavigationStateRouter(
    navigationStateRouteBuilder: AppNavigationStateRouteBuilder(),
    defaultNavigationState: HomeNavigationState(), 
    child: MyApp()
  ));
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'MyApp',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      routeInformationParser: context.navigationStateRouter.routeInformationParser, 
      routerDelegate: context.navigationStateRouter.routerDelegate
    );
  }
}

```