// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library unittest.runner.browser.host;

import 'dart:async';
import 'dart:convert';
import 'dart:html';

import 'package:stack_trace/stack_trace.dart';

import '../../util/multi_channel.dart';
import '../../util/stream_channel.dart';

void main() {
  runZoned(() {
    var serverChannel = _connectToServer();
    serverChannel.input.listen((message) {
      assert(message['command'] == 'loadSuite');
      var subChannel = serverChannel.createSubChannel(message['channel']);
      var iframeChannel = _connectToIframe(message['url']);

      iframeChannel.input.pipe(subChannel.output);
      subChannel.input.pipe(iframeChannel.output);
    });
  }, onError: (error, stackTrace) {
    print("$error\n${new Trace.from(stackTrace).terse}");
  });
}

MultiChannel _connectToServer() {
  var currentUrl = Uri.parse(window.location.href);
  var webSocketUrl = currentUrl
      .resolve(currentUrl.queryParameters['managerUrl'])
      .replace(scheme: 'ws');
  var webSocket = new WebSocket(webSocketUrl.toString());

  var inputController = new StreamController(sync: true);
  webSocket.onMessage.listen(
      (message) => inputController.add(JSON.decode(message.data)));

  var outputController = new StreamController(sync: true);
  outputController.stream.listen(
      (message) => webSocket.send(JSON.encode(message)));

  return new MultiChannel(inputController.stream, outputController.sink);
}

StreamChannel _connectToIframe(String url) {
  var iframe = new IFrameElement();
  iframe.src = url;
  document.body.children.add(iframe);

  var inputController = new StreamController(sync: true);
  var outputController = new StreamController(sync: true);
  iframe.onLoad.first.then((_) {
    // TODO(nweiz): use MessageChannel once Firefox supports it
    // (http://caniuse.com/#search=MessageChannel).

    // Send an initial command to give the iframe something to reply to.
    iframe.contentWindow.postMessage(
        {"command": "connect"},
        window.location.origin);

    window.onMessage.listen((message) {
      if (message.origin != window.location.origin) return;

      // TODO(nweiz): Stop manually checking href here once issue 22554 is fixed.
      if (message.data["href"] != iframe.src) return;

      message.stopPropagation();
      inputController.add(message.data["data"]);
    });

    outputController.stream.listen((message) =>
        iframe.contentWindow.postMessage(message, window.location.origin));
  });

  return new StreamChannel(inputController.stream, outputController.sink);
}
