import 'package:flutter/material.dart';
import '../../features/settings/data/models/user_settings_model.dart';

/// Modos de filtro de período financiero en la UI (Dashboard y Reportes)
enum PeriodFilterMode {
  fullPeriod, // "Período Actual (27 Oct - 26 Nov)"
  firstHalf,  // "Primera Mitad (27 Oct - 12 Nov)"
  secondHalf, // "Segunda Mitad (13 Nov - 26 Nov)"
  custom,     // "Personalizado"
}

/// Sub-período o quincena dentro del ciclo financiero
enum FinancialSubPeriod {
  firstHalf('Primera Quincena / Inicio de Mes'),
  secondHalf('Segunda Quincena'),
  fullMonth('Período Completo (Sin división)');

  final String label;
  const FinancialSubPeriod(this.label);
}

/// Servicio Helper de Fechas para Ciclos Financieros Dinámicos (Nómina y Quincenas)
class FinancialPeriodHelper {
  final int startDayOfMonth;
  final bool enableSplitPeriod;
  final int midMonthDay;

  const FinancialPeriodHelper({
    this.startDayOfMonth = 27,
    this.enableSplitPeriod = true,
    this.midMonthDay = 13,
  });

  factory FinancialPeriodHelper.fromSettings(UserSettingsModel settings) {
    return FinancialPeriodHelper(
      startDayOfMonth: settings.startDayOfMonth,
      enableSplitPeriod: settings.enableSplitPeriod,
      midMonthDay: settings.midMonthDay,
    );
  }

  /// Ajusta el día al máximo de días que tiene un mes específico (ej. febrero 28/29)
  static int _clampDay(int year, int month, int desiredDay) {
    final daysInMonth = DateUtils.getDaysInMonth(year, month);
    return desiredDay.clamp(1, daysInMonth);
  }

  /// 1. Retorna el identificador nominal del período (ej. "2026-11" aunque sea 28 de octubre).
  /// Regla de negocio:
  /// - Si `startDayOfMonth == 1`, el período coincide con el mes calendario actual.
  /// - Si `startDayOfMonth > 1` (ej. 27) y `date.day >= 27`, la fecha ya pertenece al
  ///   ciclo financiero del mes siguiente (ej. 27 de oct inicia el período "2026-11").
  String getPeriodName(DateTime date) {
    if (startDayOfMonth <= 1) {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}';
    }

