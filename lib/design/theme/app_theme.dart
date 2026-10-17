import 'package:flutter/material.dart';

import '../tokens/token_types.dart';
import '../tokens/tokens.g.dart';
import 'section.dart';

/// DESIGN 3: the section chrome roles for one section. Section colour marks
/// only chrome, never data or a signed change (DESIGN 2.3).
final class SectionRole {
  const SectionRole({
    required this.gradientStart,
    required this.gradientEnd,
    required this.text,
    required this.selectedFill,
  });

  final Color gradientStart;
  final Color gradientEnd;
  final Color text;
  final GradientSpec selectedFill;
}

/// DESIGN 3: `context.tokens` holds the theme colour roles. Non-colour tokens
/// (space, size, radius, motion, type) are theme-independent consts
/// (`SpaceTokens`, `SizeTokens`, `RadiusTokens`, `TypeTokens`, `MotionTokens`).
class ContourTokens extends ThemeExtension<ContourTokens> {
  const ContourTokens({
    required this.isDark,
    required this.surfacePage,
    required this.surfaceGlass,
    required this.surfaceRim,
    required this.pageSpotlight,
    required this.surfaceGlassEdge,
    required this.surfaceTile,
    required this.surfaceSheet,
    required this.surfaceTrack,
    required this.surfaceInverse,
    required this.textPrimary,
    required this.textSecondary,
    required this.textControl,
    required this.textOnInverse,
    required this.textOnSection,
    required this.textHeroFill,
    required this.actionNeutralFill,
    required this.actionDestructiveFill,
    required this.actionDestructiveText,
    required this.dataNeutralFill,
    required this.iconSecondary,
    required this.borderDivider,
    required this.borderChip,
    required this.focusRing,
    required this.scrim,
    required this.stateGain,
    required this.stateLoss,
    required this.stateNeutral,
    required this.estPillFill,
    required this.disabled,
    required this.elevationGlass,
    required this.elevationSheet,
    required this.elevationNav,
    required this.sectionRoles,
  });

  factory ContourTokens.dark() => const ContourTokens(
        isDark: true,
        surfacePage: ColorTokensDark.roleSurfacePage,
        surfaceGlass: GradientTokensDark.roleSurfaceGlass,
        surfaceRim: GradientTokensDark.roleSurfaceRim,
        pageSpotlight: GradientTokensDark.roleSurfacePageSpotlight,
        surfaceGlassEdge: ColorTokensDark.roleSurfaceGlassEdge,
        surfaceTile: ColorTokensDark.roleSurfaceTile,
        surfaceSheet: ColorTokensDark.roleSurfaceSheet,
        surfaceTrack: ColorTokensDark.roleSurfaceTrack,
        surfaceInverse: ColorTokensDark.roleSurfaceInverse,
        textPrimary: ColorTokensDark.roleTextPrimary,
        textSecondary: ColorTokensDark.roleTextSecondary,
        textControl: ColorTokensDark.roleTextControl,
        textOnInverse: ColorTokensDark.roleTextOnInverse,
        textOnSection: ColorTokensDark.roleTextOnSection,
        textHeroFill: GradientTokensDark.roleTextHeroFill,
        actionNeutralFill: ColorTokensDark.roleActionNeutralFill,
        actionDestructiveFill: ColorTokensDark.roleActionDestructiveFill,
        actionDestructiveText: ColorTokensDark.roleActionDestructiveText,
        dataNeutralFill: ColorTokensDark.roleDataNeutralFill,
        iconSecondary: ColorTokensDark.roleIconSecondary,
        borderDivider: ColorTokensDark.roleBorderDivider,
        borderChip: ColorTokensDark.roleBorderChip,
        focusRing: ColorTokensDark.roleFocusRing,
        scrim: ColorTokensDark.roleOverlayScrim,
        stateGain: ColorTokensDark.roleStateGain,
        stateLoss: ColorTokensDark.roleStateLoss,
        stateNeutral: ColorTokensDark.roleStateNeutral,
        estPillFill: ColorTokensDark.roleStateEstPillFill,
        disabled: ColorTokensDark.roleStateDisabled,
        elevationGlass: ElevationTokensDark.glass,
        elevationSheet: ElevationTokensDark.sheet,
        elevationNav: ElevationTokensDark.nav,
        sectionRoles: <Section, SectionRole>{
          Section.home: SectionRole(
            gradientStart: ColorTokensDark.sectionHomeGradientStart,
            gradientEnd: ColorTokensDark.sectionHomeGradientEnd,
            text: ColorTokensDark.sectionHomeText,
            selectedFill: GradientTokensDark.sectionHomeSelectedFill,
          ),
          Section.spending: SectionRole(
            gradientStart: ColorTokensDark.sectionSpendingGradientStart,
            gradientEnd: ColorTokensDark.sectionSpendingGradientEnd,
            text: ColorTokensDark.sectionSpendingText,
            selectedFill: GradientTokensDark.sectionSpendingSelectedFill,
          ),
          Section.income: SectionRole(
            gradientStart: ColorTokensDark.sectionIncomeGradientStart,
            gradientEnd: ColorTokensDark.sectionIncomeGradientEnd,
            text: ColorTokensDark.sectionIncomeText,
            selectedFill: GradientTokensDark.sectionIncomeSelectedFill,
          ),
          Section.wealth: SectionRole(
            gradientStart: ColorTokensDark.sectionWealthGradientStart,
            gradientEnd: ColorTokensDark.sectionWealthGradientEnd,
            text: ColorTokensDark.sectionWealthText,
            selectedFill: GradientTokensDark.sectionWealthSelectedFill,
          ),
          Section.plan: SectionRole(
            gradientStart: ColorTokensDark.sectionPlanGradientStart,
            gradientEnd: ColorTokensDark.sectionPlanGradientEnd,
            text: ColorTokensDark.sectionPlanText,
            selectedFill: GradientTokensDark.sectionPlanSelectedFill,
          ),
        },
      );

