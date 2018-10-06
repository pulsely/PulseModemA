/* $Id: regs.h 226 2014-11-23 12:33:36Z oh2gve $
 *
 * Copyright 2005-2012 Tapio Sokura
 * Copyright 2007-2012 Heikki Hannikainen
 *
 * Perl-to-C modifications
 * Copyright 2009-2014 Tapio Aaltonen
 *
 * This file is part of libfap.
 *
 * Libfap is free software; you can redistribute it and/or modify it under the
 * terms of either:
 *
 * a) the GNU General Public License as published by the Free Software
 * Foundation; either version 1, or (at your option) any later
 * version, or
 * 
 * b) the "Artistic License". 
 * 
 * Both licenses can be found in the licenses directory of this source code
 * package.
 *
 * APRS is a registered trademark of APRS Software and Bob Bruninga, WB4APR.
*/

/**
 * \file regs.h
 * \brief Regular expressions needed in helpers.
 * \author Tapio Aaltonen
*/

#ifndef REGS_H
#define REGS_H

#include <regex.h>


extern regex_t fapint_regex_ax25call, fapint_regex_header, fapint_regex_digicall, fapint_regex_digicallv6;
extern regex_t fapint_regex_normalpos, fapint_regex_normalamb, fapint_regex_timestamp;
extern regex_t fapint_regex_mice_dstcall, fapint_regex_mice_body, fapint_regex_mice_amb;
extern regex_t fapint_regex_comment, fapint_regex_phgr, fapint_regex_phg, fapint_regex_rng, fapint_regex_altitude;
extern regex_t fapint_regex_mes_dst, fapint_regex_mes_ack, fapint_regex_mes_nack;
extern regex_t fapint_regex_wx1, fapint_regex_wx2, fapint_regex_wx3, fapint_regex_wx4, fapint_regex_wx5;
extern regex_t fapint_regex_wx_r1, fapint_regex_wx_r24, fapint_regex_wx_rami;
extern regex_t fapint_regex_wx_humi, fapint_regex_wx_pres, fapint_regex_wx_lumi, fapint_regex_wx_what;
extern regex_t fapint_regex_wx_snow, fapint_regex_wx_rrc, fapint_regex_wx_any, fapint_regex_wx_soft;
extern regex_t fapint_regex_nmea_chksum, fapint_regex_nmea_dst, fapint_regex_nmea_time, fapint_regex_nmea_date;
extern regex_t fapint_regex_nmea_specou, fapint_regex_nmea_fix, fapint_regex_nmea_altitude, fapint_regex_nmea_flag, fapint_regex_nmea_coord;
extern regex_t fapint_regex_telemetry, fapint_regex_peet_splitter, fapint_regex_kiss_callsign;
extern regex_t fapint_regex_base91_telemetry;


#endif // REGS_H
