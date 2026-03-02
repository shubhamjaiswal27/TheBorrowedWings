/// Utilities for IGC file format coordinate and altitude formatting.
/// 
/// Provides functions to format coordinates, altitudes, and other data
/// according to the IGC specification for flight data exchange.
class IgcUtils {
  /// Convert decimal degrees latitude to IGC DDMMmmmN/S format
  static String formatLatitude(double latitude) {
    final isNorth = latitude >= 0;
    final absLat = latitude.abs();
    
    final degrees = absLat.floor();
    final minutes = (absLat - degrees) * 60;
    final minutesInt = minutes.floor();
    final minutesFrac = ((minutes - minutesInt) * 1000).round();
    
    final hemisphereChar = isNorth ? 'N' : 'S';
    
    return '${degrees.toString().padLeft(2, '0')}'
        '${minutesInt.toString().padLeft(2, '0')}'
        '${minutesFrac.toString().padLeft(3, '0')}'
        '$hemisphereChar';
  }

  /// Convert decimal degrees longitude to IGC DDDMMmmmE/W format
  static String formatLongitude(double longitude) {
    final isEast = longitude >= 0;
    final absLon = longitude.abs();
    
    final degrees = absLon.floor();
    final minutes = (absLon - degrees) * 60;
    final minutesInt = minutes.floor();
    final minutesFrac = ((minutes - minutesInt) * 1000).round();
    
    final hemisphereChar = isEast ? 'E' : 'W';
    
    return '${degrees.toString().padLeft(3, '0')}'
        '${minutesInt.toString().padLeft(2, '0')}'
        '${minutesFrac.toString().padLeft(3, '0')}'
        '$hemisphereChar';
  }

  /// Format altitude in meters to IGC 5-digit format (00000-99999)
  static String formatAltitude(int? altitudeM) {
    if (altitudeM == null) {
      return '00000';
    }
    
    // Clamp altitude to valid IGC range
    final clampedAltitude = altitudeM.clamp(-9999, 99999);
    
    if (clampedAltitude < 0) {
      // Handle negative altitudes (below sea level)
      return (100000 + clampedAltitude).toString().padLeft(5, '0');
    }
    
    return clampedAltitude.toString().padLeft(5, '0');
  }

