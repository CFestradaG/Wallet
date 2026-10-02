import { PeriodFilterMode, UserSettingsModel } from '../types/wallet';

export interface DateRangeValue {
  start: Date;
  end: Date;
}

const MONTH_NAMES_SHORT = [
  'Ene',
  'Feb',
  'Mar',
  'Abr',
  'May',
  'Jun',
  'Jul',
  'Ago',
  'Sep',
  'Oct',
  'Nov',
  'Dic',
];

function getDaysInMonth(year: number, monthZeroIndexed: number): number {
  return new Date(year, monthZeroIndexed + 1, 0).getDate();
}

function clampDay(year: number, monthZeroIndexed: number, desiredDay: number): number {
  const maxDays = getDaysInMonth(year, monthZeroIndexed);
  return Math.max(1, Math.min(desiredDay, maxDays));
}

/**
 * Servicio Helper de Fechas (`FinancialPeriodHelper`)
 * Replica exactamente la lógica del módulo Dart `financial_period_helper.dart`.
 */
export class FinancialPeriodHelper {
  readonly startDayOfMonth: number;
  readonly enableSplitPeriod: boolean;
  readonly midMonthDay: number;

  constructor(settings?: Partial<UserSettingsModel>) {
    this.startDayOfMonth = Math.max(1, Math.min(31, settings?.startDayOfMonth ?? 27));
    this.enableSplitPeriod = settings?.enableSplitPeriod ?? true;
    this.midMonthDay = Math.max(1, Math.min(31, settings?.midMonthDay ?? 13));
  }

  /**
   * 1. `getPeriodName(Date date)` -> Retorna el identificador del período (ej. "2026-11" aunque sea 28 de octubre)
   */
  getPeriodName(date: Date): string {
    const year = date.getFullYear();
    const month = date.getMonth(); // 0..11
    const day = date.getDate();

    if (this.startDayOfMonth <= 1) {
      return `${year}-${String(month + 1).padStart(2, '0')}`;
    }

    const effectiveStart = clampDay(year, month, this.startDayOfMonth);
    if (day >= effectiveStart) {
      const nextMonthDate = new Date(year, month + 1, 1);
      return `${nextMonthDate.getFullYear()}-${String(
        nextMonthDate.getMonth() + 1
      ).padStart(2, '0')}`;
    } else {
      return `${year}-${String(month + 1).padStart(2, '0')}`;
    }
  }

  /**
   * Retorna el ID de documento para `/users/{userId}/summaries/{periodId}` (ej. `period_2026_11`)
   */
  getFirestorePeriodId(date: Date): string {
    return `period_${this.getPeriodName(date).replace('-', '_')}`;
  }

  /**
   * 2. `getPeriodDateRange(Date date)` -> Retorna el rango exacto (ej. `2026-10-27 00:00:00` hasta `2026-11-26 23:59:59`)
   */
  getPeriodDateRange(date: Date): DateRangeValue {
    const year = date.getFullYear();
    const month = date.getMonth();
    const day = date.getDate();

    if (this.startDayOfMonth <= 1) {
      const lastDay = getDaysInMonth(year, month);
      return {
        start: new Date(year, month, 1, 0, 0, 0, 0),
        end: new Date(year, month, lastDay, 23, 59, 59, 999),
      };
    }

    const effectiveStartThisMonth = clampDay(year, month, this.startDayOfMonth);

    if (day >= effectiveStartThisMonth) {
      const start = new Date(year, month, effectiveStartThisMonth, 0, 0, 0, 0);
      const nextMonth = new Date(year, month + 1, 1);
      const nextStartDay = clampDay(
        nextMonth.getFullYear(),
        nextMonth.getMonth(),
        this.startDayOfMonth
      );
      const nextCycleStart = new Date(
        nextMonth.getFullYear(),
        nextMonth.getMonth(),
        nextStartDay,
        0,
        0,
        0,
        0
      );
      const end = new Date(nextCycleStart.getTime() - 1);
      return { start, end };
    } else {
      const prevMonth = new Date(year, month - 1, 1);
      const prevStartDay = clampDay(
        prevMonth.getFullYear(),
        prevMonth.getMonth(),
        this.startDayOfMonth
      );
      const start = new Date(
        prevMonth.getFullYear(),
        prevMonth.getMonth(),
        prevStartDay,
        0,
        0,
        0,
        0
      );
      const thisCycleStart = new Date(
        year,
        month,
        effectiveStartThisMonth,
        0,
        0,
        0,
        0
      );
      const end = new Date(thisCycleStart.getTime() - 1);
      return { start, end };
    }
  }

