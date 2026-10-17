import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// DESIGN 2.11: one icon set (Lucide, ISC licence), stroke 1.75. Access only
/// through `AppIcons.*`. Colour comes from the component. Size comes from
/// `size.icon*` (DESIGN 2.7).
final class AppIconData {
  const AppIconData(this.asset);

  final String asset;
}

abstract final class AppIcons {
  const AppIcons._();

  static const String _base = 'lib/design/icons';

  static const AppIconData add = AppIconData('$_base/plus.svg');

  /// Tab bar Add uses stroke 2.2 (DESIGN 2.11).
  static const AppIconData addTabBar = AppIconData('$_base/plus-tab.svg');
  static const AppIconData mic = AppIconData('$_base/mic.svg');
  static const AppIconData scanQr = AppIconData('$_base/scan-qr-code.svg');
  static const AppIconData receipt = AppIconData('$_base/receipt.svg');
  static const AppIconData file = AppIconData('$_base/file.svg');
  static const AppIconData chevronRight =
      AppIconData('$_base/chevron-right.svg');
  static const AppIconData info = AppIconData('$_base/info.svg');
  static const AppIconData hide = AppIconData('$_base/eye-off.svg');
  static const AppIconData show = AppIconData('$_base/eye.svg');
  static const AppIconData inbox = AppIconData('$_base/inbox.svg');
  static const AppIconData settings = AppIconData(
    '$_base/sliders-horizontal.svg',
  );
  static const AppIconData tools = AppIconData('$_base/calculator.svg');
  static const AppIconData search = AppIconData('$_base/search.svg');
  static const AppIconData filter = AppIconData('$_base/funnel.svg');
  static const AppIconData import = AppIconData('$_base/import.svg');
  static const AppIconData lock = AppIconData('$_base/lock.svg');
  static const AppIconData shield = AppIconData('$_base/shield.svg');
  static const AppIconData trash = AppIconData('$_base/trash.svg');
  static const AppIconData edit = AppIconData('$_base/pencil.svg');
  static const AppIconData more = AppIconData('$_base/ellipsis.svg');
  static const AppIconData close = AppIconData('$_base/x.svg');
  static const AppIconData back = AppIconData('$_base/arrow-left.svg');
  static const AppIconData viewBubbles = AppIconData('$_base/circle-dot.svg');
  static const AppIconData viewList = AppIconData('$_base/list.svg');
  static const AppIconData viewTree = AppIconData('$_base/network.svg');
  static const AppIconData bank = AppIconData('$_base/landmark.svg');
  static const AppIconData chart = AppIconData('$_base/chart-line.svg');
  static const AppIconData card = AppIconData('$_base/credit-card.svg');
  static const AppIconData repeat = AppIconData('$_base/repeat.svg');
  static const AppIconData house = AppIconData('$_base/house.svg');
  static const AppIconData car = AppIconData('$_base/car.svg');
  static const AppIconData safe = AppIconData('$_base/vault.svg');

  /// Every icon, for the gallery.
  static const Map<String, AppIconData> all = <String, AppIconData>{
    'add': add,
    'addTabBar': addTabBar,
    'mic': mic,
    'scanQr': scanQr,
    'receipt': receipt,
    'file': file,
    'chevronRight': chevronRight,
    'info': info,
    'hide': hide,
    'show': show,
    'inbox': inbox,
    'settings': settings,
    'tools': tools,
    'search': search,
    'filter': filter,
    'import': import,
    'lock': lock,
    'shield': shield,
    'trash': trash,
    'edit': edit,
    'more': more,
    'close': close,
    'back': back,
    'viewBubbles': viewBubbles,
    'viewList': viewList,
    'viewTree': viewTree,
    'bank': bank,
    'chart': chart,
    'card': card,
    'repeat': repeat,
    'house': house,
    'car': car,
    'safe': safe,
  };
}

/// Draws one [AppIconData] at [size] in [color] with a required semantic label
/// when the icon carries meaning (AGENTS 6.9).
class AppIcon extends StatelessWidget {
  const AppIcon({
    required this.data,
    required this.size,
    required this.color,
    this.semanticLabel,
    super.key,
  });

  final AppIconData data;
  final double size;
  final Color color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final picture = SvgPicture.asset(
      data.asset,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
    final label = semanticLabel;
    if (label == null) {
      return ExcludeSemantics(child: picture);
    }
    return Semantics(label: label, child: picture);
  }
}
