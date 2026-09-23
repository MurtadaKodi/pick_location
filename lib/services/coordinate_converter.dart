import 'package:latlong2/latlong.dart';
import 'package:proj4dart/proj4dart.dart';

class CoordinateConverter {
  CoordinateConverter._();
  // IMPORTANT:
// QND95 (EPSG:2932)
// lat_0 must be 24.45 to match QGIS and the official CGIS GeoPortal.
// Using 24.4666666667 causes an offset of approximately 1.8 km.

  static final Projection _qnd =
      Projection.get('EPSG:2932') ??
      Projection.add(
        'EPSG:2932',
        '+proj=tmerc '
            '+lat_0=24.45 '
            '+lon_0=51.21666666666667 '
            '+k=0.99999 '
            '+x_0=200000 '
            '+y_0=300000 '
            '+ellps=intl '
            '+towgs84=-127.78,-283.37,21.24,0,0,0,0 '
            '+units=m +no_defs',
      );
      

  static final Projection _wgs = Projection.get('EPSG:4326')!;

  static LatLng qndToWgs({required double easting, required double northing}) {
    final src = Point(x: easting, y: northing);

    final dst = _qnd.transform(_wgs, src);

    return LatLng(dst.y, dst.x);
  }

  static Point wgsToQnd({required double latitude, required double longitude}) {
    final src = Point(x: longitude, y: latitude);

    return _wgs.transform(_qnd, src);
  }
}
