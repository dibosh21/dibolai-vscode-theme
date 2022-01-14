import 'package:colorcode/Component/Layout/widgets/PureAndDirect/Buttons/button_elevated_custom.dart';
import 'package:colorcode/Component/Layout/widgets/PureAndDirect/Inputs/input_text_widget.dart';
import 'package:colorcode/Component/Utils/utils_core.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:get/get.dart';
import 'dart:async';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import "package:google_maps_webservice/places.dart" as Places;
import 'GoogleMapAPI.dart';
import 'MapStyle.dart';

void main() async {
  Util.init.init();
  await Util.init.firebase();
  await Util.init.location();

  runApp(
    GetMaterialApp(
      debugShowCheckedModeBanner: false,
      home: GoogleMapApp(),
    ),
  );
}

class GoogleMapApp extends StatelessWidget {
  static String pageId = '/GoogleMapApp';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          child: Center(
            child: SingleChildScrollView(
              reverse: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  /// Title
                  Text(
                    'Google Map',
                    style: TextStyle(
                      fontSize: 40,
                      color: Colors.black.withOpacity(0.7),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Google Map Flutter',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.black.withOpacity(0.7),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  ),
                  SizedBox(height: 35),

                  /// Go to Second (Google Map) Page
                  ElevatedButtonCustom(
                    onPressed: () async {
                      String _permission = await Util.h.permission.location;
                      if (_permission == 'denied') {
                        Util.snackbar.showGetX(
                          title: 'Error',
                          msg: 'Permission is not granted',
                          actionButtonOnPress: () => Util.h.permission.openAppSettings,
                        );
                      } else {
                        /*Going to map Page*/
                        await Get.to(() => GoogleMapPage(), transition: Transition.downToUp);
                      }
                    },
                    text: 'Get Location',
                    width: 250,
                    fontSize: 16,
                    letterSpacing: 1,
                    fontWeight: FontWeight.bold,
                    iconLeft: Icon(Icons.location_pin, size: 30),
                    iconRight: Icon(FontAwesomeIcons.chevronRight, size: 16),
                    iconGapRight: 10,
                    dividerShowLeft: true,
                    dividerThickness: 3,
                    borderRadius: BorderRadius.circular(30),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// GOOGLE MAP Page
class GoogleMapPage extends StatelessWidget {
  GoogleMapPage({this.mapWidth, this.mapHeight});

  final double? mapWidth;
  final double? mapHeight;

  /// GetX Use it Back Page
  // final logic = Get.put(GoogleMapLogic());
  // final state = Get.find<GoogleMapLogic>().state;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Container(
          width: mapWidth ?? double.infinity,
          height: mapHeight ?? double.infinity,
          child: MyGoogleMap(),
        ),
      ),
    );
  }
}

/// GOOGLE MAP MAIN CALLBACK
class MyGoogleMap extends StatefulWidget {
  @override
  _MyGoogleMapState createState() => _MyGoogleMapState();
}

/* *** */
class _MyGoogleMapState extends State<MyGoogleMap> {
  /* CONTROLLERS */
  final _searchHintDelay = SearchTimerDelay(milliseconds: 50);
  final TextEditingController _searchController = TextEditingController();
  Completer<GoogleMapController> _controller = Completer();

  /* VARIABLES */
  double markerSize = 60; // Max 70
  bool showOriginalMarker = false;
  bool _searching = false;
  bool _dragMap = false;
  bool _dragPin = false;
  double _zoomLevel = 18;
  double _tilt = 0;
  double _bearing = 0;
  Set<Marker> _markers = {};
  late BitmapDescriptor _customMarkerIcon;
  late BitmapDescriptor _defaultMarkerIcon;
  LatLng _updatedUatLong = LatLng(0, 0);
  List _hintTexts = [];

  /* GETTERS */
  LatLng get _currentLatLong {
    return LatLng(
      23.80502230710163,
      90.37112586200237,
    );
  }

  CameraPosition get _initialCameraPosition => CameraPosition(zoom: _zoomLevel, tilt: _tilt, bearing: _bearing, target: _currentLatLong);

  /* FUNCTIONS */
  /// Set Custom Marker :: Init */
  void _setMarkerIconsOnInit() async {
    _defaultMarkerIcon = BitmapDescriptor.defaultMarker;
    _customMarkerIcon = await BitmapDescriptor.fromAssetImage(ImageConfiguration(), "assets/ui/customMapMarker.png");
  }

  /// Add Marker | Function */
  _addMarker({MarkerId? markerId, required LatLng position, String? title, String? snippet, Offset? anchor, BitmapDescriptor? icon}) {
    _markers.add(Marker(
      // markerId: MarkerId(point.toString()), // This is for multiple Points
      markerId: markerId ?? MarkerId("id_1"),
      position: position,
      infoWindow: InfoWindow(
        title: title ?? '',
        snippet: snippet ?? '${position.latitude}, ${position.longitude}',
        anchor: anchor ?? Offset(0.5, 0.0),
      ),
      icon: icon ?? _defaultMarkerIcon,
      draggable: true,
      onDragEnd: ((latLong) => _onDragEnd(latLong)),
    ));
  }

  /// Animate To Position | Function */
  _animateToPosition(LatLng latLong) async {
    // Controller Variable for Animation
    final GoogleMapController controller = await _controller.future;

    // Go to New Position
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          zoom: _zoomLevel,
          tilt: 0,
          bearing: 0,
          target: latLong,
        ),
      ),
    );
  }

  /// Go To Searched Position | Function */
  Future<void> _goToSearchedPosition({String? address, double? lat, double? long}) async {
    LatLng? _latLong;
    // Get Lat Long From Address
    if (address != null) {
      Map _latLongMap = await Util.h.geoCoder.getLocationFromAddress(address);
      _latLong = LatLng(_latLongMap['lat'], _latLongMap['long']);
    } else {
      _latLong = LatLng(lat ?? 0, long ?? 0);
    }

    // Animating to Position
    _animateToPosition(_latLong);
  }

  /// Get Address | Function */
  Future<String> _getAddress({required double latitude, required double longitude}) async {
    Placemark _placeMark = await Util.h.geoCoder.getPlaceMark(
      index: 0,
      lat: latitude,
      long: longitude,
    );

    /*
    print("Name => ${_placeMark.name}");
    print("AdministrativeArea => ${_placeMark.administrativeArea}");
    print("Country => ${_placeMark.country}");
    print("Iso CountryCode => ${_placeMark.isoCountryCode}");
    print("Locality => ${_placeMark.locality}");
    print("Postal Code => ${_placeMark.postalCode}");
    print("Street => ${_placeMark.street}");
    print("SubAdministrativeArea => ${_placeMark.subAdministrativeArea}");
    print("SubLocality => ${_placeMark.subLocality}");
    print("SubThoroughfare => ${_placeMark.subThoroughfare}");
    print("Thoroughfare => ${_placeMark.thoroughfare}");
    */

    return _placeMark.street.toString() +
        ', ' +
        // _placeMark.thoroughfare.toString() +
        // ', ' +
        // _placeMark.subLocality.toString() +
        // ', ' +
        _placeMark.locality.toString() +
        (_placeMark.postalCode != '' ? (' - ' + _placeMark.postalCode.toString() + ', ') : ', ') +
        _placeMark.country.toString();
  }

  // Set Search TextBox Text | Function */
  _setSearchTextAsLatLong({required double latitude, required double longitude}) {
    return _getAddress(latitude: latitude, longitude: longitude).then((value) => _searchController.text = value);
  }

  /* ON */
  /// On Drag End */
  _onDragEnd(LatLng latLong) {
    // Setting true so that Marker stick on the map
    _dragPin = true;

    // Animating to Position
    _animateToPosition(latLong);
  }

  /// On Map Create */
  _onMapCreated(GoogleMapController controller) {
    // controller.setMapStyle(MapStyle.mapStyle);
    _controller.complete(controller);

    // SettingUp New Marker
    setState(() => _addMarker(position: _currentLatLong));
  }

  /// On Camera Move */
  _onCameraMove({required CameraPosition cameraPosition, required bool realTimeMovement}) {
    // SettingUp New Marker
    double _latitude = cameraPosition.target.latitude;
    double _longitude = cameraPosition.target.longitude;

    _updatedUatLong = LatLng(_latitude, _longitude);

    setState(() => _dragMap = true);

    // SettingUp New Marker
    if (_dragMap && !_dragPin && realTimeMovement) setState(() => _addMarker(position: _updatedUatLong));
  }

  /// On Camera Idle */
  _onCameraIdle({required bool autoPosition}) {
    if (autoPosition) setState(() => _addMarker(position: _updatedUatLong));

    // Setting Search Text Address
    // _setSearchTextAsLatLong(latitude: _movedLatLong!.latitude, longitude: _movedLatLong!.longitude);
    _getAddress(latitude: _updatedUatLong.latitude, longitude: _updatedUatLong.longitude).then((value) => print(value));
    print(_updatedUatLong);

    // Resetting
    setState(() {
      _dragMap = false;
      _dragPin = false;
    });

    _clearPlaceHint();
    _searchingStatus(false);
    _clearSearchTextFocus();
  }

  /// On Tap || Map Marker and Actions "LatLng point" : Getting Current tapped Point (Lat, Long)
  _onTap({required LatLng latLong, required bool tap, required bool cameraUpdate}) async {
    if (tap) {
      // Setting true so that Marker stick on the map
      // _dragPin = true;

      // SettingUp New Marker
      // setState(() => _addMarker(position: latLong));

      // Animating to Position
      // if (cameraUpdate) _animateToPosition(latLong);

      _clearPlaceHint();
      _searchingStatus(false);
      _clearSearchTextFocus();
    }
  }

  /* PLACE HINTS */
  /// API ...
  final _places = Places.GoogleMapsPlaces(apiKey: GoogleMapAPI.getAPI);

  /// Search Status On/Off
  _searchingStatus(bool status) => setState(() => _searching = status);

  /// Clear Hint Array
  _clearPlaceHint() => setState(() => _hintTexts.clear());

  _clearSearchTextFocus() {
    FocusScope.of(context).unfocus();
    _searchController.clear();
  }

  /// Get Lists of Places
  _getSearchedMapPlacesHints({required String address}) async {
    // _clearPlaceHint();
    _searchingStatus(false);

    final _response = await _places.autocomplete(
      address,
      radius: 1,
    );

    if (_response.isDenied) {
      print(_response.errorMessage);
      Util.snackbar.showGetX(title: 'Error!', msg: 'Search Hint Response is Denied');
    }
    if (_response.isInvalid) {
      print(_response.errorMessage);
      Util.snackbar.showGetX(title: 'Error!', msg: 'Search Hint Response is Invalid');
    }
    if (_response.isNotFound) {
      print(_response.errorMessage);
      Util.snackbar.showGetX(title: 'Error!', msg: 'Search Hint Response is NotFound');
    }
    if (_response.isOverQueryLimit) {
      print(_response.errorMessage);
      Util.snackbar.showGetX(title: 'Error!', msg: 'Search Hint Response is OverQueryLimit');
    }

    if (_response.isOkay) {
      List _n = [];
      for (Places.Prediction prediction in _response.predictions) {
        String title = prediction.structuredFormatting!.mainText.toString();
        String subTitle = prediction.structuredFormatting!.secondaryText.toString();
        String icon = '';
        double lat = 0;
        double long = 0;

        if (prediction.placeId != null) {
          Places.PlacesDetailsResponse _placeDetails = await _getSearchedMapPlaceDetails(placeID: prediction.placeId);
          icon = _placeDetails.result.icon.toString();
          lat = _placeDetails.result.geometry!.location.lat;
          long = _placeDetails.result.geometry!.location.lng;
        }

        _n.add({
          'title': title,
          'subTitle': subTitle,
          'icon': icon,
          'lat': lat,
          'long': long,
        });
      }

      _clearPlaceHint();
      setState(() => _hintTexts = _n);
      _searchingStatus(true);
    }
  }

  /// Returning details from place
  Future<Places.PlacesDetailsResponse> _getSearchedMapPlaceDetails({required placeID}) async {
    return await _places.getDetailsByPlaceId(placeID);
  }

  /* INIT */
  @override
  void initState() {
    super.initState();
    _searchController.text = '';
    _setMarkerIconsOnInit();
    Util.h.location.setGeoPoint();
  }

  /* BUILD */
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          /// Google Map
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: 0,
            child: GoogleMap(
              markers: showOriginalMarker ? _markers : {},
              initialCameraPosition: _initialCameraPosition,
              onMapCreated: _onMapCreated,
              onCameraMove: ((cameraPosition) => _onCameraMove(cameraPosition: cameraPosition, realTimeMovement: true)),
              onCameraMoveStarted: () => print('Started'),
              onCameraIdle: () => _onCameraIdle(autoPosition: false),
              onTap: (latLong) => _onTap(latLong: latLong, tap: true, cameraUpdate: false),
              onLongPress: (latLong) => _onTap(latLong: latLong, tap: true, cameraUpdate: false),
              padding: EdgeInsets.only(top: 70),
              mapToolbarEnabled: true,
              buildingsEnabled: true,
              compassEnabled: true,
              indoorViewEnabled: true,
              liteModeEnabled: false,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              rotateGesturesEnabled: true,
              scrollGesturesEnabled: true,
              tiltGesturesEnabled: true,
              trafficEnabled: false,
              zoomControlsEnabled: true,
              zoomGesturesEnabled: true,
            ),
          ),

          showOriginalMarker
              ? Container()
              : !_dragMap

                  /// Marker
                  ? Align(
                      alignment: Alignment.center,
                      child: Container(
                        width: 70,
                        height: 70,
                        // color: Colors.white.withOpacity(0.8),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: SizedBox(
                            width: markerSize,
                            height: markerSize,
                            child: Image.asset(
                              'assets/ui/customMapMarker.png',
                              scale: 1,
                            ),
                          ),
                        ),
                      ),
                    )
                  : Align(
                      alignment: Alignment.center,
                      child: Container(
                        width: 70,
                        height: 70,
                        // color: Colors.white.withOpacity(0.8),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: SizedBox(
                            width: markerSize,
                            height: markerSize,
                            child: Image.asset(
                              'assets/ui/customMapMarker.gif',
                              scale: 1,
                            ),
                          ),
                        ),
                      ),
                    ),

          /// Search Hint Box
          !_searching
              ? Container()
              : Positioned(
                  left: 18,
                  right: 18,
                  top: 67,
                  // bottom: 20,
                  child: Container(
                    width: double.infinity,
                    constraints: BoxConstraints(maxHeight: 450),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(1),
                      boxShadow: [
                        BoxShadow(
                          offset: Offset(0, 0),
                          blurRadius: 10,
                          color: Colors.black.withOpacity(0.5),
                        ),
                      ],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: EdgeInsets.only(left: 20, right: 20, top: 3, bottom: 3),
                    child: Builder(builder: (_) {
                      List _res = _hintTexts;
                      List<Widget> _wid = [SizedBox(height: 10)];

                      _res.forEach((placesDetails) {
                        String title = placesDetails['title'];
                        String subTitle = placesDetails['subTitle'];
                        String icon = placesDetails['icon'];
                        double lat = placesDetails['lat'];
                        double long = placesDetails['long'];

                        _wid.add(

                            /// Clickable Button
                            InkWell(
                          onTap: () async {
                            await _goToSearchedPosition(lat: lat, long: long);
                            _clearPlaceHint();
                            _searchingStatus(false);
                            _clearSearchTextFocus();
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 3),
                                    child: SizedBox(width: 18, height: 18, child: Image.network(icon)),
                                  ),
                                  SizedBox(width: 15),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('$title', style: TextStyle(fontSize: 14, color: Colors.cyan.shade900)),
                                        Text('$subTitle', style: TextStyle(fontSize: 13, color: Colors.black54)),
                                        Text('${lat.toStringAsFixed(3)}, ${long.toStringAsFixed(3)}',
                                            style: TextStyle(fontSize: 11, color: Colors.grey)),
                                      ],
                                    ),
                                  )
                                ],
                              ),
                              Divider(height: 20),
                            ],
                          ),
                        ));
                      });
                      return SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _wid,
                        ),
                      );
                    }),
                  ),
                ),

          /// Input Form Search Field
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Container(
              margin: EdgeInsets.all(5),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(50), boxShadow: [
                BoxShadow(
                  offset: Offset(0, 10),
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                ),
                BoxShadow(
                  offset: Offset(0, -5),
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 5,
                ),
              ]),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(50),
                child: Container(
                  decoration: BoxDecoration(),
                  child: InputTextWidgetCustom(
                    inputPadding: EdgeInsets.only(left: 10, right: 110),
                    fontSize: 16,
                    hintText: 'Search',
                    controller: _searchController,
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.done,
                    margin: EdgeInsets.all(0),
                    onChanged: (val) async {
                      // Timed Execution and Set List
                      if (val.toString().length > 4) {
                        await _getSearchedMapPlacesHints(address: val);
                        print(_searching);
                      } else {
                        _searchingStatus(false);
                        _clearPlaceHint();
                      }
                      // _searchHintDelay.run(() async {});
                    },
                  ),
                ),
              ),
            ),
          ),

          /// Button To Navigate Next
          Positioned(
            right: 5,
            top: 5,
            child: ElevatedButtonCustom(
              onPressed: () async {
                /// Clickable Button
                await _goToSearchedPosition(address: _searchController.text);
                _clearPlaceHint();
                _searchingStatus(false);
                _clearSearchTextFocus();
              },
              height: 58,
              width: 60,
              iconLeft: Icon(Icons.search),
              fontSize: 16,
              letterSpacing: 1,
              fontWeight: FontWeight.w400,
              textColor: Colors.white,
              backgroundColor: Colors.blueGrey.shade900,
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(50),
                bottomRight: Radius.circular(50),
                topLeft: Radius.circular(10),
                bottomLeft: Radius.circular(10),
              ),
              borderSide: BorderSide(color: Colors.white, width: 1),
            ),
          ),

          /// Test Button
          // Positioned(
          //   left: 5,
          //   top: 100,
          //   child: ElevatedButtonCustom(
          //     onPressed: () async {
          //       /// Clickable Button
          //       Places.PlacesSearchResponse _res = await _places.searchByText("Mirpur 10 Dhaka");
          //       print(_res.errorMessage);
          //     },
          //     height: 58,
          //     text: 'Test Button',
          //     fontSize: 16,
          //     letterSpacing: 1,
          //     fontWeight: FontWeight.w400,
          //     color: Colors.white,
          //     backgroundColor: Colors.blueGrey.shade900,
          //     borderSide: BorderSide(color: Colors.white, width: 1),
          //   ),
          // ),
        ],
      ),
    );
  }
}

/// Timer Class
class SearchTimerDelay {
  SearchTimerDelay({this.milliseconds = 500});

  final int milliseconds;
  VoidCallback? action;
  Timer? _timer;

  run(VoidCallback action) {
    if (null != _timer) _timer!.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }
}
