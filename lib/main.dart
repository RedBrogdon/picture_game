// Copyright 2024 the Dart project authors. All rights reserved.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file.

import 'dart:math' as math;
import 'dart:math';
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/rendering.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:url_launcher/link.dart';


final wordList = [
  'STAR',
  'HAPPY FACE',
  'MOON',
  'ARROW',
  'DIAMOND',
  'SUN',
  'EARTH',
  'SATURN',
  'PIZZA'
];

void main() {
  runApp(const GenerativeAISample());
}

class GenerativeAISample extends StatelessWidget {
  const GenerativeAISample({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Gemini Picture Game',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark)
      ),
      home: const ChatScreen(title: 'Gemini Picture Game'),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.title});

  final String title;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  String? apiKey;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
        ),
        body: switch (apiKey) {
        final providedKey? => ChatWidgetContainer(apiKey: providedKey),
        _ => ApiKeyWidget(onSubmitted: (key) {
          if (key.toString().isNotEmpty) {
            setState(() => apiKey = key);
          } else {
            showDialog(context: context, builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Invalid API Key'),
                content: const Text('You have entered an empty string for your API key.'),
                actions: [
                  Link(
                    uri: Uri.https('aistudio.google.com', '/app/apikey'),
                    target: LinkTarget.blank,
                    builder: (context, followLink) => TextButton(
                      onPressed: followLink,
                      child: const Text('Get an API Key'),
                    ),
                  ),
                  FilledButton(onPressed: () {Navigator.of(context).pop();}, child: Text("Cancel"))
                ],
              );
            });
          }
          }),
      },
        );
  }
}

class ChatWidgetContainer extends StatefulWidget {
  const ChatWidgetContainer({required this.apiKey, super.key});

  final String apiKey;

  @override
  State<ChatWidgetContainer> createState() => _ChatWidgetContainerState(this.apiKey);
}

class _ChatWidgetContainerState extends State<ChatWidgetContainer> {
  String? apiKey;
  var guessWidgets = <Widget>[];
  final Random _rng = math.Random();

  _ChatWidgetContainerState(this.apiKey);

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox.expand(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16, horizontal: 64),
              child: Text('Click/tap and drag in the rectangle below to make an'
                  ' image, and then hit the "Identify" button to send that'
                  ' image to the Gemini API. The multimodal prompt will ask the'
                  ' model to determine if the image and secret word are a'
                  ' match!'),
            ),
            FilledButton.tonal(
              onPressed: _createNewGuessWidget,
              child: const Text("Add New Attempt"),
            ),
            const SizedBox(height: 24,),
            GridView.count(crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8, shrinkWrap: true,
            children: [
              ...guessWidgets,
              ])
          ],
        ),
      ),
    );
  }

  void _createNewGuessWidget() {
    String secretWord = wordList[_rng.nextInt(wordList.length)];

    setState(() {
      guessWidgets.add(ChatWidget(apiKey: widget.apiKey, secretWord: secretWord,));
    });
  }
}

class ChatWidget extends StatefulWidget {
  ChatWidget({required this.apiKey, super.key, required this.secretWord});

  final String apiKey;
  final String secretWord;

  @override
  State<ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<ChatWidget> {
  final dots = <Offset>[];
  final paintKey = GlobalKey();
  late final IdentificationService _service;
  Future<(bool, String?)>? idResult;
  late String secretWord;

  @override
  void initState() {
    super.initState();
    _service = IdentificationService(widget.apiKey);
    secretWord = widget.secretWord;
  }

  Widget _buildIdButton(bool enabled) {
    return FilledButton(
      onPressed: !enabled
          ? null
          : () async {
              setState(() => idResult = null);
              final bytes = await _captureWidget();
              setState(() {
                idResult = _service.getId(bytes, secretWord);
              });
            },
      child: const Text('Identify'),
    );
  }

  Widget _buildButtonBar(BuildContext context) {
    final theme = Theme.of(context);
      return Column(children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (idResult != null)
              FutureBuilder(
                future: idResult,
                builder: (context, snapshot) {
                  return _buildIdButton(snapshot.hasData);
                },
              )
            else
              _buildIdButton(dots.isNotEmpty),
            const SizedBox(width: 32),
            FilledButton(style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.errorContainer, foregroundColor: theme.colorScheme.onErrorContainer),

              onPressed: dots.isEmpty ? null :() => setState(() {
                dots.clear();
                idResult = null;
              }),
              child: const Text('Clear'),
            ),
          ],
        ),
        if (idResult != null)
          FutureBuilder(
            future: idResult,
            builder: (context, snapshot) {
              if (snapshot.data?.$1 == true) {
                return const StatusWidget('Correct!');
              } else if (snapshot.data?.$1 == false) {
                final result =
                    "Not a match. Gemini responded with: ${snapshot.data?.$2 ?? ""}";
                return StatusWidget(result);
              } else {
                return const StatusWidget('Thinking...');
              }
            },
          )
        else
          const StatusWidget(''),
      ]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    const width = 400.0;
    const height = 300.0;

    return SizedBox(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Secret word:  $secretWord',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: theme.colorScheme.outline,
                  style: BorderStyle.solid,
                  width: 1.0,
                ),
              ),
              child: RepaintBoundary(
                key: paintKey,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: GestureDetector(
                        onPanUpdate: (details) {
                          setState(() {
                            // reject gesture events outside the selected space
                            if (details.localPosition.dx > width - 5 ||
                                details.localPosition.dx < 0 ||
                                details.localPosition.dy < 0 ||
                                details.localPosition.dy > height - 5) {
                              // eat the event
                            } else {
                              dots.add(details.localPosition);
                            }
                          });
                        },
                        //
                      ),
                    ),
                    CustomPaint(painter: DrawingPainter(dots, width, height)),
                  ],
                ),
              ),
            ),
            //const SizedBox(height: 16),
            //PaletteWidget(),
            const SizedBox(height: 16,),
            ///fd
            _buildButtonBar(context),
          ],
        ),
      ),
    );
  }

  Future<Uint8List> _captureWidget() async {
    final RenderRepaintBoundary boundary =
        paintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage();
    final ByteData byteData =
        (await image.toByteData(format: ui.ImageByteFormat.png))!;
    final Uint8List pngBytes = byteData.buffer.asUint8List();
    return pngBytes;
  }
}

