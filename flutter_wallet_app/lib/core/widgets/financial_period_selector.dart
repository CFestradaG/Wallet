import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/dashboard/presentation/providers/dashboard_providers.dart';
import '../theme/theme.dart';
import '../utils/financial_period_helper.dart';

/// Selector de Período Financiero Dinámico para DashboardScreen y AnalyticsScreen.
/// Permite alternar entre:
/// - "Período Actual (27 Oct - 26 Nov)"
/// - "Primera Mitad (27 Oct - 12 Nov)"
/// - "Segunda Mitad (13 Nov - 26 Nov)"
/// - "Personalizado"
class FinancialPeriodSelectorBar extends ConsumerWidget {
  const FinancialPeriodSelectorBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final helper = ref.watch(financialPeriodHelperProvider);
    final filterState = ref.watch(periodFilterProvider);
    final refDate = filterState.referenceDate;

    final fullRange = helper.getPeriodDateRange(refDate);
    final firstHalfRange = helper.getFirstHalfDateRange(refDate);
    final secondHalfRange = helper.getSecondHalfDateRange(refDate);
    final periodId = helper.getFirestorePeriodId(refDate);

    final options = <({PeriodFilterMode mode, String label})>[
      (
        mode: PeriodFilterMode.fullPeriod,
        label:
            'Período Actual (${FinancialPeriodHelper.formatShortRange(fullRange)})',
      ),
      if (helper.enableSplitPeriod) ...[
        (
          mode: PeriodFilterMode.firstHalf,
          label:
              'Primera Mitad (${FinancialPeriodHelper.formatShortRange(firstHalfRange)})',
        ),
        (
          mode: PeriodFilterMode.secondHalf,
          label:
              'Segunda Mitad (${FinancialPeriodHelper.formatShortRange(secondHalfRange)})',
        ),
      ],
      (
        mode: PeriodFilterMode.custom,
        label: filterState.customRange != null
            ? 'Personalizado (${FinancialPeriodHelper.formatShortRange(filterState.customRange!)})'
            : 'Personalizado',
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: StitchColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_month_rounded,
                size: 16,
                color: StitchColors.primaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ciclo Nómina: ${helper.getPeriodName(refDate)} · $periodId',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: StitchColors.onSurfaceVariant,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: StitchColors.secondaryContainer.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  helper.getSubPeriod(refDate),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: StitchColors.secondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: options.map((opt) {
                final isSelected = filterState.mode == opt.mode;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(opt.label),
                    selected: isSelected,
                    onSelected: (_) async {
                      if (opt.mode == PeriodFilterMode.custom) {
                        final picked = await showDateRangePicker(
                          context: context,
                          initialDateRange:
                              filterState.customRange ?? fullRange,
                          firstDate: DateTime(2024, 1, 1),
                          lastDate: DateTime(2030, 12, 31),
                        );
                        if (picked != null) {
                          ref
                              .read(periodFilterProvider.notifier)
                              .setFilterMode(
                                PeriodFilterMode.custom,
                                customRange: picked,
                              );
                        }
                      } else {
                        ref
                            .read(periodFilterProvider.notifier)
                            .setFilterMode(opt.mode);
                      }
                    },
                    selectedColor:
                        StitchColors.primaryContainer.withValues(alpha: 0.22),
                    backgroundColor: StitchColors.surfaceContainerHigh,
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? StitchColors.primary
                          : StitchColors.onSurfaceVariant,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: isSelected
                            ? StitchColors.primaryContainer
                            : Colors.transparent,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
