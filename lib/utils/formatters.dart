// Archivo: formatters.dart

/// Formatea un número entero a texto con puntos de miles y millones (Ej: 30000000 -> "30.000.000")
String formatCurrencyCol(int amount) {
  if (amount == 0) return '0';

  final negative = amount < 0;
  final absValue = amount.abs().toString();

  // Expresión regular que inserta un punto cada 3 dígitos de derecha a izquierda
  final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
  final formatted = absValue.replaceAllMapped(reg, (Match m) => '${m[1]}.');

  return negative ? '-$formatted' : formatted;
}

/// Parsea un texto con o sin puntos/espacios a un entero real (Ej: "30.000.000" -> 30000000)
int parseCurrencyInputToInteger(String input) {
  if (input.trim().isEmpty) return 0;

  // Elimina puntos, comas y espacios
  final normalized = input
      .trim()
      .replaceAll('.', '')
      .replaceAll(',', '')
      .replaceAll(' ', '');

  return int.tryParse(normalized) ?? 0;
}