class DrawingPainter extends CustomPainter {
  DrawingPainter(this.dots, this.width, this.height);

  List<Offset> dots;
  double width;
  double height;

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    for (final dot in dots) {
      canvas.drawRect(Rect.fromLTWH(dot.dx, dot.dy, 2.0, 2.0),
          Paint()..color = Colors.green);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
    //return dots == (oldDelegate as DrawingPainter).dots;
  }
}

class StatusWidget extends StatelessWidget {
  final String status;

  const StatusWidget(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ConstrainedBox(
      constraints: BoxConstraints.loose(const Size(400,64)),
      child: Center(
        child: Text(
          status,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.tertiary,
          ),
        ),
      ),
    );
  }
}

InputDecoration textFieldDecoration(BuildContext context, String hintText) =>
    InputDecoration(
      contentPadding: const EdgeInsets.all(15),
      hintText: hintText,
      border: OutlineInputBorder(
        borderRadius: const BorderRadius.all(
          Radius.circular(14),
        ),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.secondary,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(
          Radius.circular(14),
        ),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.secondary,
        ),
      ),
    );

class IdentificationService {
  final String apiKey;

  late final GenerativeModel model;

  final generationConfig = GenerationConfig(
    temperature: 0.4,
    topK: 32,
    topP: 1,
    maxOutputTokens: 4096,
  );

  final safetySettings = [
    SafetySetting(HarmCategory.harassment, HarmBlockThreshold.medium),
    SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.medium),
    SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.medium),
    SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.medium),
  ];

  IdentificationService(this.apiKey) {
    model = GenerativeModel(model: 'gemini-pro-vision', apiKey: apiKey);
  }

  Future<(bool, String?)> getId(Uint8List pngBytes, String symbolName) async {
    final prompt = [
      Content.multi([
        DataPart('image/jpeg', pngBytes),
        TextPart('Does this image contain a $symbolName? Answer "yes" or'
            ' "no". If the answer is no, tell me what is identified'),
      ]),
    ];

    try {
      final response = await model.generateContent(
        prompt,
        safetySettings: safetySettings,
        generationConfig: generationConfig,
      );
      print(response.text);
      if (response.text?.toLowerCase().contains('yes') ?? false) {
        return (true, "");
      }

      if (response.text?.toLowerCase().contains('no') ?? false) {
        final parts = response.text?.split("\n");
        return (false, parts?.last);
      }

      return (false, "Unknown Object");
    } on GenerativeAIException {
      return (false, "Unknown object");
    }
  }
}

class ApiKeyWidget extends StatelessWidget {
  ApiKeyWidget({required this.onSubmitted, super.key});

  final ValueChanged onSubmitted;
  final TextEditingController _textController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    double viewWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'To use the Gemini API, you\'ll need an API key. '
                  'If you don\'t already have one, '
                  'create a key in Google AI Studio.',
            ),
            const SizedBox(height: 8),
            Link(
              uri: Uri.https('aistudio.google.com', '/app/apikey'),
              target: LinkTarget.blank,
              builder: (context, followLink) => TextButton(
                onPressed: followLink,
                child: const Text('Get an API Key'),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  SizedBox(
                    width: viewWidth *0.85,
                    height: 48,
                    child: TextField(
                      maxLines: 1,
                      decoration:
                      textFieldDecoration(context, 'Enter your API key'),
                      controller: _textController,
                      onSubmitted: (value) {
                        onSubmitted(value);
                      },
                    ),
                  ),

                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      onSubmitted(_textController.value.text);
                    },
                    child: const Text('Submit'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PaletteWidget extends StatefulWidget {

  @override
  State<PaletteWidget> createState() => _PaletteWidgetState();
}

class _PaletteWidgetState extends State<PaletteWidget> {
  Color selectedColor = Colors.black;
  List<Color> colors = [
    Colors.white, Colors.red,
    Colors.orange, Colors.yellow, Colors.green, Colors.blue, Colors.indigo, Colors.purple
  ];
  late List<Widget> colorChips = [];

  @override
  void initState() {
    _buildColorChips();
  }

  void _buildColorChips() {
    for (Color color in colors) {
      var g = GestureDetector(child: Container(color: color, height: 10, width: 50,));
      colorChips.add(g);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GridView.count(crossAxisCount: 10, shrinkWrap: true, children: colorChips,);
  }
}
