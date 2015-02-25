// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library unittest.runner.browser.browser_manager;

import 'dart:async';
import 'dart:convert';

import 'package:http_parser/http_parser.dart';

import '../../backend/suite.dart';
import '../../util/multi_channel.dart';
import '../../util/remote_exception.dart';
import '../../utils.dart';
import '../load_exception.dart';
import 'browser_test.dart';

class BrowserManager {
  final MultiChannel _channel;

  BrowserManager(CompatibleWebSocket webSocket)
      : _channel = new MultiChannel(
          webSocket.map(JSON.decode),
          transformSink(webSocket, JSON.encoder));

  Future<Suite> loadSuite(String path, Uri url) {
    var suiteChannel = _channel.virtualChannel();
    _channel.sink.add({
      "command": "loadSuite",
      "url": url.toString(),
      "channel": suiteChannel.id
    });

    // Create a nested MultiChannel because the iframe will be using a channel
    // wrapped within the host's channel.
    suiteChannel = new MultiChannel(suiteChannel.stream, suiteChannel.sink);
    return suiteChannel.stream.first.then((response) {
      if (response["type"] == "loadException") {
        return new Future.error(new LoadException(path, response["message"]));
      } else if (response["type"] == "error") {
        var asyncError = RemoteException.deserialize(response["error"]);
        return new Future.error(
            new LoadException(path, asyncError.error),
            asyncError.stackTrace);
      }

      return new Suite(path, response["tests"].map((test) {
        var testChannel = suiteChannel.virtualChannel(test['channel']);
        return new BrowserTest(test['name'], testChannel);
      }));
    });
  }
}
