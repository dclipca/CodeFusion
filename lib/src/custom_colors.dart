import 'package:flutter/material.dart';

class CustomColors extends ThemeExtension<CustomColors> {
  final Color? leftPanelColor;
  final Color? rightPanelColor;

  const CustomColors({this.leftPanelColor, this.rightPanelColor});

  @override
  CustomColors copyWith({Color? leftPanelColor, Color? rightPanelColor}) {
    return CustomColors(
      leftPanelColor: leftPanelColor ?? this.leftPanelColor,
      rightPanelColor: rightPanelColor ?? this.rightPanelColor,
    );
  }

  @override
  CustomColors lerp(ThemeExtension<CustomColors>? other, double t) {
    if (other is! CustomColors) {
      return this;
    }
    return CustomColors(
      leftPanelColor: Color.lerp(leftPanelColor, other.leftPanelColor, t),
      rightPanelColor: Color.lerp(rightPanelColor, other.rightPanelColor, t),
    );
  }
}