  private getMidPeriodStartDate(fullRange: DateRangeValue): Date {
    if (this.startDayOfMonth > this.midMonthDay) {
      const targetYear = fullRange.end.getFullYear();
      const targetMonth = fullRange.end.getMonth();
      const clampedMid = clampDay(targetYear, targetMonth, this.midMonthDay);
      return new Date(targetYear, targetMonth, clampedMid, 0, 0, 0, 0);
    } else {
      const targetYear = fullRange.start.getFullYear();
      const targetMonth = fullRange.start.getMonth();
      const clampedMid = clampDay(targetYear, targetMonth, this.midMonthDay);
      return new Date(targetYear, targetMonth, clampedMid, 0, 0, 0, 0);
    }
  }

  /**
   * Rango de la "Primera Mitad" (ej. 27 Oct 00:00:00 - 12 Nov 23:59:59)
   */
  getFirstHalfDateRange(date: Date): DateRangeValue {
    const fullRange = this.getPeriodDateRange(date);
    if (!this.enableSplitPeriod) return fullRange;
    const midStart = this.getMidPeriodStartDate(fullRange);
    return {
      start: fullRange.start,
      end: new Date(midStart.getTime() - 1),
    };
  }

  /**
   * Rango de la "Segunda Mitad" (ej. 13 Nov 00:00:00 - 26 Nov 23:59:59)
   */
  getSecondHalfDateRange(date: Date): DateRangeValue {
    const fullRange = this.getPeriodDateRange(date);
    if (!this.enableSplitPeriod) return fullRange;
    const midStart = this.getMidPeriodStartDate(fullRange);
    return {
      start: midStart,
      end: fullRange.end,
    };
  }

  /**
   * 3. `getSubPeriod(Date date)` -> Retorna si la fecha cae en "Primera Quincena / Inicio de Mes" o "Segunda Quincena"
   */
  getSubPeriod(date: Date): string {
    if (!this.enableSplitPeriod) {
      return 'Período Completo';
    }
    const firstHalf = this.getFirstHalfDateRange(date);
    const ts = date.getTime();
    if (ts >= firstHalf.start.getTime() && ts <= firstHalf.end.getTime()) {
      return 'Primera Quincena / Inicio de Mes';
    }
    return 'Segunda Quincena';
  }

  getRangeForFilterMode(
    mode: PeriodFilterMode,
    referenceDate: Date,
    customRange?: DateRangeValue
  ): DateRangeValue {
    switch (mode) {
      case 'fullPeriod':
        return this.getPeriodDateRange(referenceDate);
      case 'firstHalf':
        return this.getFirstHalfDateRange(referenceDate);
      case 'secondHalf':
        return this.getSecondHalfDateRange(referenceDate);
      case 'custom':
        return customRange ?? this.getPeriodDateRange(referenceDate);
    }
  }

  isDateInRange(txDate: Date, range: DateRangeValue): boolean {
    const t = txDate.getTime();
    return t >= range.start.getTime() && t <= range.end.getTime();
  }

  static formatShortRange(range: DateRangeValue): string {
    const sDay = String(range.start.getDate()).padStart(2, '0');
    const sMon = MONTH_NAMES_SHORT[range.start.getMonth()];
    const eDay = String(range.end.getDate()).padStart(2, '0');
    const eMon = MONTH_NAMES_SHORT[range.end.getMonth()];
    return `${sDay} ${sMon} - ${eDay} ${eMon}`;
  }
}
