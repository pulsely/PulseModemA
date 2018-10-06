/* $Id: fap.c 227 2015-01-31 12:27:07Z oh2gve $
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
 * \mainpage
 * \section abstract Abstract
 * This documentation describes briefly libfap, an APRS parser made by
 * porting most important parts of the Ham::APRS::FAP - Finnish APRS Parser
 * (Fabulous APRS Parser) perl module into C.
 * 
 * API of the parser has been declared in the fap.h file, others are listed
 * here for those who are interested in internal operation of the parser.
 *
 * \section usage Usage example
 * \code
#include <fap.h>

int main()
{
	char* input;
	unsigned int input_len;
	fap_packet_t* packet;

	fap_init();

	// Read TNC2-formatted input for example from APRS-IS.
	
	// Process the packet.
	packet = fap_parseaprs(input, input_len, 0);
	if ( packet->error_code )
	{
		printf("Failed to parse packet (%s): %s\n", input, fap_explain_error(*packet->error_code));
	}
	else if ( packet->src_callsign )
	{
		printf("Got packet from %s.\n", packet->src_callsign);
	}
	fap_free(packet);
	
	fap_cleanup();
	
	return EXIT_SUCCESS;
}
 * \endcode
*/

/**
 * \file fap.c
 * \brief Implementation of public interface.
 * \author Tapio Aaltonen
*/

#include "fap.h"
#include "helpers.h"
#include "helpers2.h"
#include "regs.h"
#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include <stdlib.h>
#include <string.h>
#include <regex.h>
#include <ctype.h>
#include <math.h>
#include <stdio.h>


/// The magic constant.
#define PI 3.14159265
/// Degrees to radians.
#define DEG2RAD(x) (x/360*2*PI)
/// Radians to degrees.
#define RAD2DEG(x) (x*(180/PI))

/// KISS frame start and end delimeter.
#define FEND 0xc0
/// KISS frame escape byte.
#define FESC 0xdb
/// Escaped FEND.
#define TFEND 0xdc
/// Escaped FESC.
#define TFESC 0xdd
/// Size of buffers reserved for frame conversions.
#define FRAME_MAXLEN 512

/// UI-frame identification byte.
#define AX25_FRAME_UI 0x03
/// Protocol id of APRS in AX.25 frame.
#define AX25_PID_APRS 0xf0



/* Regexs needed by helpers. */
regex_t fapint_regex_header, fapint_regex_ax25call, fapint_regex_digicall, fapint_regex_digicallv6;
regex_t fapint_regex_normalpos, fapint_regex_normalamb, fapint_regex_timestamp;
regex_t fapint_regex_mice_dstcall, fapint_regex_mice_body, fapint_regex_mice_amb;
regex_t fapint_regex_comment, fapint_regex_phgr, fapint_regex_phg, fapint_regex_rng, fapint_regex_altitude;
regex_t fapint_regex_mes_dst, fapint_regex_mes_ack, fapint_regex_mes_nack;
regex_t fapint_regex_wx1, fapint_regex_wx2, fapint_regex_wx3, fapint_regex_wx4, fapint_regex_wx5;
regex_t fapint_regex_wx_r1, fapint_regex_wx_r24, fapint_regex_wx_rami;
regex_t fapint_regex_wx_humi, fapint_regex_wx_pres, fapint_regex_wx_lumi, fapint_regex_wx_what;
regex_t fapint_regex_wx_snow, fapint_regex_wx_rrc, fapint_regex_wx_any, fapint_regex_wx_soft;
regex_t fapint_regex_nmea_chksum, fapint_regex_nmea_dst, fapint_regex_nmea_time, fapint_regex_nmea_date;
regex_t fapint_regex_nmea_specou, fapint_regex_nmea_fix, fapint_regex_nmea_altitude, fapint_regex_nmea_flag, fapint_regex_nmea_coord;
regex_t fapint_regex_telemetry, fapint_regex_peet_splitter, fapint_regex_kiss_callsign, fapint_regex_kiss_digi;
regex_t fapint_regex_base91_telemetry;

/* Regex needed in this file. */
regex_t fapint_regex_detect_comp, fapint_regex_detect_wx, fapint_regex_detect_telem, fapint_regex_detect_exp;
regex_t fapint_regex_kiss_hdrbdy, fapint_regex_hdr_detail;
regex_t fapint_regex_hopcount1, fapint_regex_hopcount2;

/* Regex status flag. */
short fapint_initialized = 0;



