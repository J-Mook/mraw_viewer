import 'dart:ffi';
import 'dart:io';

import 'package:provider/provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:rinf/rinf.dart';
import 'package:file_picker/file_picker.dart';
import 'package:window_manager/window_manager.dart';
import 'package:desktop_drop/desktop_drop.dart';


import './messages/generated.dart';
import './messages/mooksviewer.pb.dart';

import './RGBpage.dart';
import './themeprovider.dart';
import './rawimageprovider.dart';

void main() async {
  await initializeRust();

  WidgetsFlutterBinding.ensureInitialized();
  // await WindowManager.instance.ensureInitialized();
  // windowManager.waitUntilReadyToShow().then((_) async {
  //   await windowManager.setTitleBarStyle(
  //     TitleBarStyle.hidden,
  //     windowButtonVisibility: false,
  //   );
  //   // await windowManager.setMinimumSize(const Size(500, 600));
  //   await windowManager.show();
  //   await windowManager.focus();
  //   await windowManager.setPreventClose(true);
  //   await windowManager.setSkipTaskbar(false);
  // });

  await windowManager.ensureInitialized();
  WindowOptions windowOptions = WindowOptions(
    // size: Size(800, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider( create: (context) => ThemeProvider(), ),
        ChangeNotifierProvider( create: (context) => RawImageProvider(), ),
      ],
      child: MainApp()
    )
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: "jmook",
      initialRoute: '/',
      routes: {
        '/' : (context) => MRawViewer(),
        '/home' : (context) => MRawViewer(),
        '/rgb' : (context) => RGBPage(),
      },
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: themeProvider.themeMode,

      debugShowCheckedModeBanner: false,
    );
  }
}

class MRawViewer extends StatelessWidget {
  MRawViewer({super.key});

  ThemeMode _themeMode = ThemeMode.system;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("             Mook's Viewer", style: TextStyle(fontSize: 15),),
        toolbarHeight: 35.0,
        // leading: IconButton(
        //     onPressed:() => exit(0),
        //     icon: const Icon(Icons.close)
        //   ),
        actions: <Widget>[
          Text("Dark Mode "),
          Switch(
            value: themeProvider.isDarkMode,
            inactiveTrackColor: Colors.black38,
            activeColor: Colors.white38,
            onChanged: (value) {
              themeProvider.toggleTheme(value);
            },
          ),
          IconButton(
            onPressed:() {
              Navigator.pushNamed(context, '/rgb');
            },
            icon: const Icon(Icons.palette)
          ),
        ],
      ),
      body: ViewerBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // setState(() { Navigator.pushNamed(context, '/RandColor'); });
        },
        child: const Icon(Icons.link),
      ),
    );
  }
}

class ViewerBody extends StatefulWidget {
  const ViewerBody({super.key});

  @override
  State<ViewerBody> createState() => _ViewerBodyState();
}

class _ViewerBodyState extends State<ViewerBody> {

  String mrawpath = "";
  String str_height = "";
  String str_width = "";
  bool opened = false;

  @override
  Widget build(BuildContext context) {
    final rawImageProvider = Provider.of<RawImageProvider>(context);

    return Column(
      children: [
        SizedBox(height: 10,width: 1100,),
        SizedBox(height: 35,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Flexible(
                child: Container(
                  constraints: BoxConstraints(maxWidth: 150),
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Width',
                    ),
                    onChanged: (value) { if (value.isNotEmpty){ str_width = value; } },
                  ),
                ),
              ),
              Flexible(
                child: Container(
                  constraints: BoxConstraints(maxWidth: 150),
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Height',
                    ),
                    onChanged: (value) { if (value.isNotEmpty){ str_height = value; }}
                  ),
                ),
              ),
              Spacer(),
              opened ? ElevatedButton(
                onPressed:() {
                  MessagePlayControl(cmd: 'Close', data: 0).sendSignalToRust(null);
                  opened = false;
                  setState(() { });
                },
                child: Row( children: [ Icon(Icons.close), Text(" Close"), ], )
              ) : ElevatedButton(
                onPressed:() async {
                  FilePickerResult? result = await FilePicker.platform.pickFiles();
                  if (result != null) { mrawpath = result.files.single.path!; }

                  MessageOpenFile(
                    filepath: mrawpath,
                    height: int.parse(str_height) > 0 ? int.parse(str_height) : 0,
                    width: int.parse(str_width) > 0 ? int.parse(str_width) : 0,
                    byte: 0,
                    head: 0,
                    tail: 0
                  ).sendSignalToRust(null);

                  rawImageProvider.height = int.parse(str_height) > 0 ? int.parse(str_height) : 0;
                  rawImageProvider.width = int.parse(str_width) > 0 ? int.parse(str_width) : 0;
                  opened = true;
                  // setState(() { });
                },
                child: Row( children: [ Icon(Icons.file_open), Text(" Open"), ], )
              ),
            ],
          ),
        ),
        Text(mrawpath),

        Stack(
          children: [
            Center(child: VideoArea()),
            context.watch<RawImageProvider>().ishoverImage ? Center(child: PlayController()) : Text(""),
          ],
        ),
      ],
    );
  }
}

