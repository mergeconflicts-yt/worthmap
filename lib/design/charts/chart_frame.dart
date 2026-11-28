import 'package:flutter/widgets.dart';

import '../../l10n/generated/app_localizations.dart';
import '../components/interaction/app_interaction.dart';
import '../theme/app_theme.dart';
import '../tokens/space.dart';
import '../tokens/tokens.g.dart';
import '../typography/app_text.dart';

/// DESIGN 7.1: the exact values of a chart, as rows.
///
/// The rows use the same values as the chart marks and the same order. A
/// column list is required; the first column is the row name and the rest are
/// right-aligned values.
class ChartTable extends StatelessWidget {
  const ChartTable({
    required this.columns,
    required this.rows,
    this.emptyLabel,
    super.key,
  });

  final List<String> columns;

  /// One row per chart group, in reading order. Cells are already formatted by
  /// the caller (amounts go through `lib/design/format/`).
  final List<List<String>> rows;

  /// Shown in the body when [rows] is empty, for example "None recorded".
  final String? emptyLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final body = rows.isEmpty
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.s),
            child: Text(
              emptyLabel ?? '',
              style: AppText.caption.copyWith(color: tokens.textSecondary),
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (final row in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Space.xxs),
                  child: _row(
                    row,
                    style: AppText.caption.copyWith(color: tokens.textPrimary),
                  ),
                ),
            ],
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _row(
          columns,
          style: AppText.labelCaps.copyWith(color: tokens.textSecondary),
        ),
        const VSpace(Space.xxs),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: tokens.borderDivider, width: 1),
            ),
          ),
          child: body,
        ),
      ],
    );
  }

  Widget _row(List<String> cells, {required TextStyle style}) {
    if (cells.isEmpty) {
      return const SizedBox.shrink();
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(flex: 3, child: Text(cells.first, style: style)),
        for (final cell in cells.skip(1))
          Expanded(
            flex: 2,
            child: Text(
              cell,
              style: style,
              textAlign: TextAlign.end,
            ),
          ),
      ],
    );
  }
}

/// DESIGN 7.1: every chart sits in a `ChartFrame`.
///
/// The frame supplies one accessible name, the "Show as table" disclosure and
/// the exact [ChartTable]. The chart itself is excluded from semantics, so the
/// reader hears one label, not the axis text.
///
/// A preview chart (`preview: true`) has no table: its label keeps the exact
/// values and the chart opens the full chart (PREVIEW-CHART).
class ChartFrame extends StatefulWidget {
  const ChartFrame({
    required this.label,
    required this.chart,
    this.table,
    this.preview = false,
    this.showTable = false,
    this.emptyLabel,
    this.tableLabel,
    this.initiallyOpen = false,
    super.key,
  });

  /// The one accessible name: what, period and the exact values in reading
  /// order. In the hidden state the caller masks the amounts.
  final String label;

  /// The painted chart. Its own semantics are excluded.
  final Widget chart;

  /// The exact rows. Required unless [preview] is true.
  final ChartTable? table;

  /// PREVIEW-CHART: no table, label only.
  final bool preview;

  /// Shows the "Show as table" disclosure. Off for every screen by default
  /// (owner decision, 2026-11-28): the spoken label carries the exact values.
  /// A component demo can turn it on.
  final bool showTable;

  /// The phrase for an empty table, for example "None recorded".
  final String? emptyLabel;

  /// The disclosure label; the l10n value "Show as table" by default.
  final String? tableLabel;

  /// Starts with the exact rows open (a print view or a gallery).
  final bool initiallyOpen;

  @override
  State<ChartFrame> createState() => _ChartFrameState();
}

class _ChartFrameState extends State<ChartFrame> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = AppLocalizations.of(context);
    final showLabel = widget.tableLabel ?? l10n.chartShowAsTable;
    final hideLabel = l10n.chartHideTable;
    final hasTable =
        widget.showTable && !widget.preview && widget.table != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Semantics(
          label: widget.label,
          image: true,
          container: true,
          child: ExcludeSemantics(child: widget.chart),
        ),
        if (hasTable) ...<Widget>[
          const VSpace(Space.s),
          AppInteraction(
            onActivated: () => setState(() => _open = !_open),
            borderRadius: const BorderRadius.all(
              Radius.circular(RadiusTokens.s),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.xxs),
              child: Semantics(
                button: true,
                label: _open ? hideLabel : showLabel,
                child: Text(
                  (_open ? hideLabel : showLabel).toUpperCase(),
                  style:
                      AppText.labelCaps.copyWith(color: tokens.textSecondary),
                ),
              ),
            ),
          ),
          if (_open) ...<Widget>[
            const VSpace(Space.xs),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) =>
                  SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: constraints.maxWidth.isFinite
                      ? constraints.maxWidth
                      : 320,
                  child: ChartTable(
                    columns: widget.table!.columns,
                    rows: widget.table!.rows,
                    emptyLabel: widget.emptyLabel,
                  ),
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }
}