fap_packet_t* fap_parseaprs(char const* input, unsigned int const input_len, short const is_ax25)
{
	fap_packet_t* result;
	int i, pos;
	unsigned int splitpos, body_len;
	char* body;
	char* tmp;
	char poschar, typechar;
	
	/* Check initialization status. */
	if ( !fapint_initialized )
	{
		return NULL;
	}
	
	/* Create empty packet to be returned. */
	result = fapint_create_packet();
	
	/* Check for missing params. */
	if ( input == NULL || input_len == 0 )
	{
		result->error_code = malloc(sizeof(fap_error_code_t));
		if ( result->error_code ) *result->error_code = fapPACKET_NO;
		return result;
	}
	
	/* Save the original packet. */
	result->orig_packet = malloc(input_len);
	result->orig_packet_len = input_len;
	memcpy(result->orig_packet, input, input_len);
	
	/* Find the end of header checking for NULL bytes while doing it. */
	splitpos = 0;
	for ( i = 0; i < input_len; ++i )
	{
		if ( input[i] == 0 )
		{
			result->error_code = malloc(sizeof(fap_error_code_t));
			if ( result->error_code ) *result->error_code = fapPACKET_INVALID;
			return result;
		}
		if ( input[i] == ':' )
		{
			splitpos = i;
			break;
		}
	}
	/* Check that end was found and body has at least one byte. */
	if ( splitpos == 0 || splitpos + 1 == input_len )
	{
		result->error_code = malloc(sizeof(fap_error_code_t));
		if ( result->error_code ) *result->error_code = fapPACKET_NOBODY;
		return result;
	}
	
	/* Save header and body. */
	result->header = fapint_remove_part(input, input_len, splitpos, input_len, &body_len);
	result->body = fapint_remove_part(input, input_len, 0, splitpos+1, &result->body_len);

	/* Parse source, target and path. */
	if ( !fapint_parse_header(result, is_ax25) )
	{
		return result;
	}

	/* Create 0-terminated working copy of body. Remember that this added 0 is not always the first 0 in body. */
	body_len = result->body_len;
	body = malloc(body_len + 1);
	memcpy(body, result->body, body_len);
	body[body_len] = 0;
	
	/* Detect packet type char. */
	typechar = body[0];

	/* Check for mic-e packet. */
	if ( (typechar == 0x27 || typechar == 0x60) &&
	     body_len >= 9 )
	{
		result->type = malloc(sizeof(fap_packet_type_t));
		if ( !result->type ) return result;
		*result->type = fapLOCATION; /* not fapMICE, lol */
		fapint_parse_mice(result, body+1, body_len-1);
	}
	/* Check for normal or compressed location packet. */
	else if ( typechar == '!' || typechar == '=' || typechar == '/' || typechar == '@' )
	{
		/* Check for messaging. */
		result->messaging = malloc(sizeof(short));
		if ( !result->messaging ) return result;
		if ( typechar == '=' || typechar == '@' )
		{
			*result->messaging = 1;
		}
		else
		{
			*result->messaging = 0;
		}
		/* Validate body. */
		if ( body_len >= 14 )
		{
			result->type = malloc(sizeof(fap_packet_type_t));
			if ( !result->type ) return result;
			*result->type = fapLOCATION;
			/* Check for timestamp. We use i as obfuscated status flag. Sorry. */
			i = 1; /* we has no error */
			if ( typechar == '/' || typechar == '@' )
			{
				/* Parse and remove those 7 bytes, removing also the typechar byte. */
				result->timestamp = malloc(sizeof(time_t));
				if ( !result->timestamp ) return result;
				*result->timestamp = fapint_parse_timestamp(body+1);
				if ( *result->timestamp == 0 )
				{
					result->error_code = malloc(sizeof(fap_error_code_t));
					if ( result->error_code ) *result->error_code = fapTIMESTAMP_INV_LOC;
					i = 0; /* we has error */
				}
				result->raw_timestamp = malloc(7);
				if ( !result->raw_timestamp ) return result;
				memcpy(result->raw_timestamp, body+1, 6);
				result->raw_timestamp[6] = 0;
				tmp = fapint_remove_part(body, body_len, 0, 8, &body_len);
				free(body);
				body = tmp;
			}
			else
			{
				/* Remove only typechar byte. */
				tmp = fapint_remove_part(body, body_len, 0, 1, &body_len);
				free(body);
				body = tmp;
			}
			
			/* If timestamp check didn't fail, go on with location parsing. */
			if ( i )
			{
				/* Get position type character. */
				poschar = body[0];
				
				/* Detect position type. */
				if ( poschar >= 48 && poschar <= 57 )
				{
					/* It's normal position. */
					if ( body_len >= 19 )
					{
						i = fapint_parse_normal(result, body);
						/* Check for comments or wx report. */
						if ( body_len > 19 && i && result->symbol_code != '_' )
						{
							fapint_parse_comment(result, body+19, body_len-19);
						}
						else if ( body_len > 19 && i )
						{
							fapint_parse_wx(result, body+19, body_len-19);
						}
					}
				}
				else if ( poschar == 47 || poschar == 92 || (poschar >= 65 && poschar <= 90) || (poschar >= 97 && poschar <= 106) )
				{
					/* It's compressed position. */
					if ( body_len >= 13 )
					{
						i = fapint_parse_compressed(result, body);
						/* Check for comment or wx report. */
						if ( body_len > 13 && i && result->symbol_code != '_' )
						{
							fapint_parse_comment(result, body+13, body_len-13);
						}
						else if ( body_len > 13 && i )
						{
							fapint_parse_wx(result, body+13, body_len-13);
						}
					}
					else
					{
						result->error_code = malloc(sizeof(fap_error_code_t));
						if ( result->error_code ) *result->error_code = fapCOMP_SHORT;
					}
				}
				else if ( poschar == 33 )
				{
					/* Weather report from Ultimeter 2000 */
					if ( result->type == NULL )
					{
						result->type = malloc(sizeof(fap_packet_type_t));
						if ( !result->type ) return result;
					}
					*result->type = fapWX;
					fapint_parse_wx_peet_logging(result, body+1);
				}
				else
				{
					/* Does not match any known type. */
					result->error_code = malloc(sizeof(fap_error_code_t));
					if ( result->error_code ) *result->error_code = fapPACKET_INVALID;
				}
			}
		}
		else
		{
			result->error_code = malloc(sizeof(fap_error_code_t));
			if ( result->error_code ) *result->error_code = fapPACKET_SHORT;
		}
	}
	/* Check for NMEA data packet. */
	else if ( typechar == '$' )
	{
		if ( body_len > 3 && body[0] == '$' && body[1] == 'G' && body[2] == 'P' )
		{
			result->type = malloc(sizeof(fap_packet_type_t));
			if ( !result->type ) return result;
			*result->type = fapLOCATION; /* not fapNMEA, lol */
			fapint_parse_nmea(result, body+1, body_len-1);
		}
		else if ( body_len > 5 && body[0] == '$' && body[1] == 'U' && body[2] == 'L' && body[3] == 'T' && body[4] == 'W' )
		{
			result->type = malloc(sizeof(fap_packet_type_t));
			if ( !result->type ) return result;
			*result->type = fapWX;
			fapint_parse_wx_peet_packet(result, body+5);
		}
	}
	/* Check for object packet. */
	else if ( typechar == ';' )
	{   
		if ( body_len >= 31 )
		{
			result->type = malloc(sizeof(fap_packet_type_t));
			if ( !result->type ) return result;
			*result->type = fapOBJECT;
			fapint_parse_object(result, body, body_len);
		}
	}
	/* Check for item packet. */
	else if ( typechar == ')' )
	{  
		if ( body_len >= 18 )
		{
			result->type = malloc(sizeof(fap_packet_type_t));
			if ( !result->type ) return result;
			*result->type = fapITEM;
			fapint_parse_item(result, body, body_len);
		}
	}
	/* Check for message, bulletin or announcement packet. */
	else if ( typechar == ':' )
	{   
		if ( body_len >= 11 )
		{
			/* All are labeled as messages for the time being. */
			result->type = malloc(sizeof(fap_packet_type_t));
			if ( !result->type ) return result;
			*result->type = fapMESSAGE;
			fapint_parse_message(result, body, body_len);
		}
	}
	/* Check for capabilities packet. */
	else if ( typechar == '<' )
	{   
		/* At least one other character besides '<' required. */
		if ( body_len >= 2 )
		{
			result->type = malloc(sizeof(fap_packet_type_t));
			if ( !result->type ) return result;
			*result->type = fapCAPABILITIES;
			fapint_parse_capabilities(result, body+1, body_len-1);
		}
	}
	/* Check for status packet. */
	else if ( typechar == '>' )
	{
		/* We can live with empty status reports. */
		if ( body_len >= 1 )
		{
			result->type = malloc(sizeof(fap_packet_type_t));
			if ( !result->type ) return result;
			*result->type = fapSTATUS;
			fapint_parse_status(result, body+1, body_len-1);
		}
	}
	/* Check for weather packet. */
	else if ( typechar == '_' )
	{
		if ( regexec(&fapint_regex_detect_wx, body, 0, NULL, 0) == 0 )
		{
			result->type = malloc(sizeof(fap_packet_type_t));
			if ( !result->type ) return result;
			*result->type = fapWX;
			fapint_parse_wx(result, body+9, body_len-9);
		}
		else
		{
			result->error_code = malloc(sizeof(fap_error_code_t));
			if ( result->error_code ) *result->error_code = fapWX_UNSUPP;
		}
	}
	/* Check for telemetry packet. */
	else if ( regexec(&fapint_regex_detect_telem, body, 0, NULL, 0) == 0 )
	{   
		result->type = malloc(sizeof(fap_packet_type_t));
		if ( !result->type ) return result;
		*result->type = fapTELEMETRY;
		fapint_parse_telemetry(result, body+2);
	}
	/* Check for experimental packet. */
	else if ( regexec(&fapint_regex_detect_exp, body, 0, NULL, 0) == 0 )
	{   
		result->type = malloc(sizeof(fap_packet_type_t));
		if ( !result->type ) return result;
		*result->type = fapEXPERIMENTAL;
		result->error_code = malloc(sizeof(fap_error_code_t));
		if ( result->error_code ) *result->error_code = fapEXP_UNSUPP;
	}
	/* Check for third party packets. */
	else if ( typechar == '}' )
	{
		/* Come here to avoid the "when all else fails" option. */
	}
	/* When all else fails, try to look for a !-position that can occur
	   anywhere within the 40 first characters according to the spec. */
	else
	{
		tmp = strchr(body, '!');
		if ( tmp != NULL && (pos = tmp-body) < 40 && pos+1 < body_len ) /* Check that pos is not last char. */
		{
			result->type = malloc(sizeof(fap_packet_type_t));
			if ( !result->type ) return result;
			*result->type = fapLOCATION;
			poschar = tmp[1];

			/* Detect position type. */
			if ( poschar == 47 || poschar == 92 || (poschar >= 65 && poschar <= 90) || (poschar >= 97 && poschar <= 106) )
			{
				/* It's compressed position. */
				if ( body_len >= pos + 1 + 13 )
				{
					i = fapint_parse_compressed(result, body+pos+1);
					/* Check for comment. */
					if ( body_len - (pos+1) > 13 && i && result->symbol_code != '_' )
					{
						fapint_parse_comment(result, body+pos+1+13, body_len-pos-1-13);
					}
				}
			}
			else if ( isdigit(poschar) )
			{
				/* It's normal position. */
				if ( body_len >= pos + 1 + 19 )
				{
					i = fapint_parse_normal(result, tmp+1);
					/* Check for comment. */
					if ( body_len - (pos+1) > 19 && i && result->symbol_code != '_' )
					{
						fapint_parse_comment(result, body+pos+1+19, body_len-pos-1-19);
					}
				}
			}
		}
		else
		{
			/* No luck. It's propably not APRS packet at all. */
			result->error_code = malloc(sizeof(fap_error_code_t));
			if ( result->error_code ) *result->error_code = fapNO_APRS;
		}
	}
	
	/* We're done. */
	free(body);
	
	return result;
}



