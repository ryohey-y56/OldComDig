import 'dart:io';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:external_path/external_path.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:collection/collection.dart';
import 'package:photofilters/filters/color_filters.dart' as filters;
//import 'package:photofilters/filters/filters.dart';
import 'package:photofilters/filters/subfilters.dart';
import 'package:photofilters/utils/image_filter_utils.dart';

Future<void> main() async {
  // main 関数内で非同期処理を呼び出すための設定
  WidgetsFlutterBinding.ensureInitialized();

  // デバイスで使用可能なカメラのリストを取得
  final cameras = await availableCameras();
  for (var cameraElement in cameras) {
    debugPrint('$cameraElement');
  }
  // 利用可能なカメラのリストから特定のカメラを取得
  final firstCamera = cameras.elementAt(0);
  //画面を絶対横向きにする
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(MyApp(camera: firstCamera));
}

class MyApp extends StatelessWidget {
  const MyApp({
    Key? key,
    required this.camera,
  }) : super(key: key);

  final CameraDescription camera;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Camera Test',
      theme: ThemeData(),
      home: TakePictureScreen(camera: camera),
    );
  }
}

class TakePictureScreen extends StatefulWidget {
  const TakePictureScreen({
    Key? key,
    required this.camera,
  }) : super(key: key);

  final CameraDescription camera;

  @override
  TakePictureScreenState createState() => TakePictureScreenState();
}

class TakePictureScreenState extends State<TakePictureScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  @override
  void initState() {
    super.initState();

    _controller = CameraController(
      // カメラを指定
      widget.camera,
      // 解像度を定義
      ResolutionPreset.medium,
    );

    // コントローラーを初期化
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    // ウィジェットが破棄されたら、コントローラーを破棄
    _controller.dispose();
    super.dispose();
  }

  //UIはここに追加
  @override
  Widget build(BuildContext context) {
    // FutureBuilder で初期化を待ってからプレビューを表示（それまではインジケータを表示）
    return Scaffold(
        body: Center(
          child: FutureBuilder<void>(
            future: _initializeControllerFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                //上からフィルターかける(取った写真にはフィルターはかからない)
                /*return ColorFiltered(
                    colorFilter: ColorFilter.mode(
                        Color.fromARGB(255, 102, 7, 204).withOpacity(0.3),
                        BlendMode.srcATop),
                    child: */
                return CameraPreview(_controller);
              } else {
                return const CircularProgressIndicator();
              }
            },
          ),
        ),
        floatingActionButton: Row(
          //mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            //画像を開く
            FloatingActionButton(
              heroTag: "btn1",
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) =>
                        DisplayGallalyScreen(imagefile: loadimage())));
                final picker = ImagePicker();
                picker.pickImage(source: ImageSource.gallery);
              },
              child: const Icon(Icons.image),
            ),
            //写真を撮る
            FloatingActionButton(
              heroTag: "btn2",
              onPressed: () async {
                var cameraFilter = AddictiveColorSubFilter(100, 100, 100);
                //cameraFilter.addSubFilter(RGBScaleSubFilter(100, 100, 100));
                final image = await _controller.takePicture();
                var decodedImage = img.decodeImage(await image.readAsBytes());
                if (decodedImage == null) {
                  debugPrint('failed to decode image');
                  return;
                }
                Uint8List bytefile = await File(image.path).readAsBytes();
                debugPrint(
                    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa${bytefile.length}  &  ${decodedImage.width}  &  ${decodedImage.height}');
                //cameraFilter.apply(bytefile, decodedImage.width, decodedImage.height);
                for (int i = 0; i + 2 < bytefile.length; i += 4) {
                  bytefile[i] = clampPixel(bytefile[i] + 255);
                  bytefile[i + 1] = clampPixel(bytefile[i + 1] + 0);
                  bytefile[i + 2] = clampPixel(bytefile[i + 2] + 0);
                }
                //List<int> Jpegdata = img.encodeJpg(decodedImage);
                final file = File(image.path);
                file.writeAsBytes(bytefile);
                saveimage(file);
                //final Uint8List buffer = await image.readAsBytes();
                //await ImageGallerySaver.saveImage(buffer, name: image.name);
                //表示用の画面に遷移
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        DisplayPictureScreen(imagepath: file.path),
                    fullscreenDialog: true,
                  ),
                );
              },
              child: const Icon(Icons.camera_alt),
            )
          ],
        ));
  }
}

