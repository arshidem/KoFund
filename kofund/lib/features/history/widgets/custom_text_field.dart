// custom_text_field.dart
import 'package:flutter/material.dart';

class CustomTextField extends StatelessWidget {
  final String label;
  final String? hintText;
  final TextEditingController? controller;
  final String? initialValue;
  final TextInputType? keyboardType;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final bool obscureText;
  final bool readOnly;
  final bool enabled;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? prefixText;
  final String? suffixText;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final void Function()? onTap;
  final TextCapitalization textCapitalization;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool expands;
  final EdgeInsetsGeometry? contentPadding;
  final InputBorder? border;
  final InputBorder? enabledBorder;
  final InputBorder? focusedBorder;
  final InputBorder? errorBorder;
  final InputBorder? focusedErrorBorder;
  final Color? fillColor;
  final bool filled;
  final TextStyle? labelStyle;
  final TextStyle? hintStyle;
  final TextStyle? errorStyle;
  final String? errorText;
  final bool showCounter;
  final bool showRequiredStar;

  const CustomTextField({
    Key? key,
    required this.label,
    this.hintText,
    this.controller,
    this.initialValue,
    this.keyboardType,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.obscureText = false,
    this.readOnly = false,
    this.enabled = true,
    this.prefixIcon,
    this.suffixIcon,
    this.prefixText,
    this.suffixText,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction,
    this.focusNode,
    this.autofocus = false,
    this.expands = false,
    this.contentPadding,
    this.border,
    this.enabledBorder,
    this.focusedBorder,
    this.errorBorder,
    this.focusedErrorBorder,
    this.fillColor,
    this.filled = false,
    this.labelStyle,
    this.hintStyle,
    this.errorStyle,
    this.errorText,
    this.showCounter = false,
    this.showRequiredStar = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label with optional required star
        if (label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: labelStyle ?? TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: enabled 
                        ? theme.colorScheme.onSurface.withOpacity(0.7)
                        : theme.disabledColor,
                    ),
                  ),
                ),
                if (showRequiredStar)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      '*',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        
        // Text Field
        TextFormField(
          controller: controller,
          initialValue: initialValue,
          keyboardType: keyboardType,
          maxLines: expands ? null : maxLines,
          minLines: minLines,
          maxLength: maxLength,
          obscureText: obscureText,
          readOnly: readOnly,
          enabled: enabled,
          validator: validator,
          onChanged: onChanged,
          onFieldSubmitted: onSubmitted,
          onTap: onTap,
          textCapitalization: textCapitalization,
          textInputAction: textInputAction,
          focusNode: focusNode,
          autofocus: autofocus,
          expands: expands,
          style: TextStyle(
            color: enabled 
              ? theme.colorScheme.onSurface 
              : theme.disabledColor,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: hintStyle ?? TextStyle(
              color: theme.hintColor,
              fontSize: 14,
            ),
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            prefixText: prefixText,
            suffixText: suffixText,
            prefixStyle: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
            suffixStyle: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
            contentPadding: contentPadding ?? EdgeInsets.symmetric(
              horizontal: 12,
              vertical: maxLines! > 1 ? 12 : 16,
            ),
            border: border ?? OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: theme.dividerColor,
                width: 1,
              ),
            ),
            enabledBorder: enabledBorder ?? OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: theme.dividerColor,
                width: 1,
              ),
            ),
            focusedBorder: focusedBorder ?? OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: theme.primaryColor,
                width: 2,
              ),
            ),
            errorBorder: errorBorder ?? OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: theme.colorScheme.error,
                width: 1,
              ),
            ),
            focusedErrorBorder: focusedErrorBorder ?? OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: theme.colorScheme.error,
                width: 2,
              ),
            ),
            fillColor: fillColor ?? (enabled 
              ? theme.colorScheme.surface 
              : theme.colorScheme.surface.withOpacity(0.5)),
            filled: filled || !enabled,
            errorText: errorText,
            errorStyle: errorStyle ?? TextStyle(
              color: theme.colorScheme.error,
              fontSize: 12,
              height: 1,
            ),
            counterText: showCounter ? null : '',
            errorMaxLines: 2,
          ),
        ),
      ],
    );
  }
}

