import 'package:flutter/material.dart';

class AttachmentMenu extends StatefulWidget {
  final VoidCallback? onGallery;
  final VoidCallback? onCamera;
  final VoidCallback? onContacts;
  final VoidCallback? onDocuments;
  final VoidCallback? onImages;

  const AttachmentMenu({
    super.key,
    this.onGallery,
    this.onCamera,
    this.onContacts,
    this.onDocuments,
    this.onImages,
  });

  @override
  State<AttachmentMenu> createState() => _AttachmentMenuState();
}

class _AttachmentMenuState extends State<AttachmentMenu> {
  OverlayEntry? _overlayEntry;

  void _showMenu(BuildContext context) {
    if (_overlayEntry != null) {
      _removeMenu();
      return;
    }

    final overlay = Overlay.of(context);

    final renderBox = context.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            // Close when tapping outside
            Positioned.fill(
              child: GestureDetector(
                onTap: _removeMenu,
                behavior: HitTestBehavior.translucent,
                child: Container(),
              ),
            ),

            Positioned(
              left: 12,

              // Places it exactly above input field
              bottom: MediaQuery.of(context).viewInsets.bottom + 25,

              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.80,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 0,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _item(
                        Icons.photo_library_rounded,
                        "Gallery",
                        Colors.purple,
                        widget.onGallery,
                      ),
                      _item(
                        Icons.camera_alt_rounded,
                        "Camera",
                        Colors.redAccent,
                        widget.onCamera,
                      ),
                      _item(
                        Icons.contacts_rounded,
                        "Contacts",
                        Colors.blue,
                        widget.onContacts,
                      ),
                      _item(
                        Icons.attach_file_rounded,
                        "Files",
                        Colors.orange,
                        widget.onDocuments,
                      ),
                      _item(
                        Icons.location_pin,
                        "Location",
                        Colors.green,
                        widget.onImages,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    overlay.insert(_overlayEntry!);
  }

  Widget _item(
    IconData icon,
    String title,
    Color color,
    VoidCallback? action,
  ) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(0),

        // pressed effect
        splashColor: color.withOpacity(0.18),
        highlightColor: Colors.grey.withOpacity(0.12),

        onTap: () {
          _removeMenu();
          action?.call();
        },

        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 8,
            horizontal: 16,
          ),
          child: Row(
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _removeMenu() {
    _overlayEntry?.remove();

    _overlayEntry = null;
  }

  @override
  void dispose() {
    _removeMenu();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      child: IconButton(
        icon: const Icon(
          Icons.attach_file,
          color: Color.fromARGB(255, 102, 102, 102),
          size: 24,
          shadows: [
            Shadow(
              blurRadius: 0.5,
              color: Colors.black,
            )
          ],
        ),
        onPressed: () => _showMenu(context),
      ),
    );
  }
}
