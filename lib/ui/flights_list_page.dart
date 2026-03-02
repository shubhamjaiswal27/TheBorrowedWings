import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/flight.dart';
import '../models/glider.dart';
import '../db/flight_dao.dart';
import '../igc/igc_writer.dart';
import 'flight_details_page.dart';

/// Page displaying list of recorded flights with options to view, export, and manage.
class FlightsListPage extends StatefulWidget {
  const FlightsListPage({super.key});

  @override
  State<FlightsListPage> createState() => _FlightsListPageState();
}

class _FlightsListPageState extends State<FlightsListPage> {
  final FlightDao _flightDao = FlightDao();
  final IgcWriter _igcWriter = IgcWriter();
  
  List<Map<String, dynamic>> _flightsWithGliders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFlights();
  }

  Future<void> _loadFlights() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final flightsWithGliders = await _flightDao.getAllFlightsWithGliders();
      if (mounted) {
        setState(() {
          _flightsWithGliders = flightsWithGliders;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackBar('Failed to load flights: $e');
      }
    }
  }

  Future<void> _exportFlight(Flight flight) async {
    try {
      _showLoadingSnackBar('Exporting flight...');
      
      final result = await _igcWriter.exportFlight(flight.id!);
      
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      
      if (result.success && result.filePath != null) {
        await Share.shareXFiles(
          [XFile(result.filePath!)],
          text: 'Flight log from ${flight.formattedDate}',
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

  Future<void> _deleteFlight(Flight flight) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Flight'),
        content: Text(
          'Are you sure you want to delete the flight from ${flight.formattedDate}?\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _flightDao.deleteFlight(flight.id!);
        _loadFlights();
        _showSuccessSnackBar('Flight deleted successfully');
      } catch (e) {
        _showErrorSnackBar('Failed to delete flight: $e');
      }
    }
  }

  void _viewFlightDetails(Flight flight, Glider glider) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FlightDetailsPage(
          flight: flight,
          glider: glider,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flight Log'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFlights,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _flightsWithGliders.isEmpty
              ? _buildEmptyState()
              : _buildFlightsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.flight,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No Flights Yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start recording your first flight from the home screen',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.home),
              label: const Text('Go to Home'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlightsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: _flightsWithGliders.length,
      itemBuilder: (context, index) {
        final item = _flightsWithGliders[index];
        final flight = item['flight'] as Flight;
        final glider = item['glider'] as Glider;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
          child: InkWell(
            onTap: () => _viewFlightDetails(flight, glider),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              flight.formattedDate,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              glider.displayName,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildFlightStatusChip(flight),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoItem(
                          Icons.schedule,
                          'Time',
                          flight.timeRange,
                        ),
                      ),
                      Expanded(
                        child: _buildInfoItem(
                          Icons.timer,
                          'Duration',
                          flight.isCompleted 
                              ? flight.formattedFlightDuration
                              : flight.formattedRecordingDuration,
                        ),
                      ),
                      Expanded(
                        child: _buildInfoItem(
                          Icons.gps_fixed,
                          'Fixes',
                          '${flight.fixCount}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => _viewFlightDetails(flight, glider),
                        icon: const Icon(Icons.visibility),
                        label: const Text('View'),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () => _exportFlight(flight),
                        icon: const Icon(Icons.share),
                        label: const Text('Export IGC'),
                      ),
                      const SizedBox(width: 8),
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          switch (value) {
                            case 'delete':
                              _deleteFlight(flight);
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Delete'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFlightStatusChip(Flight flight) {
    Color chipColor;
    String statusText;
    IconData statusIcon;

    if (flight.isCompleted) {
      chipColor = Colors.green;
      statusText = 'Completed';
      statusIcon = Icons.check_circle;
    } else if (flight.isInProgress) {
      chipColor = Colors.orange;
      statusText = 'In Progress';
      statusIcon = Icons.flight;
    } else if (flight.isWaitingForTakeoff) {
      chipColor = Colors.blue;
      statusText = 'Waiting';
      statusIcon = Icons.schedule;
    } else {
      chipColor = Colors.grey;
      statusText = 'Incomplete';
      statusIcon = Icons.warning;
    }

    return Chip(
      avatar: Icon(statusIcon, size: 18, color: Colors.white),
      label: Text(
        statusText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: chipColor,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
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
        duration: const Duration(minutes: 1), // Long duration for loading
      ),
    );
  }
}