// For a simpler version if you prefer:
class SimpleTextField extends StatelessWidget {
  final String label;
  final String? hintText;
  final TextEditingController? controller;
  final String? initialValue;
  final TextInputType? keyboardType;
  final int? maxLines;
  final int? maxLength;
  final bool obscureText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final bool isRequired;
  final bool enabled;

  const SimpleTextField({
    Key? key,
    required this.label,
    this.hintText,
    this.controller,
    this.initialValue,
    this.keyboardType,
    this.maxLines = 1,
    this.maxLength,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.onChanged,
    this.isRequired = false,
    this.enabled = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: enabled 
                      ? Colors.grey[700]
                      : Colors.grey[400],
                  ),
                ),
                if (isRequired)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      '*',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        
        TextFormField(
          controller: controller,
          initialValue: initialValue,
          keyboardType: keyboardType,
          maxLines: maxLines,
          maxLength: maxLength,
          obscureText: obscureText,
          enabled: enabled,
          validator: validator,
          onChanged: onChanged,
          style: TextStyle(
            fontSize: 16,
            color: enabled ? Colors.black87 : Colors.grey[600],
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              color: Colors.grey[500],
              fontSize: 16,
            ),
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: theme.primaryColor, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.red, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.red, width: 2),
            ),
            fillColor: enabled ? Colors.white : Colors.grey[100],
            filled: true,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: maxLines! > 1 ? 12 : 16,
            ),
            errorStyle: TextStyle(
              color: Colors.red,
              fontSize: 12,
              height: 0.8,
            ),
          ),
        ),
      ],
    );
  }
}

// For currency input specifically
class CurrencyTextField extends StatelessWidget {
  final String label;
  final String? hintText;
  final TextEditingController? controller;
  final String? initialValue;
  final String currencySymbol;
  final String? Function(String?)? validator;
  final void Function(double)? onChanged;
  final bool isRequired;

  const CurrencyTextField({
    Key? key,
    required this.label,
    this.hintText,
    this.controller,
    this.initialValue,
    this.currencySymbol = '₹',
    this.validator,
    this.onChanged,
    this.isRequired = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SimpleTextField(
      label: label,
      hintText: hintText ?? '0.00',
      controller: controller,
      initialValue: initialValue,
      keyboardType: TextInputType.numberWithOptions(decimal: true),
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 12, right: 8),
        child: Text(
          currencySymbol,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
      ),
      isRequired: isRequired,
      validator: validator ?? (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter amount';
        }
        final amount = double.tryParse(value);
        if (amount == null || amount <= 0) {
          return 'Please enter a valid amount';
        }
        return null;
      },
      onChanged: (value) {
        if (onChanged != null) {
          final amount = double.tryParse(value) ?? 0;
          onChanged!(amount);
        }
      },
    );
  }
}

// For dropdown selection
class CustomDropdownField<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?)? onChanged;
  final String? Function(T?)? validator;
  final String? hintText;
  final bool isRequired;
  final bool enabled;
  final Widget? prefixIcon;
  final String? errorText;

  const CustomDropdownField({
    Key? key,
    required this.label,
    required this.value,
    required this.items,
    this.onChanged,
    this.validator,
    this.hintText,
    this.isRequired = false,
    this.enabled = true,
    this.prefixIcon,
    this.errorText,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: enabled ? Colors.grey[700] : Colors.grey[400],
                  ),
                ),
                if (isRequired)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      '*',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        
        DropdownButtonFormField<T>(
          value: value,
          items: items,
          onChanged: enabled ? onChanged : null,
          validator: validator,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: prefixIcon,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.red, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.red, width: 2),
            ),
            fillColor: enabled ? Colors.white : Colors.grey[100],
            filled: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            errorText: errorText,
            errorStyle: TextStyle(
              color: Colors.red,
              fontSize: 12,
              height: 0.8,
            ),
          ),
          icon: Icon(
            Icons.arrow_drop_down,
            color: enabled ? Colors.grey[600] : Colors.grey[400],
          ),
          style: TextStyle(
            fontSize: 16,
            color: enabled ? Colors.black87 : Colors.grey[600],
          ),
          isExpanded: true,
          dropdownColor: Colors.white,
        ),
      ],
    );
  }
}