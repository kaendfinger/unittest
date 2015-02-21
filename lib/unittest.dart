// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library unittest;

import 'dart:async';

import 'package:path/path.dart' as p;

import 'src/declarer.dart';
import 'src/console_reporter.dart';
import 'src/invoker.dart';
import 'src/suite.dart';

export 'package:matcher/matcher.dart'
    hide
        completes,
        completion,
        configureExpectFailureHandler,
        DefaultFailureHandler,
        ErrorFormatter,
        expect,
        fail,
        FailureHandler,
        getOrCreateExpectFailureHandler,
        prints,
        TestFailure,
        Throws,
        throws,
        throwsA,
        throwsArgumentError,
        throwsConcurrentModificationError,
        throwsCyclicInitializationError,
        throwsException,
        throwsFormatException,
        throwsNoSuchMethodError,
        throwsNullThrownError,
        throwsRangeError,
        throwsStateError,
        throwsUnimplementedError,
        throwsUnsupportedError;

export 'src/expect.dart';
export 'src/expect_async.dart';
export 'src/future_matchers.dart';
export 'src/prints_matcher.dart';
export 'src/throws_matcher.dart';
export 'src/throws_matchers.dart';

/// The global declarer.
///
/// This is used if a test file is run directly, rather than through the runner.
Declarer _globalDeclarer;

/// Gets the declarer for the current scope.
///
/// When using the runner, this returns the [Zone]-scoped declarer that's set by
/// [VmListener]. If the test file is run directly, this returns
/// [_globalDeclarer] (and sets it up on the first call).
Declarer get _declarer {
  var declarer = Zone.current[#unittest.declarer];
  if (declarer != null) return declarer;
  if (_globalDeclarer != null) return _globalDeclarer;

  // Since there's no Zone-scoped declarer, the test file is being run directly.
  // In order to run the tests, we set up our own Declarer via
  // [_globalDeclarer], and schedule a microtask to run the tests once they're
  // finished being defined.
  _globalDeclarer = new Declarer();
  scheduleMicrotask(() {
    var suite = new Suite(p.prettyUri(Uri.base), _globalDeclarer.tests);
    // TODO(nweiz): Use a reporter that doesn't import dart:io here.
    // TODO(nweiz): Set the exit code on the VM when issue 6943 is fixed.
    new ConsoleReporter([suite]).run();
  });
  return _globalDeclarer;
}

// TODO(nweiz): This and other top-level functions should throw exceptions if
// they're called after the declarer has finished declaring.
void test(String description, body()) => _declarer.test(description, body);

void group(String description, void body()) =>
    _declarer.group(description, body);

void setUp(callback()) => _declarer.setUp(callback);

void tearDown(callback()) => _declarer.tearDown(callback);

/// Handle an error that occurs outside of any test.
void handleExternalError(error, String message, [stackTrace]) {
  // TODO(nweiz): handle this better.
  registerException(error, stackTrace);
}

/// Registers an exception that was caught for the current test.
void registerException(error, [StackTrace stackTrace]) =>
    Invoker.current.handleError(error, stackTrace);
