// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library unittest.runner.browser.server;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';

import '../../backend/suite.dart';
import '../../util/dart.dart' as dart;
import '../../util/io.dart';
import '../../util/one_off_handler.dart';
import 'browser_manager.dart';
import 'chrome.dart';

class BrowserServer {
  static Future<BrowserServer> start({String packageRoot}) {
    var server = new BrowserServer._(packageRoot);
    return server._load().then((_) => server);
  }

  final _oneOffHandler = new OneOffHandler();

  HttpServer _server;

  Uri get url => baseUrlForAddress(_server.address, _server.port);

  final String _compiledDir;

  final String _packageRoot;

  Chrome _browser;

  Future<BrowserManager> get _browserManager {
    if (_browserManagerCompleter == null) {
      _browserManagerCompleter = new Completer();
      var path = _oneOffHandler.create(webSocketHandler((webSocket) {
        _browserManagerCompleter.complete(new BrowserManager(webSocket));
      }));

      _browser = new Chrome(url.resolve(
          "?managerUrl=/one-off/${Uri.encodeQueryComponent(path)}"));
      _browser.onExit.catchError((error, stackTrace) {
        if (_browserManagerCompleter.isCompleted) return;
        _browserManagerCompleter.completeError(error, stackTrace);
      });
    }
    return _browserManagerCompleter.future;
  }
  Completer<BrowserManager> _browserManagerCompleter;

  BrowserServer._(this._packageRoot)
      : _compiledDir = Directory.systemTemp.createTempSync('unittest_').path;

  Future _load() {
    return shelf_io.serve(_onRequest, 'localhost', 0).then((server) {
      _server = server;
    });
  }

  Future<Suite> loadSuite(String path) {
    return _compileDart(path).then((compiledPath) {
      return _browserManager.then((browserManager) {
        var scriptPath = _oneOffHandler.create((request) {
          // TODO: check request method
          if (request.url.path != '/') return new shelf.Response.notFound(null);

          return new shelf.Response.ok(
              new File(compiledPath).openRead(),
              headers: {'content-type': 'application/javascript'});
        });

        var htmlPath = _oneOffHandler.create((request) {
          // TODO: check request method
          if (request.url.path != '/') return new shelf.Response.notFound(null);

          return new shelf.Response.ok('''
<!DOCTYPE html>
<html>
<head>
  <title>${HTML_ESCAPE.convert(path)} Test</title>
  <script src="/one-off/${HTML_ESCAPE.convert(scriptPath)}"></script>
</head>
</html>
''', headers: {'content-type': 'text/html'});
        });

        return browserManager.loadSuite(
            path, url.resolve('/one-off/$htmlPath'));
      });
    });
  }

  _onRequest(shelf.Request request) {
    // Skip the first component because it's always "/".
    var components = p.url.split(request.url.path).skip(1);

    if (request.url.path == "/" || request.url.path == "/index.html") {
      var path = p.join(libDir, 'src/runner/browser/host.html');
      return new shelf.Response.ok(
          new File(path).openRead(),
          headers: {'content-type': 'text/html'});
    } else if (request.url.path == "/index.js") {
      // TODO: check request method
      var path = p.join(libDir, 'src/runner/browser/host.dart.js');
      return new shelf.Response.ok(
          new File(path).openRead(),
          headers: {'content-type': 'application/javascript'});
    }

    if (components.first != 'one-off') return new shelf.Response.notFound(null);

    var url = request.url.replace(
        path: "/" + p.url.joinAll(components.skip(1)));
    return _oneOffHandler.handler(request.change(url: url));
  }

  Future<String> _compileDart(String path) {
    print("Compiling $path...");
    var dir = new Directory(_compiledDir).createTempSync('test_').path;
    var output = p.join(dir, p.basename(path) + ".js");
    return dart.compile('''
import "package:unittest/src/runner/browser/iframe_listener.dart";

import "${p.toUri(p.absolute(path))}" as test;

void main(_) {
  BrowserListener.start(() => test.main);
}
''', output, packageRoot: packageRootFor(path, _packageRoot))
        .then((_) => output);
  }

  Future close() {
    new Directory(_compiledDir).deleteSync(recursive: true);
    return _server.close().then((_) {
      if (_browserManagerCompleter == null) return;
      return _browserManager.then((_) => _browser.close());
    });
  }
}
