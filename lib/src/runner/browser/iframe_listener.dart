// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library unittest.runner.browser.iframe_listener;

import 'dart:async';
import 'dart:html';

import '../../backend/declarer.dart';
import '../../backend/suite.dart';
import '../../backend/test.dart';
import '../../util/multi_channel.dart';
import '../../util/remote_exception.dart';
import '../../utils.dart';

class IframeListener {
  /// The test suite to run.
  final Suite _suite;

  static void start(Function getMain()) {
    var channel = _postMessageChannel();

    var main;
    try {
      main = getMain();
    } on NoSuchMethodError catch (_) {
      _sendLoadException(channel, "No top-level main() function defined.");
      return;
    }

    if (main is! Function) {
      _sendLoadException(channel, "Top-level main getter is not a function.");
      return;
    } else if (main is! AsyncFunction) {
      _sendLoadException(channel, "Top-level main() function takes arguments.");
      return;
    }

    var declarer = new Declarer();
    try {
      runZoned(main, zoneValues: {#unittest.declarer: declarer});
    } catch (error, stackTrace) {
      channel.output.add({
        "type": "error",
        "error": RemoteException.serialize(error, stackTrace)
      });
      return;
    }

    new BrowserListener._(new Suite("BrowserListener", declarer.tests))
        ._listen(channel);
  }

  static MultiChannel _postMessageChannel() {
    var inputController = new StreamController(sync: true);
    var outputController = new StreamController(sync: true);

    var first = true;
    window.onMessage.listen((message) {
      if (message.origin != window.location.origin) return;
      message.stopPropagation();

      if (first) {
        outputController.stream.listen((data) {
          message.source.postMessage(data, window.location.origin);
        });
        first = false;
      } else {
        inputController.add(message.data);
      }
    });

    return new MultiChannel(inputController.stream, outputController.sink);
  }

  static void _sendLoadException(MultiChannel channel, String message) {
    channel.output.add({"type": "loadException", "message": message});
  }

  BrowserListener._(this._suite);

  void _listen(MultiChannel channel) {
    var tests = [];
    for (var i = 0; i < _suite.tests.length; i++) {
      var test = _suite.tests[i];
      var testChannel = channel.createSubChannel();
      tests.add({"name": test.name, "channel": testChannel.id});

      testChannel.input.listen((message) {
        assert(message['command'] == 'run');
        _runTest(test, channel.createSubChannel(message['channel']));
      });
    }

    channel.output.add({
      "type": "success",
      "tests": tests
    });
  }

  /// Runs [test] and send the results across [sendPort].
  void _runTest(Test test, MultiChannel channel) {
    var liveTest = test.load(_suite);

    liveTest.onStateChange.listen((state) {
      channel.output.add({
        "type": "state-change",
        "status": state.status.name,
        "result": state.result.name
      });
    });

    liveTest.onError.listen((asyncError) {
      channel.output.add({
        "type": "error",
        "error": RemoteException.serialize(
            asyncError.error, asyncError.stackTrace)
      });
    });

    liveTest.run().then((_) => channel.output.add({"type": "complete"}));
  }
}
