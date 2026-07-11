import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final ImagePicker _picker = ImagePicker();

  File? capturedFile;

  bool isVideo = false;

  Future<void> openCamera() async {
    // First try taking a photo
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        capturedFile = File(image.path);
        isVideo = false;
      });

      return;
    }

    // If no photo, allow video capture
    final XFile? video = await _picker.pickVideo(
      source: ImageSource.camera,
    );

    if (video != null) {
      setState(() {
        capturedFile = File(video.path);
        isVideo = true;
      });
    }
  }

  @override
  void initState() {
    super.initState();

    openCamera();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Camera",
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Center(
        child: capturedFile == null
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 320,
                    width: 300,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.grey.shade200,
                    ),
                    child: isVideo
                        ? const Center(
                            child: Icon(
                              Icons.video_file_rounded,
                              size: 80,
                              color: Color(0XFF2563EB),
                            ),
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.file(
                              capturedFile!,
                              fit: BoxFit.cover,
                            ),
                          ),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    onPressed: () {
                      // Later:
                      // Send media through ChatService
                    },
                    icon: const Icon(
                      Icons.send,
                    ),
                    label: Text(
                      isVideo ? "Send Video" : "Send Image",
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0XFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  )
                ],
              ),
      ),
    );
  }
}
