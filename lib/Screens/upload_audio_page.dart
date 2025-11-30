import 'package:flutter/material.dart';

class UploadAudioPage extends StatefulWidget {
  const UploadAudioPage({super.key});

  @override
  State<UploadAudioPage> createState() => _UploadAudioPageState();
}

class _UploadAudioPageState extends State<UploadAudioPage> {
  String? selectedFile;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Upload Audio')),
      body: Center(
        child: Text(
          "Coming Soon",
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: const Color.fromARGB(255, 51, 60, 116),
          ),
        ),
      ),
      // Padding(
      //   padding: const EdgeInsets.all(16),
      //   child: SingleChildScrollView(
      //     child: Column(
      //       crossAxisAlignment: CrossAxisAlignment.start,
      //       children: [
      //         // 🔹 Preview / Placeholder
      //         Container(
      //           height: 200,
      //           width: double.infinity,
      //           decoration: BoxDecoration(
      //             color: cs.primaryContainer.withOpacity(.5),
      //             borderRadius: BorderRadius.circular(16),
      //           ),
      //           child: const Center(
      //             child: Icon(Icons.upload_file, size: 70, color: Colors.black54),
      //           ),
      //         ),

      //         const SizedBox(height: 24),

      //         // 🔹 Audio title
      //         const Text(
      //           "Audio Title",
      //           style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      //         ),
      //         const SizedBox(height: 8),
      //         TextField(
      //           decoration: InputDecoration(
      //             hintText: "Enter audio title...",
      //             border: OutlineInputBorder(
      //               borderRadius: BorderRadius.circular(12),
      //             ),
      //             prefixIcon: const Icon(Icons.title),
      //           ),
      //         ),

      //         const SizedBox(height: 24),

      //         // 🔹 Card: Choose Audio File
      //         _uploadCard(
      //           context,
      //           icon: Icons.folder_open,
      //           title: "Choose Audio File",
      //           subtitle: selectedFile ?? "No file selected yet",
      //           onTap: () {
      //             // TODO: Replace with file picker later
      //             setState(() => selectedFile = "example_audio.mp3");
      //             ScaffoldMessenger.of(context).showSnackBar(
      //               const SnackBar(content: Text("File picker will open soon.")),
      //             );
      //           },
      //         ),

      //         const SizedBox(height: 24),

      //         // 🔹 Upload button
      //         SizedBox(
      //           width: double.infinity,
      //           height: 55,
      //           child: ElevatedButton.icon(
      //             icon: const Icon(Icons.cloud_upload, size: 26 ,color: Colors.white,),
      //             label: const Text(
      //               "Upload",
      //               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,  color: Colors.white,),
      //             ),
      //             onPressed: () {
      //               if (selectedFile == null) {
      //                 ScaffoldMessenger.of(context).showSnackBar(
      //                   const SnackBar(
      //                     content: Text("Please choose a file first."),
      //                   ),
      //                 );
      //               } else {
      //                 ScaffoldMessenger.of(context).showSnackBar(
      //                   const SnackBar(
      //                       content: Text("Audio uploaded successfully!")),
      //                 );
      //               }
      //             },
      //             style: ElevatedButton.styleFrom(
      //               backgroundColor: const Color(0xFF2A4D69),
      //               shape: RoundedRectangleBorder(
      //                 borderRadius: BorderRadius.circular(14),
      //               ),
      //             ),
      //           ),
      //         ),
      //       ],
      //     ),
      //   ),
      // ),
    );
  }

  // 🔹 Custom card widget
  // Widget _uploadCard(
  //   BuildContext context, {
  //   required IconData icon,
  //   required String title,
  //   required String subtitle,
  //   required VoidCallback onTap,
  // }) {
  //   final cs = Theme.of(context).colorScheme;

  //   return Card(
  //     elevation: 0,
  //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  //     child: InkWell(
  //       borderRadius: BorderRadius.circular(16),
  //       onTap: onTap,
  //       child: Padding(
  //         padding: const EdgeInsets.all(14),
  //         child: Row(
  //           children: [
  //             Container(
  //               padding: const EdgeInsets.all(12),
  //               decoration: BoxDecoration(
  //                 color: cs.primaryContainer.withOpacity(.5),
  //                 borderRadius: BorderRadius.circular(14),
  //               ),
  //               child: Icon(icon, size: 26, color: Colors.black87),
  //             ),
  //             const SizedBox(width: 16),
  //             Expanded(
  //               child: Column(
  //                 crossAxisAlignment: CrossAxisAlignment.start,
  //                 children: [
  //                   Text(
  //                     title,
  //                     style: const TextStyle(
  //                       fontWeight: FontWeight.bold,
  //                       fontSize: 17,
  //                     ),
  //                   ),
  //                   const SizedBox(height: 4),
  //                   Text(
  //                     subtitle,
  //                     style: TextStyle(
  //                       color: Colors.grey.shade700,
  //                       fontSize: 15,
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             ),
  //             const Icon(Icons.chevron_right, color: Colors.black54),
  //           ],
  //         ),
  //       ),
  //     ),
  //   );
  // }
}
