// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// TODO(nweiz): move this into its own package?
library unittest.browser_controller;

import 'dart:async';
import 'dart:io';

// TODO(nweiz): support other browsers.
class Chrome {
  Process _process;

  String _dir;

  Future get onExit => _onExitCompleter.future;
  final _onExitCompleter = new Completer();

  Chrome(url) {
    Directory.systemTemp.createTemp().then((dir) {
      _dir = dir.path;
      Process.start("google-chrome", [
        "--user-data-dir=$_dir",
        url.toString(),
        "--disable-extensions",
        "--disable-popup-blocking",
        "--bwsi",
        "--no-first-run"
      ]).then((process) {
        _process = process;
        _process.stdout.listen(stdout.add);
        _process.stderr.listen(stderr.add);

        _process.exitCode.then((exitCode) {
          if (exitCode == 0) {
            _onExitCompleter.complete();
          } else {
            _onExitCompleter.completeError(
                "Chrome failed with exit code $exitCode");
          }
        });
      });
    });
  }
}
