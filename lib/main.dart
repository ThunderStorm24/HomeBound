import 'dart:async';
import 'package:flutter/material.dart';

import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_foreground_service/flutter_foreground_service.dart';

import 'noti.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HomeBound',
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _addressController = TextEditingController();
  String _distanceText = "";
  Color _distanceTextColor = Colors.grey;
  Position _currentPosition = Position(
    latitude: 0.0,
    longitude: 0.0,
    timestamp: DateTime.now(),
    accuracy: 0,
    altitude: 0,
    heading: 0,
    speed: 0,
    speedAccuracy: 0,
  );
  Position _homePosition = Position(
    latitude: 0.0,
    longitude: 0.0,
    timestamp: DateTime.now(),
    accuracy: 0,
    altitude: 0,
    heading: 0,
    speed: 0,
    speedAccuracy: 0,
  );
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _getHomeLocation();
    Noti.initialize(flutterLocalNotificationsPlugin);
    _timer = Timer.periodic(Duration(seconds: 1), (Timer t) {
      _getCurrentLocation();
      _checkDistance();
    });
  }

  @override
  void dispose() {
    ForegroundService().stop();
    _timer.cancel();
    super.dispose();
  }

  bool isWithin500m(Position currentPosition, Position homePosition) {
    double distanceInMeters = Geolocator.distanceBetween(
      currentPosition.latitude,
      currentPosition.longitude,
      homePosition.latitude,
      homePosition.longitude,
    );
    return distanceInMeters <= _maxDistance;
  }

  _getCurrentLocation() async {
    LocationPermission permision = await Geolocator.checkPermission();
    if (permision == LocationPermission.denied ||
        permision == LocationPermission.deniedForever) {
      print("Permision not granted");
      LocationPermission asked = await Geolocator.requestPermission();
    } else {
      Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best)
          .then((Position position) {
        setState(() {
          _currentPosition = position;
        });
      }).catchError((e) {
        print(e);
      });
    }
  }

  _checkDistance() {
    if (_homePosition.latitude != 0.0 && _homePosition.longitude != 0.0) {
      double distanceInMeters = Geolocator.distanceBetween(
        _homePosition.latitude,
        _homePosition.longitude,
        _currentPosition.latitude,
        _currentPosition.longitude,
      );
      String distanceText;
      Color textColor;
      if (distanceInMeters <= _maxDistance) {
        distanceText = '${distanceInMeters.toStringAsFixed(1)} m';
        textColor = Colors.green;
      } else {
        distanceText = '${distanceInMeters.toStringAsFixed(1)} m';
        textColor = Colors.red;
      }
      setState(() {
        _distanceText = distanceText;
        _distanceTextColor = textColor;
      });
      if (distanceInMeters < _maxDistance && _isSwitched == true) {
        Noti.showBigTextNotification(
          title: "Już prawie w domu!!!",
          body:
              "Znajdujesz się mniej niż ${_maxDistance.toStringAsFixed(1)} m od domu!!!",
          fln: flutterLocalNotificationsPlugin,
        );
        setState(() {
          _isSwitched = false;
        });
      }
    }
  }

  _EditHomeLocation() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('homeLocation',
        '${_homePosition.latitude},${_homePosition.longitude}');
    setState(() {
      _homePosition = _homePosition;
    });
    _getHomeLocation();
  }

  _saveHomeLocation() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('homeLocation',
        '${_currentPosition.latitude},${_currentPosition.longitude}');
    setState(() {
      _homePosition = _currentPosition;
    });
    _getHomeLocation();
  }

  _getHomeLocation() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? homeLocation = prefs.getString('homeLocation');
    if (homeLocation != null) {
      List<String> coordinates = homeLocation.split(',');
      setState(() {
        _homePosition = Position(
          latitude: double.parse(coordinates[0]),
          longitude: double.parse(coordinates[1]),
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
        );
        _addressController.text = homeLocation;
      });
    }
  }

  bool _myBoolean = false;
  bool _isSwitched = false;
  double _maxDistance = 500;
  bool isServiceRunning = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('HomeBound'),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.only(left: 16.0),
                title: Row(
                  children: [
                    Text('Alarm'),
                    Spacer(),
                    Text(_isSwitched ? 'Tak' : 'Nie')
                  ],
                ),
                value: _isSwitched,
                activeColor: Colors.green,
                inactiveTrackColor: Colors.grey,
                inactiveThumbColor: Colors.grey,
                secondary: Icon(
                  _isSwitched ? Icons.check : Icons.close,
                  color: _isSwitched ? Colors.green : Colors.red,
                ),
                onChanged: (value) {
                  setState(() {
                    _isSwitched = value;
                  });
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.only(left: 16.0),
                title: Row(
                  children: [
                    Text('Działanie w tle'),
                    Spacer(),
                    Text(isServiceRunning ? 'Tak' : 'Nie')
                  ],
                ),
                value: isServiceRunning,
                activeColor: Colors.green,
                inactiveTrackColor: Colors.grey,
                inactiveThumbColor: Colors.grey,
                secondary: Icon(
                  isServiceRunning ? Icons.check : Icons.close,
                  color: isServiceRunning ? Colors.green : Colors.red,
                ),
                onChanged: (value) {
                  setState(() {
                    isServiceRunning = value;
                    if (isServiceRunning) {
                      // start ForegroundService
                      ForegroundService().start();
                    } else {
                      // stop ForegroundService
                      ForegroundService().stop();
                    }
                  });
                },
              ),
              SizedBox(height: 90),
              if (_currentPosition != null)
                Text(
                  'Aktualna lokalizacja:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              SizedBox(height: 10),
              Text(
                '${_currentPosition.latitude}, ${_currentPosition.longitude}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              if (_homePosition != null) SizedBox(height: 20),
              Text(
                'Domowy adres:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              SizedBox(height: 10),
              Text(
                '${_homePosition.latitude}, ${_homePosition.longitude}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 10),
              SizedBox(
                width: 300,
                child: ElevatedButton(
                  onPressed: _saveHomeLocation,
                  child: Text('Zapisz obecną lokalizację domu'),
                ),
              ),
              _myBoolean
                  ? Column(
                      children: [
                        SizedBox(height: 15),
                        SizedBox(
                          width: 200.0,
                          child: TextField(
                            controller: _addressController,
                            decoration: InputDecoration(
                              labelText: 'Domowy adres',
                              contentPadding:
                                  EdgeInsets.symmetric(horizontal: 20.0),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.grey),
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.blue),
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                            ),
                            onChanged: (value) {
                              final coordinates = value.split(',');
                              setState(() {
                                _homePosition = Position(
                                  latitude: double.parse(coordinates[0]),
                                  longitude: double.parse(coordinates[1]),
                                  timestamp: DateTime.now(),
                                  accuracy: 0,
                                  altitude: 0,
                                  heading: 0,
                                  speed: 0,
                                  speedAccuracy: 0,
                                );
                              });
                            },
                          ),
                        ),
                        SizedBox(height: 10),
                        SizedBox(
                          width: 300,
                          child: ElevatedButton(
                            onPressed: () {
                              _EditHomeLocation();
                              setState(() {
                                _myBoolean = false;
                              });
                            },
                            child: Text('Zapisz'),
                            style: ElevatedButton.styleFrom(
                              primary: Colors.orange,
                            ), //
                          ),
                        ),
                      ],
                    )
                  : SizedBox(
                      width: 300,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _myBoolean = true;
                          });
                        },
                        child: Text('Edytuj Domowy Adres'),
                        style: ElevatedButton.styleFrom(
                          primary: Colors.orange,
                        ), // ust
                      ),
                    ),
              SizedBox(height: 90),
              Text(
                'Odległość od domu:',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 10),
              Text(
                _distanceText,
                style: TextStyle(
                  fontSize: 30,
                  color: _distanceTextColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 40),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 25.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Min: 200 m'),
                    Spacer(),
                    Text('${_maxDistance.round()} m'),
                    Spacer(),
                    Text('Max: 1000 m'),
                  ],
                ),
              ),
              Slider(
                value: _maxDistance,
                min: 200,
                max: 1000,
                onChanged: (value) {
                  setState(() {
                    _maxDistance = value;
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