class VideoArea extends StatefulWidget {
  const VideoArea({super.key});

  @override
  State<VideoArea> createState() => _VideoAreaState();
}

class _VideoAreaState extends State<VideoArea> {

  @override
  Widget build(BuildContext pcontext) {
    // final rawImageProvider = Provider.of<RawImageProvider>(pcontext);
    return MouseRegion(
      onEnter: (event) { pcontext.read<RawImageProvider>().setHover(true); },
      onExit: (event) { pcontext.read<RawImageProvider>().setHover(false); },
      child: StreamBuilder(
        stream: MessageRaw.rustSignalStream,
        builder: (context, snapshot) {
          final rustSignal = snapshot.data;
          if (rustSignal == null) {
            pcontext.read<RawImageProvider>().setImageSize(640, 480);
            return Container(
              margin: const EdgeInsets.all(20),
              width: 640,
              height: 480,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24.0),
                color: Colors.black,
              ),
            );
          }
      
          final imageData = rustSignal.blob!;
          final msg = rustSignal.message;
          pcontext.read<RawImageProvider>().setImageSize(msg.width.toInt(), msg.height.toInt());
          pcontext.read<RawImageProvider>().setIdx(msg.curidx.toInt());
          pcontext.read<RawImageProvider>().maxidx = msg.endidx.toInt() - 1;

          return Container(
            margin: const EdgeInsets.fromLTRB(20, 20, 20, 7),
            width: msg.width.toDouble(),
            height: msg.height.toDouble(),
            
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24.0),
              child: FittedBox(
                fit: BoxFit.contain,
                child: Image.memory(
                  imageData,
                  width: msg.width.toDouble(),
                  height: msg.height.toDouble(),
                  gaplessPlayback: true,
                ),
              ),
            ),
          );
        }
      ),
    );
  }
}

class PlayController extends StatefulWidget {
  const PlayController({super.key});

  @override
  State<PlayController> createState() => _PlayControllerState();
}

class _PlayControllerState extends State<PlayController> {
  static double controllerSize = 50;
  static double siderSize = 20;
  double silderValue = 0;
  double silderMax = 1;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final rawImageProvider = Provider.of<RawImageProvider>(context);
    silderMax = context.watch<RawImageProvider>().maxidx.toDouble();

    return MouseRegion(
      onEnter: (event) { context.read<RawImageProvider>().setHover(true); },
      onExit: (event) { context.read<RawImageProvider>().setHover(false); },
      child: Column(
        children: [
          SizedBox(height: rawImageProvider.height > (controllerSize + siderSize) ? rawImageProvider.height - (controllerSize + siderSize) : 0,),
          SizedBox(
            height: siderSize,
            width: rawImageProvider.width.toDouble(),
            child: Slider(
              value: context.watch<RawImageProvider>().curidx.toDouble(),
              max: silderMax,
              onChanged: (value) {
                MessagePlayControl(cmd: 'Jump', data: value).sendSignalToRust(null);
                setState(() { });
              },
            ),
          ),
          SizedBox(height: 5),
          Container(
            width: 200, height: controllerSize,
            decoration: BoxDecoration(
              color: themeProvider.isDarkMode ? Color.fromARGB(142, 0, 0, 0) : Color.fromARGB(218, 255, 255, 255),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed:() {
                    MessagePlayControl(cmd: 'Play', data: 0).sendSignalToRust(null);
                  },
                  icon: Icon(Icons.play_arrow,)
                ),
                IconButton(
                  onPressed:() {
                    MessagePlayControl(cmd: 'Pause', data: 0).sendSignalToRust(null);
                  },
                  icon: Icon(Icons.pause)
                ),
                IconButton(
                  onPressed:() {
                    MessagePlayControl(cmd: 'Stop', data: 0).sendSignalToRust(null);
                  },
                  icon: Icon(Icons.stop)
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}