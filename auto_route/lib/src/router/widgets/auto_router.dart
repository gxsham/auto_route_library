import 'package:auto_route/src/route/page_route_info.dart';
import 'package:auto_route/src/route/route_data.dart';
import 'package:auto_route/src/router/controller/routing_controller.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import '../controller/routing_controller.dart';
import 'auto_router_delegate.dart';

class AutoRouter extends StatefulWidget {
  final List<PageRouteInfo> Function(BuildContext context, List<PageRouteInfo> routes) onGenerateRoutes;
  final bool _isDeclarative;
  final Function(PageRouteInfo route) onPopRoute;
  final List<NavigatorObserver> navigatorObservers;
  final Widget Function(BuildContext context, Widget content) builder;

  const AutoRouter({
    Key key,
    this.navigatorObservers = const [],
    this.builder,
  })  : _isDeclarative = false,
        onGenerateRoutes = null,
        onPopRoute = null,
        super(key: key);

  const AutoRouter.declarative({
    Key key,
    this.navigatorObservers = const [],
    @required this.onGenerateRoutes,
    this.onPopRoute,
  })  : _isDeclarative = true,
        builder = null,
        super(key: key);

  @override
  AutoRouterState createState() => AutoRouterState();

  static StackRouter of(BuildContext context) {
    var scope = StackRouterScope.of(context);
    assert(() {
      if (scope == null) {
        throw FlutterError('AutoRouter operation requested with a context that does not include an AutoRouter.\n'
            'The context used to retrieve the Router must be that of a widget that '
            'is a descendant of an AutoRouter widget.');
      }
      return true;
    }());

    return scope.controller;
  }

  static StackRouter childRouterOf(BuildContext context, String routeKey) {
    return of(context)?.childRouterOf(routeKey);
  }
}

class AutoRouterState extends State<AutoRouter> {
  ChildBackButtonDispatcher _backButtonDispatcher;
  AutoRouterDelegate _routerDelegate;
  List<PageRouteInfo> _routes;

  // StackRouter get controller => _routerDelegate?.controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_routerDelegate == null) {
      final router = Router.of(context);
      assert(router != null);
      _backButtonDispatcher = router.backButtonDispatcher.createChildBackButtonDispatcher();

      assert(router.routerDelegate is AutoRouterDelegate);
      final autoRouterDelegate = (router.routerDelegate as AutoRouterDelegate);
      final parentData = RouteData.of(context);
      assert(parentData != null);
      RoutingController controller = autoRouterDelegate.controller.routerOfRoute(parentData);
      assert(controller != null);
      if (widget._isDeclarative) {
        _routes = controller.preMatchedRoutes;
        _routerDelegate = DeclarativeRouterDelegate(
          controller: controller,
          navigatorObservers: widget.navigatorObservers,
          routes: widget.onGenerateRoutes(context, _routes),
          onPopRoute: widget.onPopRoute,
          rootDelegate: autoRouterDelegate.rootDelegate,
        );
      } else {
        _routerDelegate = InnerRouterDelegate(
          controller: controller,
          builder: widget.builder,
          navigatorObservers: widget.navigatorObservers,
          defaultRoutes: controller.preMatchedRoutes,
          rootDelegate: autoRouterDelegate.rootDelegate,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = Router(
      routerDelegate: _routerDelegate,
      backButtonDispatcher: _backButtonDispatcher..takePriority(),
    );
    if (widget._isDeclarative) {
      return router;
    } else {
      return StackRouterScope(
        child: router,
        controller: _routerDelegate.controller,
      );
    }
  }

  @override
  void didUpdateWidget(covariant AutoRouter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget._isDeclarative) {
      var newRoutes = widget.onGenerateRoutes(context, _routes);
      if (!ListEquality().equals(newRoutes, _routes)) {
        _routes = newRoutes;
        (_routerDelegate as DeclarativeRouterDelegate).updateRoutes(newRoutes);
      }
    }
  }
}
