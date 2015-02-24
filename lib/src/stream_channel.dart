// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library unittest.stream_channel;

import 'dart:async';

class StreamChannel {
  final Stream input;
  final StreamSink output;

  StreamChannel(this.input, this.output);
}
