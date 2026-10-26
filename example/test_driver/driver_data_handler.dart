import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show InkWell;

/// Handles `requestData` messages from `flutter_driver`.
///
/// Dropdown items stay mounted inside an [IndexedStack], and the open menu
/// mounts a second copy. Value keys on those items are therefore not unique
/// while the menu is open. Popup helpers below target only the copy that lives
/// on a [PopupRoute].
Future<String> driverDataHandler(String? message) async {
  if (message == null || message.isEmpty || message == 'ping') {
    return 'ok';
  }
  if (message.startsWith('exists:')) {
    return _findByValueKey(message.substring('exists:'.length)) != null
        ? 'yes'
        : 'no';
  }
  if (message.startsWith('count:')) {
    return '${_countValueKey(message.substring('count:'.length))}';
  }
  if (message.startsWith('text:')) {
    final Element? element = _findByValueKey(message.substring('text:'.length));
    return element == null ? '' : _collectText(element);
  }
  if (message.startsWith('visibleText:')) {
    final Element? element = _findByValueKey(
      message.substring('visibleText:'.length),
    );
    return element == null ? '' : _visibleText(element);
  }
  if (message.startsWith('existsText:')) {
    return _containsText(message.substring('existsText:'.length))
        ? 'yes'
        : 'no';
  }
  if (message.startsWith('popupText:')) {
    return _findPopupText(message.substring('popupText:'.length)) == null
        ? 'no'
        : 'yes';
  }
  if (message.startsWith('tapPopupText:')) {
    final String text = message.substring('tapPopupText:'.length);
    final DateTime deadline = DateTime.now().add(const Duration(seconds: 3));
    Element? label;
    while (DateTime.now().isBefore(deadline)) {
      label = _findPopupText(text);
      final Element? target = label == null ? null : _tappableAncestor(label);
      if (target != null && _isHitTestable(target)) {
        await _tapElement(target);
        return 'tapped';
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    return label == null ? 'missing' : 'not-hit-testable';
  }
  return 'unknown';
}

final Stopwatch _clock = Stopwatch()..start();
int _nextPointer = 1;

Element? _root() => WidgetsBinding.instance.rootElement;

Element? _findByValueKey(String key) {
  final Element? root = _root();
  if (root == null) {
    return null;
  }
  final ValueKey<String> needle = ValueKey<String>(key);
  Element? match;
  void visit(Element element) {
    if (match != null) {
      return;
    }
    if (element.widget.key == needle) {
      match = element;
      return;
    }
    element.visitChildren(visit);
  }

  visit(root);
  return match;
}

int _countValueKey(String key) {
  final Element? root = _root();
  if (root == null) {
    return 0;
  }
  final ValueKey<String> needle = ValueKey<String>(key);
  var count = 0;
  void visit(Element element) {
    if (element.widget.key == needle) {
      count += 1;
    }
    element.visitChildren(visit);
  }

  visit(root);
  return count;
}

String _collectText(Element root) {
  String? editable;
  final List<String> texts = <String>[];
  void visit(Element element) {
    final Widget widget = element.widget;
    if (widget is EditableText) {
      editable ??= widget.controller.text;
    } else if (widget is Text && widget.data != null) {
      texts.add(widget.data!);
    }
    element.visitChildren(visit);
  }

  visit(root);
  if (editable != null) {
    return editable!;
  }
  return texts.join('\n');
}

String _visibleText(Element root) {
  final List<String> texts = <String>[];
  void visit(Element element) {
    if (!_isShownByIndexedStacks(element)) {
      return;
    }
    final Widget widget = element.widget;
    if (widget is Text && widget.data != null && widget.data!.isNotEmpty) {
      texts.add(widget.data!);
      return;
    }
    element.visitChildren(visit);
  }

  visit(root);
  return texts.join('\n');
}

bool _isShownByIndexedStacks(Element element) {
  var shown = true;
  element.visitAncestorElements((Element ancestor) {
    final RenderObject? render = ancestor.renderObject;
    if (render is RenderIndexedStack &&
        !_isUnderIndexedChild(element, render)) {
      shown = false;
      return false;
    }
    return true;
  });
  return shown;
}

bool _isUnderIndexedChild(Element element, RenderIndexedStack stack) {
  final int? index = stack.index;
  if (index == null || index < 0) {
    return false;
  }
  RenderBox? child = stack.firstChild;
  for (var i = 0; i < index; i++) {
    if (child == null) {
      return false;
    }
    child = stack.childAfter(child);
  }
  if (child == null) {
    return false;
  }
  RenderObject? node = element.renderObject;
  while (node != null && node != stack) {
    if (identical(node, child)) {
      return true;
    }
    node = node.parent;
  }
  return false;
}

bool _containsText(String needle) {
  final Element? root = _root();
  if (root == null || needle.isEmpty) {
    return false;
  }
  var found = false;
  void visit(Element element) {
    if (found) {
      return;
    }
    final Widget widget = element.widget;
    if (widget is Text &&
        widget.data != null &&
        widget.data!.contains(needle)) {
      found = true;
      return;
    }
    element.visitChildren(visit);
  }

  visit(root);
  return found;
}

/// Menu rows fade in for most of the route animation. A tap during that
/// window lands on the modal barrier and dismisses the menu without selecting.
Element? _tappableAncestor(Element element) {
  final ModalRoute<dynamic>? route = ModalRoute.of(element);
  if (route?.animation?.status != AnimationStatus.completed) {
    return null;
  }
  Element? inkWell;
  element.visitAncestorElements((Element ancestor) {
    if (ancestor.widget is InkWell) {
      inkWell = ancestor;
      return false;
    }
    return ancestor.widget is! Overlay;
  });
  return inkWell ?? element;
}

/// True only when [element]'s box is the hit target or an ancestor of it.
///
/// The overlay itself is always on the hit path, so treating every ancestor
/// as a successful hit taps the barrier instead of the menu row.
bool _isHitTestable(Element element) {
  final RenderObject? renderObject = element.renderObject;
  if (renderObject is! RenderBox ||
      !renderObject.attached ||
      !renderObject.hasSize ||
      renderObject.size.isEmpty) {
    return false;
  }
  final Offset position = renderObject.localToGlobal(
    renderObject.size.center(Offset.zero),
  );
  final HitTestResult result = HitTestResult();
  RendererBinding.instance.hitTestInView(
    result,
    position,
    View.of(element).viewId,
  );
  for (final HitTestEntry entry in result.path) {
    if (_isAncestorOfHitTarget(renderObject, entry.target)) {
      return true;
    }
  }
  return false;
}

bool _isAncestorOfHitTarget(RenderObject ancestor, HitTestTarget target) {
  if (identical(target, ancestor)) {
    return true;
  }
  if (target is! RenderObject) {
    return false;
  }
  for (
    RenderObject? current = target.parent;
    current != null;
    current = current.parent
  ) {
    if (identical(current, ancestor)) {
      return true;
    }
  }
  return false;
}

Element? _findPopupText(String text) {
  final Element? root = _root();
  if (root == null) {
    return null;
  }
  Element? match;
  var matches = 0;
  void visit(Element element) {
    final Widget widget = element.widget;
    if (widget is Text && widget.data == text) {
      final ModalRoute<dynamic>? route = ModalRoute.of(element);
      if (route is PopupRoute<dynamic>) {
        matches += 1;
        match ??= element;
      }
    }
    element.visitChildren(visit);
  }

  visit(root);
  return matches == 1 ? match : null;
}

Future<void> _tapElement(Element element) async {
  final RenderObject? renderObject = element.renderObject;
  if (renderObject is! RenderBox || !renderObject.hasSize) {
    return;
  }
  final Offset position = renderObject.localToGlobal(
    renderObject.size.center(Offset.zero),
  );
  final int pointer = _nextPointer++;
  final int viewId = View.of(element).viewId;
  GestureBinding.instance.handlePointerEvent(
    PointerDownEvent(
      viewId: viewId,
      timeStamp: _clock.elapsed,
      pointer: pointer,
      kind: PointerDeviceKind.touch,
      position: position,
      buttons: kPrimaryButton,
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 50));
  GestureBinding.instance.handlePointerEvent(
    PointerUpEvent(
      viewId: viewId,
      timeStamp: _clock.elapsed,
      pointer: pointer,
      kind: PointerDeviceKind.touch,
      position: position,
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 50));
}
