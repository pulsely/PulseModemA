/* $Id: helpers.h 226 2014-11-23 12:33:36Z oh2gve $
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
 * \file helpers.h
 * \brief Declarations of helper functions for fap.c.
 * \author Tapio Aaltonen
*/

#ifndef HELPERS_H
#define HELPERS_H


#include <time.h>
#include "fap.h"



/// Parses packet->header into source, target and path.
/**
 * \return 1 on success, 0 on failure.
*/
int fapint_parse_header(fap_packet_t* packet, short const is_ax25);


/// Try to parse given packet body as mic-e packet.
/**
 * Everything after the mic-e report is also parsed here.
 * \return 1 on success, 0 on failure.
*/
int fapint_parse_mice(fap_packet_t* packet, char const* input, unsigned int const input_len);


/// Returns unixtime based on timestamp in given body.
/**
 * \return Unixtime if body had valid timestamp, 0 if not.
*/
time_t fapint_parse_timestamp(char const* input);


/// Try to parse given packet body as compressed position report.
/**
 * Handles only compressed position report from beginning of body. Input is assumed to be null-terminated.
 * \return 1 on success, 0 on failure.
*/
int fapint_parse_compressed(fap_packet_t* packet, char const* input);


/// Try to parse given packet body as normal position report.
/**
 * Handles only normal position report from beginning of body. Input is assumed to be null-terminated.
 * \return 1 on success, 0 on failure.
*/
int fapint_parse_normal(fap_packet_t* packet, char const* input);


/// Check given packet body for course, speed PHGR, altitude and comments.
/**
 * Looks for optional fields and can't thus fail.
*/
void fapint_parse_comment(fap_packet_t* packet, char const* input, unsigned int const input_len);


/// Parse NMEA packet.
/**
 * \return 1 on success, 0 on failure.
*/
int fapint_parse_nmea(fap_packet_t* packet, char const* input, unsigned int const input_len);


/// Try to parse given packet body as object.
/**
 * \return 1 on success, 0 on failure.
*/
int fapint_parse_object(fap_packet_t* packet, char const* input, unsigned int const input_len);


/// Try to parse given packet body as item.
/**
 * \return 1 on success, 0 on failure.
*/
int fapint_parse_item(fap_packet_t* packet, char const* input, unsigned int const input_len);


/// Try to parse given packet body as message.
/**
 * \return 1 on success, 0 on failure.
*/
int fapint_parse_message(fap_packet_t* packet, char const* input, unsigned int const input_len);


/// Parse capabilities message.
/**
 * \return 1 on success, 0 on failure.
*/
int fapint_parse_capabilities(fap_packet_t* packet, char const* input, unsigned int const input_len);


/// Parse status message.
/**
 * \return 1 on success, 0 on failure.
*/
int fapint_parse_status(fap_packet_t* packet, char const* input, unsigned int const input_len);


/// Parse wx report.
/**
 * \return 1 on success, 0 on failure.
*/
int fapint_parse_wx(fap_packet_t* packet, char const* input, unsigned int const input_len);


/// Parse telemetry message.
/**
 * \return 1 on success, 0 on failure.
*/
int fapint_parse_telemetry(fap_packet_t* packet, char const* input);


/// Parses a Peet bros Ultimeter weather logging frame (!! header).
/**
 * \return 1 on success, 0 on failure.
*/
int fapint_parse_wx_peet_logging(fap_packet_t* packet, char const* input);


/// Parses a Peet bros Ultimeter weather packet ($ULTW header).
/**
 * \return 1 on success, 0 on failure.
*/
int fapint_parse_wx_peet_packet(fap_packet_t* packet, char const* input);


/// Parse given !DAO! extension.
/**
 * Parse a possible !DAO! extension (datum and extra lat/lon digits).
 * \param packet Results are saved here.
 * \param input The 3 bytes between exclamation marks.
 * \return 1 if a valid !DAO! extension was detected in the test subject (and stored in $rethash), 0 if not.
*/
int fapint_parse_dao(fap_packet_t* packet, char input[3]);



/// Validates given KISS-level callsign.
/**
 * Checks a callsign for validity and strips trailing spaces out and returns
 * the string.
 * \return Copy of input at success, NULL when failure occurs.
*/
char* fapint_check_kiss_callsign(char* input);



/* Implementation-specific helpers. */


/// Creates and initializes an empty packet.
fap_packet_t* fapint_create_packet();



#endif // HELPERS_H