    final effectiveStartDay = _clampDay(date.year, date.month, startDayOfMonth);
    if (date.day >= effectiveStartDay) {
      // Pertenece al período del mes siguiente
      final nextMonthDate = DateTime(date.year, date.month + 1, 1);
      return '${nextMonthDate.year}-${nextMonthDate.month.toString().padLeft(2, '0')}';
    } else {
      // Pertenece al período del mes actual (inició el mes pasado)
      return '${date.year}-${date.month.toString().padLeft(2, '0')}';
    }
  }

  /// Retorna el ID del documento para la subcolección `/users/{userId}/summaries/{periodId}`
  /// Ejemplo: `"period_2026_11"`
  String getFirestorePeriodId(DateTime date) {
    final periodName = getPeriodName(date); // "2026-11"
    return 'period_${periodName.replaceAll('-', '_')}';
  }

  /// 2. Retorna el `DateTimeRange` exacto del período financiero completo al que pertenece [date].
  /// Ejemplo con `startDayOfMonth = 27` y fecha `2026-10-28`:
  /// Inicio: `2026-10-27 00:00:00.000`
  /// Fin:    `2026-11-26 23:59:59.999`
  DateTimeRange getPeriodDateRange(DateTime date) {
    if (startDayOfMonth <= 1) {
      final lastDay = DateUtils.getDaysInMonth(date.year, date.month);
      return DateTimeRange(
        start: DateTime(date.year, date.month, 1, 0, 0, 0),
        end: DateTime(date.year, date.month, lastDay, 23, 59, 59, 999),
      );
    }

    final effectiveStartThisMonth =
        _clampDay(date.year, date.month, startDayOfMonth);

    late final DateTime startDate;
    late final DateTime endDate;

    if (date.day >= effectiveStartThisMonth) {
      // El ciclo inició este mes en `startDayOfMonth` y termina el mes siguiente en `startDayOfMonth - 1`
      startDate = DateTime(
        date.year,
        date.month,
        effectiveStartThisMonth,
        0,
        0,
        0,
      );
      final nextMonth = DateTime(date.year, date.month + 1, 1);
      final nextMonthStartDay =
          _clampDay(nextMonth.year, nextMonth.month, startDayOfMonth);
      endDate = DateTime(
        nextMonth.year,
        nextMonth.month,
        nextMonthStartDay,
        0,
        0,
        0,
      ).subtract(const Duration(milliseconds: 1));
    } else {
      // El ciclo inició el mes anterior en `startDayOfMonth` y termina este mes en `startDayOfMonth - 1`
      final prevMonth = DateTime(date.year, date.month - 1, 1);
      final prevMonthStartDay =
          _clampDay(prevMonth.year, prevMonth.month, startDayOfMonth);
      startDate = DateTime(
        prevMonth.year,
        prevMonth.month,
        prevMonthStartDay,
        0,
        0,
        0,
      );
      endDate = DateTime(
        date.year,
        date.month,
        effectiveStartThisMonth,
        0,
        0,
        0,
      ).subtract(const Duration(milliseconds: 1));
    }

    return DateTimeRange(start: startDate, end: endDate);
  }

  /// Calcula la fecha exacta de corte de quincena (`midMonthDay`) dentro del rango del período
  DateTime _getMidPeriodStartDate(DateTimeRange fullRange) {
    // Si startDayOfMonth > midMonthDay (ej. inicia 27 Oct y corta 13 Nov), el corte cae en el mes de `fullRange.end`
    if (startDayOfMonth > midMonthDay) {
      final targetYear = fullRange.end.year;
      final targetMonth = fullRange.end.month;
      final clampedMid = _clampDay(targetYear, targetMonth, midMonthDay);
      return DateTime(targetYear, targetMonth, clampedMid, 0, 0, 0);
    } else {
      final targetYear = fullRange.start.year;
      final targetMonth = fullRange.start.month;
      final clampedMid = _clampDay(targetYear, targetMonth, midMonthDay);
      return DateTime(targetYear, targetMonth, clampedMid, 0, 0, 0);
    }
  }

  /// Retorna el rango de la "Primera Mitad / Inicio de Mes" (ej. 27 Oct 00:00:00 - 12 Nov 23:59:59)
  DateTimeRange getFirstHalfDateRange(DateTime referenceDate) {
    final fullRange = getPeriodDateRange(referenceDate);
    if (!enableSplitPeriod) return fullRange;

    final midStart = _getMidPeriodStartDate(fullRange);
    final firstHalfEnd = midStart.subtract(const Duration(milliseconds: 1));
    return DateTimeRange(start: fullRange.start, end: firstHalfEnd);
  }

  /// Retorna el rango de la "Segunda Mitad / Segunda Quincena" (ej. 13 Nov 00:00:00 - 26 Nov 23:59:59)
  DateTimeRange getSecondHalfDateRange(DateTime referenceDate) {
    final fullRange = getPeriodDateRange(referenceDate);
    if (!enableSplitPeriod) return fullRange;

    final midStart = _getMidPeriodStartDate(fullRange);
    return DateTimeRange(start: midStart, end: fullRange.end);
  }

  /// 3. Retorna si la fecha cae en "Primera Quincena / Inicio de Mes" o "Segunda Quincena"
  String getSubPeriod(DateTime date) {
    if (!enableSplitPeriod) {
      return FinancialSubPeriod.fullMonth.label;
    }
    final firstHalf = getFirstHalfDateRange(date);
    if (!date.isBefore(firstHalf.start) && !date.isAfter(firstHalf.end)) {
      return FinancialSubPeriod.firstHalf.label;
    }
    return FinancialSubPeriod.secondHalf.label;
  }

  /// Retorna el `DateTimeRange` activo según el modo seleccionado en la UI
  DateTimeRange getRangeForFilterMode(
    PeriodFilterMode mode,
    DateTime referenceDate, {
    DateTimeRange? customRange,
  }) {
    switch (mode) {
      case PeriodFilterMode.fullPeriod:
        return getPeriodDateRange(referenceDate);
      case PeriodFilterMode.firstHalf:
        return getFirstHalfDateRange(referenceDate);
      case PeriodFilterMode.secondHalf:
        return getSecondHalfDateRange(referenceDate);
      case PeriodFilterMode.custom:
        return customRange ?? getPeriodDateRange(referenceDate);
    }
  }

  /// Verifica si una fecha [txDate] se encuentra dentro del rango activo
  bool isDateInRange(DateTime txDate, DateTimeRange range) {
    return !txDate.isBefore(range.start) && !txDate.isAfter(range.end);
  }

  /// Formatea un rango corto para el selector de la UI (ej. "27 Oct - 26 Nov")
  static String formatShortRange(DateTimeRange range) {
    const months = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    final s = '${range.start.day.toString().padLeft(2, '0')} ${months[range.start.month - 1]}';
    final e = '${range.end.day.toString().padLeft(2, '0')} ${months[range.end.month - 1]}';
    return '$s - $e';
  }
}
