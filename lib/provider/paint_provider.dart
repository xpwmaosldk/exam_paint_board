import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:paint_board/model/line_info.dart';
import 'package:permission_handler/permission_handler.dart';

class PaintProvider extends ChangeNotifier {
  final lines = <LineInfo>[];
  final lineHistory = <LineInfo>[];
  final GlobalKey captureKey = GlobalKey();
  bool _outOfRange = false;
  Uint8List? backgroundImageData;
  Uint8List? loadImageData;

  String _mode = 'PEN';
  String get mode => _mode;

  void changeMode(String mode) {
    _mode = mode;
    notifyListeners();
  }

  void drawStart(Offset offset) {
    lineHistory.clear();
    _startPint(offset);
  }

  void drawing(Offset offset) {
    if (_outOfRange && offset.dy > 0) {
      _startPint(offset);
      _outOfRange = false;
    }

    if (offset.dy > 0) {
      _movePint(offset);
    } else {
      _outOfRange = true;
    }
  }

  void _startPint(Offset offset) {
    var oneLine = LineInfo(_mode);
    oneLine.points.add(offset);
    lines.add(oneLine);
    notifyListeners();
  }

  void _movePint(Offset offset) {
    lines.last.points.add(offset);
    notifyListeners();
  }

  void save() async {
    if (await _checkPermission()) {
      var renderObject = captureKey.currentContext?.findRenderObject();

      if (renderObject is RenderRepaintBoundary) {
        ui.Image image = await renderObject.toImage();

        ByteData? byteData =
            await image.toByteData(format: ui.ImageByteFormat.png);

        Uint8List pngBytes = byteData!.buffer.asUint8List();

        final result = await ImageGallerySaver.saveImage(
          pngBytes,
          quality: 100,
          name: 'capture_${DateFormat('HH_mm_ss').format(DateTime.now())}',
        );

        print(result);
      }
    }
  }

  Future<bool> _checkPermission() async {
    var status = await Permission.storage.status;

    if (!status.isGranted) {
      status = await Permission.storage.request();
    }

    return status.isGranted;
  }

  void load() async {
    var result = await _pickImage(false);
    if (result) _clearData();
  }

  void _clearData() {
    lines.clear();
    lineHistory.clear();
    backgroundImageData = null;
  }

  void add() {
    _pickImage(true);
  }

  Future<bool> _pickImage(bool isAdd) async {
    final PickedFile? pickedFile =
        await ImagePicker().getImage(source: ImageSource.gallery);

    if (pickedFile == null) return false;

    if (isAdd) {
      backgroundImageData = await pickedFile.readAsBytes();
    } else {
      loadImageData = await pickedFile.readAsBytes();
    }

    notifyListeners();
    return true;
  }

  void back() {
    if (lines.isNotEmpty) {
      lineHistory.add(lines.removeLast());
      notifyListeners();
    }
  }

  void forward() {
    if (lineHistory.isNotEmpty) {
      lines.add(lineHistory.removeLast());
      notifyListeners();
    }
  }
}
