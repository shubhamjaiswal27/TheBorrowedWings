import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/flight.dart';
import '../models/flight_fix.dart';
import '../models/glider.dart';
import '../db/flight_dao.dart';
import '../igc/igc_writer.dart';

/// Detailed view of a specific flight with summary and GPS fix preview.
class FlightDetailsPage extends StatefulWidget {
  final Flight flight;
  final Glider glider;

  const FlightDetailsPage({
    super.key,
    required this.flight,
    required this.glider,
  });

  @override
  State<FlightDetailsPage> createState() => _FlightDetailsPageState();
}

class _FlightDetailsPageState extends State<FlightDetailsPage> {
  final FlightDao _flightDao = FlightDao();
  final IgcWriter _igcWriter = IgcWriter();
  
  List<FlightFix> _firstFixes = [];
  List<FlightFix> _lastFixes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFlightFixPreviews();
  }

  Future<void> _loadFlightFixPreviews() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final firstFixes = await _flightDao.getFlightFixesPreview(widget.flight.id!, limit: 5);
      final lastFixes = await _flightDao.getFlightFixesLast(widget.flight.id!, limit: 5);
      
      if (mounted) {
        setState(() {
          _firstFixes = firstFixes;
          _lastFixes = lastFixes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackBar('Failed to load flight details: $e');
      }
    }
  }

  Future<void> _exportFlight() async {
    try {
      _showLoadingSnackBar('Exporting flight...');
      
      final result = await _igcWriter.exportFlight(widget.flight.id!);
      
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      
      if (result.success && result.filePath != null) {
        await Share.shareXFiles(
          [XFile(result.filePath!)],
          text: 'Flight log from ${widget.flight.formattedDate}',
        );
        _showSuccessSnackBar('Flight exported successfully!');
      } else {
        _showErrorSnackBar(result.error ?? 'Export failed');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _showErrorSnackBar('Export error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Flight ${widget.flight.formattedDate}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _exportFlight,
            tooltip: 'Export IGC',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFlightSummaryCard(),
                  const SizedBox(height: 16),
                  _buildGliderInfoCard(),
                  const SizedBox(height: 16),
                  _buildFlightMetricsCard(),
                  const SizedBox(height: 16),
                  if (_firstFixes.isNotEmpty) ...[
                    _buildFixesPreviewCard('Start of Flight', _firstFixes),
                    const SizedBox(height: 16),
                  ],
                  if (_lastFixes.isNotEmpty && widget.flight.isCompleted) ...[
                    _buildFixesPreviewCard('End of Flight', _lastFixes),
                    const SizedBox(height: 16),
                  ],
                  _buildActionsCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildFlightSummaryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flight, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Flight Summary',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),
            _buildSummaryRow('Date', widget.flight.formattedDate),
            _buildSummaryRow('Time Range', widget.flight.timeRange),
            _buildSummaryRow('Status', _getFlightStatusText()),
            if (widget.flight.isCompleted) ...[
              _buildSummaryRow('Flight Duration', widget.flight.formattedFlightDuration),
            ],
            _buildSummaryRow('Recording Duration', widget.flight.formattedRecordingDuration),
            _buildSummaryRow('GPS Fixes', '${widget.flight.fixCount}'),
          ],
        ),
      ),
    );
  }

  Widget _buildGliderInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.paragliding, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Glider Information',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),
            _buildSummaryRow('Model', widget.glider.displayName),
            if (widget.glider.wingClass != null)
              _buildSummaryRow('Class', widget.glider.wingClass!),
            if (widget.glider.gliderId != null)
              _buildSummaryRow('Registration', widget.glider.gliderId!),
          ],
        ),
      ),
    );
  }

  Widget _buildFlightMetricsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Flight Metrics',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    icon: Icons.schedule,
                    label: 'Recording Time',
                    value: widget.flight.formattedRecordingDuration,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricCard(
                    icon: Icons.gps_fixed,
                    label: 'GPS Fixes',
                    value: '${widget.flight.fixCount}',
                  ),
                ),
              ],
            ),
            if (widget.flight.isCompleted) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.flight_takeoff,
                      label: 'Takeoff Time',
                      value: widget.flight.takeoffAt != null
                          ? '${widget.flight.takeoffAt!.hour.toString().padLeft(2, '0')}:'
                            '${widget.flight.takeoffAt!.minute.toString().padLeft(2, '0')}'
                          : '--:--',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.flight_land,
                      label: 'Landing Time',
                      value: widget.flight.landedAt != null
                          ? '${widget.flight.landedAt!.hour.toString().padLeft(2, '0')}:'
                            '${widget.flight.landedAt!.minute.toString().padLeft(2, '0')}'
                          : '--:--',
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFixesPreviewCard(String title, List<FlightFix> fixes) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 20,
                dataRowMinHeight: 32,
                dataRowMaxHeight: 32,
                headingRowHeight: 40,
                columns: const [
                  DataColumn(label: Text('Time')),
                  DataColumn(label: Text('Lat')),
                  DataColumn(label: Text('Lon')),
                  DataColumn(label: Text('Alt (m)')),
                  DataColumn(label: Text('Speed')),
                ],
                rows: fixes.map((fix) {
                  return DataRow(cells: [
                    DataCell(Text(fix.formattedTime)),
                    DataCell(Text(fix.latitude.toStringAsFixed(6))),
                    DataCell(Text(fix.longitude.toStringAsFixed(6))),
                    DataCell(Text(fix.bestAltitudeM?.toString() ?? '--')),
                    DataCell(Text(fix.speedKmh?.toStringAsFixed(1) ?? '--')),
                  ]);
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Actions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _exportFlight,
                    icon: const Icon(Icons.share),
                    label: const Text('Export IGC'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Export your flight as an IGC file to share with other pilots or upload to flight analysis websites.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  String _getFlightStatusText() {
    if (widget.flight.isCompleted) {
      return 'Completed';
    } else if (widget.flight.isInProgress) {
      return 'In Progress';
    } else if (widget.flight.isWaitingForTakeoff) {
      return 'Waiting for Takeoff';
    } else {
      return 'Incomplete';
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showLoadingSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            ),
            const SizedBox(width: 16),
            Text(message),
          ],
        ),
        duration: const Duration(minutes: 1),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        children: [
          Icon(icon, color: Theme.of(context).primaryColor),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}