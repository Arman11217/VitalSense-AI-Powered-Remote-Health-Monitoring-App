import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/animated_gradient_bg.dart';
import '../../vitals/application/vitals_providers.dart';
import '../../dashboard/presentation/widgets/ai_risk_card.dart';
import '../../dashboard/presentation/widgets/health_score_ring.dart';

/// AI Analysis (Module 6) — full-screen version of the dashboard widgets.
class AiAnalysisScreen extends ConsumerWidget {
  const AiAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prediction = ref.watch(latestPredictionProvider);
    final scheme = Theme.of(context).colorScheme;
    return AnimatedGradientBg(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('AI Analysis'),
        ),
        body: prediction.when(
          data: (p) => SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Center(child: HealthScoreRing(score: p.healthScore, size: 180)),
                const SizedBox(height: 24),
                AIRiskCard(prediction: p),
                const SizedBox(height: 24),
                Text(
                  'Recommendations',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                ...p.recommendations.map(
                  (r) => Card(
                    elevation: 0,
                    color: scheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    child: ListTile(
                      leading: const Icon(Icons.check_circle_outline_rounded),
                      title: Text(r),
                    ),
                  ),
                ),
              ],
            ),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }
}