void fap_explain_error(fap_error_code_t const error, char* output)
{
	/* Dummy check. */
	if ( output == NULL )
	{
		return;
	}
	
	switch (error)
	{
		case fapPACKET_NO:
			sprintf(output, "No packet given to parse");
			break;
		case fapPACKET_SHORT:
			sprintf(output, "Too short packet");
			break;
		case fapPACKET_NOBODY:
			sprintf(output, "No body in packet");
			break;
		
		case fapSRCCALL_NOAX25:
			sprintf(output, "Source callsign is not a valid AX.25 call");
			break;
		case fapSRCCALL_BADCHARS:
			sprintf(output, "Source callsign contains bad characters");
			break;
		
		case fapDSTPATH_TOOMANY:
			sprintf(output, "Too many destination path components to be AX.25");
			break;
		case fapDSTCALL_NONE:
			sprintf(output, "No destination field in packet");
			break;
		case fapDSTCALL_NOAX25:
			sprintf(output, "Destination callsign is not a valid AX.25 call");
			break;
		
		case fapDIGICALL_NOAX25:
			sprintf(output, "Digipeater callsign is not a valid AX.25 call");
			break;
		case fapDIGICALL_BADCHARS:
			sprintf(output, "Digipeater callsign contains bad characters");
			break;
		
		case fapTIMESTAMP_INV_LOC:
			sprintf(output, "Invalid timestamp in location");
			break;
		case fapTIMESTAMP_INV_OBJ:
			sprintf(output, "Invalid timestamp in object");
			break;
		case fapTIMESTAMP_INV_STA:
			sprintf(output, "Invalid timestamp in status");
			break;
		case fapTIMESTAMP_INV_GPGGA:
			sprintf(output, "Invalid timestamp in GPGGA sentence");
			break;
		case fapTIMESTAMP_INV_GPGLL:
			sprintf(output, "Invalid timestamp in GPGLL sentence");
			break;
		
		case fapPACKET_INVALID:
			sprintf(output, "Invalid packet");
			break;
		
		case fapNMEA_INV_CVAL:
			sprintf(output, "Invalid coordinate value in NMEA sentence");
			break;
		case fapNMEA_LARGE_EW:
			sprintf(output, "Too large value in NMEA sentence (east/west)");
			break;
		case fapNMEA_LARGE_NS:
			sprintf(output, "Too large value in NMEA sentence (north/south)");
			break;
		case fapNMEA_INV_SIGN:
			sprintf(output, "Invalid lat/long sign in NMEA sentence");
			break;
		case fapNMEA_INV_CKSUM:
			sprintf(output, "Invalid checksum in NMEA sentence");
			break;
		
		case fapGPRMC_FEWFIELDS:
			sprintf(output, "Less than ten fields in GPRMC sentence");
			break;
		case fapGPRMC_NOFIX:
			sprintf(output, "No GPS fix in GPRMC sentence");
			break;
		case fapGPRMC_INV_TIME:
			sprintf(output, "Invalid timestamp in GPRMC sentence");
			break;
		case fapGPRMC_INV_DATE:
			sprintf(output, "Invalid date in GPRMC sentence");
			break;
		case fapGPRMC_DATE_OUT:
			sprintf(output, "GPRMC date does not fit in an Unix timestamp");
			break;
		
		case fapGPGGA_FEWFIELDS:
			sprintf(output, "Less than 11 fields in GPGGA sentence");
			break;
		case fapGPGGA_NOFIX:
			sprintf(output, "No GPS fix in GPGGA sentence");
			break;
		
		case fapGPGLL_FEWFIELDS:
			sprintf(output, "Less than 5 fields in GPGLL sentence");
			break;
		case fapGPGLL_NOFIX:
			sprintf(output, "No GPS fix in GPGLL sentence");
			break;
		
		case fapNMEA_UNSUPP:
			sprintf(output, "Unsupported NMEA sentence type");
			break;
		
		case fapOBJ_SHORT:
			sprintf(output, "Too short object");
			break;
		case fapOBJ_INV:
			sprintf(output, "Invalid object");
			break;
		case fapOBJ_DEC_ERR:
			sprintf(output, "Error in object location decoding");
			break;
		
		case fapITEM_SHORT:
			sprintf(output, "Too short item");
			break;
		case fapITEM_INV:
			sprintf(output, "Invalid item");
			break;
		case fapITEM_DEC_ERR:
			sprintf(output, "Error in item location decoding");
			break;
		
		case fapLOC_SHORT:
			sprintf(output, "Too short uncompressed location");
			break;
		case fapLOC_INV:
			sprintf(output, "Invalid uncompressed location");
			break;
		case fapLOC_LARGE:
			sprintf(output, "Degree value too large");
			break;
		case fapLOC_AMB_INV:
			sprintf(output, "Invalid position ambiguity");
			break;
		
		case fapMICE_SHORT:
			sprintf(output, "Too short mic-e packet");
			break;
		case fapMICE_INV:
			sprintf(output, "Invalid characters in mic-e packet");
			break;
		case fapMICE_INV_INFO:
			sprintf(output, "Invalid characters in mic-e information field");
			break;
		case fapMICE_AMB_LARGE:
			sprintf(output, "Too much position ambiguity in mic-e packet");
			break;
		case fapMICE_AMB_INV:
			sprintf(output, "Invalid position ambiguity in mic-e packet");
			break;
		case fapMICE_AMB_ODD:
			sprintf(output, "Odd position ambiguity in mic-e packet");
			break;
		
		case fapCOMP_INV:
			sprintf(output, "Invalid compressed packet");
			break;
		case fapCOMP_SHORT:
			sprintf(output, "Short compressed packet");
			break;
		
		case fapMSG_INV:
			sprintf(output, "Invalid message packet");
			break;
		
		case fapWX_UNSUPP:
			sprintf(output, "Unsupported weather format");
			break;
		case fapUSER_UNSUPP:
			sprintf(output, "Unsupported user format");
			break;
		
		case fapDX_INV_SRC:
			sprintf(output, "Invalid DX spot source callsign");
			break;
		case fapDX_INF_FREQ:
			sprintf(output, "Invalid DX spot frequency");
			break;
		case fapDX_NO_DX:
			sprintf(output, "No DX spot callsign found");
			break;
		
		case fapTLM_INV:
			sprintf(output, "Invalid telemetry packet");
			break;
		case fapTLM_LARGE:
			sprintf(output, "Too large telemetry value");
			break;
		case fapTLM_UNSUPP:
			sprintf(output, "Unsupported telemetry");
			break;
		
		case fapEXP_UNSUPP:
			sprintf(output, "Unsupported experimental");
			break;
		case fapSYM_INV_TABLE:
			sprintf(output, "Invalid symbol table or overlay");
			break;
		
		case fapNOT_IMPLEMENTED:
			sprintf(output, "Sorry, feature not implemented yet.");
			break;
		case fapNMEA_NOFIELDS:
			sprintf(output, "No fields in NMEA fields in NMEA packet.");
			break;
		
		case fapNO_APRS:
			sprintf(output, "Not an APRS packet");
			break;
		
		default:
			sprintf(output, "Default error message.");
			break;
	}
}