  factory ContourTokens.light() => const ContourTokens(
        isDark: false,
        surfacePage: ColorTokensLight.roleSurfacePage,
        surfaceGlass: GradientTokensLight.roleSurfaceGlass,
        surfaceRim: GradientTokensLight.roleSurfaceRim,
        pageSpotlight: GradientTokensLight.roleSurfacePageSpotlight,
        surfaceGlassEdge: ColorTokensLight.roleSurfaceGlassEdge,
        surfaceTile: ColorTokensLight.roleSurfaceTile,
        surfaceSheet: ColorTokensLight.roleSurfaceSheet,
        surfaceTrack: ColorTokensLight.roleSurfaceTrack,
        surfaceInverse: ColorTokensLight.roleSurfaceInverse,
        textPrimary: ColorTokensLight.roleTextPrimary,
        textSecondary: ColorTokensLight.roleTextSecondary,
        textControl: ColorTokensLight.roleTextControl,
        textOnInverse: ColorTokensLight.roleTextOnInverse,
        textOnSection: ColorTokensLight.roleTextOnSection,
        textHeroFill: GradientTokensLight.roleTextHeroFill,
        actionNeutralFill: ColorTokensLight.roleActionNeutralFill,
        actionDestructiveFill: ColorTokensLight.roleActionDestructiveFill,
        actionDestructiveText: ColorTokensLight.roleActionDestructiveText,
        dataNeutralFill: ColorTokensLight.roleDataNeutralFill,
        iconSecondary: ColorTokensLight.roleIconSecondary,
        borderDivider: ColorTokensLight.roleBorderDivider,
        borderChip: ColorTokensLight.roleBorderChip,
        focusRing: ColorTokensLight.roleFocusRing,
        scrim: ColorTokensLight.roleOverlayScrim,
        stateGain: ColorTokensLight.roleStateGain,
        stateLoss: ColorTokensLight.roleStateLoss,
        stateNeutral: ColorTokensLight.roleStateNeutral,
        estPillFill: ColorTokensLight.roleStateEstPillFill,
        disabled: ColorTokensLight.roleStateDisabled,
        elevationGlass: ElevationTokensLight.glass,
        elevationSheet: ElevationTokensLight.sheet,
        elevationNav: ElevationTokensLight.nav,
        sectionRoles: <Section, SectionRole>{
          Section.home: SectionRole(
            gradientStart: ColorTokensLight.sectionHomeGradientStart,
            gradientEnd: ColorTokensLight.sectionHomeGradientEnd,
            text: ColorTokensLight.sectionHomeText,
            selectedFill: GradientTokensLight.sectionHomeSelectedFill,
          ),
          Section.spending: SectionRole(
            gradientStart: ColorTokensLight.sectionSpendingGradientStart,
            gradientEnd: ColorTokensLight.sectionSpendingGradientEnd,
            text: ColorTokensLight.sectionSpendingText,
            selectedFill: GradientTokensLight.sectionSpendingSelectedFill,
          ),
          Section.income: SectionRole(
            gradientStart: ColorTokensLight.sectionIncomeGradientStart,
            gradientEnd: ColorTokensLight.sectionIncomeGradientEnd,
            text: ColorTokensLight.sectionIncomeText,
            selectedFill: GradientTokensLight.sectionIncomeSelectedFill,
          ),
          Section.wealth: SectionRole(
            gradientStart: ColorTokensLight.sectionWealthGradientStart,
            gradientEnd: ColorTokensLight.sectionWealthGradientEnd,
            text: ColorTokensLight.sectionWealthText,
            selectedFill: GradientTokensLight.sectionWealthSelectedFill,
          ),
          Section.plan: SectionRole(
            gradientStart: ColorTokensLight.sectionPlanGradientStart,
            gradientEnd: ColorTokensLight.sectionPlanGradientEnd,
            text: ColorTokensLight.sectionPlanText,
            selectedFill: GradientTokensLight.sectionPlanSelectedFill,
          ),
        },
      );

