// Formats a numeric amount with thousands separators, e.g. 20000 -> "20,000".
String formatAmount(num amount) {
  final rounded = amount.round();
  final digits = rounded.abs().toString();

  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i != 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }

  return rounded < 0 ? '-${buffer.toString()}' : buffer.toString();
}

// Strips thousands separators so operator input like "20,000" parses correctly.
num? parseAmount(String value) =>
    num.tryParse(value.trim().replaceAll(',', ''));
