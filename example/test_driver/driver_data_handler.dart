import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

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
    final Element? target = _findPopupText(
      message.substring('tapPopupText:'.length),
    );
    if (target == null) {
      return 'missing';
    }
    await _tapElement(target);
    return 'tapped';
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
  GestureBinding.instance.handlePointerEvent(
    PointerDownEvent(
      timeStamp: _clock.elapsed,
      pointer: pointer,
      kind: PointerDeviceKind.mouse,
      position: position,
      buttons: kPrimaryButton,
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 40));
  GestureBinding.instance.handlePointerEvent(
    PointerUpEvent(
      timeStamp: _clock.elapsed,
      pointer: pointer,
      kind: PointerDeviceKind.mouse,
      position: position,
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 40));
}