  final bool isDark;
  final Color surfacePage;
  final GradientSpec surfaceGlass;
  final GradientSpec surfaceRim;
  final SpotlightSpec pageSpotlight;
  final Color surfaceGlassEdge;
  final Color surfaceTile;
  final Color surfaceSheet;
  final Color surfaceTrack;
  final Color surfaceInverse;
  final Color textPrimary;
  final Color textSecondary;
  final Color textControl;
  final Color textOnInverse;
  final Color textOnSection;
  final GradientSpec textHeroFill;
  final Color actionNeutralFill;
  final Color actionDestructiveFill;
  final Color actionDestructiveText;
  final Color dataNeutralFill;
  final Color iconSecondary;
  final Color borderDivider;
  final Color borderChip;
  final Color focusRing;
  final Color scrim;
  final Color stateGain;
  final Color stateLoss;
  final Color stateNeutral;
  final Color estPillFill;
  final Color disabled;
  final ElevationSpec elevationGlass;
  final ElevationSpec elevationSheet;
  final ElevationSpec elevationNav;
  final Map<Section, SectionRole> sectionRoles;

  /// The chrome roles for [section] (DESIGN 2.3).
  SectionRole role(Section section) => sectionRoles[section]!;

  static ContourTokens of(BuildContext context) =>
      Theme.of(context).extension<ContourTokens>()!;

  @override
  ContourTokens copyWith() => this;

  @override
  ContourTokens lerp(ThemeExtension<ContourTokens>? other, double t) {
    if (other is! ContourTokens) {
      return this;
    }
    return t < 0.5 ? this : other;
  }
}

extension ContourTokensContext on BuildContext {
  ContourTokens get tokens => ContourTokens.of(this);
}

/// DESIGN 3: builds `ThemeData` and registers [ContourTokens]. Material defaults
/// are overridden here once, never per widget.
abstract final class AppTheme {
  const AppTheme._();

  static ThemeData dark() => _build(ContourTokens.dark());

  static ThemeData light() => _build(ContourTokens.light());

  static ThemeData _build(ContourTokens tokens) {
    return ThemeData(
      brightness: tokens.isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: tokens.surfacePage,
      fontFamily: 'Inter',
      colorScheme: ColorScheme.fromSeed(
        seedColor: tokens.sectionRoles[Section.home]!.gradientStart,
        brightness: tokens.isDark ? Brightness.dark : Brightness.light,
      ),
      extensions: <ThemeExtension<dynamic>>[tokens],
    );
  }
}