void fap_mice_mbits_to_message(char const* bits, char* output)
{
	/* Dummy check. */
	if ( bits == NULL || output == NULL )
	{
		return;
	}
	
	/* Detect known bit combinations. */
	if ( strcmp(bits, "111") == 0 ) sprintf(output, "off duty");
	else if ( strcmp(bits, "222") == 0 ) sprintf(output, "custom 0");
	else if ( strcmp(bits, "110") == 0 ) sprintf(output, "en route");
	else if ( strcmp(bits, "220") == 0 ) sprintf(output, "custom 1");
	else if ( strcmp(bits, "101") == 0 ) sprintf(output, "in service");
	else if ( strcmp(bits, "202") == 0 ) sprintf(output, "custom 2");
	else if ( strcmp(bits, "100") == 0 ) sprintf(output, "returning");
	else if ( strcmp(bits, "200") == 0 ) sprintf(output, "custom 3");
	else if ( strcmp(bits, "011") == 0 ) sprintf(output, "committed");
	else if ( strcmp(bits, "022") == 0 ) sprintf(output, "custom 4");
	else if ( strcmp(bits, "010") == 0 ) sprintf(output, "special");
	else if ( strcmp(bits, "020") == 0 ) sprintf(output, "custom 5");
	else if ( strcmp(bits, "001") == 0 ) sprintf(output, "priority");
	else if ( strcmp(bits, "002") == 0 ) sprintf(output, "custom 6");
	else if ( strcmp(bits, "000") == 0 ) sprintf(output, "emergency");
	else sprintf(output, "unknown");
}



double fap_distance(double lon0, double lat0, double lon1, double lat1)
{
	/* Convert degrees into radians. */
	lon0 = DEG2RAD(lon0);
	lat0 = DEG2RAD(lat0);
	lon1 = DEG2RAD(lon1);
	lat1 = DEG2RAD(lat1);

	/* Use the haversine formula for distance calculation
	 * http://mathforum.org/library/drmath/view/51879.html */
	double dlon = lon1 - lon0;
	double dlat = lat1 - lat0;
	double a = pow(sin(dlat/2),2) + cos(lat0) * cos(lat1) * pow(sin(dlon/2), 2);
	double c = 2 * atan2(sqrt(a), sqrt(1-a));
	
	return c * 6366.71; /* in kilometers */
}



double fap_direction(double lon0, double lat0, double lon1, double lat1)
{
	double direction;

	/* Convert degrees into radians. */
	lon0 = DEG2RAD(lon0);
	lat0 = DEG2RAD(lat0);
	lon1 = DEG2RAD(lon1);
	lat1 = DEG2RAD(lat1);
	
	/* Direction from Aviation Formulary V1.42 by Ed Williams by way of
	 * http://mathforum.org/library/drmath/view/55417.html */
	direction = atan2(sin(lon1-lon0)*cos(lat1), cos(lat0)*sin(lat1)-sin(lat0)*cos(lat1)*cos(lon1-lon0));
	if ( direction < 0 )
	{
		/* Make direction positive. */
		direction += 2 * PI;
	}

	return RAD2DEG(direction);
}



int fap_count_digihops(fap_packet_t const* packet)
{
	int i, len;
	unsigned int hopcount = 0, n, N;
	short wasdigied;
	char* element;
	char* call_ssid;

	unsigned int const matchcount = 3;
	regmatch_t matches[matchcount];
				
	
	/* Check input. */
	if ( !fapint_initialized || packet == NULL || packet->path == NULL )
	{
		return -1;
	}
	
	/* Process all path elements. */
	for ( i = 0; i < packet->path_len; ++i )
	{
		wasdigied = 0;
		
		/* Check if packet was digied due to this element. */
		if ( regexec(&fapint_regex_hopcount1, packet->path[i], matchcount, (regmatch_t*)&matches, 0) == 0 )
		{
			wasdigied = 1;

			/* Save working copy of the element, but without the '*'. */
			len = matches[1].rm_eo - matches[1].rm_so;
			element = malloc(len+1);
			if ( !element ) return -1;
			memcpy(element, packet->path[i]+matches[1].rm_so, len);
			element[len] = 0;
  
			/* Check the callsign for validity and expand it. */
			call_ssid = fap_check_ax25_call(element, 1);
			free(element);
		}
		else
		{
			call_ssid = fap_check_ax25_call(packet->path[i], 1);
		}

		/* Check validity test result. */
		if ( call_ssid == NULL )
		{
			return -1;
		}
		
		/* Check for WIDEn-N. */
		if ( regexec(&fapint_regex_hopcount2, call_ssid, matchcount, (regmatch_t*)&matches, 0) == 0 )
		{
			/* Get n and N by converting them from ASCII digits to numbers. */
			n = call_ssid[matches[1].rm_so] - 48;
			N = call_ssid[matches[2].rm_so] - 48;
			
			/* Add difference to hopcount, if not negative. */
			if ( (i = n - N) >= 0 )
			{
				hopcount += i;
			}
		}
		else
		{
			/* No WIDEn-N, TRACE and other things are calculated bases on the '*' indicators. */
			if ( wasdigied )
			{
				hopcount++;
			}
		}
		
		/* Prepare to check next path element. */
		free(call_ssid);
	}
				
	return hopcount;
}



char* fap_check_ax25_call(char const* input, short const add_ssid0)
{
	unsigned int const matchcount = 3;
	regmatch_t matches[matchcount];

	int ssid = 0, len;
	char call[7], ssid_str[4];
	
	char* result = NULL;
	char buf[10];
	
	
	/* Check initialization status. */
	if ( !fapint_initialized )
	{
		return NULL;
	}
	
	/* Check input. */
	if ( !input || !strlen(input) )
	{
		return NULL;
	}
	
	/* Validate callsign. */
	if ( regexec(&fapint_regex_ax25call, input, matchcount, (regmatch_t*)&matches, 0) == 0 )
	{
		/* Get callsign. */
		memset(call, 0, 7);
		len = matches[1].rm_eo - matches[1].rm_so;
		memcpy(call, input+matches[1].rm_so, len);

		/* Get SSID. */
		memset(ssid_str, 0, 4);
		len = matches[2].rm_eo - matches[2].rm_so;
		memcpy(ssid_str, input+matches[2].rm_so, len);
		
		/* If we got ssid, check that it is valid. */
		if ( len )
		{
			ssid = atoi(ssid_str);
			ssid = 0 - ssid;
			if ( ssid > 15 )
			{
				return NULL;
			}
		}
		
		/* Create result. */
		memset(buf, 0, 10);
		if ( !add_ssid0 && ssid == 0 )
		{
			sprintf(buf, "%s", call);
		}
		else
		{
			sprintf(buf, "%s-%d", call, ssid);
		}
			
		result = malloc( strlen(buf)+1 );
		if ( !result ) return NULL;
		strcpy(result, buf);
	}
	
	/* We're done. */
	return result;
}



int fap_kiss_to_tnc2(char const* kissframe, unsigned int kissframe_len,
                     char* tnc2frame, unsigned int* tnc2frame_len, unsigned int* tnc_id)
{
	char input[FRAME_MAXLEN];
	unsigned int input_len = 0;
	
	char output[2*FRAME_MAXLEN];
	unsigned int output_len = 0;
	
	int i = 0, j = 0, escape_mode = 0;

	/* Check that we got params. */
	if ( !kissframe || !kissframe_len || !tnc2frame || !tnc2frame_len || !tnc_id )
	{
		return 0;
	}
	
	/* Check that frame is short enough. */
	if ( kissframe_len >= FRAME_MAXLEN )
	{
		sprintf(output, "Too long KISS frame.");
		output_len = strlen(output)+1;
		if ( output_len > *tnc2frame_len ) output_len = *tnc2frame_len;
		memcpy(tnc2frame, output, output_len);
		*tnc2frame_len = output_len;
		return 0;
	}
	
	/* Check for FEND at start, remove if found. */
	if ( kissframe_len > 0 && (kissframe[0] & 0xff) == FEND )
	{
		kissframe += 1;
		kissframe_len -= 1;
	}
	
	/* Check for ending FEND. */
	for ( i = 0; i < kissframe_len; ++i )
	{
		if ( (kissframe[i] & 0xff) == FEND )
		{
			kissframe_len = i;
		}
	}
	
	/* Save and remove tnc id. */
	if ( kissframe_len > 0 )
	{
		*tnc_id = kissframe[0];
		kissframe += 1;
		kissframe_len -= 1;
	}
	
	/* Perform byte unstuffing. */
	j = 0;
	for ( i = 0; i < kissframe_len; ++i )
	{
		if ( (kissframe[i] & 0xff) == FESC )
		{
			escape_mode = 1;
			continue;
		}
	
		if ( escape_mode )
		{
			if ( (kissframe[i] & 0xff) == TFEND )
			{
				input[j] = FEND;
			}
			else if ( (kissframe[i] & 0xff) == TFESC )
			{
				input[j] = FESC;
			}
			escape_mode = 0;
			++j;
			continue;
		}
		
		input[j] = kissframe[i];
		++j;
	}
	input_len = j;

	/* Length checking _after_ byte unstuffing. */
	if ( input_len < 16 )
	{
		sprintf(output, "Too short KISS frame (%d bytes after unstuffing).", input_len);
		output_len = strlen(output)+1;
		if ( output_len > *tnc2frame_len ) output_len = *tnc2frame_len;
		memcpy(tnc2frame, output, output_len);
		*tnc2frame_len = output_len;
		return 0;
	}
	
	// Now we have an AX.25-frame, let's parse it.
	return fap_ax25_to_tnc2(input, input_len, tnc2frame, tnc2frame_len);
}



