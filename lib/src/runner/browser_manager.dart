// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library unittest.browser_manager;

import 'dart:async';
import 'dart:convert';

import 'package:http_parser/http_parser.dart';

import '../backend/suite.dart';
import '../util/multi_channel.dart';
import '../util/remote_exception.dart';
import '../utils.dart';
import 'browser_test.dart';
import 'load_exception.dart';

class BrowserManager {
  final MultiChannel _channel;

  BrowserManager(CompatibleWebSocket webSocket)
      : _channel = new MultiChannel(
          webSocket.map(JSON.decode),
          transformSink(webSocket, JSON.encoder));

  Future<Suite> loadSuite(String path, Uri url) {
    var suiteChannel = _channel.createSubChannel();
    _channel.output.add({
      "command": "loadSuite",
      "url": url.toString(),
      "channel": suiteChannel.id
    });

    // Create a nested MultiChannel because the iframe will be using a channel
    // wrapped within the host's channel.
    suiteChannel = new MultiChannel(suiteChannel.input, suiteChannel.output);
    return suiteChannel.input.first.then((response) {
      if (response["type"] == "loadException") {
        return new Future.error(new LoadException(path, response["message"]));
      } else if (response["type"] == "error") {
        var asyncError = RemoteException.deserialize(response["error"]);
        return new Future.error(
            new LoadException(path, asyncError.error),
            asyncError.stackTrace);
      }

      return new Suite(path, response["tests"].map((test) {
        var testChannel = suiteChannel.createSubChannel(test['channel']);
        return new BrowserTest(test['name'],
            suiteChannel.createSubChannel(test['channel']));
      }));
    });
  }
}
