function [lat, lon, alt, t] = BSP_mapCoordsFcn(fds)

group = 'vehicle_GPS_position_0';

t = kVIS_fdsGetChannel(fds, group, 'Time');

lon = kVIS_fdsGetChannel(fds, group, 'lon');

lat = kVIS_fdsGetChannel(fds, group, 'lat');

alt = kVIS_fdsGetChannel(fds, group, 'alt');
alt(alt < 0) = 0;

end