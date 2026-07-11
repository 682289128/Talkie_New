import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

enum MediaType {
  image,
  video,
  audio,
}

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({
    super.key,
  });

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final ImagePicker _picker = ImagePicker();

  File? selectedFile;

  MediaType? selectedType;

  Future<void> pickMedia() async {
    final choice = await showModalBottomSheet<MediaType>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _option(
                Icons.image,
                "Image",
                MediaType.image,
              ),
              _option(
                Icons.video_library,
                "Video",
                MediaType.video,
              ),
              _option(
                Icons.audiotrack,
                "Audio",
                MediaType.audio,
              ),
            ],
          ),
        );
      },
    );

    if (choice == null) return;

    XFile? result;

    if (choice == MediaType.image) {
      result = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
    } else if (choice == MediaType.video) {
      result = await _picker.pickVideo(
        source: ImageSource.gallery,
      );
    } else if (choice == MediaType.audio) {
      // ImagePicker does not support audio
      // We handle this with file_picker later

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Audio picker will be added using file_picker",
          ),
        ),
      );

      return;
    }

    if (result != null) {
      setState(() {
        selectedFile = File(
          result!.path,
        );

        selectedType = choice;
      });
    }
  }

  Widget _option(
    IconData icon,
    String text,
    MediaType type,
  ) {
    return ListTile(
      leading: Icon(
        icon,
        color: const Color(0XFF2563EB),
      ),
      title: Text(text),
      onTap: () {
        Navigator.pop(
          context,
          type,
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();

    Future.delayed(
      Duration.zero,
      pickMedia,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Gallery",
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Center(
        child: selectedFile == null
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 300,
                    width: 300,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.grey.shade200,
                    ),
                    child: selectedType == MediaType.image
                        ? Image.file(
                            selectedFile!,
                            fit: BoxFit.cover,
                          )
                        : Icon(
                            selectedType == MediaType.video
                                ? Icons.video_file
                                : Icons.audio_file,
                            size: 100,
                            color: const Color(0XFF2563EB),
                          ),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    onPressed: () {
                      // NEXT STEP:
                      // Send file to ChatService
                    },
                    icon: const Icon(
                      Icons.send,
                    ),
                    label: Text(
                      selectedType == MediaType.image
                          ? "Send Image"
                          : selectedType == MediaType.video
                              ? "Send Video"
                              : "Send Audio",
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
