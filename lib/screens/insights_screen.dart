import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/event_provider.dart';
import '../providers/note_provider.dart';
import '../services/analytics_service.dart';
import '../services/gemini_service.dart';
import '../utils/category_constants.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  bool _isLast7Days = true; // Toggle between 7 days and 30 days
  bool _isLoadingInsights = false;
  String _aiInsights = '';
  Map<String, double> _categoryBreakdown = {};

  @override
  void initState() {
    super.initState();
    _loadInsights();
  }

  Future<void> _loadInsights() async {
    setState(() {
      _isLoadingInsights = true;
      _aiInsights = '';
    });

    try {
      final eventProvider = Provider.of<EventProvider>(context, listen: false);
      final noteProvider = Provider.of<NoteProvider>(context, listen: false);

      // Get category breakdown
      final breakdown = AnalyticsService.getCategoryBreakdownLastNDays(
        events: eventProvider.events,
        notes: noteProvider.notes,
        days: _isLast7Days ? 7 : 30,
      );

      setState(() {
        _categoryBreakdown = breakdown;
      });

      // Generate AI insights
      if (breakdown.isNotEmpty) {
        final period = _isLast7Days ? 'Last 7 Days' : 'Last 30 Days';
        final insights = await GeminiService.generateReportInsight(
          breakdown,
          period,
        );

        if (mounted) {
          setState(() {
            _aiInsights = insights;
            _isLoadingInsights = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _aiInsights = 'No data available for the selected period.';
            _isLoadingInsights = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading insights: $e');
      if (mounted) {
        setState(() {
          _aiInsights = 'Error loading insights. Please try again.';
          _isLoadingInsights = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Intelligence Reports'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Period Toggle
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildPeriodButton('Last 7 Days', true),
                const SizedBox(width: 16),
                _buildPeriodButton('Last 30 Days', false),
              ],
            ),
          ),

          // Pie Chart
          Expanded(
            flex: 2,
            child: _categoryBreakdown.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.pie_chart_outline,
                          size: 64,
                          color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No data available',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: _buildPieChart(),
                  ),
          ),

          // AI Insights
          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.all(16.0),
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: _isLoadingInsights
                  ? const Center(child: CircularProgressIndicator())
                  : _aiInsights.isEmpty
                      ? Center(
                          child: Text(
                            'Loading insights...',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        )
                      : SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.psychology,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'AI Coach Feedback',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _aiInsights,
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      height: 1.6,
                                    ),
                              ),
                            ],
                          ),
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodButton(String label, bool isSelected) {
    final isActive = _isLast7Days == isSelected;
    return Expanded(
      child: ElevatedButton(
        onPressed: () {
          setState(() {
            _isLast7Days = isSelected;
          });
          _loadInsights();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isActive
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceVariant,
          foregroundColor: isActive
              ? Theme.of(context).colorScheme.onPrimary
              : Theme.of(context).colorScheme.onSurfaceVariant,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(label),
      ),
    );
  }

  Widget _buildPieChart() {
    // Prepare pie chart data
    final pieChartSections = <PieChartSectionData>[];
    final totalHours = AnalyticsService.getTotalHours(_categoryBreakdown);

    _categoryBreakdown.forEach((category, hours) {
      final percentage = totalHours > 0 ? (hours / totalHours * 100) : 0.0;
      final color = CategoryConstants.getColorFromHex(
        CategoryConstants.getColorHex(category),
      );

      pieChartSections.add(
        PieChartSectionData(
          value: hours,
          title: '${percentage.toStringAsFixed(1)}%',
          color: color,
          radius: 80,
          titleStyle: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: _getContrastColor(color),
          ),
        ),
      );
    });

    return Column(
      children: [
        // Chart
        Expanded(
          child: PieChart(
            PieChartData(
              sections: pieChartSections,
              centerSpaceRadius: 40,
              sectionsSpace: 2,
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Legend
        Wrap(
          spacing: 16,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: _categoryBreakdown.entries.map((entry) {
            final color = CategoryConstants.getColorFromHex(
              CategoryConstants.getColorHex(entry.key),
            );
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${entry.key}: ${entry.value.toStringAsFixed(1)}h',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  Color _getContrastColor(Color color) {
    // Calculate luminance to determine if we need light or dark text
    final luminance = color.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
}

