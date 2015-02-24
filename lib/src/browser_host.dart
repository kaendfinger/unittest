// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library unittest.browser_host;

import 'dart:async';
import 'dart:convert';
import 'dart:html';

import 'multi_channel.dart';
import 'stream_channel.dart';

void main() {
  runZoned(() {
    var serverChannel = _connectToServer();
    serverChannel.input.listen((message) {
      assert(message['command'] == 'loadSuite');
      var subChannel = serverChannel.createSubChannel(message['channel']);
      var iframeChannel = _connectToIframe(message['url']);

      iframeChannel.input.listen((data) {
        print("[if -> ws] $data");
        subChannel.output.add(data);
      });
      subChannel.input.listen((data) {
        print("[ws -> if] $data");
        iframeChannel.output.add(data);
      });
    });
  }, onError: (error, stackTrace) {
    print("$error\n$stackTrace");
  });
}

MultiChannel _connectToServer() {
  var currentUrl = Uri.parse(window.location.href);
  var webSocketUrl = currentUrl
      .resolve(currentUrl.queryParameters['managerUrl'])
      .replace(scheme: 'ws');
  var webSocket = new WebSocket(webSocketUrl.toString());

  var inputController = new StreamController(sync: true);
  webSocket.onMessage.listen((message) {
    print("[outer ws] incoming message: ${message.data}");
    inputController.add(JSON.decode(message.data));
  });

  var outputController = new StreamController(sync: true);
  outputController.stream.listen((message) {
    print("[outer ws] outgoing message: $message");
    webSocket.send(JSON.encode(message));
  });

  return new MultiChannel(inputController.stream, outputController.sink);
}

StreamChannel _connectToIframe(String url) {
  var iframe = new IFrameElement();
  iframe.src = url;
  document.body.children.add(iframe);

  var inputController = new StreamController(sync: true);
  var outputController = new StreamController(sync: true);
  iframe.onLoad.first.then((_) {
    // TODO: use MessageChannel?

    print("iframe onload, posting message");
    // Send an initial command to give the iframe something to reply to.
    iframe.contentWindow.postMessage(
        {"command": "connect"},
        window.location.origin);

    window.onMessage.listen((message) {
      // TODO: ensure that this message is coming from the correct iframe
      print("[outer pm] incoming message: ${message.data}");
      message.stopPropagation();
      inputController.add(message.data);
    });

    outputController.stream.listen((message) {
      print("[outer pm] outgoing message: $message");
      iframe.contentWindow.postMessage(message, window.location.origin);
    });
  });

  return new StreamChannel(inputController.stream, outputController.sink);
}
