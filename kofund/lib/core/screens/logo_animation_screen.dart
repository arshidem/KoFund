import 'package:flutter/material.dart';
import '../widgets/animated_logo.dart';
import '../../core/constants/app_colors.dart';

class LogoAnimationScreen extends StatelessWidget {
  final String? message;
  final bool showLoadingIndicator;
  final Color backgroundColor;
  final bool useGradientBackground;

  const LogoAnimationScreen({
    Key? key,
    this.message,
    this.showLoadingIndicator = true,
    this.backgroundColor = Colors.transparent,
    this.useGradientBackground = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: useGradientBackground
            ? BoxDecoration(
                gradient: AppColors.primaryGradient(context),
              )
            : BoxDecoration(
                color: backgroundColor,
              ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const AnimatedLogo(
                size: 180,
                showBackground: true,
                backgroundColor: Colors.white,
                loopAnimation: true,
              ),
              
              if (message != null) ...[
                const SizedBox(height: 30),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: useGradientBackground 
                          ? Colors.white 
                          : Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
              
              if (showLoadingIndicator) ...[
                const SizedBox(height: 40),
                SizedBox(
                  width: 50,
                  height: 50,
                  child: CircularProgressIndicator(
                    color: useGradientBackground 
                        ? Colors.white 
                        : Theme.of(context).colorScheme.primary,
                    strokeWidth: 3,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}