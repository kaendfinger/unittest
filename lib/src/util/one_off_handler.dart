// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library unittest.one_off_handler;

import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart' as shelf;

class OneOffHandler {
  final _handlers = new Map<int, shelf.Handler>();
  var _counter = 0;

  shelf.Handler get handler => _onRequest;

  String create(shelf.Handler handler) {
    _handlers[_counter] = handler;
    var path = _counter.toString();
    _counter++;
    return path;
  }

  _onRequest(shelf.Request request) {
    // Skip the first component because it's always "/".
    var components = p.url.split(request.url.path).skip(1).toList();
    if (components.isEmpty) return new shelf.Response.notFound(null);

    var first = components.removeAt(0);
    var number;
    try {
      number = int.parse(first);
    } on FormatException catch (_) {
      return new shelf.Response.notFound(null);
    }

    var handler = _handlers[number];
    if (handler == null) return new shelf.Response.notFound(null);

    var url = request.url.replace(path: "/" + p.url.joinAll(components));
    return handler(request.change(url: url));
  }
}