int fap_ax25_to_tnc2(char const* ax25frame, unsigned int ax25frame_len,
                     char* tnc2frame, unsigned int* tnc2frame_len)
{
	int i, j, retval = 1;
	char *checked_call, *dst_callsign = NULL;
	int part_no, header_len, ssid, digi_count;
	char tmp_callsign[10];
	char charri;

	char output[2*FRAME_MAXLEN];
	unsigned int output_len = 0;
	
	/* Check that we got params. */
	if ( !ax25frame || !ax25frame_len || !tnc2frame || !tnc2frame_len )
	{
		return 0;
	}
	
	/* Check that frame size is good. */
	if ( ax25frame_len >= FRAME_MAXLEN )
	{
		sprintf(output, "Too long AX.25 frame.");
		output_len = strlen(output)+1;
		if ( output_len > *tnc2frame_len ) output_len = *tnc2frame_len;
		memcpy(tnc2frame, output, output_len);
		*tnc2frame_len = output_len;
		return 0;
	}
	if ( ax25frame_len < 16 )
	{
		sprintf(output, "Too short AX.25 frame (%d bytes).", ax25frame_len);
		output_len = strlen(output)+1;
		if ( output_len > *tnc2frame_len ) output_len = *tnc2frame_len;
		memcpy(tnc2frame, output, output_len);
		*tnc2frame_len = output_len;
		return 0;
	}
	
	/* Go through the frame to get 4 parts: header, control field, pid and body. */
	part_no = 0;
	header_len = 0;
	memset(tmp_callsign, 0, 10);
	digi_count = 0;
	j = 0;
	for ( i = 0; i < ax25frame_len; ++i )
	{
		charri = ax25frame[i];
		
		if ( part_no == 0 )
		{
			/* New byte to header. */
			header_len++;
			
			/* We're at header, check if it should end with this byte. */
			if ( charri & 1 )
			{
				/* Yes, lets do some checks. */
				if ( header_len < 14 || header_len % 7 != 0 )
				{
					sprintf(output, "Invalid header length (%d).", header_len);
					output_len = strlen(output)+1;
					retval = 0;
					break;
				}
				
				/* Go for control field upon next cycle. */
				part_no = 1;
			}
			
			/* Check if a callsign is about to be complete. */
			if ( header_len && header_len % 7 == 0 )
			{
				/* This byte is SSID, get the number. */
				ssid = (charri >> 1) & 0xf;
				if ( ssid != 0 )
				{
					sprintf(tmp_callsign+6, "-%d", ssid);
				}
				/* Validate callsign. */
				checked_call = fapint_check_kiss_callsign(tmp_callsign);
				if ( !checked_call )
				{
					sprintf(output, "Invalid callsign in header (%s).", tmp_callsign);
					output_len = strlen(output)+1;
					retval = 0;
					break;
				}
				/* Figure out which part of header this callsign is. */
				if ( header_len == 7 )
				{
					/* We have a destination callsign. */
					dst_callsign = checked_call;
				}
				else if ( header_len == 14 )
				{
					/* We have a source callsign, copy it to the final frame directly. */
					output_len = sprintf(output, "%s>%s", checked_call, dst_callsign);
					free(dst_callsign);
					free(checked_call);
				}
				else if ( header_len > 14 )
				{
					/* We're at path part, save the call. */
					output_len += sprintf(output+output_len, "%s", checked_call);
					free(checked_call);
					/* Get the has-been-repeated flag. */
					if ( charri & 0x80 ) 
					{
						output[output_len] = '*';
						output_len++;
					}
					digi_count++;
				}
				else
				{
					sprintf(output, "Internal error.");
					output_len = strlen(output)+1;
					retval = 0;
					break;
				}
				/* Check what happens next. */
				if ( part_no == 0 )
				{
					/* More address fields will follow. Check that there's no more than 8 digis in path. */
					if ( digi_count >= 8 )
					{
						sprintf(output, "Too many digis.");
						output_len = strlen(output)+1;
						retval = 0;
						break;
					}
					output[output_len] = ',';
					output_len++;
				}
				else
				{
					/* End of header. */
					output[output_len] = ':';
					output_len++;
				}
				j = 0;
				memset(tmp_callsign, 0, 10);
				continue;
			}
			
			/* Shift one bit right to get the ascii character. */
			tmp_callsign[j] = (charri & 0xff) >> 1;
			++j;
		}
		else if ( part_no == 1 )
		{
			/* We're at control field. We are only interested in UI frames, discard others. */
			if ( (charri & 0xff) != AX25_FRAME_UI )
			{
				retval = 0;
				break;
			}
			part_no = 2;
		}
		else if ( part_no == 2 )
		{
			/* We're at pid. */
			if ( (charri & 0xff) != AX25_PID_APRS )
			{
				retval = 0;
				break;
			}
			part_no = 3;
		}
		else
		{
			output[output_len] = charri;
			output_len++;
		}
	}
	
	/* Copy result to output. */
	if ( output_len > *tnc2frame_len ) output_len = *tnc2frame_len;
	memcpy(tnc2frame, output, output_len);
	*tnc2frame_len = output_len;

	return retval;
}



int fap_tnc2_to_kiss(char const* tnc2frame, unsigned int tnc2frame_len, unsigned int const tnc_id,
                     char* kissframe, unsigned int* kissframe_len)
{
	char ax25frame[2*FRAME_MAXLEN];
	unsigned int ax25frame_len;
	int i;

	/* Initialize slot for starting FEND and tnc id by skipping two first bytes of our conversion buffer. */
	ax25frame_len = 2*FRAME_MAXLEN-2;
	memset(ax25frame, 0, 2);
	
	/* Convert into AX.25-frame. */
	if ( !fap_tnc2_to_ax25(tnc2frame, tnc2frame_len, ax25frame+2, &ax25frame_len) )
	{
		strcpy(kissframe, ax25frame);
		*kissframe_len = strlen(kissframe);
		return 0;
	}
	ax25frame_len += 2;
	
	/* Check for room in output buffer. */
	if ( *kissframe_len <= ax25frame_len )
	{
		return 0;
	}
	
	/* Perform byte stuffing. */
	*kissframe_len = 2;
	for ( i = 2; i < ax25frame_len; ++i )
	{
		if ( (ax25frame[i] & 0xff) == FEND || (ax25frame[i] & 0xff) == FESC )
		{
			kissframe[*kissframe_len] = FESC;
			(*kissframe_len)++;
			if ( (ax25frame[i] & 0xff) == FEND )
			{
				kissframe[*kissframe_len] = TFEND;
			}
			else
			{
				kissframe[*kissframe_len] = TFESC;
			}
			(*kissframe_len)++;
		}
		else
		{
			kissframe[*kissframe_len] = ax25frame[i];
			(*kissframe_len)++;
		}
	}
	
	/* Put FENDs and tnc id in place. */
	kissframe[0] = FEND;
	kissframe[1] = tnc_id;
	kissframe[*kissframe_len] = FEND;
	(*kissframe_len)++;
	
	return 1;
}



