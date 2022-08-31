import 'dart:async';
import 'package:background_fetch/background_fetch.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

Future<void> makeRequest() async {
  try {
    BackgroundFetch.scheduleTask(
      TaskConfig(
        taskId: "com.transistorsoft.customtask",
        delay: 1000,
        periodic: false,
        forceAlarmManager: true,
        stopOnTerminate: false,
        enableHeadless: true,
      ),
    );

    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    var url = Uri.https('testios.free.beeceptor.com', 'my/api/path', {
      'latitude': position.latitude.toString(),
      'longitude': position.longitude.toString(),
    });

    print(position.latitude.toString());

    var response = await http.get(url);
    print(response);
  } catch (e) {
    print(e);
  }
}

// [Android-only] This "Headless Task" is run when the Android app
// is terminated with enableHeadless: true
void backgroundFetchHeadlessTask(HeadlessTask task) async {
  await makeRequest();

  print('[BackgroundFetch] main Headless event received.');
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
  BackgroundFetch.registerHeadlessTask(backgroundFetchHeadlessTask);
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late LocationSettings locationSettings;
  late StreamSubscription<Position> positionStream;
  bool isEnable = false;

  void _configureBackgroundFetch() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    setState(() {
      isEnable = prefs.getBool('isEnable') ?? false;
    });

    BackgroundFetch.configure(
        BackgroundFetchConfig(
          minimumFetchInterval: 15,
          startOnBoot: true,
          stopOnTerminate: false,
          enableHeadless: true,
          requiresStorageNotLow: false,
          requiresBatteryNotLow: false,
          requiresCharging: false,
          requiresDeviceIdle: false,
          requiredNetworkType: NetworkType.ANY,
        ), (String taskId) async {
      await makeRequest();

      print("[BackgroundFetch] michael taskId: $taskId");

      BackgroundFetch.finish(taskId);
    });
  }

  @override
  void initState() {
    super.initState();

    _determinePosition();
    _configureBackgroundFetch();

    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        // forceLocationManager: true,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText:
              "Example app will continue to receive your location even when you aren't using it",
          notificationTitle: "Running in Background",
          // enableWakeLock: true,
        ),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.high,
        pauseLocationUpdatesAutomatically: true,
        showBackgroundLocationIndicator: false,
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
      );
    }
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text(
            'BackgroundFetch Example',
            style: TextStyle(color: Colors.black),
          ),
          backgroundColor: Colors.amberAccent,
        ),
        body: Center(
          child: InkWell(
            onTap: () async {
              if (!isEnable) {
                BackgroundFetch.scheduleTask(
                  TaskConfig(
                    taskId: "com.transistorsoft.customtask",
                    delay: 1000,
                    periodic: true,
                    forceAlarmManager: true,
                    stopOnTerminate: false,
                    enableHeadless: true,
                  ),
                );
              } else {
                BackgroundFetch.stop('com.transistorsoft.customtask');
              }

              SharedPreferences prefs = await SharedPreferences.getInstance();

              print('Test');

              setState(() {
                isEnable = !isEnable;
                prefs.setBool('isEnable', isEnable);
              });
            },
            child: Container(
              width: 100,
              height: 100,
              color: Colors.red,
              alignment: Alignment.center,
              child: Text(!isEnable ? 'Start' : 'Stop'),
            ),
          ),
        ),
      ),
    );
    // return Scaffold(
    //   appBar: AppBar(
    //     title: const Text('Test app'),
    //   ),
    //   body: Center(
    //     child: Column(
    //       mainAxisAlignment: MainAxisAlignment.center,
    //       children: <Widget>[
    //         Text(
    //           isEnable ? 'is start' : 'is Stop',
    //         ),
    //       ],
    //     ),
    //   ),
    //   floatingActionButton: FloatingActionButton(
    //     onPressed: _getMyLocation,
    //     tooltip: 'Increment',
    //     child: const Icon(Icons.add),
    //   ),
    // );
  }
}