  /// Format time as HHMMSS for IGC records
  static String formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}'
        '${dateTime.minute.toString().padLeft(2, '0')}'
        '${dateTime.second.toString().padLeft(2, '0')}';
  }

  /// Format date as DDMMYY for IGC header
  static String formatDate(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}'
        '${dateTime.month.toString().padLeft(2, '0')}'
        '${(dateTime.year % 100).toString().padLeft(2, '0')}';
  }

  /// Generate A record (manufacturer and logger ID)
  static String generateARecord() {
    // A record format: AXXXLOGGERID where XXX is manufacturer code
    // Using 'FLT' as manufacturer code for Flutter app
    const manufacturerCode = 'FLT';
    const loggerId = 'PARAGLIDINGLOG'; // Up to 13 characters
    return 'A$manufacturerCode$loggerId';
  }

  /// Generate H record for date (HFDTE)
  static String generateDateHeader(DateTime flightDate) {
    return 'HFDTE${formatDate(flightDate)}';
  }

  /// Generate pilot and crew header
  static String generatePilotHeader(String pilotName) {
    // Clean pilot name - remove special characters, limit length
    final cleanName = pilotName
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .trim()
        .toUpperCase();
    
    final truncatedName = cleanName.length > 50 
        ? cleanName.substring(0, 50) 
        : cleanName;
    
    return 'HFPLTPILOTINCHARGE:$truncatedName';
  }

  /// Generate glider type header
  static String generateGliderTypeHeader(String manufacturer, String model) {
    final cleanManufacturer = manufacturer
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .trim()
        .toUpperCase();
    
    final cleanModel = model
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .trim()
        .toUpperCase();
    
    final gliderInfo = cleanManufacturer.isNotEmpty 
        ? '$cleanManufacturer $cleanModel'
        : cleanModel;
    
    final truncatedInfo = gliderInfo.length > 50
        ? gliderInfo.substring(0, 50)
        : gliderInfo;
    
    return 'HFGTYGLIDERTYPE:$truncatedInfo';
  }

  /// Generate glider ID header
  static String generateGliderIdHeader(String? gliderId) {
    if (gliderId == null || gliderId.isEmpty) {
      return 'HFGIDGLIDERID:';
    }
    
    final cleanId = gliderId
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .trim()
        .toUpperCase();
    
    final truncatedId = cleanId.length > 30
        ? cleanId.substring(0, 30)
        : cleanId;
    
    return 'HFGIDGLIDERID:$truncatedId';
  }

  /// Generate GPS datum header
  static String generateGpsDatumHeader() {
    return 'HFGPSRECEIVER:FLUTTERAPP,WGS84';
  }

  /// Generate firmware version header
  static String generateFirmwareHeader() {
    return 'HFFIRMWAREVERSION:PARAGLIDINGLOG1.0';
  }

  /// Generate comment line (L record)
  static String generateComment(String comment) {
    // L records are free-form comments
    final cleanComment = comment
        .replaceAll(RegExp(r'[\r\n]'), ' ')
        .trim();
    
    return 'LPARAGLIDINGLOG:$cleanComment';
  }

  /// Validate IGC coordinate format
  static bool isValidLatitudeFormat(String latString) {
    // Should be format: DDMMmmmN or DDMMmmmS
    final regex = RegExp(r'^\d{7}[NS]$');
    return regex.hasMatch(latString);
  }

  /// Validate IGC longitude format
  static bool isValidLongitudeFormat(String lonString) {
    // Should be format: DDDMMmmmE or DDDMMmmmW
    final regex = RegExp(r'^\d{8}[EW]$');
    return regex.hasMatch(lonString);
  }

  /// Validate IGC altitude format
  static bool isValidAltitudeFormat(String altString) {
    // Should be 5 digits
    final regex = RegExp(r'^\d{5}$');
    return regex.hasMatch(altString);
  }

  /// Validate IGC time format
  static bool isValidTimeFormat(String timeString) {
    // Should be HHMMSS
    final regex = RegExp(r'^\d{6}$');
    return regex.hasMatch(timeString);
  }

  /// Generate B record from flight fix data
  /// Format: BHHMMSSDDMMmmmNDDDMMmmmEAxxxxx yyyyy
  static String generateBRecord(
    DateTime timestamp,
    double latitude,
    double longitude,
    int? pressureAltM,
    int? gpsAltM,
  ) {
    final timeStr = formatTime(timestamp);
    final latStr = formatLatitude(latitude);
    final lonStr = formatLongitude(longitude);
    final validityFlag = 'A'; // A = valid, V = invalid
    final pressureAltStr = formatAltitude(pressureAltM);
    final gpsAltStr = formatAltitude(gpsAltM);
    
    return 'B$timeStr$latStr$lonStr$validityFlag$pressureAltStr$gpsAltStr';
  }

  /// Calculate checksum for data integrity (if needed)
  static String calculateChecksum(List<String> lines) {
    // Simple XOR checksum
    int checksum = 0;
    for (final line in lines) {
      for (final char in line.codeUnits) {
        checksum ^= char;
      }
    }
    return checksum.toRadixString(16).toUpperCase().padLeft(2, '0');
  }

  /// Sanitize filename for IGC export
  static String sanitizeFilename(String filename) {
    return filename
        .replaceAll(RegExp(r'[^\w\s-.]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
  }

  /// Generate IGC filename from flight data
  static String generateIgcFilename(DateTime flightDate, String gliderModel) {
    final dateStr = '${flightDate.year}'
        '${flightDate.month.toString().padLeft(2, '0')}'
        '${flightDate.day.toString().padLeft(2, '0')}';
    
    final timeStr = '${flightDate.hour.toString().padLeft(2, '0')}'
        '${flightDate.minute.toString().padLeft(2, '0')}';
    
    final sanitizedModel = sanitizeFilename(gliderModel)
        .replaceAll('_', '')
        .toLowerCase();
    
    final modelPrefix = sanitizedModel.isNotEmpty 
        ? '${sanitizedModel.substring(0, sanitizedModel.length > 8 ? 8 : sanitizedModel.length)}_'
        : '';
    
    return '${modelPrefix}${dateStr}_$timeStr.igc';
  }
}