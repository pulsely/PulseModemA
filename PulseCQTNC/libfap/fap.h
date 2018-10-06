/* $Id: fap.h 226 2014-11-23 12:33:36Z oh2gve $
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
 * \file fap.h
 * \brief Declaration of libfap's public interface.
 *
 * This file declares data types used to represent a single APRS packet.
 * Functions include the parser, some utility functions and library
 * initialization stuff.
 *
 * Note: it is very important to call fap_init() before calling any other
 * function. Also note that fap_cleanup() should be called when shutting
 * down, or memory leaks will occur.
 *
 * \author Tapio Aaltonen
*/

#ifndef FAP_H
#define FAP_H


#include <time.h>


#ifdef __cplusplus
extern "C" {
#endif 



/// Packet error code type.
typedef enum
{
	fapPACKET_NO,
	fapPACKET_SHORT,
	fapPACKET_NOBODY,
	
	fapSRCCALL_NOAX25,
	fapSRCCALL_BADCHARS,
	
	fapDSTPATH_TOOMANY,
	fapDSTCALL_NONE,
	fapDSTCALL_NOAX25,
	
	fapDIGICALL_NOAX25,
	fapDIGICALL_BADCHARS,
	
	fapTIMESTAMP_INV_LOC,
	fapTIMESTAMP_INV_OBJ,
	fapTIMESTAMP_INV_STA,
	fapTIMESTAMP_INV_GPGGA,
	fapTIMESTAMP_INV_GPGLL,
	
	fapPACKET_INVALID,
	
	fapNMEA_INV_CVAL,
	fapNMEA_LARGE_EW,
	fapNMEA_LARGE_NS,
	fapNMEA_INV_SIGN,
	fapNMEA_INV_CKSUM,
	
	fapGPRMC_FEWFIELDS,
	fapGPRMC_NOFIX,
	fapGPRMC_INV_TIME,
	fapGPRMC_INV_DATE,
	fapGPRMC_DATE_OUT,
	
	fapGPGGA_FEWFIELDS,
	fapGPGGA_NOFIX,
	
	fapGPGLL_FEWFIELDS,
	fapGPGLL_NOFIX,

	fapNMEA_UNSUPP,
	
	fapOBJ_SHORT,
	fapOBJ_INV,
	fapOBJ_DEC_ERR,
	
	fapITEM_SHORT,
	fapITEM_INV,
	fapITEM_DEC_ERR,
	
	fapLOC_SHORT,
	fapLOC_INV,
	fapLOC_LARGE,
	fapLOC_AMB_INV,
	
	fapMICE_SHORT,
	fapMICE_INV,
	fapMICE_INV_INFO,
	fapMICE_AMB_LARGE,
	fapMICE_AMB_INV,
	fapMICE_AMB_ODD,
	
	fapCOMP_INV,
	fapCOMP_SHORT,
	
	fapMSG_INV,
	
	fapWX_UNSUPP,
	fapUSER_UNSUPP,
	
	fapDX_INV_SRC,
	fapDX_INF_FREQ,
	fapDX_NO_DX,
	
	fapTLM_INV,
	fapTLM_LARGE,
	fapTLM_UNSUPP,
	
	fapEXP_UNSUPP,
	fapSYM_INV_TABLE,
	
	fapNOT_IMPLEMENTED,
	fapNMEA_NOFIELDS,
	
	fapNO_APRS
} fap_error_code_t;


/// Packet type type.
typedef enum
{
	fapLOCATION,
	fapOBJECT,
	fapITEM,
	fapMICE,
	fapNMEA,

	fapWX,
	fapMESSAGE,
	fapCAPABILITIES,
	fapSTATUS,
	fapTELEMETRY,
	fapTELEMETRY_MESSAGE,
	fapDX_SPOT,

	fapEXPERIMENTAL
} fap_packet_type_t;


/// Position format type.
typedef enum
{
	fapPOS_COMPRESSED,
	fapPOS_UNCOMPRESSED,
	fapPOS_MICE,
	fapPOS_NMEA
} fap_pos_format_t;


/// Weather report type.
typedef struct
{
	/// Wind gust in m/s.
	double* wind_gust;
	/// Wind direction in degrees.
	unsigned int* wind_dir;
	/// Wind speed in m/s.
	double* wind_speed;
	
	/// Temperature in degrees Celcius.
	double* temp;
	/// Indoor temperature in degrees Celcius.
	double* temp_in;
	
	/// Rain from last 1 hour, in millimeters.
	double* rain_1h;
	/// Rain from last day, in millimeters.
	double* rain_24h;
	/// Rain since midnight, in millimeters.
	double* rain_midnight;
	
	/// Relative humidity percentage.
	unsigned int* humidity;
	/// Relative inside humidity percentage.
	unsigned int* humidity_in;

	/// Air pressure in millibars.
	double* pressure;
	/// Luminosity in watts per square meter.
	unsigned int* luminosity;
	
	/// Show depth increasement from last day, in millimeters.
	double* snow_24h;
	
	/// Software type indicator.
	char* soft;
} fap_wx_report_t;



/// Telemetry report type.
typedef struct
{
	/// Id of report.
	unsigned int* seq;
	/// First value.
	double* val1;
	/// Second value.
	double* val2;
	/// Third value.
	double* val3;
	/// Fourth value.
	double* val4;
	/// Fifth value.
	double* val5;
	
	/// Telemetry bits as ASCII 0s and 1s. Undefined bits are marked with question marks.
	char bits[8];
} fap_telemetry_t;



/// APRS packet type.
typedef struct
{
	/// Error code.
	fap_error_code_t* error_code;
	/// Packet type.
	fap_packet_type_t* type;
	
	/// Exact copy of the original packet, if such thing was given.
	char* orig_packet;
	/// Length of orig_packet.
	unsigned int orig_packet_len;
	
	/// Header part of the packet.
	char* header;
	/// Body of the packet. No null termination.
	char* body;
	/// Lenght of body.
	unsigned int body_len;
	/// AX.25-level source callsign.
	char* src_callsign;
	/// AX.25-level destination callsign.
	char* dst_callsign;
	/// Array of path elements.
	char** path;
	/// Number of path elements.
	unsigned int path_len;
	
	/// Latitude, west is negative.
	double* latitude;
	/// Longitude, south is negative.
	double* longitude;
	/// Position format.
	fap_pos_format_t* format;
	/// Position resolution in meters.
	double* pos_resolution;
	/// Position ambiguity, number of digits.
	unsigned int* pos_ambiguity;
	/// Datum character from !DAO! extension. 0x00 = undef.
	char dao_datum_byte;

	/// Altitude in meters.
	double* altitude;
	/// Course in degrees, zero is unknown and 360 is north.
	unsigned int* course;
	/// Land speed in km/h.
	double* speed;

	/// Symbol table designator. 0x00 = undef.
	char symbol_table;
	/// Slot of symbol table 0x00 = undef.
	char symbol_code;
	
	/// Zero for no messaging capability, 1 for yes.
	short* messaging;
	/// Destination of message.
	char* destination;
	/// The actual message text.
	char* message;
	/// Id of the message which is acked with this packet.
	char* message_ack;
	/// Id of the message which was rejected with this packet.
	char* message_nack;
	/// Id of this message.
	char* message_id;
	/// Station, object or item comment. No null termination.
	/**
	 * Here's a difference between Perl module and C library. Perl
	 * module removes whitespace characters from beginning and end of
	 * the comment.  C library returns comment exactly as seen in
	 * original packet.
	*/
	char* comment;
	/// Length of comment.
	unsigned int comment_len;

	/// Name of object or item in packet.
	char* object_or_item_name;
	/// Object or item status. 1 = alive, 0 = killed.
	short* alive;

	/// Zero if GPS has no fix, one if it has.
	short* gps_fix_status;
	/// Radio range of the station in km.
	unsigned int* radio_range;
	/// TX power, antenna height, antenna gain and possibly beacon rate.
	char* phg;
	/// Timestamp of the packet in UTC.
	time_t* timestamp;
	/// Timestamp as it appears in the packet.
	char* raw_timestamp;
	/// NMEA checksum validity indicator, 1 = valid.
	short* nmea_checksum_ok;
	
	/// Weather report.
	fap_wx_report_t* wx_report;
	
	/// Telemetry report.
	fap_telemetry_t* telemetry;
	
	/// Message bits in case of mic-e packet.
	char* messagebits;
	/// Status message. No 0-termination.
	char* status;
	/// Amount of bytes in status message.
	unsigned int status_len;
	/// Capabilities list. Indexes 0, 2, 4, ... store keys and 1, 3, 5, ... the values (or NULL if the key has no value).
	char** capabilities;
	/// Amount of capabilities in list.
	unsigned int capabilities_len;
	
} fap_packet_t;




/// The parser.
/**
 * Resulting packet object will be filled with as much data as possible
 * based on the packet given as parameter. Unfilled fields are set to NULL.
 *
 * When parsing in AX.25 mode, source callsign and path elements are checked
 * to be strictly compatible with AX.25 specs so that they can be sent into
 * AX.25 network. Destination callsign is always checked this way.
 *
 * The parser should handle null bytes, newline chars and other badness
 * sometimes seen in packets without crashing as long as input_len is given
 * correctly.
 *
 * \param input TNC-2 mode APRS packet string.
 * \param input_len Amount of bytes in input.
 * \param is_ax25 If 1, packet is parsed as AX.25 network packet. If 0, packet is parsed as APRS-IS packet.
 * \return A packet is always returned, no matter how the parsing went. Use
 * error_code to check how it did. If library is not initialized, returns
 * NULL.
*/
fap_packet_t* fap_parseaprs(char const* input, unsigned int const input_len, short const is_ax25);


/// Return human-readable error message for given error code.
/**
 * \param error Error code from fap_packet_t.
 * \param buffer Pre-allocated space for the message. Must be at least 60 bytes long.
*/
void fap_explain_error(fap_error_code_t const error, char* buffer);

/// Convert mic-e message bits (three numbers 0-2) to a textual message.
/**
 * \param bits Bits as returned by fap_parseaprs().
 * \param buffer Pre-allocated space for the message. Must be at least 20 bytes long.
*/
void fap_mice_mbits_to_message(char const* bits, char* buffer);

/// Calculate distance between given locations.
/**
 * Returns the distance in kilometers between two locations given in decimal
 * degrees. Arguments are given in order as lon0, lat0, lon1, lat1, east and
 * north positive. The calculation uses the great circle distance, it is not
 * too exact, but good enough for us.
*/
double fap_distance(double lon0, double lat0, double lon1, double lat1);


/// Calculate direction from first to second location.
/**
 * Returns the initial great circle direction in degrees from lat0/lon0 to
 * lat1/lon1. Locations are input in decimal degrees, north and east
 * positive.
*/
double fap_direction(double lon0, double lat0, double lon1, double lat1);


/// Count amount of digihops the packet has gone through.
/**
 * The number returned is just an educated guess, not absolute truth.
 *
 * \return Number of digipeated hops or -1 in case of error.
*/
int fap_count_digihops(fap_packet_t const* packet);


/// Check if the callsign is a valid AX.25 callsign.
/**
 * \param input Callsign to be checked. If SSID is 0, the "-0" suffix can be omitted.
 * \param add_ssid0 If 1, a missing SSID 0 (in practice "-0") is appended to the
 * returned callsign. If 0, valid callsign is returned as is.
 * \return Given input if it was valid. NULL if the input was not a valid
 *  AX.25 address or library is not initialized.
 *
 * Please note that it's very common to use invalid callsigns on the
 * APRS-IS.
*/
char* fap_check_ax25_call(char const* input, short const add_ssid0);


/// Convert a KISS-frame into a TNC-2 compatible UI-frame.
/**
 * Non-UI and non-pid-F0 frames are dropped. The KISS-frame to be decoded
 * may or may not have a FEND (0xC0) character at beginning. If there's a
 * FEND in the frame before or at the end, the frame is cutted just before
 * the FEND. Byte unstuffing must not be done before calling this function.
 *
 * \param kissframe KISS-frame.
 * \param kissframe_len Amount of bytes in kissframe. Must be less than 512.
 * \param tnc2frame Result of conversion is stored here. In case of error an error message may be found here.
 * \param tnc2frame_len Amount of bytes available in tnc2frame is read from
 * here. Amount of bytes written to tnc2frame is written to here upon
 * return.
 * \param tnc_id TNC ID from the kissframe, usually zero.
 * \return 1 in case of success, 0 when error occured.
*/
int fap_kiss_to_tnc2(char const* kissframe, unsigned int kissframe_len,
                     char* tnc2frame, unsigned int* tnc2frame_len, unsigned int* tnc_id);


/// Convert a TNC-2 compatible UI-frame into a KISS data frame.
/**
 * The frame will be complete, i.e. it has byte stuffing done and FEND
 * (0xC0) characters on both ends.
 *
 * \param tnc2frame TNC-2 frame.
 * \param tnc2frame_len Amount of bytes in tnc2frame.
 * \param tnc_id TNC ID to use in KISS frame. When is doubt, use zero.
 * \param kissframe Where to store the KISS-frame. Be sure to allocate enough space.
 * \param kissframe_len Amount of bytes stored into kissframe during successfull conversion.
 * \return 1 in case of success, 0 when error occured.
*/
int fap_tnc2_to_kiss(char const* tnc2frame, unsigned int tnc2frame_len, unsigned int const tnc_id,
                     char* kissframe, unsigned int* kissframe_len);



/* Implementation-specific functions. */

/// Convert raw AX.25 frame into TNC-2 compatible UI-frame.
/**
 * Params and return value work just like similar ones in fap_kiss_to_tnc2().
*/
int fap_ax25_to_tnc2(char const* ax25frame, unsigned int ax25frame_len,
                     char* tnc2frame, unsigned int* tnc2frame_len);

/// Convert TNC-2 compatible UI-frame into raw AX.25-frame.
/**
 * Params and return value work just like similar ones in fap_tnc2_to_kiss().
*/
int fap_tnc2_to_ax25(char const* tnc2frame, unsigned int tnc2frame_len,
                     char* ax25frame, unsigned int* ax25frame_len);


/// Custom free() for fap_packet_t*.
/**
 * Use this in place of normal free() when disposing a packet. Will free()
 * all non-NULL fields for you.
*/
void fap_free(fap_packet_t* packet);



/// Library initialization.
/**
 * This must be called once and before anything else when starting to use
 * libfap in your program.
*/
void fap_init();



/// Library cleanup.
/**
 * This must be called once when closing your app. Make sure that no fap
 * calls are issued after this.
*/
void fap_cleanup();


#ifdef __cplusplus
}
#endif 

#endif // FAP_H