int fap_tnc2_to_ax25(char const* tnc2frame, unsigned int tnc2frame_len,
                     char* ax25frame, unsigned int* ax25frame_len)
{
	char input[FRAME_MAXLEN];
	
	char output[2*FRAME_MAXLEN];
	unsigned int output_len = 0;

	char *header = NULL, *digipeaters = NULL, *body = NULL;
	unsigned int digi_count, body_len;

	char sender[6], sender_ssid[4], receiver[6], receiver_ssid[4];
	int sender_ssid_num = 0, receiver_ssid_num = 0;
	
	char digicall[6], digicall_ssid[4], hbit;
	int digicall_ssid_num = 0;

	int retval = 1, len, i;
	char* tmp_str;
	
	unsigned int const matchcount = 6;
	regmatch_t matches[matchcount];
	
	
	/* Check params. */
	if ( !tnc2frame || !tnc2frame_len || tnc2frame_len >= FRAME_MAXLEN || !ax25frame || !ax25frame_len )
	{  
		return 0;
	}
	
	/* Create working copy of input. */
	memset(input, 0, FRAME_MAXLEN);
	memcpy(input, tnc2frame, tnc2frame_len );
	
	/* Separate header and body. */
	if ( regexec(&fapint_regex_kiss_hdrbdy, input, matchcount, (regmatch_t*)&matches, 0) == 0 )
	{
		len = matches[1].rm_eo - matches[1].rm_so;
		header = malloc(len+1);
		if ( !header ) return 0;
		memcpy(header, input+matches[1].rm_so, len);
		header[len] = 0;
		
		body_len = matches[2].rm_eo - matches[2].rm_so;
		body = malloc(body_len);
		if ( !body )
		{
			free(header);
			return 0;
		}
		memcpy(body, input+matches[2].rm_so, body_len);
	}
	else
	{
		sprintf(output, "Failed to separate header and body of TNC-2 packet.");
		output_len = strlen(output)+1;
		if ( output_len > *ax25frame_len ) output_len = *ax25frame_len;
		strcpy(ax25frame, output);
		*ax25frame_len = output_len;
		return 0;
	}
	
	/* Separate the sender, recipient and digipeaters. */
	if ( regexec(&fapint_regex_hdr_detail, header, matchcount, (regmatch_t*)&matches, 0) == 0 )
	{
		len = matches[1].rm_eo - matches[1].rm_so;
		memset(sender, ' ', 6);
		memcpy(sender, header+matches[1].rm_so, len);
		
		len = matches[2].rm_eo - matches[2].rm_so;
		memset(sender_ssid, 0, 4);
		if ( len )
		{
			memcpy(sender_ssid, header+matches[2].rm_so, len);
		}
		
		len = matches[3].rm_eo - matches[3].rm_so;
		memset(receiver, ' ', 6);
		memcpy(receiver, header+matches[3].rm_so, len);
		
		len = matches[4].rm_eo - matches[4].rm_so;
		memset(receiver_ssid, 0, 4);
		if ( len )
		{
			memcpy(receiver_ssid, header+matches[4].rm_so, len);
		}
		
		len = matches[5].rm_eo - matches[5].rm_so;
		if ( len )
		{
			digipeaters = malloc(len+5);
			if ( !digipeaters )
			{
				free(header);
				free(body);
				return 0;
			}
			memcpy(digipeaters, header+matches[5].rm_so, len);
			digipeaters[len] = 0;
		}
	}
	else
	{
		free(header);
		free(body);
		return 0;
	}
	free(header);
	
	/* Frame header compilation is done in a easy-to-break-out block. */
	while ( 1 )
	{
		/* Check SSID format and convert to number. */
		if ( sender_ssid[0] == '-' )
		{
			sender_ssid_num = 0 - atoi(sender_ssid);
			if ( sender_ssid_num > 15 )
			{
				retval = 0;
				break;
			}
		}
		if ( receiver_ssid[0] == '-' )
		{
			receiver_ssid_num = 0 - atoi(receiver_ssid);
			if ( receiver_ssid_num > 15 )
			{
				retval = 0;
				break;
			}
		}
	
		/* Encode destination and source. */
		for ( i = 0; i < 6; ++i )
		{
			output[output_len] = receiver[i] << 1;
			output_len++;
		}
		output[output_len] = 0xe0 | (receiver_ssid_num << 1);
		output_len++;
		for ( i = 0; i < 6; ++i )
		{
			output[output_len] = sender[i] << 1;
			output_len++;
		}   
		if ( digipeaters )
		{
			output[output_len] = 0x60 | (sender_ssid_num << 1);
		}
		else
		{
			output[output_len] = 0x61 | (sender_ssid_num << 1);
		}
		output_len++;
		
		/* If there are digipeaters, add them. */
		if ( digipeaters )
		{
			/* Split into parts. */
			tmp_str = strtok(digipeaters+1, ",");
			digi_count = 0;
			while ( tmp_str != NULL )
			{
				/* Split into callsign, SSID and h-bit. */
				if ( regexec(&fapint_regex_kiss_digi, tmp_str, matchcount, (regmatch_t*)&matches, 0) == 0 )
				{
					/* digi's plain callsign */
					len = matches[1].rm_eo - matches[1].rm_so;
					memset(digicall, ' ', 6);
					memcpy(digicall, tmp_str+matches[1].rm_so, len);
					
					/* ssid */
					digicall_ssid_num = 0;
					len = matches[2].rm_eo - matches[2].rm_so;
					if ( len )
					{
						memset(digicall_ssid, 0, 4);
						memcpy(digicall_ssid, tmp_str+matches[2].rm_so, len);
						
						digicall_ssid_num = 0 - atoi(digicall_ssid);
						if ( digicall_ssid_num > 15 )
						{
							retval = 0;
							break;
						}
					}
					
					/* h-bit */
					hbit = 0x00;
					if ( tmp_str[matches[3].rm_so] == '*' )
					{
						hbit = 0x80;
					}
					
					/* Check for next part. */
					tmp_str = strtok(NULL, ",");
					
					/* Add plain callsign frame. */
					for ( i = 0; i < 6; ++i )
					{
						output[output_len] = digicall[i] << 1;
						output_len++;
					}
					/* Add ssid. */
					if ( tmp_str )
					{
						/* More digipeaters to follow. */
						output[output_len] = 0x60 | (digicall_ssid_num << 1) | hbit;
					}
					else
					{
						/* Last digipeater. */
						output[output_len] = 0x61 | (digicall_ssid_num << 1) | hbit;
					}
					output_len++;
				}
				else
				{
					/* Invalid digi callsign. */
					retval = 0;
					break;
				}
			}
		}
		
		/* Frame header compiled. */
		break;
	}   
	if ( digipeaters ) free(digipeaters);
	
	
	/* Add frame type and pid. */
	output[output_len] = AX25_FRAME_UI;
	output_len++;
	output[output_len] = AX25_PID_APRS;
	output_len++;
	
	/* Add body. */
	memcpy(output+output_len, body, body_len);
	output_len += body_len;
	free(body);
	
	/* Check how header compilation went. */
	if ( !retval )
	{
		return 0;
	}
	
	/* Return result. */
	if ( output_len > *ax25frame_len ) output_len = *ax25frame_len;
	memcpy(ax25frame, output, output_len);
	*ax25frame_len = output_len;
	return 1;
}



