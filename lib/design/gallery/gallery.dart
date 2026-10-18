import 'package:flutter/material.dart';

import '../icons/app_icons.dart';
import '../theme/app_theme.dart';
import '../theme/section.dart';
import '../tokens/token_types.dart';
import '../tokens/tokens.g.dart';
import '../typography/app_text.dart';

/// DESIGN 0.5: every component and variant is in the gallery (debug builds).
/// This T04 entry covers the theme colour roles, the type styles and the icons.
class DesignGallery extends StatelessWidget {
  const DesignGallery({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return ColoredBox(
      color: tokens.surfacePage,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(SpaceTokens.page),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Contour design gallery',
              style: AppText.titleScreen.copyWith(
                color: tokens.textPrimary,
              ),
            ),
            const SizedBox(height: SpaceTokens.l),
            _heading(context, 'Colour roles'),
            _swatches(context, <(String, Color)>[
              ('surface.page', tokens.surfacePage),
              ('surface.tile', tokens.surfaceTile),
              ('surface.track', tokens.surfaceTrack),
              ('surface.inverse', tokens.surfaceInverse),
              ('text.primary', tokens.textPrimary),
              ('text.secondary', tokens.textSecondary),
              ('text.control', tokens.textControl),
              ('text.onSection', tokens.textOnSection),
              ('state.gain', tokens.stateGain),
              ('state.loss', tokens.stateLoss),
              ('focus.ring', tokens.focusRing),
              ('icon.secondary', tokens.iconSecondary),
            ]),
            _gradient(context, 'surface.glass', tokens.surfaceGlass),
            _gradient(context, 'surface.rim', tokens.surfaceRim),
            const SizedBox(height: SpaceTokens.l),
            _heading(context, 'Section roles'),
            for (final section in Section.values) ...<Widget>[
              Text(
                section.name,
                style: AppText.body.copyWith(
                  color: tokens.role(section).text,
                ),
              ),
              const SizedBox(height: SpaceTokens.xs),
              _gradient(
                context,
                'selectedFill',
                tokens.role(section).selectedFill,
              ),
            ],
            const SizedBox(height: SpaceTokens.l),
            _heading(context, 'Type styles'),
            for (final entry in AppText.all.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: SpaceTokens.s),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: <Widget>[
                    SizedBox(
                      width: 140,
                      child: Text(
                        entry.key,
                        style: AppText.caption.copyWith(
                          color: tokens.textSecondary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '187,900 Contour',
                        style: entry.value.copyWith(color: tokens.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: SpaceTokens.l),
            _heading(context, 'Icons'),
            Wrap(
              spacing: SpaceTokens.m,
              runSpacing: SpaceTokens.m,
              children: <Widget>[
                for (final entry in AppIcons.all.entries)
                  AppIcon(
                    data: entry.value,
                    size: SizeTokens.iconL,
                    color: tokens.textPrimary,
                    semanticLabel: entry.key,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _heading(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: SpaceTokens.s),
        child: Text(
          text.toUpperCase(),
          style:
              AppText.labelCaps.copyWith(color: context.tokens.textSecondary),
          // CR-14: spoken name keeps the original case.
          semanticsLabel: text,
        ),
      );

  Widget _swatches(BuildContext context, List<(String, Color)> roles) => Wrap(
        spacing: SpaceTokens.m,
        runSpacing: SpaceTokens.s,
        children: <Widget>[
          for (final (name, color) in roles)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 72,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(RadiusTokens.s),
                    border: Border.all(color: context.tokens.borderChip),
                  ),
                ),
                const SizedBox(height: SpaceTokens.xs),
                Text(
                  name,
                  style: AppText.caption.copyWith(
                    color: context.tokens.textSecondary,
                  ),
                ),
              ],
            ),
        ],
      );

  Widget _gradient(BuildContext context, String name, GradientSpec spec) =>
      Padding(
        padding: const EdgeInsets.only(bottom: SpaceTokens.s),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              height: 40,
              decoration: BoxDecoration(
                gradient: spec.toLinearGradient(),
                borderRadius: BorderRadius.circular(RadiusTokens.s),
              ),
            ),
            const SizedBox(height: SpaceTokens.xs),
            Text(
              name,
              style: AppText.caption.copyWith(
                color: context.tokens.textSecondary,
              ),
            ),
          ],
        ),
      );
}
