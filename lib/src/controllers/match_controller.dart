import '../../qlevar_router.dart';
import '../routes/qroute_children.dart';
import '../routes/qroute_internal.dart';
import 'middleware_controller.dart';

class MatchController {
  final Uri path;
  final QRouteChildren routes;
  String foundPath;
  final params = QParams();
  MatchController(String sPath, this.foundPath, this.routes)
      : path = Uri.parse(sPath) {
    QR.log('Finding Match for $sPath');
  }

  factory MatchController.fromName(String name, QRouteChildren routes) {
    final path = QR.treeInfo.namePath[name];
    if (path == null) {
      throw Exception('Route with name $name was not found in the tree info');
    }
    return MatchController(path, '', routes);
  }

  void updateFoundPath(String segment) {
    foundPath += "/$segment";
    if (path.pathSegments.isNotEmpty &&
        path.pathSegments.last == segment &&
        path.hasQuery) {
      foundPath += '?${path.query}';
      params.addAll(path.queryParameters);
    }
  }

  QRouteInternal get match {
    var searchIn = routes;
    if (path.pathSegments.isEmpty) {
      final match = _tryFind(searchIn, '')!;
      return match;
    }

    final result = _tryFind(searchIn, path.pathSegments[0]);
    if (result == null) {
      return QRouteInternal.notfound();
    }
    var match = result;
    for (var i = 1; i < path.pathSegments.length; i++) {
      searchIn = match.children!;
      match.child = _tryFind(searchIn, path.pathSegments[i]);
      if (match.child == null) {
        return QRouteInternal.notfound();
      }
      match = match.child!;
    }
    return result;
  }

  QRouteInternal? _tryFind(QRouteChildren routes, String path) {
    bool find(QRouteInternal route) => '/$path' == route.route.path;

    bool findComponent(QRouteInternal route) {
      var routePath = route.route.path;
      if (routePath.startsWith('/:')) {
        final name = routePath.replaceAll('/:', '');
        params[name] = path;
        return true;
      }
      return false;
    }

    QRouteInternal? result;
    if (routes.routes.any(find)) {
      result = routes.routes.firstWhere(find);
    }
    // try find component
    else if (routes.routes.any(findComponent)) {
      result = routes.routes.firstWhere(findComponent);
    }

    if (result != null) {
      updateFoundPath(path);
      result.clean();
      result.activePath = foundPath;
      result.params = params.copyWith();
      MiddlewareController(result).runOnMatch();
      return result;
    }

    QR.log('[$path] is not child of ${routes.parentKey}');
    return null;
  }
}