//画像の保存
Future<void> saveimage(File file) async {
  final tempDir = await getTemporaryDirectory();
  const albumName = 'oldComDig';

  // create save directory
  if (Platform.isAndroid) {
    final picturesPath = await ExternalPath.getExternalStoragePublicDirectory(
      ExternalPath.DIRECTORY_PICTURES,
    );
    final albumPath = '$picturesPath/$albumName';
    debugPrint(albumPath);
    // If directory does not exist, create directory before writing.
    await Directory(albumPath).create(recursive: true);
  }

  final now = DateTime.now();
  DateFormat outputFormat = DateFormat('yyyy-MM-dd_HH-mm_ssS');
  final fileName = '${outputFormat.format(now)}.jpg';
  debugPrint('file name: $fileName');

  final uint8list = file.readAsBytesSync();
  final List<int> fileByte = uint8list;
  file = File('${tempDir.path}/$fileName')..writeAsBytesSync(fileByte);
  debugPrint('temp file path: ${file.path}');
  final permissionState = await PhotoManager.requestPermissionExtend();
  if (!permissionState.isAuth) {
    debugPrint('Please allow access and try again.');
    return;
  }

  // save image
  final assetEntity = await PhotoManager.editor.saveImageWithPath(
    file.path,
    title: fileName,
    relativePath: Platform.isAndroid ? 'Pictures/$albumName' : albumName,
  );
  debugPrint('assetEntity: $assetEntity');

  // iOS needs tagging to image.
  if (Platform.isIOS) {
    final paths = await PhotoManager.getAssetPathList();
    var assetPathEntity = paths.firstWhereOrNull((e) => e.name == albumName);
    // If album does not exist, you also need to use the createAlbum method before copying.
    assetPathEntity ??= await PhotoManager.editor.darwin.createAlbum(albumName);
    await PhotoManager.editor.copyAssetToPath(
      asset: assetEntity!,
      pathEntity: assetPathEntity!,
    );
  }

  // clear cache
  file.deleteSync(recursive: true);
  debugPrint('completed!');
}

//画像の読み込み
File loadimage() {
  debugPrint('loadimage');
  String? albumpath;
  if (Platform.isAndroid) {
    final imagepath = ExternalPath.getExternalStoragePublicDirectory(
        ExternalPath.DIRECTORY_PICTURES);
    albumpath = '$imagepath/OldComDig';
  }
  if (Platform.isIOS) {
    albumpath = getTemporaryDirectory().toString();
  }
  File imagefile = File(albumpath ?? '/aaaaa');
  debugPrint('loadimage2');
  return imagefile;
}

//撮影した写真を表示する画面
class DisplayPictureScreen extends StatelessWidget {
  const DisplayPictureScreen({Key? key, required this.imagepath})
      : super(key: key);

  final String imagepath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('撮れた写真')),
      body: _buildImage(),
      );
  }

  Widget _buildImage() {
    final file = File(imagepath);

    if (!file.existsSync()) {
      return Text('File does not exist at path: $imagepath');
    }

    try {
      return Image.file(file);
    } catch (e) {
      return Text('Failed to load image: $e');
    }
  }
}

//このアプリで取った写真を見る
class DisplayGallalyScreen extends StatelessWidget {
  const DisplayGallalyScreen({Key? key, required this.imagefile})
      : super(key: key);
  final File imagefile;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('いったん')),
      body: Center(child: Image.file(imagefile)),
    );
  }
}
