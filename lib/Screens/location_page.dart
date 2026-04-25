import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';

class LocationPage extends StatelessWidget {
  final String elderlyId;

  const LocationPage({
    super.key,
    required this.elderlyId,
  });

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
            return const Center(
              child: Text(
                "No location available",
                style: TextStyle(fontSize: 20),
              ),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          final double lat = (data['latitude'] as num).toDouble();
          final double lng = (data['longitude'] as num).toDouble();

          final updatedAt = data['updatedAt'] as Timestamp?;
          final timeText = updatedAt != null
              ? updatedAt.toDate().toString().substring(0, 16)
              : "No time";

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
                      infoWindow: const InfoWindow(
                        title: 'Elderly Location',
                      ),
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
                    const Text(
                      "Elderly Current Location",
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
                            "Latitude: $lat\nLongitude: $lng",
                            style: const TextStyle(
                              fontSize: 16,
                              height: 1.4,
                            ),
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
                            "Last update: $timeText",
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
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