void fap_init()
{
	if ( !fapint_initialized )
	{
		/* Compile regexs. */
		regcomp(&fapint_regex_header, "^([A-Z0-9\\-]{1,9})>(.*)$", REG_EXTENDED);
		regcomp(&fapint_regex_ax25call, "^([A-Z0-9]{1,6})(-[0-9]{1,2}|())$", REG_EXTENDED);
		regcomp(&fapint_regex_digicall, "^([a-zA-Z0-9-]{1,9})([*]?)$", REG_EXTENDED);
		regcomp(&fapint_regex_digicallv6, "^([0-9A-F]{32})$", REG_EXTENDED|REG_NOSUB);

		regcomp(&fapint_regex_normalpos, "^([0-9]{2})([0-7 ][0-9 ]\\.[0-9 ]{2})([NnSs])(.)([0-9]{3})([0-7 ][0-9 ]\\.[0-9 ]{2})([EeWw])(.)", REG_EXTENDED);
		regcomp(&fapint_regex_normalamb, "^([0-9]{0,4})( {0,4})$", REG_EXTENDED);
		regcomp(&fapint_regex_timestamp, "^([0-9]{2})([0-9]{2})([0-9]{2})([zh\\/])", REG_EXTENDED);

		regcomp(&fapint_regex_mice_dstcall, "^[0-9A-LP-Z]{3}[0-9LP-Z]{3}$", REG_EXTENDED|REG_NOSUB);      
		regcomp(&fapint_regex_mice_body, "^[\\/\\\\A-Z0-9]", REG_EXTENDED|REG_NOSUB);
		regcomp(&fapint_regex_mice_amb, "^([0-9]+)(_*)$", REG_EXTENDED);
		
		regcomp(&fapint_regex_comment, "^([0-9\\. ]{3})\\/([0-9\\. ]{3})", REG_EXTENDED|REG_NOSUB);
		regcomp(&fapint_regex_phgr, "^PHG([0-9].[0-9]{2}[1-9A-Z])\\/", REG_EXTENDED|REG_NOSUB);
		regcomp(&fapint_regex_phg, "^PHG([0-9].[0-9]{2})", REG_EXTENDED|REG_NOSUB);
		regcomp(&fapint_regex_rng, "^RNG([0-9]{4})", REG_EXTENDED|REG_NOSUB);
		regcomp(&fapint_regex_altitude, "\\/A=(-[0-9]{5}|[0-9]{6})", REG_EXTENDED);
		
		regcomp(&fapint_regex_mes_dst, "^:([A-Za-z0-9_ -]{9}):", REG_EXTENDED);
		regcomp(&fapint_regex_mes_ack, "^ack([A-Za-z0-9}]{1,5}) *$", REG_EXTENDED);
		regcomp(&fapint_regex_mes_nack, "^rej([A-Za-z0-9}]{1,5}) *$", REG_EXTENDED);

		regcomp(&fapint_regex_wx1, "^_{0,1}([0-9 \\.\\-]{3})\\/([0-9 \\.]{3})g([0-9 \\.]+)t(-{0,1}[0-9 \\.]+)", REG_EXTENDED);
		regcomp(&fapint_regex_wx2, "^_{0,1}c([0-9 \\.\\-]{3})s([0-9 \\.]{3})g([0-9 \\.]+)t(-{0,1}[0-9 \\.]+)", REG_EXTENDED);
		regcomp(&fapint_regex_wx3, "^_{0,1}([0-9 \\.\\-]{3})\\/([0-9 \\.]{3})t(-{0,1}[0-9 \\.]+)", REG_EXTENDED);
		regcomp(&fapint_regex_wx4, "^_{0,1}([0-9 \\.\\-]{3})\\/([0-9 \\.]{3})g([0-9 \\.]+)", REG_EXTENDED);
		regcomp(&fapint_regex_wx5, "^g([0-9]+)t(-?[0-9 \\.]{1,3})", REG_EXTENDED);
 
		regcomp(&fapint_regex_wx_r1, "r([0-9]{1,3})", REG_EXTENDED);
		regcomp(&fapint_regex_wx_r24, "p([0-9]{1,3})", REG_EXTENDED);
		regcomp(&fapint_regex_wx_rami, "P([0-9]{1,3})", REG_EXTENDED);

		regcomp(&fapint_regex_wx_humi, "h([0-9]{1,3})", REG_EXTENDED);
		regcomp(&fapint_regex_wx_pres, "b([0-9]{4,5})", REG_EXTENDED);
		regcomp(&fapint_regex_wx_lumi, "([lL])([0-9]{1,3})", REG_EXTENDED);
		regcomp(&fapint_regex_wx_what, "v([\\-\\+]{0,1}[0-9]+)", REG_EXTENDED);
		
		regcomp(&fapint_regex_wx_snow, "s([0-9]+)", REG_EXTENDED);
		regcomp(&fapint_regex_wx_rrc, "#([0-9]+)", REG_EXTENDED);
		regcomp(&fapint_regex_wx_any, "^([rPphblLs#][\\. ]{1,5})+", REG_EXTENDED);
		regcomp(&fapint_regex_wx_soft, "^[a-zA-Z0-9\\-\\_]{3,5}$", REG_EXTENDED|REG_NOSUB);
		
		regcomp(&fapint_regex_nmea_chksum, "^(.+)\\*([0-9A-F]{2})$", REG_EXTENDED);
		regcomp(&fapint_regex_nmea_dst, "^(GPS|SPC)([A-Z0-9]{2,3})", REG_EXTENDED);
		regcomp(&fapint_regex_nmea_time, "^[:space:]*([0-9]{2})([0-9]{2})([0-9]{2})(()|\\.[0-9]+)[:space:]*$", REG_EXTENDED);
		regcomp(&fapint_regex_nmea_date, "^[:space:]*([0-9]{2})([0-9]{2})([0-9]{2})[:space:]*$", REG_EXTENDED);

		regcomp(&fapint_regex_nmea_specou, "^[:space:]*([0-9]+(()|\\.[0-9]+))[:space:]*$", REG_EXTENDED);
		regcomp(&fapint_regex_nmea_fix, "^[:space:]*([0-9]+)[:space:]*$", REG_EXTENDED);
		regcomp(&fapint_regex_nmea_altitude, "^(-?[0-9]+(()|\\.[0-9]+))$", REG_EXTENDED);
		regcomp(&fapint_regex_nmea_flag, "^[:space:]*([NSEWnsew])[:space:]*$", REG_EXTENDED);
		regcomp(&fapint_regex_nmea_coord, "^[:space:]*([0-9]{1,3})([0-5][0-9]\\.([0-9]+))[:space:]*$", REG_EXTENDED);

		regcomp(&fapint_regex_telemetry, "^([0-9]+),(-?)([0-9]{1,6}|[0-9]+\\.[0-9]+|\\.[0-9]+)?,(-?)([0-9]{1,6}|[0-9]+\\.[0-9]+|\\.[0-9]+)?,(-?)([0-9]{1,6}|[0-9]+\\.[0-9]+|\\.[0-9]+)?,(-?)([0-9]{1,6}|[0-9]+\\.[0-9]+|\\.[0-9]+)?,(-?)([0-9]{1,6}|[0-9]+\\.[0-9]+|\\.[0-9]+)?,([01]{0,8})", REG_EXTENDED);
		regcomp(&fapint_regex_peet_splitter, "^([0-9a-f]{4}|----)", REG_EXTENDED|REG_ICASE);
		regcomp(&fapint_regex_kiss_callsign, "^([A-Z0-9]+) *(-[0-9]+)?$", REG_EXTENDED);

		regcomp(&fapint_regex_detect_comp, "^[\\/\\\\A-Za-j]$", REG_EXTENDED|REG_NOSUB);
		regcomp(&fapint_regex_detect_wx, "^_([0-9]{8})c[- .0-9]{1,3}s[- .0-9]{1,3}", REG_EXTENDED|REG_NOSUB);
		regcomp(&fapint_regex_detect_telem, "^T#(.*?),(.*)$", REG_EXTENDED|REG_NOSUB);
		regcomp(&fapint_regex_detect_exp, "^\\{\\{", REG_EXTENDED|REG_NOSUB);
	
		regcomp(&fapint_regex_kiss_hdrbdy, "^([A-Z0-9,*>-]+):(.+)$", REG_EXTENDED);
		regcomp(&fapint_regex_hdr_detail, "^([A-Z0-9]{1,6})(-[0-9]{1,2})?>([A-Z0-9]{1,6})(-[0-9]{1,2})?(,.*)?$", REG_EXTENDED);
		regcomp(&fapint_regex_kiss_digi, "^([A-Z0-9]{1,6})(-[0-9]{1,2})?(\\*)?$", REG_EXTENDED);
		
		regcomp(&fapint_regex_base91_telemetry, "\\|([!-{]{2})([!-{]{2})([!-{]{2}|)([!-{]{2}|)([!-{]{2}|)([!-{]{2}|)([!-{]{2}|)\\|", REG_EXTENDED);
		
		regcomp(&fapint_regex_hopcount1, "^([A-Z0-9-]+)\\*$", REG_EXTENDED);
		regcomp(&fapint_regex_hopcount2, "^WIDE([1-7])-([0-7])$", REG_EXTENDED);
	
		
		/* Initialized. */
		fapint_initialized = 1;
	}
}



