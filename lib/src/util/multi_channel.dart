// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library unittest.multi_channel;

import 'dart:async';

import 'stream_channel.dart';

abstract class MultiChannel implements StreamChannel {
  Stream get input;
  StreamSink get output;

  factory MultiChannel(Stream input, StreamSink output) =>
      new _MultiChannel(input, output);

  SubChannel createSubChannel([id]);
}

class _MultiChannel implements MultiChannel {
  final Stream _innerInput;
  final StreamSink _innerOutput;

  Stream get input => _inputController.stream;
  final _inputController = new StreamController(sync: true);

  StreamSink get output => _outputController.sink;
  final _outputController = new StreamController(sync: true);

  final _inputs = new Map<int, StreamSink>();

  var _nextId = 1;

  _MultiChannel(this._innerInput, this._innerOutput) {
    _inputs[0] = _inputController.sink;
    _outputController.stream.listen((message) {
      _innerOutput.add([0, message]);
    });

    _innerInput.listen((message) {
      assert(_inputs.containsKey(message[0]));
      _inputs[message[0]].add(message[1]);
    });
  }

  SubChannel createSubChannel([id]) {
    var inputId;
    var outputId;
    if (id != null) {
      // Since the user is passing in an id, we're connected to a remote
      // SubChannel. This means messages they send over this channel will have
      // the original odd id, but our replies will have an even id.
      inputId = id;
      outputId = (id as int) + 1;
    } else {
      // Since we're generating an id, we originated this SubChannel. This means
      // messages we send over this channel will have the original odd id, but
      // the remote channel's replies will have an even id.
      inputId = _nextId + 1;
      outputId = _nextId;
      _nextId += 2;
    }

    var inputController = new StreamController(sync: true);
    var outputController = new StreamController(sync: true);
    _inputs[inputId] = inputController.sink;
    outputController.stream.listen((message) =>
        _innerOutput.add([outputId, message]));

    return new SubChannel._(
        this, outputId, inputController.stream, outputController.sink);
  }
}

class SubChannel implements MultiChannel {
  final MultiChannel _parent;
  final id;
  final Stream input;
  final StreamSink output;

  SubChannel._(this._parent, this.id, this.input, this.output);

  SubChannel createSubChannel([id]) => _parent.createSubChannel(id);
}
