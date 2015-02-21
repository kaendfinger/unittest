// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library unittest.group;

import 'dart:async';

import 'utils.dart';

/// A group contains multiple tests and subgroups.
///
/// A group has a description that is prepended to that of all nested tests and
/// subgroups. It also has [setUp] and [tearDown] functions which are scoped to
/// the tests and groups it contains.
class Group {
  /// The parent group, or `null` if this is the root group.
  final Group parent;

  /// The description of the current test group, or `null` if this is the root
  /// group.
  final String _description;

  /// The set-up function for this group, or `null`.
  AsyncFunction setUp;

  /// The tear-down function for this group, or `null`.
  AsyncFunction tearDown;

  /// Returns the description for this group, including the description of any
  /// parent groups.
  ///
  /// If this is the root group, returns `null`.
  String get description {
    if (parent == null || parent.description == null) return _description;
    return "${parent.description} $_description";
  }

  /// Creates a new root group.
  ///
  /// This is the implicit group that exists outside of any calls to `group()`.
  Group.root() : this(null, null);

  Group(this.parent, this._description);

  /// Run the set-up functions for this and any parent groups.
  ///
  /// If no set-up functions are declared, this returns a [Future] that
  /// completes immediately.
  Future runSetUp() async {
    if (parent != null) {
      await parent.runSetUp();
    }

    if (setUp != null) await setUp();
  }

  /// Run the tear-up functions for this and any parent groups.
  ///
  /// If no set-up functions are declared, this returns a [Future] that
  /// completes immediately.
  Future runTearDown() async {
    if (tearDown != null) await tearDown();

    if (parent != null) {
      await parent.runTearDown();
    }
  }
}