void fap_cleanup()
{
	if ( fapint_initialized )
	{
		/* Free regexs. */
		regfree(&fapint_regex_header);
		regfree(&fapint_regex_ax25call);
		regfree(&fapint_regex_digicall);
		regfree(&fapint_regex_digicallv6);

		regfree(&fapint_regex_normalpos);
		regfree(&fapint_regex_normalamb);
		regfree(&fapint_regex_timestamp);
		
		regfree(&fapint_regex_mice_dstcall);
		regfree(&fapint_regex_mice_body);
		regfree(&fapint_regex_mice_amb);
		
		regfree(&fapint_regex_comment);
		regfree(&fapint_regex_phgr);
		regfree(&fapint_regex_phg);
		regfree(&fapint_regex_rng);
		regfree(&fapint_regex_altitude);
		
		regfree(&fapint_regex_mes_dst);
		regfree(&fapint_regex_mes_ack);
		regfree(&fapint_regex_mes_nack);
		
		regfree(&fapint_regex_wx1);
		regfree(&fapint_regex_wx2);
		regfree(&fapint_regex_wx3);
		regfree(&fapint_regex_wx4);
		regfree(&fapint_regex_wx5);
		
		regfree(&fapint_regex_wx_r1);
		regfree(&fapint_regex_wx_r24);
		regfree(&fapint_regex_wx_rami);

		regfree(&fapint_regex_wx_humi);
		regfree(&fapint_regex_wx_pres);
		regfree(&fapint_regex_wx_lumi);
		regfree(&fapint_regex_wx_what);
		
		regfree(&fapint_regex_wx_snow);
		regfree(&fapint_regex_wx_rrc);
		regfree(&fapint_regex_wx_any);
		regfree(&fapint_regex_wx_soft);
		
		regfree(&fapint_regex_nmea_chksum);
		regfree(&fapint_regex_nmea_dst);
		regfree(&fapint_regex_nmea_time);
		regfree(&fapint_regex_nmea_date);

		regfree(&fapint_regex_nmea_specou);
		regfree(&fapint_regex_nmea_fix);
		regfree(&fapint_regex_nmea_altitude);
		regfree(&fapint_regex_nmea_flag);
		regfree(&fapint_regex_nmea_coord);
		
		regfree(&fapint_regex_telemetry);
		regfree(&fapint_regex_peet_splitter);
		regfree(&fapint_regex_kiss_callsign);
		
		regfree(&fapint_regex_detect_comp);
		regfree(&fapint_regex_detect_wx);
		regfree(&fapint_regex_detect_telem);
		regfree(&fapint_regex_detect_exp);
		
		regfree(&fapint_regex_kiss_hdrbdy);
		regfree(&fapint_regex_hdr_detail);
		regfree(&fapint_regex_kiss_digi);
		
		regfree(&fapint_regex_base91_telemetry);
		
		regfree(&fapint_regex_hopcount1);
		regfree(&fapint_regex_hopcount2);
		
		/* No more initialized. */
		fapint_initialized = 0;
	}
}



void fap_free(fap_packet_t* packet)
{
	unsigned int i;
	
	if ( packet == NULL )
	{
		return;
	}

	if ( packet->error_code ) { free(packet->error_code); }
	if ( packet->type ) { free(packet->type); }
	
	if ( packet->orig_packet ) { free(packet->orig_packet); }

	if ( packet->header ) { free(packet->header); }
	if ( packet->body ) { free(packet->body); }
	if ( packet->src_callsign ) { free(packet->src_callsign); }
	if ( packet->dst_callsign ) { free(packet->dst_callsign); }
	for ( i = 0; i < packet->path_len; ++i )
	{
		if ( packet->path[i] ) { free(packet->path[i]); }
	}
	if ( packet->path ) { free(packet->path); }

	if ( packet->latitude ) { free(packet->latitude); }
	if ( packet->longitude ) { free(packet->longitude); }
	if ( packet->format ) { free(packet->format); }
	if ( packet->pos_resolution ) { free(packet->pos_resolution); }
	if ( packet->pos_ambiguity ) { free(packet->pos_ambiguity); }
	
	if ( packet->altitude ) { free(packet->altitude); }
	if ( packet->course ) { free(packet->course); }
	if ( packet->speed ) { free(packet->speed); }

	if ( packet->messaging ) { free(packet->messaging); }   
	if ( packet->destination ) { free(packet->destination); }
	if ( packet->message ) { free(packet->message); }   
	if ( packet->message_ack ) { free(packet->message_ack); }   
	if ( packet->message_nack ) { free(packet->message_nack); }   
	if ( packet->message_id ) { free(packet->message_id); }   
	if ( packet->comment ) { free(packet->comment); }

	if ( packet->object_or_item_name ) { free(packet->object_or_item_name); }
	if ( packet->alive ) { free(packet->alive); }

	if ( packet->gps_fix_status ) { free(packet->gps_fix_status); }
	if ( packet->radio_range ) { free(packet->radio_range); }
	if ( packet->phg ) { free(packet->phg); }
	if ( packet->timestamp ) { free(packet->timestamp); }
	if ( packet->raw_timestamp ) { free(packet->raw_timestamp); }
	if ( packet->nmea_checksum_ok ) { free(packet->nmea_checksum_ok); }
	
	if ( packet->wx_report )
	{
		if ( packet->wx_report->wind_gust ) { free(packet->wx_report->wind_gust); }
		if ( packet->wx_report->wind_dir ) { free(packet->wx_report->wind_dir); }
		if ( packet->wx_report->wind_speed ) { free(packet->wx_report->wind_speed); }

		if ( packet->wx_report->temp ) { free(packet->wx_report->temp); }
		if ( packet->wx_report->temp_in ) { free(packet->wx_report->temp_in); }

		if ( packet->wx_report->rain_1h ) { free(packet->wx_report->rain_1h); }
		if ( packet->wx_report->rain_24h ) { free(packet->wx_report->rain_24h); }
		if ( packet->wx_report->rain_midnight ) { free(packet->wx_report->rain_midnight); }
		
		if ( packet->wx_report->humidity ) { free(packet->wx_report->humidity); }
		if ( packet->wx_report->humidity_in ) { free(packet->wx_report->humidity_in); }
		
		if ( packet->wx_report->pressure ) { free(packet->wx_report->pressure); }
		if ( packet->wx_report->luminosity ) { free(packet->wx_report->luminosity); }

		if ( packet->wx_report->snow_24h ) { free(packet->wx_report->snow_24h); }

		if ( packet->wx_report->soft ) { free(packet->wx_report->soft); }

		free(packet->wx_report);
	}
	
	if ( packet->telemetry )
	{
		if ( packet->telemetry->seq ) { free(packet->telemetry->seq); }
		if ( packet->telemetry->val1 ) { free(packet->telemetry->val1); }
		if ( packet->telemetry->val2 ) { free(packet->telemetry->val2); }
		if ( packet->telemetry->val3 ) { free(packet->telemetry->val3); }
		if ( packet->telemetry->val4 ) { free(packet->telemetry->val4); }
		if ( packet->telemetry->val5 ) { free(packet->telemetry->val5); }
		free(packet->telemetry);
	}

	if ( packet->messagebits ) { free(packet->messagebits); }
	if ( packet->status ) { free(packet->status); }
	for ( i = 0; i < packet->capabilities_len*2; i += 2 )
	{
		if ( packet->capabilities[i] ) { free(packet->capabilities[i]); }
		if ( packet->capabilities[i+1] ) { free(packet->capabilities[i+1]); }
	}
	if ( packet->capabilities ) { free(packet->capabilities); }
	
	free(packet);
}
