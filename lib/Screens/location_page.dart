import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

class LocationPage extends StatelessWidget {
  final String elderlyId;

  const LocationPage({super.key, required this.elderlyId});

  Future<void> _openInGoogleMaps(double lat, double lng) async {
    final Uri googleMapsUrl = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );

    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF1B3A52);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.location),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('elderly_locations')
            .doc(elderlyId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(
              child: Text(
                AppLocalizations.of(context)!.noLocationAvailable,
                style: TextStyle(fontSize: 20),
              ),
            );
          }
          final loc = AppLocalizations.of(context)!;
          final data = snapshot.data!.data() as Map<String, dynamic>;

          final double lat = (data['latitude'] as num).toDouble();
          final double lng = (data['longitude'] as num).toDouble();

          final updatedAt = data['updatedAt'] as Timestamp?;
          final timeText = updatedAt != null
              ? updatedAt.toDate().toString().substring(0, 16)
              : loc.noTime;

          final position = LatLng(lat, lng);

          return Column(
            children: [
              Expanded(
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: position,
                    zoom: 16,
                  ),
                  markers: {
                    Marker(
                      markerId: const MarkerId('elderly_location'),
                      position: position,
                      infoWindow: InfoWindow(title: loc.elderlyLocation),
                    ),
                  },
                  myLocationEnabled: false,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: true,
                ),
              ),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(22),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 12,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.elderlyCurrentLocation,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: primary,
                      ),
                    ),

                    const SizedBox(height: 14),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.place, color: Colors.teal),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${loc.latitude}: $lat${loc.longitude}: $lng',
                            style: const TextStyle(fontSize: 16, height: 1.4),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        const Icon(Icons.access_time, color: Colors.teal),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${loc.lastUpdate}: $timeText',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: primary,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => _openInGoogleMaps(lat, lng),
                        icon: const Icon(Icons.map_outlined),
                        label: Text(
                          loc.openInGoogleMaps,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
