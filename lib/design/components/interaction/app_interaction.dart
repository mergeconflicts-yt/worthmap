import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../theme/app_theme.dart';
import '../../tokens/tokens.g.dart';

/// DESIGN 13.2: shared focus, hover and keyboard activation for a control.
///
/// It makes a custom control behave like a real button:
/// - Tab and Shift+Tab reach it when [enabled]; a disabled control is not
///   focusable and cannot activate;
/// - Enter and Space activate it once (a held key repeats is consumed, not
///   re-fired);
/// - a focused control shows the `focus.ring` (2 px, offset 2);
/// - a hovered control shows the `surface.tile` hover tint.
///
/// Every tappable component uses this one implementation (AGENTS 11); no
/// component adds its own `GestureDetector` for activation.
class AppInteraction extends StatefulWidget {
  const AppInteraction({
    required this.onActivated,
    required this.child,
    this.enabled = true,
    this.borderRadius,
    this.cursor = SystemMouseCursors.click,
    this.hoverTint = true,
    super.key,
  });

  /// Called by a tap, Enter or Space when [enabled].
  final VoidCallback? onActivated;
  final Widget child;
  final bool enabled;

  /// The corner radius of the control, for the hover and focus shapes.
  final BorderRadius? borderRadius;

  final MouseCursor cursor;
  final bool hoverTint;

  @override
  State<AppInteraction> createState() => _AppInteractionState();
}

class _AppInteractionState extends State<AppInteraction> {
  late final FocusNode _focusNode = FocusNode(debugLabel: 'AppInteraction');
  bool _focused = false;
  bool _hovered = false;

  bool get _enabled => widget.enabled && widget.onActivated != null;

  @override
  void initState() {
    super.initState();
    _focusNode
      ..canRequestFocus = _enabled
      ..addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant AppInteraction oldWidget) {
    super.didUpdateWidget(oldWidget);
    _focusNode.canRequestFocus = _enabled;
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_onFocusChange)
      ..dispose();
    super.dispose();
  }

  void _onFocusChange() {
    final focused = _focusNode.hasFocus;
    if (focused != _focused) {
      setState(() => _focused = focused);
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!_enabled) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final isActivation = key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space;
    if (!isActivation) {
      return KeyEventResult.ignored;
    }
    // Activate on the first key down only; consume the repeat and the key up so
    // no other handler (for example an app-level shortcut) fires.
    if (event is KeyDownEvent) {
      widget.onActivated?.call();
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Focus(
      focusNode: _focusNode,
      canRequestFocus: _enabled,
      onKeyEvent: _onKey,
      child: MouseRegion(
        cursor: _enabled ? widget.cursor : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _enabled ? widget.onActivated : null,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              widget.child,
              if (_hovered && _enabled && widget.hoverTint)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: tokens.surfaceTile,
                        borderRadius: widget.borderRadius,
                      ),
                    ),
                  ),
                ),
              if (_focused && _enabled)
                Positioned(
                  left: -BorderTokens.focusRing,
                  top: -BorderTokens.focusRing,
                  right: -BorderTokens.focusRing,
                  bottom: -BorderTokens.focusRing,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: tokens.focusRing,
                          width: BorderTokens.focusRing,
                        ),
                        borderRadius: widget.borderRadius,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
