import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kofund/core/constants/app_colors.dart';

/// Full-screen primary gradient with a fixed header row and a rounded sheet
/// body — matches [SettingsScreen] chrome.
class GradientSheetScaffold extends StatelessWidget {
  const GradientSheetScaffold({
    super.key,
    required this.title,
    this.titleWidget,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.actions,
    this.onPop,
    this.headerHeight = 72,
    this.gapBelowHeader = 0,
    this.sheetBorderRadius = 28,
    this.belowHeader,
    required this.body,
    this.resizeToAvoidBottomInset,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
  });

  final String title;
  final Widget? titleWidget;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final List<Widget>? actions;
  final VoidCallback? onPop;
  final double headerHeight;
  final double gapBelowHeader;
  final double sheetBorderRadius;
  /// Placed under the title row, still on the primary gradient (e.g. [TabBar], search).
  final Widget? belowHeader;
  final Widget body;
  final bool? resizeToAvoidBottomInset;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  @override
  Widget build(BuildContext context) {
    final sheetRadius = BorderRadius.vertical(
      top: Radius.circular(sheetBorderRadius),
    );
    final canPop = Navigator.canPop(context);
    final Widget? effectiveLeading = leading ??
        (automaticallyImplyLeading && canPop
            ? IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: AppColors.textPrimary(context),
                ),
                onPressed: onPop ?? () => Navigator.of(context).pop(),
              )
            : null);

    final Widget centerTitle = titleWidget ??
        Text(
          title,
          style: TextStyle(
            color: AppColors.textPrimary(context),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Theme.of(context).brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
        statusBarBrightness: Theme.of(context).brightness == Brightness.dark
            ? Brightness.dark
            : Brightness.light,
        systemNavigationBarColor: AppColors.background(context),
        systemNavigationBarIconBrightness:
            Theme.of(context).brightness == Brightness.dark
                ? Brightness.light
                : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset ?? true,
        floatingActionButton: floatingActionButton,
        floatingActionButtonLocation: floatingActionButtonLocation,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark ? null : AppColors.background(context),
            gradient: Theme.of(context).brightness == Brightness.dark
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    stops: [0.0, 0.3], // Forces the gradient to finish transitioning within the header 
                    colors: [
                      Color(0xFF1A2E2E),
                      Color(0xFF0D1B1A),
                    ],
                  )
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SafeArea(
                bottom: false,
                child: SizedBox(
                  height: headerHeight,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      if (effectiveLeading != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: effectiveLeading,
                        ),
                      Center(child: centerTitle),
                      if (actions != null && actions!.isNotEmpty)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: actions!,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (belowHeader != null) belowHeader!,
              SizedBox(height: gapBelowHeader),
              Expanded(
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: AppColors.background(context),
                    borderRadius: sheetRadius,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: Theme.of(context).brightness == Brightness.dark ? 0.15 : 0.08,
                        ),
                        offset: const Offset(0, -4),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: sheetRadius,
                    child: body,
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





