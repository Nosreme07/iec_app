class HolidayUtil {
  static Map<DateTime, String> getHolidays(int year) {
    Map<DateTime, String> holidays = {};

    // --- FERIADOS FIXOS ---
    holidays[DateTime(year, 1, 1)] = "Confraternização Universal";
    holidays[DateTime(year, 4, 21)] = "Tiradentes";
    holidays[DateTime(year, 5, 1)] = "Dia do Trabalho";
    holidays[DateTime(year, 9, 7)] = "Independência do Brasil";
    holidays[DateTime(year, 10, 12)] = "Nossa Sra. Aparecida";
    holidays[DateTime(year, 11, 2)] = "Finados";
    holidays[DateTime(year, 11, 15)] = "Proclamação da República";
    holidays[DateTime(year, 12, 25)] = "Natal";

    // --- FERIADOS MÓVEIS (Baseados na Páscoa) ---
    DateTime pascoa = _getEasterDate(year);
    DateTime sextaFeiraSanta = pascoa.subtract(const Duration(days: 2));
    DateTime carnaval = pascoa.subtract(const Duration(days: 47));
    DateTime corpusChristi = pascoa.add(const Duration(days: 60));

    holidays[pascoa] = "Páscoa";
    holidays[sextaFeiraSanta] = "Sexta-feira Santa";
    holidays[carnaval] = "Carnaval";
    holidays[corpusChristi] = "Corpus Christi";

    return holidays;
  }

  // Algoritmo para calcular a Páscoa
  static DateTime _getEasterDate(int year) {
    int a = year % 19;
    int b = year ~/ 100;
    int c = year % 100;
    int d = b ~/ 4;
    int e = b % 4;
    int f = (b + 8) ~/ 25;
    int g = (b - f + 1) ~/ 3;
    int h = (19 * a + b - d - g + 15) % 30;
    int i = c ~/ 4;
    int k = c % 4;
    int l = (32 + 2 * e + 2 * i - h - k) % 7;
    int m = (a + 11 * h + 22 * l) ~/ 451;
    int month = (h + l - 7 * m + 114) ~/ 31;
    int day = ((h + l - 7 * m + 114) % 31) + 1;
    return DateTime(year, month, day);
  }
}