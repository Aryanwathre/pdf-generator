import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_painter_v2/flutter_painter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class CanvasScreen extends StatefulWidget {
  @override
  _CanvasScreenState createState() => _CanvasScreenState();
}

class _CanvasScreenState extends State<CanvasScreen> {
  static const Color red = Color(0xFFFF0000);
  FocusNode textFocusNode = FocusNode();
  TextEditingController _fontSizeController = TextEditingController();
  FocusNode _fontSizeFocusNode = FocusNode();
  late PainterController controller;
  Paint shapePaint = Paint()
    ..strokeWidth = 5
    ..color = Colors.black
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  ObjectDrawable? selectedDrawable;


  @override
  void initState() {
    super.initState();
    controller = PainterController(
      settings: PainterSettings(
        text: TextSettings(
          focusNode: textFocusNode,
          textStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
            fontSize: 18,
          ),
        ),
        shape: ShapeSettings(
          paint: shapePaint,

        ),
        scale: const ScaleSettings(
          enabled: true,
          minScale: 1,
          maxScale: 5,
        ),
      ),
    );

    textFocusNode.addListener(onFocus);
  }

  void onFocus() {
    setState(() {});
  }
  Future<void> addImage(PainterController controller) async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final ui.Image image = await decodeImageFromList(
        await File(pickedFile.path).readAsBytes(),
      );

      const double canvasWidth = 595;
      const double canvasHeight = 842;

      double scaleX = canvasWidth / image.width;
      double scaleY = canvasHeight / image.height;
      double scale = (scaleX < scaleY) ? scaleX : scaleY;

      double newWidth = image.width * scale;
      double newHeight = image.height * scale;

      if (newWidth > canvasWidth) {
        newWidth = canvasWidth;
      }
      if (newHeight > canvasHeight) {
        newHeight = canvasHeight;
      }

      controller.addImage(image, Size(newWidth, newHeight));
    }
  }


  Future<void> printCanvas() async {
    final image = await controller.renderImage(const Size(595, 842)); // A4 Size
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List imageBytes = byteData!.buffer.asUint8List();

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Image(
              pw.MemoryImage(imageBytes),
              width: 595,
              height: 842,
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  Widget buildDefault(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("A4 Drawing App"),
        actions: [
          IconButton(icon: Icon(PhosphorIcons.printer()), onPressed: printCanvas),
          IconButton(
            icon: Icon(PhosphorIcons.trash()),
            onPressed: controller.selectedObjectDrawable == null ? null : removeSelectedDrawable,
          ),
          IconButton(
            icon: Icon(PhosphorIcons.arrowClockwise()),
            onPressed: controller.canRedo ? redo : null,
          ),
          IconButton(
            icon: Icon(PhosphorIcons.arrowCounterClockwise()),
            onPressed: controller.canUndo ? undo : null,
          ),
        ],
      ),

      body: Column(
        children: [
          if (selectedDrawable != null && Platform.isMacOS || Platform.isLinux || Platform.isWindows ) buildEditorPanel(),
          Align(
            alignment: Alignment.center,
            child: Container(
              alignment: Alignment.topCenter,
              width: (Platform.isAndroid || Platform.isIOS) ? MediaQuery.of(context).size.width * 0.9 : 595,
              height: (Platform.isAndroid || Platform.isIOS) ? MediaQuery.of(context).size.height * 0.62 : 842,
              padding: (Platform.isAndroid || Platform.isIOS) ? EdgeInsets.all(8) : EdgeInsets.zero,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
              ),
              child: FlutterPainter(
                controller: controller,
                onSelectedObjectDrawableChanged: (drawable) {
                  setState(() {
                    selectedDrawable = drawable;
                    if (drawable is TextDrawable) {
                      _fontSizeController.text = drawable.style.fontSize?.toString() ?? "18";
                      _fontSizeFocusNode.requestFocus();
                    }
                  });
                },
              ),
            ),
          ),
          if (selectedDrawable != null && Platform.isAndroid || Platform.isIOS ) buildEditorPanel(),
        ],
      ),

      bottomNavigationBar: ValueListenableBuilder(
        valueListenable: controller,
        builder: (context, _, __) => SizedBox(
          height: 100,
          child: BottomAppBar(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                IconButton(icon: Icon(PhosphorIcons.textT()), onPressed: addText),
                PopupMenuButton<ShapeFactory?>(
                  tooltip: "Add shape",
                  itemBuilder: (context) => <ShapeFactory, String>{
                    LineFactory(): "Line",
                    ArrowFactory(): "Arrow",
                    DoubleArrowFactory(): "Double Arrow",
                    RectangleFactory(): "Rectangle",
                    OvalFactory(): "Oval",
                  }
                      .entries
                      .map((e) => PopupMenuItem(
                    value: e.key,
                    child: Row(
                      children: [Icon(getShapeIcon(e.key)), Text(" ${e.value}")],
                    ),
                  ))
                      .toList(),
                  onSelected: selectShape,
                  child: Icon(getShapeIcon(controller.shapeFactory)),
                ),
                IconButton(icon: Icon(Icons.image), onPressed: () => addImage(controller)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return buildDefault(context);
  }

  static IconData getShapeIcon(ShapeFactory? shapeFactory) {
    if (shapeFactory is LineFactory) return PhosphorIcons.lineSegment();
    if (shapeFactory is ArrowFactory) return PhosphorIcons.arrowUpRight();
    if (shapeFactory is DoubleArrowFactory) {
      return PhosphorIcons.arrowsHorizontal();
    }
    if (shapeFactory is RectangleFactory) return PhosphorIcons.rectangle();
    if (shapeFactory is OvalFactory) return PhosphorIcons.circle();
    return PhosphorIcons.polygon();
  }

  void undo() {
    controller.undo();
  }

  void redo() {
    controller.redo();
  }

  void addText() {
    if (controller.freeStyleMode != FreeStyleMode.none) {
      controller.freeStyleMode = FreeStyleMode.none;
    }
    controller.addText();
  }

  void setFreeStyleStrokeWidth(double value) {
    controller.freeStyleStrokeWidth = value;
  }

  void setFreeStyleColor(double hue) {
    controller.freeStyleColor = HSVColor.fromAHSV(1, hue, 1, 1).toColor();
  }

  void setTextFontSize(double size) {
    setState(() {
      controller.textSettings = controller.textSettings.copyWith(
        textStyle:
        controller.textSettings.textStyle.copyWith(fontSize: size),
      );
    });
  }

  void setShapeFactoryPaint(Paint paint) {
    setState(() {
      controller.shapePaint = paint;
    });
  }

  void setTextColor(double hue) {
    controller.textStyle = controller.textStyle
        .copyWith(color: HSVColor.fromAHSV(1, hue, 1, 1).toColor());
  }

  void selectShape(ShapeFactory? factory) {
    controller.shapeFactory = factory;
  }

  void removeSelectedDrawable() {
    final selectedDrawable = controller.selectedObjectDrawable;
    if (selectedDrawable != null) controller.removeDrawable(selectedDrawable);
  }

  void flipSelectedImageDrawable() {
    final imageDrawable = controller.selectedObjectDrawable;
    if (imageDrawable is! ImageDrawable) return;

    controller.replaceDrawable(
      imageDrawable,
      imageDrawable.copyWith(flipped: !imageDrawable.flipped),
    );
  }

  void _pickTextColor(TextDrawable drawable) {
    showDialog(
      context: context,
      builder: (context) {
        Color newColor = drawable.style.color ?? Colors.black;

        return AlertDialog(
          title: Text("Pick a Color"),
          content: BlockPicker(
            pickerColor: newColor,
            onColorChanged: (color) {
              newColor = color;
            },
          ),
          actions: [
            TextButton(
              child: Text("OK"),
              onPressed: () {
                _updateTextStyle(
                  drawable,
                  drawable.style.copyWith(color: newColor),
                );
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  void _pickShapeColor(ShapeDrawable drawable) {
    showDialog(
      context: context,
      builder: (context) {
        Color newColor = drawable.paint.color;

        return AlertDialog(
          title: Text("Pick a Color"),
          content: BlockPicker(
            pickerColor: newColor,
            onColorChanged: (color) {
              newColor = color;
            },
          ),
          actions: [
            TextButton(
              child: Text("OK"),
              onPressed: () {
                _updateShapeStyle(
                  drawable,
                  drawable.paint.copyWith(color: newColor),
                );
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }


  void _updateTextStyle(TextDrawable drawable, TextStyle newStyle) {
    final updatedDrawable = drawable.copyWith(style: newStyle);
    controller.replaceDrawable(drawable, updatedDrawable);
    setState(() {
      selectedDrawable = updatedDrawable;
    });
  }

  void _updateShapeStyle(ShapeDrawable drawable, Paint newPaint) {
    final updatedDrawable = drawable.copyWith(paint: newPaint);
    controller.replaceDrawable(drawable, updatedDrawable);
    setState(() {
      selectedDrawable = updatedDrawable;
    });
  }

  Widget buildShapeEditor() {
    if (selectedDrawable is! ShapeDrawable) return SizedBox();

    ShapeDrawable shape = selectedDrawable as ShapeDrawable;

    return SizedBox(
      width: double.infinity,
      child: Container(
        padding: EdgeInsets.all(10),
        color: Colors.white,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Color: "),
                GestureDetector(
                  onTap: () => _pickShapeColor(shape),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: shape.paint.color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black),
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(
              width: double.infinity,
              child: Row(
                children: [
                  Text("Stroke Width: "),
                  Flexible(
                    child: Slider(
                      min: 1,
                      max: 20,
                      value: shape.paint.strokeWidth,
                      onChanged: (value) {
                        _updateShapeStyle(
                          shape,
                          shape.paint.copyWith(strokeWidth: value),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),


            SizedBox(
              width: double.infinity,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Fill Shape"),
                  Switch(
                    value: shape.paint.style == PaintingStyle.fill,
                    onChanged: (value) {
                      _updateShapeStyle(
                        shape,
                        shape.paint.copyWith(
                          style: value ? PaintingStyle.fill : PaintingStyle.stroke,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget buildTextEditor() {
    if (selectedDrawable is! TextDrawable) return SizedBox();

    TextDrawable textDrawable = selectedDrawable as TextDrawable;

    return (Platform.isMacOS || Platform.isLinux || Platform.isWindows)
        ? SizedBox(
      width: double.infinity, // Ensuring a defined width
      child: Container(
        padding: EdgeInsets.all(10),
        color: Colors.white,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Color: "),
                GestureDetector(
                  onTap: () => _pickTextColor(textDrawable),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: textDrawable.style.color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black),
                    ),
                  ),
                ),
              ],
            ),


            SizedBox(
              width: double.infinity,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Font Size: "),
                  SizedBox(
                    width: 60,
                    child: TextField(
                      controller: _fontSizeController,
                      focusNode: _fontSizeFocusNode,
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        double? newSize = double.tryParse(value);
                        if (newSize != null) {
                          _updateTextStyle(
                            textDrawable,
                            textDrawable.style.copyWith(fontSize: newSize),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),


            SizedBox(
              width: double.infinity,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Font: "),
                  DropdownButton<String>(
                    value: textDrawable.style.fontFamily ?? "Roboto",
                    items: ["Roboto", "Arial", "Times New Roman"].map((String font) {
                      return DropdownMenuItem<String>(
                        value: font,
                        child: Text(font),
                      );
                    }).toList(),
                    onChanged: (newFont) {
                      if (newFont != null) {
                        _updateTextStyle(
                          textDrawable,
                          textDrawable.style.copyWith(fontFamily: newFont),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),

            SizedBox(
              width: double.infinity,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Font Weight: "),
                  DropdownButton<FontWeight>(
                    value: textDrawable.style.fontWeight ?? FontWeight.normal,
                    items: [
                      DropdownMenuItem(value: FontWeight.w100, child: Text("Thin")),
                      DropdownMenuItem(value: FontWeight.w400, child: Text("Normal")),
                      DropdownMenuItem(value: FontWeight.w700, child: Text("Bold")),
                      DropdownMenuItem(value: FontWeight.w900, child: Text("Extra Bold")),
                    ],
                    onChanged: (newWeight) {
                      if (newWeight != null) {
                        _updateTextStyle(
                          textDrawable,
                          textDrawable.style.copyWith(fontWeight: newWeight),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    )
        : Container(
      height: 90,
      padding: EdgeInsets.all(8),
      color: Colors.white,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Column(
            children: [
              Text("Color: "),
              SizedBox(height: 10),
              GestureDetector(
                onTap: () => _pickTextColor(textDrawable),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: textDrawable.style.color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(width: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Font Size: "),
              SizedBox(
                width: 60,
                child:TextField(
                  controller: _fontSizeController,
                  focusNode: _fontSizeFocusNode,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,

                  style: TextStyle(fontSize: 12),
                  onChanged: (value) {
                    double? newSize = double.tryParse(value);
                    if (newSize != null) {
                      _updateTextStyle(
                        textDrawable,
                        textDrawable.style.copyWith(fontSize: newSize),
                      );
                    }
                  },
                )

              ),
            ],
          ),
          SizedBox(width: 10),
          Column(
            children: [
              Text("Font: "),
              SizedBox(
                width: 100, // Adjust width as needed
                child: DropdownButton<String>(
                  value: textDrawable.style.fontFamily ?? "Roboto",
                  isDense: true,
                  isExpanded: false,
                  style: TextStyle(fontSize: 12, color: Colors.black, overflow: TextOverflow.ellipsis),
                  items: ["Roboto", "Arial", "Times New Roman"].map((String font) {
                    return DropdownMenuItem<String>(
                      value: font,
                      child: Text(font, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (newFont) {
                    if (newFont != null) {
                      _updateTextStyle(
                        textDrawable,
                        textDrawable.style.copyWith(fontFamily: newFont),
                      );
                    }
                  },
                ),
              )

            ],
          ),
          SizedBox(width: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              DropdownButton<FontWeight>(
                value: textDrawable.style.fontWeight ?? FontWeight.normal,
                items: [
                  DropdownMenuItem(value: FontWeight.w100, child: Text("Thin")),
                  DropdownMenuItem(value: FontWeight.w400, child: Text("Normal")),
                  DropdownMenuItem(value: FontWeight.w700, child: Text("Bold")),
                  DropdownMenuItem(value: FontWeight.w900, child: Text("Extra Bold")),
                ],
                onChanged: (newWeight) {
                  if (newWeight != null) {
                    _updateTextStyle(
                      textDrawable,
                      textDrawable.style.copyWith(fontWeight: newWeight),
                    );
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget buildEditorPanel() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          if (selectedDrawable is TextDrawable) buildTextEditor(),
          if (selectedDrawable is ShapeDrawable) buildShapeEditor(),
        ],
      ),
    );
  }


}
