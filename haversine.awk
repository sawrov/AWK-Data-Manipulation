
    function degrees_to_radians(degrees) {
        pi = 3.141592653589793
        return (degrees * pi / 180.0);
    }

    function asin(x) {
        return atan2(x, sqrt(1-x*x));
    }

    function haversine(lat1, lon1, lat2, lon2) {
        EARTH_RADIUS_IN_METRES = 6372797;

        deltalat = (lat2 - lat1) / 2.0;
        deltalon = (lon2 - lon1) / 2.0;

        sin1     = sin( degrees_to_radians(deltalat) );
        cos1     = cos( degrees_to_radians(lat1) );
        cos2     = cos( degrees_to_radians(lat2) );
        sin2     = sin( degrees_to_radians(deltalon) );

        x        = sin1*sin1 + cos1*cos2 * sin2*sin2;
        metres   = 2 * EARTH_RADIUS_IN_METRES * asin( sqrt(x) );

        return metres;
    }
        {

        print haversine($1,$2,$3,$4),NR
        }