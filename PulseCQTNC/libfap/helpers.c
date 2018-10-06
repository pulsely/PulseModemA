/* $Id: helpers.c 226 2014-11-23 12:33:36Z oh2gve $
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
 * \file helpers.c
 * \brief Implementation of helper functions for fap.c.
 * \author Tapio Aaltonen
*/


#include "helpers.h"
#include "helpers2.h"
#include "regs.h"
#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <regex.h>
#include <ctype.h>
#include <math.h>



int fapint_parse_header(fap_packet_t* packet, short const is_ax25)
{
	int i, len, startpos, retval = 1;
	char* rest = NULL;
	char* tmp = NULL;
	char buf_10b[10];
	fapint_llist_item_t* path;
	int path_len;
	fapint_llist_item_t* current_elem;
	short seenq = 0;
	
	unsigned int const matchcount = 3;
	regmatch_t matches[matchcount];
	
	/* Separate source callsign and the rest. */
	if ( regexec(&fapint_regex_header, packet->header, matchcount, (regmatch_t*)&matches, 0) == 0 )
	{
		/* Save (and validate if we're AX.25) the callsign. */
		tmp = malloc(matches[1].rm_eo+1);
		if ( !tmp ) return 0;
		memcpy(tmp, packet->header, matches[1].rm_eo);
		tmp[matches[1].rm_eo] = 0;
		if ( is_ax25 )
		{
			packet->src_callsign = fap_check_ax25_call(tmp, 0);
			free(tmp);
			if ( !packet->src_callsign )
			{
				packet->error_code = malloc(sizeof(fap_error_code_t));
				if ( packet->error_code ) *packet->error_code = fapSRCCALL_NOAX25;
				retval = 0;
			}
		}
		else
		{
			packet->src_callsign = tmp;
		}
		
		/* Save the rest of the header also 0-terminated string. */
		len = matches[2].rm_eo - matches[2].rm_so;
		rest = malloc(len+1);
		if ( !rest ) return 0;
		memcpy(rest, packet->header + matches[2].rm_so, len);
		rest[len] = 0;
	}
	else
	{
		packet->error_code = malloc(sizeof(fap_error_code_t));
		if ( packet->error_code ) *packet->error_code = fapSRCCALL_BADCHARS;
		retval = 0;
	}
	if ( !retval )
	{
	        if ( rest ) free(rest);
		return 0;
	}
	
	/* Find path elements. */
	len = 0;
	startpos = 0;
	path = NULL;
	path_len = -1;
	current_elem = NULL;
	tmp = NULL;
	for ( i = 0; i < strlen(rest); ++i )
	{
		tmp = NULL;
		
		/* Look for element boundary. */
		if ( rest[i] == ',' )
		{
			/* Found a bound, let's create a copy of the element it ends. */
			len = i - startpos;
			tmp = malloc(len+1);
			if ( !tmp )
			{
				retval = 0;
				break;
			}
			memcpy(tmp, rest+startpos, len);
			tmp[len] = 0;
			
			/* Start to look for next element. */
			startpos = i + 1;
		}
		else if ( i+1 == strlen(rest) )
		{
			/* We're at the end, save the last element. */
			len = i+1 - startpos;
			tmp = malloc(len+1);
			if ( !tmp )
			{
				retval = 0;
				break;
			}
			memcpy(tmp, rest+startpos, len);
			tmp[len] = 0;
		}
		
		/* Check if we found something. */
		if ( tmp )
		{
			/* Create list item. */
			if ( path == NULL )
			{
				path = malloc(sizeof(fapint_llist_item_t));
				if ( !path )
				{
					retval = 0;
					break;
				}
				current_elem = path;
			}
			else
			{
				current_elem->next = malloc(sizeof(fapint_llist_item_t));
				if ( !current_elem->next )
				{
					retval = 0;
					break;
				}
				current_elem = current_elem->next;
			}
			current_elem->next = NULL;
			current_elem->text = tmp;
			
			++path_len;
		}
	}
	if ( !retval )
	{
		if ( tmp ) free(tmp);
		fapint_clear_llist(path);
		free(rest);
		return 0;
	}
	
	/* Check that we got at least destination callsign. */
	if ( !path )
	{
		/* Found nothing. */
		packet->error_code = malloc(sizeof(fap_error_code_t));
		if ( packet->error_code ) *packet->error_code = fapDSTCALL_NONE;
		fapint_clear_llist(path);
		free(rest);
		return 0;
	}

	/* Validate dst call. We are strict here, there should be no need to use
	 * a non-AX.25 compatible destination callsigns in the APRS-IS. */
	packet->dst_callsign = fap_check_ax25_call(path->text, 0);
	if ( !packet->dst_callsign )
	{
		packet->error_code = malloc(sizeof(fap_error_code_t));
		if ( packet->error_code ) *packet->error_code = fapDSTCALL_NOAX25;
		fapint_clear_llist(path);
		free(rest);
		return 0;
	}

	/* If in AX.25 mode, check that path length is valid. */
	if ( is_ax25 && path_len > MAX_DIGIS )
	{
		packet->error_code = malloc(sizeof(fap_error_code_t));
		if ( packet->error_code ) *packet->error_code = fapDSTPATH_TOOMANY;
		fapint_clear_llist(path);
		free(rest);
		return 0;
	}

	/* Validate path elements, saving them while going. */
	packet->path = calloc(path_len, sizeof(char*));
	if ( !packet->path )
	{
		fapint_clear_llist(path);
		free(rest);
	}
	for ( i = 0; i < path_len; ++i ) packet->path[i] = NULL;
	i = 0;
	current_elem = path->next;
	while ( current_elem != NULL )
	{
		/* First we validate the element in a relaxed, APRS-IS-compatible way. */
		if ( regexec(&fapint_regex_digicall, current_elem->text, matchcount, (regmatch_t*)&matches, 0) == 0 )
		{
			/* Check if we need to be AX.25-strict. */
			if ( is_ax25 )
			{
				/* Create a copy the element without the has-been-repeated flag. */
				memset(buf_10b, 0, 10);
				memcpy(buf_10b, current_elem->text, matches[1].rm_eo);
				
				/* Validate it in AX.25-way. */
				tmp = fap_check_ax25_call(buf_10b, 1);
				if ( !tmp )
				{
					packet->error_code = malloc(sizeof(fap_error_code_t));
					if ( packet->error_code ) *packet->error_code = fapDIGICALL_NOAX25;
					retval = 0;
					break;
				}
				free(tmp);
			}
			
			/* Save the callsign as originally given. */
			len = strlen(current_elem->text);
			packet->path[i] = malloc(len+1);
			if ( !packet->path[i] )
			{
				retval = 0;
				break;
			}
			strcpy(packet->path[i], current_elem->text);
			
			/* Check if this element was a q-construct. */
			if ( !seenq && current_elem->text[0] == 'q' ) seenq = 1;
		}
		/* This includes accepting IPv6 addresses after q-construct. */
		else if ( seenq && regexec(&fapint_regex_digicallv6, current_elem->text, 0, NULL, 0) == 0 )
		{
			/* Save the callsign as originally given. */
			len = strlen(current_elem->text);
			packet->path[i] = malloc(len+1);
			if ( !packet->path[i] )
			{
				retval = 0;
				break;
			}
			strcpy(packet->path[i], current_elem->text);
		}
		else
		{
			packet->error_code = malloc(sizeof(fap_error_code_t));
			if ( packet->error_code ) *packet->error_code = fapDIGICALL_BADCHARS;
			retval = 0;
			break;
		}            
		
		/* Get next element. */
		current_elem = current_elem->next;
		++i;
	}
	if ( !retval )
	{
		fapint_clear_llist(path);
		for ( len = 0; len <= i; ++len ) { free(packet->path[len]); }
		free(packet->path);
		packet->path = NULL;
		free(rest);
		return 0;
	}
	packet->path_len = path_len;

	/* Header parsed. */
	fapint_clear_llist(path);
	free(rest);
	return 1;
}



int fapint_parse_mice(fap_packet_t* packet, char const* input, unsigned int const input_len)
{
	int len, error, i, lon;
	unsigned int tmp_us;
	char *rest, *tmp_str;
	char dstcall[7], latitude[7], buf_6b[6], longitude[6];
	double speed, course_speed, course_speed_tmp, course;
	char dao[3];

	unsigned int const matchcount = 3;
	regmatch_t matches[matchcount];

	/* Body must be at least 8 chars long. Destination callsign must exist. */
	if ( input_len < 8 || packet->dst_callsign == NULL )
	{
		packet->error_code = malloc(sizeof(fap_error_code_t));
		if ( packet->error_code ) *packet->error_code = fapMICE_SHORT;
		return 0;
	}

	/* Create copy of dst call without ssid. */
	memset(dstcall, 0, 7);
	for ( i = 0; i < strlen(packet->dst_callsign) && i < 6; ++i )
	{
		if ( packet->dst_callsign[i] == '-' ) break;
		dstcall[i] = packet->dst_callsign[i];
	}
	if ( strlen(dstcall) != 6 )
	{
		packet->error_code = malloc(sizeof(fap_error_code_t));
		if ( packet->error_code ) *packet->error_code = fapMICE_SHORT;
		return 0;
	}

	/* Validate target call. */
	if ( regexec(&fapint_regex_mice_dstcall, dstcall, 0, NULL, 0) != 0 )
	{
		/* A-K characters are not used in the last 3 characters and MNO are never used. */
		packet->error_code = malloc(sizeof(fap_error_code_t));
		if ( packet->error_code ) *packet->error_code = fapMICE_INV;
		return 0;
	}
	
	/* Get symbol table. */
	packet->symbol_table = input[7];

	/* Validate body. */
	/* "^[\x26-\x7f][\x26-\x61][\x1c-\x7f]{2}[\x1c-\x7d][\x1c-\x7f][\x21-\x7b\x7d][\/\\A-Z0-9]" */
	error = 0;
	if ( input[0] < 0x26 || (unsigned char)input[0] > 0x7f ) error = 1;
	if ( input[1] < 0x26 || input[1] > 0x61 ) error = 1;
	if ( input[2] < 0x1c || (unsigned char)input[2] > 0x7f ) error = 1;
	if ( input[3] < 0x1c || (unsigned char)input[3] > 0x7f ) error = 1;
	if ( input[4] < 0x1c || input[4] > 0x7d ) error = 1;
	if ( input[5] < 0x1c || (unsigned char)input[5] > 0x7f ) error = 1;
	if ( input[6] != 0x7d && (input[6] < 0x21 || input[6] > 0x7b) ) error = 1;
	if ( error || regexec(&fapint_regex_mice_body, input+7, 0, NULL, 0) != 0 )
	{
		packet->error_code = malloc(sizeof(fap_error_code_t));
		if ( packet->error_code )
		{
			/* Validate symbol table. */
			if ( ( packet->symbol_table == '/' ) ||
			     ( packet->symbol_table == '\\' ) ||
			     ( packet->symbol_table >= 'A' && packet->symbol_table <= 'Z' ) ||
			     isdigit(packet->symbol_table) )
			{
				// It's okay, we have some other error.
				*packet->error_code = fapMICE_INV_INFO;
			}
			else
			{
				// It's not okay.
				*packet->error_code = fapSYM_INV_TABLE;
			}
		}
		return 0;
	}
	
	/* Store pos format. */
	packet->format = malloc(sizeof(fap_pos_format_t));
	if ( !packet->format )
	{
		return 0;
	}
	*packet->format = fapPOS_MICE;
	
	/* Start process from the target call to find latitude, message bits, N/S
	 * and W/E indicators and long. offset. */
	
	/* First create a translated copy to find latitude. */
	memset(latitude, 0, 7);
	for ( i = 0; i < 6; ++i )
	{
		if ( dstcall[i] >= 'A' && dstcall[i] <= 'J' )
		{
			/* A-J -> 0-9 */
			latitude[i] = dstcall[i] - 17;
		}
		else if ( dstcall[i] >= 'P' && dstcall[i] <= 'Y' )
		{
			/* P-Y -> 0-9 */
			latitude[i] = dstcall[i] - 32;
		}
		else if ( dstcall[i] == 'K' || dstcall[i] == 'L' || dstcall[i] == 'Z' )
		{
			/* pos amb */
			latitude[i] = '_';
		}
		else
		{
			latitude[i] = dstcall[i];
		}
	}
	
	/* Check the amount of position ambiguity. */
	packet->pos_ambiguity = malloc(sizeof(unsigned int));
	if ( !packet->pos_ambiguity ) return 0;
	if ( regexec(&fapint_regex_mice_amb, latitude, matchcount, (regmatch_t*)&matches, 0) != 0 )
	{
		packet->error_code = malloc(sizeof(fap_error_code_t));
		if ( packet->error_code ) *packet->error_code = fapMICE_AMB_LARGE;
		return 0;
	}
	*packet->pos_ambiguity = matches[2].rm_eo - matches[2].rm_so;
	
	/* Validate ambiguity. */
	if ( *packet->pos_ambiguity > 4 )
	{
		packet->error_code = malloc(sizeof(fap_error_code_t));
		if ( packet->error_code ) *packet->error_code = fapMICE_AMB_INV;
		return 0;
	}
  
	/* Calculate position resolution. */
	packet->pos_resolution = malloc(sizeof(double));
	if ( !packet->pos_resolution ) return 0;
	*packet->pos_resolution = fapint_get_pos_resolution(2 - *packet->pos_ambiguity);
	
	/* Convert the latitude to the midvalue if position ambiguity is used. */
	if ( *packet->pos_ambiguity >= 4 )
	{
		/* The minute is between 0 and 60, so the midpoint is 30. */
		tmp_str = strchr(latitude, '_');
		*tmp_str = '3';
	}
	else
	{
		/* First digit is changed to 5. */
		if ( (tmp_str = strchr(latitude, '_')) != NULL )
		{
			*tmp_str = '5';
		}
	}
	
	/* Remaining digits are changed to 0. */
	while ( (tmp_str = strchr(latitude, '_')) != NULL )
	{
		*tmp_str = '0';
	}
	
	/* Convert latitude degrees into number and save it. */
	buf_6b[0] = latitude[0]; buf_6b[1] = latitude[1];
	buf_6b[2] = 0;
	packet->latitude = malloc(sizeof(double));
	if ( !packet->latitude ) return 0;
	*packet->latitude = atof(buf_6b);
	
	/* Same for minutes. */
	buf_6b[0] = latitude[2]; buf_6b[1] = latitude[3];
	buf_6b[2] = '.';
	buf_6b[3] = latitude[4]; buf_6b[4] = latitude[5];
	buf_6b[5] = 0;
	*packet->latitude += atof(buf_6b)/60;

	/* Check the north/south direction and correct the latitude if necessary. */
	if ( dstcall[3] <= 0x4c )
	{
		*packet->latitude = 0 - *packet->latitude;
	}

	/* Get the message bits. 1 is standard one-bit and 2 is custom one-bit. */
	packet->messagebits = malloc(4);
	if ( !packet->messagebits ) return 0;
	for ( i = 0; i < 3; ++i )
	{
		if ( (dstcall[i] >= '0' && dstcall[i] <= '9') || dstcall[i] == 'L' )
		{
			packet->messagebits[i] = '0';
		}
		else if ( dstcall[i] >= 'P' && dstcall[i] <= 'Z' )
		{
			packet->messagebits[i] = '1';
		}
		else if ( dstcall[i] >= 'A' && dstcall[i] <= 'K' )
		{
			packet->messagebits[i] = '2';
		}
	}
	packet->messagebits[3] = 0;
	
	/* Decode the longitude, the first three bytes of the body after the data
	 * type indicator. First longitude degrees, remember the longitude offset. */
	lon = input[0] - 28;
	if ( dstcall[4] >= 0x50 )
	{
		lon += 100;
	}
	if ( lon >= 180 && lon <= 189 )
	{
		lon -= 80;
	}
	else if ( lon >= 190 && lon <= 199 )
	{
		lon -= 190;
	}
	packet->longitude = malloc(sizeof(double));
	if ( !packet->longitude ) return 0;
	*packet->longitude = lon;
	
	/* Get longitude minutes. */
	memset(longitude, 0, 6);
	lon = input[1] - 28;
	if ( lon >= 60 )
	{
		lon -= 60;
	}
	sprintf(longitude, "%02d.%02d", lon, input[2] - 28);
	
	/* Apply pos amb and save. */
	if ( *packet->pos_ambiguity == 4 )
	{
		/* Minutes are not used. */
		*packet->longitude += 0.5;
	}
	else if ( *packet->pos_ambiguity == 3 )
	{
		/* 1 minute digit is used. */
		tmp_str = malloc(3);
		tmp_str[0] = longitude[0]; tmp_str[1] = '5'; tmp_str[2] = 0;
		*packet->longitude += atof(tmp_str)/60;
		free(tmp_str);
	}
	else if ( *packet->pos_ambiguity == 2 )
	{
		/* Whole minutes are used. */
		memset(buf_6b, 0, 6);
		buf_6b[0] = longitude[0];
		buf_6b[1] = longitude[1];
		buf_6b[2] = '.';
		buf_6b[3] = '5';
		*packet->longitude += atof(buf_6b)/60;
	}
	else if ( *packet->pos_ambiguity == 1 )
	{
		/* Whole minutes and 1 decimal are used. */
		longitude[4] = '5';
		*packet->longitude += atof(longitude)/60;
	}
	else if ( *packet->pos_ambiguity == 0 )
	{
		*packet->longitude += atof(longitude)/60;
	}
	else
	{
		packet->error_code = malloc(sizeof(fap_error_code_t));
		if ( packet->error_code ) *packet->error_code = fapMICE_AMB_ODD;
		return 0;
	}
	
	/* Check E/W sign. */
	if ( dstcall[5] >= 0x50 )
	{
		*packet->longitude = 0 - *packet->longitude;
	}

	/* Now onto speed and course. */
	speed = (input[3] - 28) * 10;
	course_speed = input[4] - 28;
	course_speed_tmp = floor(course_speed / 10);
	speed += course_speed_tmp;
	course_speed -= course_speed_tmp * 10;
	course = 100 * course_speed;
	course += input[5] - 28;
	
	/* Some adjustment. */
	if ( speed >= 800 )
	{
		speed -= 800;
	}
	if ( course >= 400 )
	{
		course -= 400;
	}
  
	/* Save values. */
	packet->speed = malloc(sizeof(double));
	if ( !packet->speed ) return 0;
	*packet->speed = speed * KNOT_TO_KMH;
	if ( course >= 0 )
	{
		packet->course = malloc(sizeof(unsigned int));
		if ( !packet->course ) return 0;
		*packet->course = course;
	}
	
	/* Save symbol code. */
	packet->symbol_code = input[6];
	
	/* If there's something left, create working copy of it. */
	if ( (len = input_len - 8) > 0 )
	{
		rest = malloc(len);
		memcpy(rest, input+8, len);
	}
	else
	{
		/* Nothing left, we're ok and out. */
		return 1;
	}
	
	/* Check for Mic-E telemetry. */
/*
	bzero(buf_6b, 6);
	fprintf(stderr, "SEARCHING 2-CHANNEL MIC-E TELEMETRY\n");
	if ( rest[0] == '\'' )
	{
		for (i = 1; i <= 4; i++ )
		{
			if ( !isxdigit(rest[i]) )
			{
				i = 0;
				break;
			}
		}
		if ( i > 0 )
		{
			fprintf(stderr, "FOUND 2-CHANNEL MIC-E TELEMETRY\n");
			packet->telemetry = malloc(sizeof(fap_telemetry_t));
			if ( !packet->telemetry ) return;
			packet->telemetry->val1 = malloc(sizeof(double));
			if ( !packet->telemetry->val1 ) return;
			buf_6b[0] = rest[1];
			buf_6b[1] = rest[2];
			*packet->telemetry->val1 = strtol(buf_6b, NULL, 16);
			packet->telemetry->val3 = malloc(sizeof(double));
			if ( !packet->telemetry->val3 ) return;
			buf_6b[0] = rest[3];
			buf_6b[1] = rest[4];
			*packet->telemetry->val3 = strtol(buf_6b, NULL, 16);
		}
	}
	fprintf(stderr, "DONE\n");
	fprintf(stderr, "SEARCHING 5-CHANNEL MIC-E TELEMETRY\n");
	if ( rest[0] == '`' )
	{
		for ( i = 1; i <= 10; i++ )
		{
			if ( !isxdigit(rest[i]) )
			{
				i = 0;
				break;
			}
		}
		if ( i > 0 )
		{
			fprintf(stderr, "FOUND 2 CHANNEL MIC-E TELEMETRY\n");
		}
	}
	fprintf(stderr, "DONE\n");
*/	
	/* Check for possible altitude. Altitude is base-91 coded and in format
	 * "xxx}" where x are the base-91 digits in meters, origin is 10000 meters
	 * below sea. */
	for ( i = 0; i+3 < len; ++i )
	{
		/* Check for possible altitude digit. */
		if ( rest[i] >= 0x21 && rest[i] <= 0x7b )
		{
			/* Check remaining digits for altitudeness. */
			if ( (rest[i+1] >= 0x21 && rest[i+1] <= 0x7b) &&
				  (rest[i+2] >= 0x21 && rest[i+2] <= 0x7b) &&
				  rest[i+3] == '}' )
			{
				/* Save altitude. */
				packet->altitude = malloc(sizeof(double));
				if ( !packet->altitude )
				{
					free(rest);
					return 0;
				}
				*packet->altitude = ( (rest[i] - 33) * pow(91,2) +
							             (rest[i+1] - 33) * 91 +
							             (rest[i+2] - 33) ) - 10000;
				/* Remove altitude. */
				tmp_str = fapint_remove_part(rest, len, i, i+4, &tmp_us);
				free(rest);
				rest = tmp_str;
				len = tmp_us;
				/* We're done. */
				break;
			}
		}
	}

	/* Check for base-91 comment telemetry. */
	fapint_parse_comment_telemetry(packet, &rest, &len);
	
	/* If we still hafe stuff left, check for !DAO!, take the last occurrence (per recommendation). */
	if ( len > 0 )
	{
		for ( i = len-1; i >= 0 ; --i )
		{
			if ( i + 4 < len && rest[i] == '!' &&
				  0x21 <= rest[i+1] && rest[i+1] <= 0x7b &&
				  0x20 <= rest[i+2] && rest[i+2] <= 0x7b &&
				  0x20 <= rest[i+3] && rest[i+3] <= 0x7b &&
				  rest[i+4] == '!' )
			{
				memcpy(dao, rest+i+1, 3);
				/* Validate and save dao. */
				if ( fapint_parse_dao(packet, dao) )
				{
					/* Remove !DAO!. */
					tmp_str = fapint_remove_part(rest, len, i, i+5, &tmp_us);
					free(rest);
					rest = tmp_str;
					len = tmp_us;
					break;
				}
			}
		}
	}

	/* If there's something left, save it as a comment. */
	if ( len > 0 )
	{
		packet->comment = rest;
		packet->comment_len = len;
	}
	
	return 1;
}


time_t fapint_parse_timestamp(char const* input)
{
	char buf_3b[3];
	unsigned int first, second, third;
	char type;
	struct tm now_struct, fwd_struct, back_struct, tmp_struct;
	time_t thismonth, nextmonth, prevmonth, result;
	const time_t now = time(NULL);
	
	unsigned int const matchcount = 5;
	regmatch_t matches[matchcount];

	gmtime_r(&now, &now_struct);

	/* Validate input. */
	if ( !input )
	{
		return 0;
	}
	if ( regexec(&fapint_regex_timestamp, input, matchcount, (regmatch_t*)&matches, 0) == 0 )
	{
		buf_3b[2] = 0;
		/* Get three numbers. */
		memcpy(buf_3b, input+matches[1].rm_so, 2);
		first = atoi(buf_3b);
		memcpy(buf_3b, input+matches[2].rm_so, 2);
		second = atoi(buf_3b);
		memcpy(buf_3b, input+matches[3].rm_so, 2);
		third = atoi(buf_3b);
		
		/* Get type flag. */
		type = input[matches[4].rm_so];
	}
	else
	{
		return 0;
	}

	/* Continue based on stamp type. */
	if ( type == 'h' )
	{
		/* HMS in UTC -format, check for valid time. */
		if ( first > 23 || second > 59 || third > 59 )
		{
			return 0;
		}
		
		/* Convert into unixtime. */
		memcpy((struct tm*)&tmp_struct, &now_struct, sizeof(struct tm));
		tmp_struct.tm_sec = third;
		tmp_struct.tm_min = second;
		tmp_struct.tm_hour = first;
		result = timegm((struct tm*)&tmp_struct);
		
		/* If the time is more than about one hour into the future, roll the
			timestamp one day backwards. */
		if ( now + 3900 < result )
		{
			result -= 86400;
		}
		/* If the time is more than about 23 hours into the past, roll the
			timestamp one day forwards. */
		else if ( now - 82500 > result )
		{
			result += 86400;
		}
		return result;
	}
	else if ( type == 'z' || type == '/' )
	{
		/* DHM in UTC (z) or local(/). Always intepret local to mean local to this computer. */
		if ( first < 1 || first > 31 || second > 23 || third > 59 )
		{
			return 0;
		}
		
		/* If time is under about 12 hours into the future, go there.
			Otherwise get the first matching time in the past. */

		/* Form the possible timestamps. */
		
		/* This month. */
		memcpy((struct tm*)&tmp_struct, &now_struct, sizeof(struct tm));
		tmp_struct.tm_mday = first;
		tmp_struct.tm_hour = second;
		tmp_struct.tm_min = third;
		tmp_struct.tm_sec = 0;
		thismonth = timegm((struct tm*)&tmp_struct);

		/* Next month. */
		memcpy((struct tm*)&tmp_struct, &now_struct, sizeof(struct tm));
		tmp_struct.tm_mon += 1;
		tmp_struct.tm_mday = first;
		tmp_struct.tm_hour = second;
		tmp_struct.tm_min = third;
		tmp_struct.tm_sec = 0;
		nextmonth = timegm((struct tm*)&tmp_struct);
		
		/* Previous month. */
		memcpy((struct tm*)&tmp_struct, &now_struct, sizeof(struct tm));
		if ( tmp_struct.tm_mon == 0 )
		{
			tmp_struct.tm_mon = 11;
			tmp_struct.tm_year -= 1;
		}
		else
		{
			tmp_struct.tm_mon -= 1;
		}
		tmp_struct.tm_mday = first;
		tmp_struct.tm_hour = second-1;
		tmp_struct.tm_min = third;
		tmp_struct.tm_sec = 0;
		prevmonth = timegm((struct tm*)&tmp_struct);
		
		/* Select the timestamp to use. Pick the timestamp that is largest,
			but under about 12 hours from current time. */
		if ( nextmonth - now < 43400 )
		{
			result = nextmonth;
		}
		else if ( thismonth - now < 43400 )
		{
			result = thismonth;
		}
		else
		{
			result = prevmonth;
		}
		
		/* Convert local to UTC. */
		if ( type == '/' )
		{
			result += timezone;
		}
		
		return result;
	 }
		
	return 0;
}


int fapint_parse_compressed(fap_packet_t* packet, char const* input)
{
	int i;
	char symboltable, symbolcode;
	char lat[4], lon[4];
	char c1, s1, comptype;
	char cs;
	
	/* Validate compressed position and things. */
	if ( strlen(input) < 13 )
	{
		packet->error_code = malloc(sizeof(fap_error_code_t));
		if ( packet->error_code ) *packet->error_code = fapCOMP_INV;
		return 0;
	}
	if ( !(  
			(input[0] >= 'A' && input[0] <= 'Z') ||
			(input[0] >= 'a' && input[0] <= 'j') ||
			input[0] == '/' ||
			input[0] == '\\')
		)
	{
		packet->error_code = malloc(sizeof(fap_error_code_t));
		if ( packet->error_code ) *packet->error_code = fapCOMP_INV;
		return 0;
	}
	for ( i = 1; i <= 8; ++i )
	{
		if ( input[i] < 0x21 || input[i] > 0x7b )
		{
			packet->error_code = malloc(sizeof(fap_error_code_t));
			if ( packet->error_code ) *packet->error_code = fapCOMP_INV;
			return 0;
		}
	}
	if ( input[9] != 0x7d && (input[9] < 0x21 || input[9] > 0x7b) )
	{
		packet->error_code = malloc(sizeof(fap_error_code_t));
		if ( packet->error_code ) *packet->error_code = fapCOMP_INV;
		return 0;
	}
	for ( i = 10; i <= 12; ++i )
	{
		if ( input[i] < 0x20 || input[i] > 0x7b )
		{
			packet->error_code = malloc(sizeof(fap_error_code_t));
			if ( packet->error_code ) *packet->error_code = fapCOMP_INV;
			return 0;
		}
	}
	
	/* Store pos format. */
	packet->format = malloc(sizeof(fap_pos_format_t));
	if ( !packet->format )
	{
		return 0;
	}
	*packet->format = fapPOS_COMPRESSED;
	
	/* Get symbol. */
	symboltable = input[0];
	symbolcode = input[9];
	
	/* Get position. */
	for ( i = 0; i < 4; ++i )
	{
		lat[i] = input[i+1] - 33;
		lon[i] = input[i+5] - 33;
	}
	
	/* Get other data. */
	c1 = input[10] - 33;
	s1 = input[11] - 33;
	comptype = input[12] - 33;
	
	/* Save symbol table. Table chars (a-j) are converted to numbers 0-9. */
	if ( symboltable >= 'a' && symboltable <= 'j' )
	{
		symboltable -= 81;
	}
	packet->symbol_table = symboltable;
	
	/* Save symbol code as is. */
	packet->symbol_code = symbolcode;
	

	/* Calculate position. */
	packet->latitude = malloc(sizeof(double));
	if ( !packet->latitude ) return 0;
	*packet->latitude = 90 - ( (lat[0] * pow(91,3) + lat[1] * pow(91,2) + lat[2] * 91 + lat[3]) / 380926);
	packet->longitude = malloc(sizeof(double));
	if ( !packet->latitude ) return 0;
	*packet->longitude = -180 + ( (lon[0] * pow(91,3) + lon[1] * pow(91,2) + lon[2] * 91 + lon[3]) / 190463);
	
	/* Save best-case position resolution in meters: 1852 meters * 60 minutes in a degree * 180 degrees / 91^4. */
	packet->pos_resolution = malloc(sizeof(double));
	if ( !packet->pos_resolution ) return 0;
	*packet->pos_resolution = 0.291;
	
	/* GPS fix status, only if csT is used. */
	if ( c1 != -1 )
	{
		packet->gps_fix_status = malloc(sizeof(short));
		if ( !packet->gps_fix_status ) return 0;
		if ( (comptype & 0x20) == 0x20 )
		{
			*packet->gps_fix_status = 1;
		}
		else
		{
			*packet->gps_fix_status = 0;
		}
	}

	/* Check the compression type, if GPGGA, then the cs bytes are altitude.
	 * Otherwise try to decode it as course and speed and finally as radio range.
	 * If c is space, then csT is not used. Also require that s is not a space. */
	if ( c1 == -1 || s1 == -1 )
	{
		/* csT not used. */
	}
	else if ( (comptype & 0x18) == 0x10 )
	{
		/* cs is altitude. */
		cs = c1 * 91 + s1;
		packet->altitude = malloc(sizeof(double));
		if ( !packet->altitude ) return 0;
		/* Convert directly to meters. */
		*packet->altitude = pow(1.002, cs) * 0.3048;
	}
	else if ( c1 >= 0 && c1 <= 89 )
	{
		packet->course = malloc(sizeof(unsigned int));
		if ( !packet->course ) return 0;
		if ( c1 == 0 )
		{
			/* Special case of north, APRS spec uses zero for unknown and 360 for north.
			 * So remember to convert north here. */
			*packet->course = 360;
		}
		else
		{
			*packet->course = c1 * 4;
		}
		/* Convert directly to km/h. */
		packet->speed = malloc(sizeof(double));
		if ( !packet->speed ) return 0;
		*packet->speed = ( pow(1.08, s1) - 1 ) * KNOT_TO_KMH;
	}
	else if ( c1 == 90 )
	{
		/* Convert directly to km. */
		packet->radio_range = malloc(sizeof(unsigned int));
		if ( !packet->radio_range ) return 0;
		*packet->radio_range = 2 * pow(1.08, s1) * MPH_TO_KMH;
	}
	
	return 1;
}


int fapint_parse_normal(fap_packet_t* packet, char const* input)
{
	char sind, wind;
	short is_south = 0;
	short is_west = 0;
	char lat_deg[3], lat_min[6], lon_deg[4], lon_min[6], tmp_5b[5];
	double lat, lon;
	
	unsigned int const matchcount = 9;
	regmatch_t matches[matchcount];

	
	/* Check length. */
	if ( strlen(input) < 19 )
	{
		packet->error_code = malloc(sizeof(fap_error_code_t));
		if ( packet->error_code ) *packet->error_code = fapLOC_SHORT;
		return 0;
	}
	
	/* Save pos format. */
	packet->format = malloc(sizeof(fap_pos_format_t));
	if ( !packet->format )
	{
		return 0;
	}
	*packet->format = fapPOS_UNCOMPRESSED;
	
	/* Validate. */
	if ( regexec(&fapint_regex_normalpos, input, matchcount, (regmatch_t*)&matches, 0) != 0 )
	{
		packet->error_code = malloc(sizeof(fap_error_code_t));
		if ( packet->error_code ) *packet->error_code = fapLOC_INV;
		return 0;
	}
	if ( input[18] != 0x7d && (input[18] < 0x21 || input[18] > 0x7b) )
	{
		packet->error_code = malloc(sizeof(fap_error_code_t));
		if ( packet->error_code ) *packet->error_code = fapLOC_INV;
		return 0;
	}
	
	/* Save hemisphere info. */
	sind = toupper(input[matches[3].rm_so]);
	wind = toupper(input[matches[7].rm_so]);
	
	/* Save symbol table and code. */
	packet->symbol_table = input[matches[4].rm_so];
	packet->symbol_code = input[18];

	/* Save position numbers as NULL-terminated strings. */
	memset(lat_deg, 0, 3);
	memcpy(lat_deg, input+matches[1].rm_so, 2);
	memset(lat_min, 0, 6);
	memcpy(lat_min, input+matches[2].rm_so, 5);
	memset(lon_deg, 0, 4);
	memcpy(lon_deg, input+matches[5].rm_so, 3);
	memset(lon_min, 0, 6);
	memcpy(lon_min, input+matches[6].rm_so, 5);
	
	/* Validate symbol table. */
	if ( ( packet->symbol_table == '/' ) ||
	     ( packet->symbol_table == '\\' ) ||
	     ( packet->symbol_table >= 'A' && packet->symbol_table <= 'Z' ) ||
	     isdigit(packet->symbol_table) )
	{
		// It's okay.
	}
	else
	{
		// It's not.
		packet->error_code = malloc(sizeof(fap_error_code_t));
		if ( packet->error_code ) *packet->error_code = fapSYM_INV_TABLE;
		return 0;
	}	
	
	/* Convert hemisphere indicators to numbers. */
	if ( sind == 'S' ) is_south = 1;
	if ( wind == 'W' ) is_west = 1;

	/* Convert degrees to numbers and check them. */
	lat = atoi(lat_deg);
	lon = atoi(lon_deg);
	if ( lat > 89 || lon > 179 )
	{
		packet->error_code = malloc(sizeof(fap_error_code_t));
		if ( packet->error_code ) *packet->error_code = fapLOC_LARGE;
		return 0;
	}
	
	/* Prepare to parse position ambiguity. */
	packet->pos_ambiguity = malloc(sizeof(unsigned int));
	if ( !packet->pos_ambiguity ) return 0;
	
	/* First task is to create a copy without the decimal separator. */
	tmp_5b[0] = lat_min[0];
	tmp_5b[1] = lat_min[1];
	tmp_5b[2] = lat_min[3];
	tmp_5b[3] = lat_min[4];
	tmp_5b[4] = 0;
	
	/* Calculate ambiguity, which is the amount of spaces at the end. */
	if ( regexec(&fapint_regex_normalamb, tmp_5b, matchcount, (regmatch_t*)&matches, 0) != 0 )
	{
		packet->error_code = malloc(sizeof(fap_error_code_t));
		if ( packet->error_code ) *packet->error_code = fapLOC_AMB_INV;
		return 0;
	}
	*packet->pos_ambiguity = matches[2].rm_eo - matches[2].rm_so;
	
	/* Continue depending on amount of position ambiguity. */
	packet->latitude = malloc(sizeof(double));
	packet->longitude = malloc(sizeof(double));
	if ( !packet->latitude || !packet->longitude ) return 0;
	switch ( *packet->pos_ambiguity )
	{
		case 0:
			/* Validate longitude and save values. */
			if ( strchr(lon_min, ' ') != NULL )
			{
				packet->error_code = malloc(sizeof(fap_error_code_t));
				if ( packet->error_code ) *packet->error_code = fapLOC_AMB_INV;
				return 0;
			}
			else
			{
			  *packet->latitude = lat + atof(lat_min)/60;
			  *packet->longitude = lon + atof(lon_min)/60;
			}
			break;
		case 4:
			/* Disregard the minutes and add 0.5 to the degree values. */
			*packet->latitude = lat + 0.5;
			*packet->longitude = lon + 0.5;
			break;
		case 1:
		case 2:
			/* Blank digits are just ignored. */
			*packet->latitude = lat + atof(lat_min)/60;
			*packet->longitude = lon + atof(lon_min)/60;
			break;
		case 3:
			/* Single minute digit is set to 5, minute decimals are ignored. */
			lat_min[1] = '5';
			memset(lat_min+2, 0, 4);
			lon_min[1] = '5';
			memset(lon_min+2, 0, 4);
			*packet->latitude = lat + atof(lat_min)/60;
			*packet->longitude = lon + atof(lon_min)/60;
			break;
		default:
			packet->error_code = malloc(sizeof(fap_error_code_t));
			if ( packet->error_code ) *packet->error_code = fapLOC_AMB_INV;
			return 0;
	}

	/* Apply hemisphere indicators. */
	if ( is_south )
	{
		*packet->latitude = 0 - *packet->latitude;
	}
	if ( is_west )
	{
		*packet->longitude = 0 - *packet->longitude;
	}
	
	/* Calculate position resolution based on position ambiguity. */
	packet->pos_resolution = malloc(sizeof(double));
	if ( !packet->pos_resolution ) return 0;
	*packet->pos_resolution = fapint_get_pos_resolution(2 - *packet->pos_ambiguity);
	
	return 1;
}



void fapint_parse_comment(fap_packet_t* packet, char const* input, unsigned int const input_len)
{
	char course[4], speed[4], range[5], altitude[7], dao[3];
	int i, tmp_s;
	char* tmp_str, *rest = NULL;
	unsigned int rest_len = 0, tmp_us;

	unsigned int const matchcount = 2;
	regmatch_t matches[matchcount];
	
	
	/* First check the possible APRS data extension, immediately following the
		packet. Then check for PHG. */
	if ( input_len >= 7 )
	{
		/* Look for data. */
		if ( regexec(&fapint_regex_comment, input, 0, NULL, 0) == 0 )
		{
			/* Get and validate course, if not already available. 0 stands for invalid. */
			if ( !packet->course )
			{
				memcpy(course, input, 3);
				course[3] = 0;
				packet->course = malloc(sizeof(unsigned int));
				if ( !packet->course ) return;
				*packet->course = 0;
				if ( isdigit(course[0]) && isdigit(course[1]) && isdigit(course[2]) )
				{
					tmp_s = atoi(course);
					if ( tmp_s >= 1 && tmp_s <= 360 )
					{
						/* It's valid, let's save it. */
						*packet->course = tmp_s;
					}
				}
			}
			
			/* Get and validate speed, if not available already. */
			if ( !packet->speed )
			{
				/* There's no speed value for invalid, so we leave it unallocated by default. */
				memcpy(speed, input+4, 3);
				speed[3] = 0;
				if ( isdigit(speed[0]) && isdigit(speed[1]) && isdigit(speed[2]) )
				{
					tmp_s = atoi(&speed[0]);
					packet->speed = malloc(sizeof(double));
					if ( !packet->speed ) return;
					*packet->speed = tmp_s * KNOT_TO_KMH;
				}
			}
			
			/* Save the rest. */
			rest = fapint_remove_part(input, input_len, 0, 7, &rest_len);
		}
		/* Look for PHGR. */
		else if ( regexec(&fapint_regex_phgr, input, 0, NULL, 0) == 0 &&
					 input[4] >= 0x30 && input[4] <= 0x7e )
		{
			/* Save PHGR. */
			packet->phg = malloc(6);
			if ( !packet->phg ) return;
			memcpy(packet->phg, input+3, 5);
			packet->phg[5] = 0;
			
			/* Save the rest. */
			rest = fapint_remove_part(input, input_len, 0, 8, &rest_len);
		}
		/* Look for PHG. */
		else if ( regexec(&fapint_regex_phg, input, 0, NULL, 0) == 0 &&
					 input[4] >= 0x30 && input[4] <= 0x7e )
		{
			/* Save PHG. */
			packet->phg = malloc(5);
			if ( !packet->phg ) return;
			memcpy(packet->phg, input+3, 4);
			packet->phg[4] = 0;
			
			/* Save the rest. */
			rest = fapint_remove_part(input, input_len, 0, 7, &rest_len);
		}
		/* Look for RNG. */
		else if ( regexec(&fapint_regex_rng, input, 0, NULL, 0) == 0 )
		{
			/* Save and validate range. There's no invalid range value. */
			memcpy(range, input+3, 4);
			range[4] = 0;
			tmp_s = atoi(range);
			packet->radio_range = malloc(sizeof(unsigned int));
			if ( !packet->radio_range ) return;
			*packet->radio_range = tmp_s * MPH_TO_KMH;
		 
			/* Save the rest. */
			rest = fapint_remove_part(input, input_len, 0, 7, &rest_len);
		}
		else
		{
			rest = malloc(input_len+1);
			if ( !rest ) return;
			memcpy(rest, input, input_len);
			rest_len = input_len;
			rest[rest_len] = 0;
		}
	}
	else if ( input_len > 0 )
	{
		rest = malloc(input_len+1);
		if ( !rest ) return;
		memcpy(rest, input, input_len);
		rest_len = input_len;
		rest[rest_len] = 0;
	}
	
	/* Check if we still have something left. */
	if ( rest_len > 0 )
	{
		/* Check for optional altitude anywhere in the comment, take the first occurrence. */
		if ( regexec(&fapint_regex_altitude, rest, matchcount, (regmatch_t*)&matches, 0) == 0 )
		{
			/* Save altitude, if not already there. */
			if ( !packet->altitude )
			{
				memcpy(altitude, rest+matches[1].rm_so, 6);
				altitude[6] = 0;
				tmp_s = atoi(altitude);
				packet->altitude = malloc(sizeof(double));
				*packet->altitude = tmp_s * FT_TO_M;
			}
		
			/* Remove altitude. */
			tmp_str = fapint_remove_part(rest, rest_len, matches[1].rm_so-3, matches[1].rm_eo, &tmp_us);
			free(rest);
			rest = tmp_str;
			rest_len = tmp_us;
		}
	}
		
	/* Check for base-91 comment telemetry. */
	fapint_parse_comment_telemetry(packet, &rest, &rest_len);
	
	/* If we still hafe stuff left, check for !DAO!, take the last occurrence (per recommendation). */
	if ( rest_len > 0 )
	{
		for ( i = rest_len-1; i >= 0 ; --i )
		{
			if ( i + 4 < rest_len && rest[i] == '!' &&
				  0x21 <= rest[i+1] && rest[i+1] <= 0x7b &&
				  0x20 <= rest[i+2] && rest[i+2] <= 0x7b &&
				  0x20 <= rest[i+3] && rest[i+3] <= 0x7b &&
				  rest[i+4] == '!' )
			{
				memcpy(dao, rest+i+1, 3);
				/* Validate and save dao. */
				if ( fapint_parse_dao(packet, dao) )
				{
					/* Remove !DAO!. */
					tmp_str = fapint_remove_part(rest, rest_len, i, i+5, &tmp_us);
					free(rest);
					rest = tmp_str;
					rest_len = tmp_us;
					break;
				}
			}
		}
	}
	
	/* If there's something left, save it as a comment. */
	if ( rest_len > 0 )
	{
		packet->comment = rest;
		packet->comment_len = rest_len;
	}
}



int fapint_parse_nmea(fap_packet_t* packet, char const* input, unsigned int const input_len)
{
	char* rest;
	unsigned int rest_len;
	int i, len, retval = 1;

	char* checksum_area;
	char checksum_given_str[3];
	long int checksum_given;
	long int checksum_calculated = 0;
	
	fapint_llist_item_t* nmea_field_list = NULL, *current_elem = NULL;
	char** nmea_fields = NULL;
	unsigned int nmea_field_count;
	char* tmp_str;
	
	char buf_3b[3];
	unsigned int year, month, day, hours, mins, secs;
	struct tm timestamp;
	
	unsigned int const matchcount = 5;
	regmatch_t matches[matchcount];
	
	/* Create working copy of input with no trailing white spaces. */
	for ( i = input_len-1; i >= 0; ++i )
	{
		if ( !isspace(input[i]) )
		{
			break;
		}
	}
	rest_len = i+1;
	
	if ( rest_len > 0 )
	{
		rest = malloc(rest_len+1);
		if ( !rest ) return 0;
		memcpy(rest, input, rest_len);
		rest[rest_len] = 0;
	}
	else
	{
		return 0;
	}
	
	/* Verify first, if it is provided. */
	if ( regexec(&fapint_regex_nmea_chksum, rest, matchcount, (regmatch_t*)&matches, 0) == 0 )
	{
		len = matches[1].rm_eo - matches[1].rm_so;
		checksum_area = malloc(len+1);
		if ( !checksum_area )
		{
			free(rest);
			return 0;
		}
		memcpy(checksum_area, rest+matches[1].rm_so, len);
		checksum_area[len] = 0;
		
		checksum_given_str[0] = rest[matches[2].rm_so];
		checksum_given_str[1] = rest[matches[2].rm_so+1];
		checksum_given_str[2] = 0;
		checksum_given = strtol(checksum_given_str, NULL, 16);
		
		for ( i = 0; i < strlen(checksum_area); ++i )
		{
			checksum_calculated ^= checksum_area[i];
		}
		free(checksum_area);
		
		if ( checksum_given != checksum_calculated )
		{
			packet->error_code = malloc(sizeof(fap_error_code_t));
			if ( packet->error_code ) *packet->error_code = fapNMEA_INV_CKSUM;
			free(rest);
			return 0;
		}
		
		/* Make a note of the existance of a checksum. */
		packet->nmea_checksum_ok = malloc(sizeof(short));
		if ( !packet->nmea_checksum_ok )
		{
			free(rest);
			return 0;
		}
		*packet->nmea_checksum_ok = 1;
	
		/* Remove checksum. */
		rest = fapint_remove_part(rest, rest_len, matches[2].rm_so-1, matches[2].rm_eo, &rest_len);
	}
	else
	{
		printf("no checksum in (%s)", rest);
	}
	
	/* Format is NMEA. */
	packet->format = malloc(sizeof(fap_pos_format_t));
	if ( !packet->format )
	{
		free(rest);
		return 0;
	}
	*packet->format = fapPOS_NMEA;

	/* Use a dot as a default symbol if one is not defined in the destination callsign. */
	if ( !fapint_parse_symbol_from_dst_callsign(packet) )
	{
	  packet->symbol_table = '/';
	  packet->symbol_code = '/';
	}
	
	/* Split to NMEA fields. */
	tmp_str = strtok(rest, ",");
	nmea_field_count = 0;
	while ( tmp_str != NULL )
	{
		/* Create new element. */
		if ( !nmea_field_list )
		{
			nmea_field_list = malloc(sizeof(fapint_llist_item_t));
			if ( !nmea_field_list ) return 0;
			current_elem = nmea_field_list;
		}
		else
		{
			current_elem->next = malloc(sizeof(fapint_llist_item_t));
			if ( !current_elem->next )
			{
				retval = 0;
				break;
			}
			current_elem = current_elem->next;
		}
		current_elem->next = NULL;

		/* Save element. */
		current_elem->text = malloc(strlen(tmp_str)+1);
		if ( !current_elem->text )
		{
			retval = 0;
			break;
		}
		strcpy(current_elem->text, tmp_str);
		nmea_field_count++;

		/* Try to get next. */
		tmp_str = strtok(NULL, ",");
	}
	if ( !retval )
	{
		fapint_clear_llist(nmea_field_list);
		free(rest);
		return 0;
	}

	/* Collect NMEA fields into an array. */
	do
	{
		if ( !nmea_field_count )
		{
			packet->error_code = malloc(sizeof(fap_error_code_t));
			if ( packet->error_code ) *packet->error_code = fapNMEA_NOFIELDS;
			retval = 0;
			break;
		}
		else
		{
			nmea_fields = calloc(nmea_field_count, sizeof(char*));
			if ( !nmea_fields )
			{
				retval = 0;
				break;
			}
			for ( i = 0; i < nmea_field_count; ++i ) nmea_fields[i] = NULL;
			current_elem = nmea_field_list;
			i = 0;
			while ( current_elem != NULL )
			{
				nmea_fields[i] = malloc(strlen(current_elem->text)+1);
				if ( !nmea_fields[i] )
				{
					retval = 0;
					break;
				}
				strcpy(nmea_fields[i], current_elem->text);
				current_elem = current_elem->next;
				i++;
			}
		}
	}
	while ( 0 );
	fapint_clear_llist(nmea_field_list);
	if ( !retval )
	{
		free(nmea_fields);
		free(rest);
		return 0;
	}
	
	
	/* Now check the sentence type and get as much info as we can (want). */
	while ( retval )
	{
		if ( strcmp(nmea_fields[0], "GPRMC") == 0 )
		{
			/* We want at least 10 fields. */
			if ( nmea_field_count < 10 )
			{
				packet->error_code = malloc(sizeof(fap_error_code_t));
				if ( packet->error_code ) *packet->error_code = fapGPRMC_FEWFIELDS;
				retval = 0;
				break;
			}
		
			/* Check for fix. */
			if ( strcmp(nmea_fields[2], "A" ) != 0 )
			{
				packet->error_code = malloc(sizeof(fap_error_code_t));
				if ( packet->error_code ) *packet->error_code = fapGPRMC_NOFIX;
				retval = 0;
				break;
			}
			
			/* Check and get timestamp. */
			if ( regexec(&fapint_regex_nmea_time, nmea_fields[1], matchcount, (regmatch_t*)&matches, 0) == 0 )
			{
				buf_3b[2] = 0;
				memcpy(buf_3b, nmea_fields[1]+matches[1].rm_so, 2);
				hours = atoi(buf_3b);
				memcpy(buf_3b, nmea_fields[1]+matches[2].rm_so, 2);
				mins = atoi(buf_3b);
				memcpy(buf_3b, nmea_fields[1]+matches[3].rm_so, 2);
				secs = atoi(buf_3b);
				
				if ( hours > 23 || mins > 59 || secs > 59 )
				{
					packet->error_code = malloc(sizeof(fap_error_code_t));
					if ( packet->error_code ) *packet->error_code = fapGPRMC_INV_TIME;
					retval = 0;
					break;
				}
			}
			else
			{
				packet->error_code = malloc(sizeof(fap_error_code_t));
				if ( packet->error_code ) *packet->error_code = fapGPRMC_INV_TIME;
				retval = 0;
				break;
			}
			
			/* Check and get date. */
			if ( regexec(&fapint_regex_nmea_date, nmea_fields[9], matchcount, (regmatch_t*)&matches, 0) == 0 )
			{
				buf_3b[2] = 0;
				memcpy(buf_3b, nmea_fields[9]+matches[1].rm_so, 2);
				day = atoi(buf_3b);
				memcpy(buf_3b, nmea_fields[9]+matches[2].rm_so, 2);
				month = atoi(buf_3b);
				memcpy(buf_3b, nmea_fields[9]+matches[3].rm_so, 2);
				year = atoi(buf_3b);
				
				/* Check the date for validity. Assume years 0-69 are 21st
					century and years 70-99 are 20th century. */
				if ( year < 70 )
				{
					year += 2000;
				}
				else
				{
					year += 1900;
				}
				if ( !fapint_check_date(year, month, day) )
				{
					packet->error_code = malloc(sizeof(fap_error_code_t));
					if ( packet->error_code ) *packet->error_code = fapGPRMC_INV_DATE;
					retval = 0;
					break;
				}
			}
			else
			{
				packet->error_code = malloc(sizeof(fap_error_code_t));
				if ( packet->error_code ) *packet->error_code = fapGPRMC_INV_DATE;
				retval = 0;
				break;
			}
			
			/* Save date and time. We can only handle 32-bit unix timestamps,
				so we need to check for non-representable years. */
			if ( year >= 2038 || year < 1970 )
			{
				packet->error_code = malloc(sizeof(fap_error_code_t));
				if ( packet->error_code ) *packet->error_code = fapGPRMC_DATE_OUT;
				retval = 0;
				break;
			}
			else
			{
				timestamp.tm_sec = secs;
				timestamp.tm_min = mins;
				timestamp.tm_hour = hours;
				timestamp.tm_mday = day;
				timestamp.tm_mon = month-1;
				timestamp.tm_year = year-1900;
				timestamp.tm_isdst = 0;
				packet->timestamp = malloc(sizeof(time_t));
				if ( !packet->timestamp )
				{
					retval = 0;
					break;
				}
				*packet->timestamp = (time_t)mktime(&timestamp) - (time_t)timezone;
			}
			
			/* Get speed, if available. */
			if ( regexec(&fapint_regex_nmea_specou, nmea_fields[7], matchcount, (regmatch_t*)&matches, 0) == 0 )
			{
				len = matches[1].rm_eo - matches[1].rm_so;
				tmp_str = malloc(len+1);
				if ( !tmp_str )
				{
					retval = 0;
					break;
				}
				memcpy(tmp_str, nmea_fields[7]+matches[1].rm_so, len);
				tmp_str[len] = 0;
				
				packet->speed = malloc(sizeof(double));
				if ( !packet->speed )
				{
					retval = 0;
					break;
				}
				*packet->speed = atof(tmp_str) * KNOT_TO_KMH;
				free(tmp_str); tmp_str = NULL;
			}
			
			/* Get course, if available. */
			if ( regexec(&fapint_regex_nmea_specou, nmea_fields[8], matchcount, (regmatch_t*)&matches, 0) == 0 )
			{
				len = matches[1].rm_eo - matches[1].rm_so;
				tmp_str = malloc(len+1);
				if ( !tmp_str )
				{
					retval = 0;
					break;
				}
				memcpy(tmp_str, nmea_fields[8]+matches[1].rm_so, len);
				tmp_str[len] = 0;
				
				packet->course = malloc(sizeof(unsigned int));
				if ( !packet->course )
				{
					retval = 0;
					break;
				}
				*packet->course = atof(tmp_str) + 0.5;
				free(tmp_str); tmp_str = NULL;
				
				/* If zero, set to 360 because in APRS zero means invalid course... */
				if ( *packet->course == 0 )
				{
					*packet->course = 360;
				}
				else if ( *packet->course > 360 )
				{
					*packet->course = 0;
				}
			}
			
			/* Get latitude and longitude. */
			if ( !fapint_get_nmea_latlon(packet, nmea_fields[3], nmea_fields[4]) )
			{
				retval = 0;
				break;
			}
			if ( !fapint_get_nmea_latlon(packet, nmea_fields[5], nmea_fields[6]) )
			{
				retval = 0;
				break;
			}
			
			/* We have everything we want, return. */
			break;
		}
		else if ( strcmp(nmea_fields[0], "GPGGA") == 0 )
		{
			/* We want at least 11 fields. */
			if ( nmea_field_count < 11 )
			{
				packet->error_code = malloc(sizeof(fap_error_code_t));
				if ( packet->error_code ) *packet->error_code = fapGPGGA_FEWFIELDS;
				retval = 0;
				break;
			}
		
			/* Check for fix. */
			if ( regexec(&fapint_regex_nmea_fix, nmea_fields[6], matchcount, (regmatch_t*)&matches, 0) == 0 )
			{
				len = matches[1].rm_eo - matches[1].rm_so;
				tmp_str = malloc(len+1);
				if ( tmp_str )
				{
					retval = 0;
					break;
				}
				memcpy(tmp_str, nmea_fields[8]+matches[1].rm_so, len);
				tmp_str[len] = 0;
				if ( atoi(tmp_str) < 1 )
				{
					free(tmp_str);
					packet->error_code = malloc(sizeof(fap_error_code_t));
					if ( packet->error_code ) *packet->error_code = fapGPGGA_NOFIX;
					retval = 0;
					break;
				}
				free(tmp_str); tmp_str = NULL;
			}
			else
			{
				packet->error_code = malloc(sizeof(fap_error_code_t));
				if ( packet->error_code ) *packet->error_code = fapGPGGA_NOFIX;
				retval = 0;
				break;
			}
			
			/* Use the APRS time parsing routines to check the time and convert
				it to timestamp. But before that, remove a possible decimal
				part. */
			if ( strlen(nmea_fields[1]) < 6 )
			{
				packet->error_code = malloc(sizeof(fap_error_code_t));
				if ( packet->error_code ) *packet->error_code = fapTIMESTAMP_INV_GPGGA;
				retval = 0;
				break;
			}
			tmp_str = malloc(8);
			if ( !tmp_str )
			{
				retval = 0;
				break;
			}
			memcpy(tmp_str, nmea_fields[1], 6);
			tmp_str[6] = 'h';
			tmp_str[7] = 0;
			packet->timestamp = malloc(sizeof(time_t));
			if ( !packet->timestamp )
			{
				retval = 0;
				break;
			}
			*packet->timestamp = fapint_parse_timestamp(tmp_str);
			free(tmp_str); tmp_str = NULL;
			if ( *packet->timestamp == 0 )
			{
				packet->error_code = malloc(sizeof(fap_error_code_t));
				if ( packet->error_code ) *packet->error_code = fapTIMESTAMP_INV_GPGGA;
				retval = 0;
				break;
			}
			
			/* Latitude and longitude. */
			if ( !fapint_get_nmea_latlon(packet, nmea_fields[2], nmea_fields[3]) )
			{
				retval = 0;
				break;
			}
			if ( !fapint_get_nmea_latlon(packet, nmea_fields[4], nmea_fields[5]) )
			{
				retval = 0;
				break;
			}
			
			/* Altitude, only meters are accepted. */
			if ( strcmp(nmea_fields[0], "M") == 0 &&
				  regexec(&fapint_regex_nmea_altitude, nmea_fields[9], matchcount, (regmatch_t*)&matches, 0) == 0 )
			{
				len = matches[1].rm_eo - matches[1].rm_so;
				tmp_str = malloc(len+1);
				if ( !tmp_str )
				{
					retval = 0;
					break;
				}
				memcpy(tmp_str, nmea_fields[8]+matches[1].rm_so, len);
				tmp_str[len] = 0;
				packet->altitude = malloc(sizeof(double));
				if ( !packet->altitude )
				{
					retval = 0;
					break;
				}
				*packet->altitude = atoi(tmp_str);
				free(tmp_str); tmp_str = NULL;
			}
			
			/* Ok. */
			break;
		}
		else if ( strcmp(nmea_fields[0], "GPGLL") == 0 )
		{
			/* We want at least 5 fields. */
			if ( nmea_field_count < 5 )
			{
				packet->error_code = malloc(sizeof(fap_error_code_t));
				if ( packet->error_code ) *packet->error_code = fapGPGLL_FEWFIELDS;
				retval = 0;
				break;
			}
			
			/* Latitude and longitude. */
			if ( !fapint_get_nmea_latlon(packet, nmea_fields[1], nmea_fields[2]) )
			{
				retval = 0;
				break;
			}
			if ( !fapint_get_nmea_latlon(packet, nmea_fields[3], nmea_fields[4]) )
			{
				retval = 0;
				break;
			}
			
			/* Use the APRS time parsing routines to check the time and convert
				it to timestamp. But before that, remove a possible decimal
				part. */
			if ( nmea_field_count >= 6 && strlen(nmea_fields[5]) >= 6 )
			{
				tmp_str = malloc(8);
				if ( !tmp_str )
				{
					retval = 0;
					break;
				}
				memcpy(tmp_str, nmea_fields[5], 6);
				tmp_str[6] = 'h';
				tmp_str[7] = 0;
				packet->timestamp = malloc(sizeof(time_t));
				if ( !packet->timestamp )
				{
					retval = 0;
					break;
				}
				*packet->timestamp = fapint_parse_timestamp(tmp_str);
				free(tmp_str); tmp_str = NULL;
				if ( *packet->timestamp == 0 )
				{
					packet->error_code = malloc(sizeof(fap_error_code_t));
					if ( packet->error_code ) *packet->error_code = fapTIMESTAMP_INV_GPGLL;
					retval = 0;
					break;
				}
			}
			
			/* Check if fix validity is available. */
			if ( nmea_field_count >= 7 )
			{
				if ( strcmp(nmea_fields[0], "GPGLL") == 0 )
				{
					packet->error_code = malloc(sizeof(fap_error_code_t));
					if ( packet->error_code ) *packet->error_code = fapGPGLL_NOFIX;
					retval = 0;
					break;
				}
			}
			
			/* Ok. */
			break;
		}
		else
		{
			packet->error_code = malloc(sizeof(fap_error_code_t));
			if ( packet->error_code ) *packet->error_code = fapNMEA_UNSUPP;
			retval = 0;
		}
		break;
	}


	for ( i = 0; i < nmea_field_count; ++i )
	{
		free(nmea_fields[i]);
	}
	if ( tmp_str ) free(tmp_str);
	if ( nmea_fields ) free(nmea_fields);
	free(rest);
	return retval;
}



int fapint_parse_object(fap_packet_t* packet, char const* input, unsigned int const input_len)
{
	int i;

	/* Validate object length. At least 31 non-null chars are needed. */
	if ( strlen(input) < 31 )
	{
		packet->error_code = malloc(sizeof(fap_error_code_t));
		if ( packet->error_code ) *packet->error_code = fapOBJ_SHORT;
		return 0;
	}
	
	/* Validate and store object name. */
	for ( i = 1; i < 10; ++i )
	{
		if ( input[i] < 0x20 || input[i] > 0x7e )
		{
			packet->error_code = malloc(sizeof(fap_error_code_t));
			if ( packet->error_code ) *packet->error_code = fapOBJ_INV;
			return 0;
		}
	}
	packet->object_or_item_name = malloc(10);
	if ( !packet->object_or_item_name ) return 0;
	memcpy(packet->object_or_item_name, input+1, 9);
	packet->object_or_item_name[9] = 0;
	
	/* Validate and store object status. */
	if ( input[i] == '*' )
	{
		packet->alive = malloc(sizeof(int));
		if ( !packet->alive ) return 0;
		*packet->alive = 1;
	}
	else if ( input[i] == '_' )
	{
		packet->alive = malloc(sizeof(int));
		if ( !packet->alive ) return 0;
		*packet->alive = 0;
	}
	else
	{
		packet->error_code = malloc(sizeof(fap_error_code_t));
		if ( packet->error_code ) *packet->error_code = fapOBJ_INV;
		return 0;
	}
	
	/* Validate and store timestamp. */
	packet->timestamp = malloc(sizeof(time_t));
	if ( !packet->timestamp ) return 0;
	*packet->timestamp = fapint_parse_timestamp(input+11);
	if ( *packet->timestamp == 0)
	{
		packet->error_code = malloc(sizeof(fap_error_code_t));
		if ( packet->error_code ) *packet->error_code = fapTIMESTAMP_INV_OBJ;
		return 0;
	}
	
	/* Check location type. */
	i = 18;
	if ( input[i] == '/' || input[i] == '\\' ||
		  (input[i] >= 'A' && input[i] <= 'Z') ||
		  (input[i] >= 'a' && input[i] <= 'j')
		)
	{
		/* It's compressed. */
		if ( !fapint_parse_compressed(packet, input+i) )
		{
			return 0;
		}
		i += 13;
	}
	else if ( isdigit(input[i]) )
	{
		/* It's normal. */
		if ( !fapint_parse_normal(packet, input+i) )
		{
			return 0;
		}
		i += 19;
	}
	else
	{
		packet->error_code = malloc(sizeof(fap_error_code_t));
		if ( packet->error_code ) *packet->error_code = fapOBJ_DEC_ERR;
		return 0;
	}
		
	/* Check the APRS data extension and possible comments, unless it is a weather report (we don't want erroneus ourse/speed figures and weather in the comments..) */
	if ( packet->symbol_code != '_' )
	{
		fapint_parse_comment(packet, (char*)input+i, input_len-i);
	}
	else
	{
		fapint_parse_wx(packet, (char*)input+i, input_len-i);
	}
	
	return 1;
}


int fapint_parse_item(fap_packet_t* packet, char const* input, unsigned int const input_len)
{
	int len, i;

	/* Check length. */
	if ( input_len < 18 )
	{
		packet->error_code = malloc(sizeof(fap_error_code_t));
		if ( packet->error_code ) *packet->error_code = fapITEM_SHORT;
		return 0;
	}
	
	/* Validate item bytes up to location. */
	if ( input[0] != ')' )
	{
		packet->error_code = malloc(sizeof(fap_error_code_t));
		if ( packet->error_code ) *packet->error_code = fapITEM_INV;
		return 0;
	}
	len = 0;
	for ( i = 1; i <= 9; ++i )
	{
		if ( input[i] == 0x20 ||
			  (input[i] >= 0x22 && input[i] <= 0x5e) ||
			  (input[i] >= 0x60 && input[i] <= 0x7e) )
		{
			len = i;
		}
		else
		{
			break;
		}
	}
	if ( input[i] == '!' )
	{
		packet->alive = malloc(sizeof(int));
		if ( !packet->alive ) return 0;
		*packet->alive = 1;
	}
	else if ( input[i] == '_' )
	{
		packet->alive = malloc(sizeof(int));
		if ( !packet->alive ) return 0;
		*packet->alive = 0;
	}
	else
	{
		packet->error_code = malloc(sizeof(fap_error_code_t));
		if ( packet->error_code ) *packet->error_code = fapITEM_INV;
		return 0;
	}
	
	/* Save item name with null termination. */
	packet->object_or_item_name = malloc(len+1);
	if ( !packet->object_or_item_name ) return 0;
	memcpy(packet->object_or_item_name, input+1, len);
	packet->object_or_item_name[len] = 0;
	
	/* Check location type. */
	i = len + 2;
	if ( input[i] == '/' || input[i] == '\\' ||
		  (input[i] >= 'A' && input[i] <= 'Z') ||
		  (input[i] >= 'a' && input[i] <= 'j')
		)
	{
		/* It's compressed. */
		if ( !fapint_parse_compressed(packet, input+i) )
		{
			return 0;
		}
		i += 13;
	}
	else if ( isdigit(input[i]) )
	{
		/* It's normal. */
		if ( !fapint_parse_normal(packet, input+i) )
		{
			return 0;
		}
		i += 19;
	}
	else
	{
		packet->error_code = malloc(sizeof(fap_error_code_t));
		if ( packet->error_code ) *packet->error_code = fapITEM_DEC_ERR;
		return 0;
	}
		
	/* Check the APRS data extension and possible comments, unless it is a weather report (we don't want erroneus ourse/speed figures and weather in the comments..) */
	if ( packet->symbol_code != '_' )
	{
		fapint_parse_comment(packet, (char*)input+i, input_len-i);
	}   

	return 1;
}


int fapint_parse_message(fap_packet_t* packet, char const* input, unsigned int const input_len)
{
	int i, len;
	char* tmp;
	short skipping_spaces = 1;
					
	unsigned int const matchcount = 3;
	regmatch_t matches[matchcount];


	/* Check length. */
	if ( input_len < 12 )
	{
		packet->error_code = malloc(sizeof(fap_error_code_t));
		if ( packet->error_code ) *packet->error_code = fapMSG_INV;
		return 0;
	}
	
	/* Validate and save destination. */
	if ( regexec(&fapint_regex_mes_dst, input, matchcount, (regmatch_t*)&matches, 0) == 0 )
	{
		/* Get length and strip trailing spaces. */
		len = matches[1].rm_eo - matches[1].rm_so;
		for ( i = matches[1].rm_eo-1; i > 0; --i )
		{
			if ( input[i] == ' ' )
			{
				--len;
			}
			else
			{
				break;
			}
		}

		/* Save with null-termination. */
		packet->destination = malloc(len+1);
		if ( !packet->destination ) return 0;
		memcpy(packet->destination, input+matches[1].rm_so, len);
		packet->destination[len] = 0;
	}
	else
	{
		packet->error_code = malloc(sizeof(fap_error_code_t));
		if ( packet->error_code ) *packet->error_code = fapMSG_INV;
		return 0;
	}
	
	/* Find message length. */
	len = 0;
	for ( i = 11; i < input_len; ++i )
	{
		if ( (input[i] >= 0x20 && input[i] <= 0x7e) || ((unsigned char)input[i] >= 0x80 && (unsigned char)input[i] <= 0xfe) )
		{
			len = i - 10;
		}
		else
		{
			break;
		}
	}
	if ( len == 0 )
	{
		packet->error_code = malloc(sizeof(fap_error_code_t));
		if ( packet->error_code ) *packet->error_code = fapMSG_INV;
		return 0;
	}
	
	/* Save message. */
	packet->message = malloc(len+1);
	if ( !packet->message ) return 0;
	memcpy(packet->message, input+11, len);
	packet->message[len] = 0;
	
	/* Check if message is an ack, save id if it is. */
	if ( regexec(&fapint_regex_mes_ack, packet->message, matchcount, (regmatch_t*)&matches, 0) == 0 )
	{
		len = matches[1].rm_eo - matches[1].rm_so;
		packet->message_ack = malloc(len+1);
		if ( !packet->message_ack ) return 0;
		memcpy(packet->message_ack, packet->message+matches[1].rm_so, len);
		packet->message_ack[len] = 0;
	}

	/* Check if message is a nack, save id if it is. */
	if ( regexec(&fapint_regex_mes_nack, packet->message, matchcount, (regmatch_t*)&matches, 0) == 0 )
	{
		len = matches[1].rm_eo - matches[1].rm_so;
		packet->message_nack = malloc(len+1);
		if ( !packet->message_nack ) return 0;
		memcpy(packet->message_nack, packet->message+matches[1].rm_so, len);
		packet->message_nack[len] = 0;
	}
	
	/* Separate message-id from the body, if present. */
	len = 0;
	for ( i = strlen(packet->message)-1; i >= 0 ; i-- )
	{
	        if ( skipping_spaces && !isspace(packet->message[i]) )
	        {
	                /* Last non-space char of the id. */
	                skipping_spaces = 0;
	        }
	        else if ( skipping_spaces )
	        {
	                continue;
                }
                
                /* New char of id. First check that it can be part of id. */
                if ( !(isalnum(packet->message[i]) || packet->message[i] == '{') )
                {
                        break;
                }
                
                /* Check that we're not too long yet. */
                len++;
                if ( len > 6 )
                {
                        break;
                }
                
                /* Check if id starts here. */
                if ( packet->message[i] == '{' )
                {
        		/* Create copy of message without the id. */
	        	tmp = packet->message;
        		packet->message = malloc(i+1);
        		if ( !packet->message )
        		{
        			free(tmp);
        			return 0;
        		}
        		memcpy(packet->message, tmp, i);
        		packet->message[i] = 0;
		
        		/* Save message id. */
        		packet->message_id = malloc(len+1);
	        	if ( !packet->message_id )
	        	{
        			free(tmp);
	        		return 0;
        		}
	        	memcpy(packet->message_id, tmp+i+1, len);
	        	packet->message_id[len] = 0;
	        	
	        	/* Get rid of the old message. */
        		free(tmp);

                        break;
                }
        }
        
	/* Catch telemetry messages. */
	if ( strcmp(packet->src_callsign, packet->destination) == 0 &&
		  ( strstr(packet->message, "BITS.") != NULL ||
			 strstr(packet->message, "PARM.") != NULL ||
			 strstr(packet->message, "UNIT.") != NULL ||
			 strstr(packet->message, "EQNS.") != NULL
		  )
		)
	{
		if ( packet->type == NULL )
		{
			packet->type = malloc(sizeof(fap_packet_type_t));
			if ( !packet->type ) return 0;
		}
		*packet->type = fapTELEMETRY_MESSAGE;
	}
	
	return 1;
}

int fapint_parse_capabilities(fap_packet_t* packet, char const* input, unsigned int const input_len)
{
	fapint_llist_item_t* caps = NULL;
	int cap_count = 0;
	fapint_llist_item_t* current_elem = NULL;

	char* tmp_str, *sepa;
	int cap_len, cap_startpos, i, retval = 1;
	unsigned int foo, saved, sepa_pos;

	/* Find capabilities. */
	cap_startpos = 0;
	for ( i = 0; i < input_len; ++i )
	{
		tmp_str = NULL;
		
		/* Look for element boundary. */
		if ( input[i] == ',' )
		{
			/* Found a bound, let's create a copy of the capability it ends. */
			cap_len = i - cap_startpos;
			tmp_str = malloc(cap_len+1);
			if ( !tmp_str )
			{
				retval = 0;
				break;
			}
			memcpy(tmp_str, input+cap_startpos, cap_len);
			tmp_str[cap_len] = 0;
			
			/* Start to look for next element. */
			cap_startpos = i + 1;
		}
		else if ( i+1 == input_len )
		{
			/* We're at the end, save the last element. */
			cap_len = i+1 - cap_startpos;
			tmp_str = malloc(cap_len+1);
			if ( !tmp_str )
			{
				retval = 0;
				break;
			}
			memcpy(tmp_str, input+cap_startpos, cap_len);
			tmp_str[cap_len] = 0;
		}
		
		/* Check if we found something. */
		if ( tmp_str )
		{
			/* Create list item. */
			if ( caps == NULL )
			{
				caps = malloc(sizeof(fapint_llist_item_t));
				if ( !caps )
				{
					retval = 0;
					break;
				}
				current_elem = caps;
			}
			else
			{
				current_elem->next = malloc(sizeof(fapint_llist_item_t));
				if ( !current_elem->next )
				{
					retval = 0;
					break;
				}
				current_elem = current_elem->next;
			}
			current_elem->next = NULL;
			current_elem->text = tmp_str;
			
			++cap_count;
		}
	}
	if ( !retval )
	{
		fapint_clear_llist(caps);
		return 0;
	}
	
	/* At least one capability is needed for the packet to be valid. */
	if ( cap_count == 0 )
	{
		return 0;
	}
	
	/* Save capabilites. */
	packet->capabilities = calloc(cap_count*2, sizeof(char*));
	if ( !packet->capabilities )
	{
		fapint_clear_llist(caps);
		return 0;
	}
	for ( i = 0; i < cap_count; ++i ) packet->capabilities[i] = NULL;
	packet->capabilities_len = cap_count;
	i = 0;
	current_elem = caps;
	while ( current_elem != NULL )
	{
		saved = 0;
		/* Find value splitpos. */
		if ( (sepa = strchr(current_elem->text, '=')) != NULL )
		{
			sepa_pos = sepa - current_elem->text - 1;
			/* Check that splitpos is not first or last char. */
			if ( sepa_pos < input_len )
			{
				packet->capabilities[i] = fapint_remove_part(current_elem->text, strlen(current_elem->text), sepa_pos, strlen(current_elem->text), &foo);
				packet->capabilities[i+1] = fapint_remove_part(current_elem->text, strlen(current_elem->text), 0, sepa_pos+2, &foo);
				saved = 1;
			}
		}
		
		/* If the cap was not yet saved, save it without value. */
		if ( !saved )
		{
			packet->capabilities[i] = malloc(strlen(current_elem->text)+1);
			if ( !packet->capabilities[i] )
			{
				retval = 0;
				break;
			}
			strcpy(packet->capabilities[i], current_elem->text);
			packet->capabilities[i+1] = NULL;
		}
		
		/* Get next element. */
		current_elem = current_elem->next;
		i += 2;
	}
	fapint_clear_llist(caps);
	
	return retval;
}



int fapint_parse_status(fap_packet_t* packet, char const* input, unsigned int const input_len)
{
	short has_timestamp = 0;
	int i;

	/* Check for timestamp. */
	if ( input_len > 6 )
	{
		has_timestamp = 1;
		for ( i = 0; i < 6; ++i )
		{
			if ( !isdigit(input[i]) )
			{
				has_timestamp = 0;
				break;
			}
		}
		if ( input[6] != 'z' )
		{
			has_timestamp = 0;
		}
	}
	
	/* Save rest as status. */
	if ( has_timestamp )
	{
		packet->timestamp = malloc(sizeof(time_t));
		if ( !packet->timestamp ) return 0;
		*packet->timestamp = fapint_parse_timestamp(input);
		if ( *packet->timestamp == 0 )
		{
			packet->error_code = malloc(sizeof(fap_error_code_t));
			if ( packet->error_code ) *packet->error_code = fapTIMESTAMP_INV_STA;
			return 0;
		}
		packet->status = fapint_remove_part(input, input_len, 0, 7, &packet->status_len);
	}
	else
	{
		packet->status = malloc(input_len);
		if ( !packet->status ) return 0;
		memcpy(packet->status, input, input_len);
		packet->status_len = input_len;
	}
	
	return 1;
}



int fapint_parse_wx(fap_packet_t* packet, char const* input, unsigned int const input_len)
{
	char wind_dir[4], wind_speed[4], *wind_gust = NULL, *temp = NULL;
	char buf_5b[6];
	int len, retval = 1;
	char* rest = NULL, *tmp_str;
	unsigned int rest_len, tmp_us;
	
	unsigned int const matchcount = 5;
	regmatch_t matches[matchcount];
        
	/* Check that we have something to look at. */
	if ( !packet || !input || !input_len )
	{
		return 0;
	}
	
	/* Initialize result vars. */
	memset(wind_dir, 0, 4);
	memset(wind_speed, 0, 4);
	
	/* Look for wind and temperature. Remaining bytes are copied to report var. */
	if ( regexec(&fapint_regex_wx1, input, matchcount, (regmatch_t*)&matches, 0) == 0 )
	{
		memcpy(wind_dir, input+matches[1].rm_so, 3);
		wind_dir[3] = 0;

		memcpy(wind_speed, input+matches[2].rm_so, 3);
		wind_speed[3] = 0;

		len = matches[3].rm_eo - matches[3].rm_so;
		wind_gust = malloc(len+1);
		if ( !wind_gust ) return 0;
		memcpy(wind_gust, input+matches[3].rm_so, len);
		wind_gust[len] = 0;

		len = matches[4].rm_eo - matches[4].rm_so;
		temp = malloc(len+1);
		if ( !temp )
		{
			free(wind_gust);
			return 0;
		}
		memcpy(temp, input+matches[4].rm_so, len);
		temp[len] = 0;

		rest = fapint_remove_part(input, input_len, 0, matches[4].rm_eo, &rest_len);
	}
	else if ( regexec(&fapint_regex_wx2, input, 5, matches, 0) == 0 )
	{
		memcpy(wind_dir, input+matches[1].rm_so, 3);
		wind_dir[3] = 0;

		memcpy(wind_speed, input+matches[2].rm_so, 3);
		wind_speed[3] = 0;

		len = matches[3].rm_eo - matches[3].rm_so;
		wind_gust = malloc(len+1);
		if ( !wind_gust ) return 0;
		memcpy(wind_gust, input+matches[3].rm_so, len);
		wind_gust[len] = 0;

		len = matches[4].rm_eo - matches[4].rm_so;
		temp = malloc(len+1);
		if ( !temp )
		{
			free(wind_gust);
			return 0;
		}
		memcpy(temp, input+matches[4].rm_so, len);
		temp[len] = 0;

		rest = fapint_remove_part(input, input_len, 0, matches[4].rm_eo, &rest_len);
	}
	else if ( regexec(&fapint_regex_wx3, input, 4, matches, 0) == 0 )
	{
		memcpy(wind_dir, input+matches[1].rm_so, 3);
		wind_dir[3] = 0;

		memcpy(wind_speed, input+matches[2].rm_so, 3);
		wind_speed[3] = 0;

		len = matches[3].rm_eo - matches[3].rm_so;
		wind_gust = malloc(len+1);
		if ( !wind_gust ) return 0;
		memcpy(wind_gust, input+matches[3].rm_so, len);
		wind_gust[len] = 0;

		rest = fapint_remove_part(input, input_len, 0, matches[3].rm_eo, &rest_len);
	}
	else if ( regexec(&fapint_regex_wx4, input, 4, matches, 0) == 0 )
	{
		memcpy(wind_dir, input+matches[1].rm_so, 3);
		wind_dir[3] = 0;

		memcpy(wind_speed, input+matches[2].rm_so, 3);
		wind_speed[3] = 0;

		len = matches[3].rm_eo - matches[3].rm_so;
		wind_gust = malloc(len+1);
		if ( !wind_gust ) return 0;
		memcpy(wind_gust, input+matches[3].rm_so, len);
		wind_gust[len] = 0;

		rest = fapint_remove_part(input, input_len, 0, matches[3].rm_eo, &rest_len);
	}
	else if ( regexec(&fapint_regex_wx5, input, 3, matches, 0) == 0 )
	{
	        len = matches[1].rm_eo - matches[1].rm_so;
	        wind_gust = malloc(len+1);
	        if ( !wind_gust ) return 0;
	        memcpy(wind_gust, input+matches[1].rm_so, len);
	        wind_gust[len] = 0;
	        
	        len = matches[2].rm_eo - matches[2].rm_so;
	        temp = malloc(len+1);
	        if ( !temp )
	        {
	                free(wind_gust);
	                return 0;
                }
                memcpy(temp, input+matches[2].rm_so, len);
                temp[len] = 0;
                
                rest = fapint_remove_part(input, input_len, 0, matches[2].rm_eo, &rest_len);
        }
	else
	{
		return 0;
	}
	
	if ( temp == NULL && rest_len > 0 && regexec(&fapint_regex_wx5, rest, matchcount, (regmatch_t*)&matches, 0) == 0 )
	{
		len = matches[1].rm_eo - matches[1].rm_so;
		temp = malloc(len+1);
		if ( !temp )
		{
			if ( wind_gust ) free(wind_gust);
			free(rest);
			return 0;
		}
		memcpy(temp, rest+matches[1].rm_so, len);
		temp[len] = 0;

		tmp_str = fapint_remove_part(rest, rest_len, matches[1].rm_so-1, matches[1].rm_eo, &tmp_us);
		free(rest);
		rest = tmp_str;
		rest_len = tmp_us;
	}
	
	/* Prepare to get results. */
	packet->wx_report = malloc(sizeof(fap_wx_report_t));
	if ( !packet->wx_report )
	{
		if ( wind_gust ) free(wind_gust);
		if ( temp ) free(temp);
		if ( rest ) free(rest);
		return 0;
	}
	fapint_init_wx_report(packet->wx_report);

	/* Save values. */
	do
	{
		if ( fapint_is_number(wind_gust) )
		{
			packet->wx_report->wind_gust = malloc(sizeof(double));
			if ( !packet->wx_report->wind_gust )
			{
				retval = 0;
				break;
			}
			*packet->wx_report->wind_gust = atof(wind_gust) * MPH_TO_MS;
		}
		if ( fapint_is_number(wind_dir) )
		{
			packet->wx_report->wind_dir = malloc(sizeof(int));
			if ( !packet->wx_report->wind_dir )
			{
				retval = 0;
				break;
			}
			*packet->wx_report->wind_dir = atoi(wind_dir);
		}
		if ( fapint_is_number(wind_speed) )
		{
			packet->wx_report->wind_speed = malloc(sizeof(double));
			if ( !packet->wx_report->wind_speed )
			{
				retval = 0;
				break;
			}
			*packet->wx_report->wind_speed = atof(wind_speed) * MPH_TO_MS;
		}
		if ( fapint_is_number(temp) )
		{
			packet->wx_report->temp = malloc(sizeof(double));
			if ( !packet->wx_report->temp )
			{
				retval = 0;
				break;
			}
			*packet->wx_report->temp = FAHRENHEIT_TO_CELCIUS(atof(temp));
		}
	} while ( 0 );
	if ( wind_gust )
	{
		free(wind_gust);
		wind_gust = NULL;
	}
	if ( temp )
	{
		free(temp);
		temp = NULL;
	}
	if ( !retval )
	{
		free(rest);
		return 0;
	}
	
	/* Then some rain values. */
	do
	{
		if ( rest_len > 0 && regexec(&fapint_regex_wx_r1, rest, matchcount, (regmatch_t*)&matches, 0) == 0 )
		{
			len = matches[1].rm_eo - matches[1].rm_so;
			memset(buf_5b, 0, 6);
			memcpy(buf_5b, rest+matches[1].rm_so, len);
			packet->wx_report->rain_1h = malloc(sizeof(double));
			if ( !packet->wx_report->rain_1h )
			{
				retval = 0;
				break;
			}
			*packet->wx_report->rain_1h = atof(buf_5b) * HINCH_TO_MM;

			tmp_str = fapint_remove_part(rest, rest_len, matches[1].rm_so-1, matches[1].rm_eo, &tmp_us);
			free(rest);
			rest = tmp_str;
			rest_len = tmp_us;
		}
		if ( rest_len > 0 && regexec(&fapint_regex_wx_r24, rest, 2, matches, 0) == 0 )
		{
			len = matches[1].rm_eo - matches[1].rm_so;
			memset(buf_5b, 0, 4);
			memcpy(buf_5b, rest+matches[1].rm_so, len);
			packet->wx_report->rain_24h = malloc(sizeof(double));
			if ( !packet->wx_report->rain_24h )
			{
				retval = 0;
				break;
			}
			*packet->wx_report->rain_24h = atof(buf_5b) * HINCH_TO_MM;
		
			tmp_str = fapint_remove_part(rest, rest_len, matches[1].rm_so-1, matches[1].rm_eo, &tmp_us);
			free(rest);
			rest = tmp_str;
			rest_len = tmp_us;
		}
		if ( rest_len > 0 && regexec(&fapint_regex_wx_rami, rest, 2, matches, 0) == 0 )
		{
			len = matches[1].rm_eo - matches[1].rm_so;
			memset(buf_5b, 0, 4);
			memcpy(buf_5b, rest+matches[1].rm_so, len);
			packet->wx_report->rain_midnight = malloc(sizeof(double));
			if ( !packet->wx_report->rain_midnight )
			{
				retval = 0;
				break;
			}
			*packet->wx_report->rain_midnight = atof(buf_5b) * HINCH_TO_MM;

			tmp_str = fapint_remove_part(rest, rest_len, matches[1].rm_so-1, matches[1].rm_eo, &tmp_us);
			free(rest);
			rest = tmp_str;
			rest_len = tmp_us;
		}
	} while ( 0 );
	if ( !retval )
	{
		free(rest);
		return 0;
	}
	
	/* Humidity. */
	if ( rest_len > 0 && regexec(&fapint_regex_wx_humi, rest, 2, matches, 0) == 0 )
	{
		len = matches[1].rm_eo - matches[1].rm_so;
		memset(buf_5b, 0, 6);
		memcpy(buf_5b, rest+matches[1].rm_so, len);
		if ( (tmp_us = atoi(buf_5b)) <= 100 )
		{
			packet->wx_report->humidity = malloc(sizeof(unsigned int));
			if ( !packet->wx_report->humidity )
			{
		  		free(rest);
		  		return 0;
		  	}
		  	if ( tmp_us == 0 ) tmp_us = 100;
		  	*packet->wx_report->humidity = tmp_us;
		}
		
		tmp_str = fapint_remove_part(rest, rest_len, matches[1].rm_so-1, matches[1].rm_eo, &tmp_us);
		free(rest);
		rest = tmp_str;
		rest_len = tmp_us;
	}
	
	/* Pressure. */
	if ( rest_len > 0 && regexec(&fapint_regex_wx_pres, rest, 2, matches, 0) == 0 )
	{
		len = matches[1].rm_eo - matches[1].rm_so;
		memset(buf_5b, 0, 6);
		memcpy(buf_5b, rest+matches[1].rm_so, len);
		packet->wx_report->pressure = malloc(sizeof(double));
		if ( !packet->wx_report->pressure )
		{
			free(rest);
			return 0;
		}
		*packet->wx_report->pressure = atoi(buf_5b)/10.0; // tenths of mbars to mbars
		
		tmp_str = fapint_remove_part(rest, rest_len, matches[1].rm_so-1, matches[1].rm_eo, &tmp_us);
		free(rest);
		rest = tmp_str;
		rest_len = tmp_us;
	}
	
	/* Luminosity. */
	if ( rest_len > 0 && regexec(&fapint_regex_wx_lumi, rest, 3, matches, 0) == 0 )
	{
		len = matches[2].rm_eo - matches[2].rm_so;
		memset(buf_5b, 0, 6);
		memcpy(buf_5b, rest+matches[2].rm_so, len);
		packet->wx_report->luminosity = malloc(sizeof(unsigned int));
		if ( !packet->wx_report->luminosity )
		{
			free(rest);
			return 0;
		}
		*packet->wx_report->luminosity = atoi(buf_5b);
		if ( input[matches[1].rm_so] == 'l' )
		{
			*packet->wx_report->luminosity += 1000;
		}
		
		tmp_str = fapint_remove_part(rest, rest_len, matches[1].rm_so, matches[2].rm_eo, &tmp_us);
		free(rest);
		rest = tmp_str;
		rest_len = tmp_us;
	}
	
	/* What? */
	if ( rest_len > 0 && regexec(&fapint_regex_wx_what, rest, 2, matches, 0) == 0 )
	{
		tmp_str = fapint_remove_part(rest, rest_len, matches[1].rm_so-1, matches[1].rm_eo, &tmp_us);
		free(rest);
		rest = tmp_str;
		rest_len = tmp_us;
	}
	
	/* Snowfall. */
	if ( rest_len > 0 && regexec(&fapint_regex_wx_snow, rest, 2, matches, 0) == 0 )
	{
		len = matches[1].rm_eo - matches[1].rm_so;
		if ( len > 5 ) len = 5;
		memset(buf_5b, 0, 6);
		memcpy(buf_5b, rest+matches[1].rm_so, len);
		packet->wx_report->snow_24h = malloc(sizeof(double));
		if ( !packet->wx_report->snow_24h )
		{
			free(rest);
			return 0;
		}
		*packet->wx_report->snow_24h = atof(buf_5b) * HINCH_TO_MM;
		
		tmp_str = fapint_remove_part(rest, rest_len, matches[1].rm_so-1, matches[1].rm_eo, &tmp_us);
		free(rest);
		rest = tmp_str;
		rest_len = tmp_us;
	}
	
	/* Raw rain counter. */
	if ( rest_len > 0 && regexec(&fapint_regex_wx_rrc, rest, 2, matches, 0) == 0 )
	{
		tmp_str = fapint_remove_part(rest, rest_len, matches[1].rm_so-1, matches[1].rm_eo, &tmp_us);
		free(rest);
		rest = tmp_str;
		rest_len = tmp_us;
	}
	
	/* Remove any remaining known report parts. */
	if ( rest_len > 0 && regexec(&fapint_regex_wx_any, rest, 2, matches, 0) == 0 )
	{
		tmp_str = fapint_remove_part(rest, rest_len, matches[1].rm_so, matches[1].rm_eo, &tmp_us);
		free(rest);
		rest = tmp_str;
		rest_len = tmp_us;
	}
	
	/* If there's still something left, we can't know what it is. We do some guesswork nevertheless. */
	
	/* Check if it could be wx software id. */
	if ( rest_len > 0 && regexec(&fapint_regex_wx_soft, rest, 0, NULL, 0) == 0 )
	{
		packet->wx_report->soft = rest;
	}
        /* If not, it is propaby a comment. */
        else if ( rest_len > 0 && packet->comment == NULL )
        {
        	packet->comment = rest;
       		packet->comment_len = rest_len;
	}
	else
	{
	        free(rest);
        }

	return 1;
}



int fapint_parse_telemetry(fap_packet_t* packet, char const* input)
{
	unsigned int matchcount = 13;
	regmatch_t matches[matchcount];
	
	char* tmp_str;
	int len1, len2;
	
	/* Check params. */
	if ( !packet || !input )
	{
		return 0;
	}
	if ( regexec(&fapint_regex_telemetry, input, matchcount, (regmatch_t*)&matches, 0) == 0 )
	{
		/* Initialize results. */
		packet->telemetry = malloc(sizeof(fap_telemetry_t));
		if ( !packet->telemetry ) return 0;
		fapint_init_telemetry_report(packet->telemetry);
		
		/* seq */
		len1 = matches[1].rm_eo - matches[1].rm_so;
		tmp_str = malloc(len1+1);
		if ( !tmp_str ) return 0;
		memcpy(tmp_str, input+matches[1].rm_so, len1);
		tmp_str[len1] = 0;
		packet->telemetry->seq = malloc(sizeof(unsigned int));
		if ( !packet->telemetry->seq ) return 0;
		*packet->telemetry->seq = atoi(tmp_str);
		free(tmp_str);
		
		/* val1 */
		len1 = matches[2].rm_eo - matches[2].rm_so;
		len2 = matches[3].rm_eo - matches[3].rm_so;
		tmp_str = malloc(len1+len2+1);
		if ( !tmp_str ) return 0;
		memcpy(tmp_str, input+matches[2].rm_so, len1);
		memcpy(tmp_str+len1, input+matches[3].rm_so, len2);
		tmp_str[len1+len2] = 0;
		packet->telemetry->val1 = malloc(sizeof(double));
		if ( !packet->telemetry->val1 ) return 0;
		*packet->telemetry->val1 = atof(tmp_str);
		free(tmp_str);

		/* val2 */
		len1 = matches[4].rm_eo - matches[4].rm_so;
		len2 = matches[5].rm_eo - matches[5].rm_so;
		tmp_str = malloc(len1+len2+1);
		if ( !tmp_str ) return 0;
		memcpy(tmp_str, input+matches[4].rm_so, len1);
		memcpy(tmp_str+len1, input+matches[5].rm_so, len2);
		tmp_str[len1+len2] = 0;
		packet->telemetry->val2 = malloc(sizeof(double));
		if ( !packet->telemetry->val2 ) return 0;
		*packet->telemetry->val2 = atof(tmp_str);
		free(tmp_str);
		
		/* val3 */
		len1 = matches[6].rm_eo - matches[6].rm_so;
		len2 = matches[7].rm_eo - matches[7].rm_so;
		tmp_str = malloc(len1+len2+1);
		if ( !tmp_str ) return 0;
		memcpy(tmp_str, input+matches[6].rm_so, len1);
		memcpy(tmp_str+len1, input+matches[7].rm_so, len2);
		tmp_str[len1+len2] = 0;
		packet->telemetry->val3 = malloc(sizeof(double));
		if ( !packet->telemetry->val3 ) return 0;
		*packet->telemetry->val3 = atof(tmp_str);
		free(tmp_str);

		/* val4 */
		len1 = matches[8].rm_eo - matches[8].rm_so;
		len2 = matches[9].rm_eo - matches[9].rm_so;
		tmp_str = malloc(len1+len2+1);
		if ( !tmp_str ) return 0;
		memcpy(tmp_str, input+matches[8].rm_so, len1);
		memcpy(tmp_str+len1, input+matches[9].rm_so, len2);
		tmp_str[len1+len2] = 0;
		packet->telemetry->val4 = malloc(sizeof(double));
		if ( !packet->telemetry->val4 ) return 0;
		*packet->telemetry->val4 = atof(tmp_str);
		free(tmp_str);

		/* val5 */
		len1 = matches[10].rm_eo - matches[10].rm_so;
		len2 = matches[11].rm_eo - matches[11].rm_so;
		tmp_str = malloc(len1+len2+1);
		if ( !tmp_str ) return 0;
		memcpy(tmp_str, input+matches[10].rm_so, len1);
		memcpy(tmp_str+len1, input+matches[11].rm_so, len2);
		tmp_str[len1+len2] = 0;
		packet->telemetry->val5 = malloc(sizeof(double));
		if ( !packet->telemetry->val5 ) return 0;
		*packet->telemetry->val5 = atof(tmp_str);
		free(tmp_str);

		/* bits */
		len1 = matches[12].rm_eo - matches[12].rm_so;
		memcpy(packet->telemetry->bits, input+matches[12].rm_so, len1);
	}
	else
	{
		packet->error_code = malloc(sizeof(fap_error_code_t));
		if ( packet->error_code ) *packet->error_code = fapTLM_INV;
		return 0;
	}
	
	return 1;
}



int fapint_parse_wx_peet_logging(fap_packet_t* packet, char const* input)
{
	fapint_llist_item_t* parts, *current_elem;
	unsigned int part_count;

	int i, retval = 1;

	unsigned int matchcount = 2;
	regmatch_t matches[matchcount];
	
	
	/* Split report into parts. */
	parts = NULL;
	current_elem = NULL;
	part_count = 0;
	i = 0;
	while ( regexec(&fapint_regex_peet_splitter, input+i, matchcount, matches, 0) == 0 )
	{
		if ( !parts )
		{
			parts = malloc(sizeof(fapint_llist_item_t));
			if ( !parts )
			{
				retval = 0;
				break;
			}
			current_elem = parts;
		}
		else
		{
			current_elem->next = malloc(sizeof(fapint_llist_item_t));
			if ( !current_elem->next )
			{
				retval = 0;
				break;
			}
			current_elem = current_elem->next;
		}
		current_elem->next = NULL;
		if ( input[i+matches[1].rm_so] != '-' )
		{
			current_elem->text = malloc(5);
			memcpy(current_elem->text, input+i+matches[1].rm_so, 4);
			current_elem->text[4] = 0;
		}
		else
		{
			current_elem->text = NULL;
		}
		part_count++;
		
		/* Prepare for next element. */
		i += 4;
		if ( i >= strlen(input) ) break;
	}
	if ( !retval || !part_count )
	{
		fapint_clear_llist(parts);
		return 0;
	}
	
	/* Prepare to return results. */
	packet->wx_report = malloc(sizeof(fap_wx_report_t));
	if ( !packet->wx_report )
	{
		fapint_clear_llist(parts);
		return 0;
	}
	fapint_init_wx_report(packet->wx_report);
	
	/* Check parts one at a time. */
	do
	{
		current_elem = parts;
		
		/* instant wind speed */
		if ( current_elem->text )
		{
			packet->wx_report->wind_speed = malloc(sizeof(double));
			if ( !packet->wx_report->wind_speed )
			{
				retval = 0;
				break;
			}
			*packet->wx_report->wind_speed = strtol(current_elem->text, NULL, 16) * KMH_TO_MS / 10.0;
		}
		current_elem = current_elem->next;
	
		/* wind direction */
		if ( current_elem )
		{
			if ( current_elem->text )
			{
				packet->wx_report->wind_dir = malloc(sizeof(unsigned int));
				if ( !packet->wx_report->wind_dir )
				{
					retval = 0;
					break;
				}
				*packet->wx_report->wind_dir = floor(strtol(current_elem->text, NULL, 16) * 1.41176 + 0.5);
			}
			current_elem = current_elem->next;
		}
		else
		{
			break;
		}
		
		/* temperature */
		if ( current_elem )
		{
			if ( current_elem->text )
			{
				packet->wx_report->temp = malloc(sizeof(double));
				if ( !packet->wx_report->temp )
				{
					retval = 0;
					break;
				}
				*packet->wx_report->temp = FAHRENHEIT_TO_CELCIUS(strtol(current_elem->text, NULL, 16)/10.0);
			}
			current_elem = current_elem->next;
		}
		else
		{
			break;
		}
		
		/* rain since midnight */
		if ( current_elem )
		{
			if ( current_elem->text )
			{
				packet->wx_report->rain_midnight = malloc(sizeof(double));
				if ( !packet->wx_report->rain_midnight )
				{
					retval = 0;
					break;
				}
				*packet->wx_report->rain_midnight = strtol(current_elem->text, NULL, 16) * HINCH_TO_MM;
			}
			current_elem = current_elem->next;
		}
		else
		{
			break;
		}
		
		/* pressure */
		if ( current_elem )
		{
			if ( current_elem->text )
			{
				packet->wx_report->pressure = malloc(sizeof(double));
				if ( !packet->wx_report->pressure )
				{
					retval = 0;
					break;
				}
				*packet->wx_report->pressure = strtol(current_elem->text, NULL, 16) / 10.0;
			}
			current_elem = current_elem->next;
		}
		else
		{
			break;
		}
		
		/* inside temperature */
		if ( current_elem )
		{
			if ( current_elem->text )
			{
				packet->wx_report->temp_in = malloc(sizeof(double));
				if ( !packet->wx_report->temp_in )
				{
					retval = 0;
					break;
				}
				*packet->wx_report->temp_in = FAHRENHEIT_TO_CELCIUS(strtol(current_elem->text, NULL, 16)/10.0);
			}
			current_elem = current_elem->next;
		}
		else
		{
			break;
		}
		
		/* humidity */
		if ( current_elem )
		{
			if ( current_elem->text )
			{
				packet->wx_report->humidity = malloc(sizeof(unsigned int));
				if ( !packet->wx_report->humidity )
				{
					retval = 0;
					break;
				}
				*packet->wx_report->humidity = strtol(current_elem->text, NULL, 16)/10.0;
			}
			current_elem = current_elem->next;
		}
		else
		{
			break;
		}
		
		/* inside humidity */
		if ( current_elem )
		{
			if ( current_elem->text )
			{
				packet->wx_report->humidity_in = malloc(sizeof(unsigned int));
				if ( !packet->wx_report->humidity_in )
				{
					retval = 0;
					break;
				}
				*packet->wx_report->humidity_in = strtol(current_elem->text, NULL, 16)/10.0;
			}
			current_elem = current_elem->next;
		}
		else
		{
			break;
		}
		
		/* date */
		if ( current_elem )
		{
			current_elem = current_elem->next;
		}
		else
		{
			break;
		}
		
		/* time */
		if ( current_elem )
		{
			current_elem = current_elem->next;
		}
		else
		{
			break;
		}

		/* rain since midnight (again?) */
		if ( current_elem )
		{
			if ( current_elem->text )
			{
				*packet->wx_report->rain_midnight = strtol(current_elem->text, NULL, 16) * HINCH_TO_MM;
			}
			current_elem = current_elem->next;

		/* avg wind speed */
		if ( current_elem && current_elem->text )
		{
			*packet->wx_report->wind_speed = strtol(current_elem->text, NULL, 16) * KMH_TO_MS / 10.0;
		}
		current_elem = current_elem->next;
		}
		
	} while ( 0 );	
	fapint_clear_llist(parts);
	
	return retval;
}



int fapint_parse_wx_peet_packet(fap_packet_t* packet, char const* input)
{
	fapint_llist_item_t* parts, *current_elem;
	unsigned int part_count;

	int i, retval = 1;
	int16_t temp;

	unsigned int matchcount = 2;
	regmatch_t matches[matchcount];
	
	
	/* Split report into parts. */
	parts = NULL;
	current_elem = NULL;
	part_count = 0;
	i = 0;
	while ( regexec(&fapint_regex_peet_splitter, input+i, matchcount, matches, 0) == 0 )
	{
		if ( !parts )
		{
			parts = malloc(sizeof(fapint_llist_item_t));
			if ( !parts ) return 0;
			current_elem = parts;
		}
		else
		{
			current_elem->next = malloc(sizeof(fapint_llist_item_t));
			if ( !current_elem->next )
			{
				retval = 0;
				break;
			}
			current_elem = current_elem->next;
		}
		current_elem->next = NULL;
		if ( input[i+matches[1].rm_so] != '-' )
		{
			current_elem->text = malloc(5);
			if ( !current_elem->text )
			{
				retval = 0;
				break;
			}
			memcpy(current_elem->text, input+i+matches[1].rm_so, 4);
			current_elem->text[4] = 0;
		}
		else
		{
			current_elem->text = NULL;
		}
		part_count++;
		
		/* Prepare for next element. */
		i += 4;
		if ( i >= strlen(input) ) break;
	}
	if ( !retval || !part_count )
	{
		fapint_clear_llist(parts);
		return 0;
	}
	
	/* Prepare to return results. */
	packet->wx_report = malloc(sizeof(fap_wx_report_t));
	if ( !packet->wx_report )
	{
	        fapint_clear_llist(parts);
	        return 0;
        }
	fapint_init_wx_report(packet->wx_report);
	
	/* Check parts one at a time. */
	do
	{
		current_elem = parts;
		
		/* wind gust */
		if ( current_elem->text )
		{
			packet->wx_report->wind_gust = malloc(sizeof(double));
			if ( !packet->wx_report->wind_gust )
			{
				retval = 0;
				break;
			}
			*packet->wx_report->wind_gust = strtol(current_elem->text, NULL, 16) * KMH_TO_MS / 10.0;
		}
		current_elem = current_elem->next;
	
		/* wind direction */
		if ( current_elem )
		{
			if ( current_elem->text )
			{
				packet->wx_report->wind_dir = malloc(sizeof(unsigned int));
				if ( !packet->wx_report->wind_dir )
				{
					retval = 0;
					break;
				}
				*packet->wx_report->wind_dir = floor(strtol(current_elem->text, NULL, 16) * 1.41176 + 0.5);
			}
			current_elem = current_elem->next;
		}
		else
		{
			break;
		}
		
		/* temperature */
		if ( current_elem )
		{
			if ( current_elem->text )
			{
				packet->wx_report->temp = malloc(sizeof(double));
				if ( !packet->wx_report->temp )
				{
					retval = 0;
					break;
				}
				temp = strtol(current_elem->text, NULL, 16);
				*packet->wx_report->temp = FAHRENHEIT_TO_CELCIUS(temp/10.0);
			}
			current_elem = current_elem->next;
		}
		else
		{
			break;
		}
		
		/* rain since midnight */
		if ( current_elem )
		{
			if ( current_elem->text )
			{
				packet->wx_report->rain_midnight = malloc(sizeof(double));
				if ( !packet->wx_report->rain_midnight )
				{
					retval = 0;
					break;
				}
				*packet->wx_report->rain_midnight = strtol(current_elem->text, NULL, 16) * HINCH_TO_MM;
			}
			current_elem = current_elem->next;
		}
		else
		{
			break;
		}
		
		/* pressure */
		if ( current_elem )
		{
			if ( current_elem->text )
			{
				packet->wx_report->pressure = malloc(sizeof(double));
				if ( !packet->wx_report->pressure )
				{
					retval = 0;
					break;
				}
				*packet->wx_report->pressure = strtol(current_elem->text, NULL, 16) / 10.0;
			}
			current_elem = current_elem->next;
		}
		else
		{
			break;
		}
		
		/* barometer delta */
		if ( current_elem )
		{
			current_elem = current_elem->next;
		}
		else
		{
			break;
		}
		
		/* barometer corr. factor */
		if ( current_elem )
		{
			current_elem = current_elem->next;
		}
		else
		{
			break;
		}

		/* barometer corr. factor */
		if ( current_elem )
		{
			current_elem = current_elem->next;
		}
		else
		{
			break;
		}
		
		/* humidity */
		if ( current_elem )
		{
			if ( current_elem->text )
			{
				packet->wx_report->humidity = malloc(sizeof(unsigned int));
				if ( !packet->wx_report->humidity )
				{
					retval = 0;
					break;
				}
				*packet->wx_report->humidity = strtol(current_elem->text, NULL, 16)/10.0;
			}
			current_elem = current_elem->next;
		}
		else
		{
			break;
		}
		
		/* date */
		if ( current_elem )
		{
			current_elem = current_elem->next;
		}
		else
		{
			break;
		}
		
		/* time */
		if ( current_elem )
		{
			current_elem = current_elem->next;
		}
		else
		{
			break;
		}
		
		/* rain since midnight */
		if ( current_elem )
		{
			if ( current_elem->text )
			{
				*packet->wx_report->rain_midnight = strtol(current_elem->text, NULL, 16) * HINCH_TO_MM;
			}
			current_elem = current_elem->next;
		}
		else
		{
			break;
		}

		/* wind speed */
		if ( current_elem )
		{
			if ( current_elem->text )
			{
				packet->wx_report->wind_speed = malloc(sizeof(double));
				if ( !packet->wx_report->wind_speed )
				{
					retval = 0;
					break;
				}
				*packet->wx_report->wind_speed = strtol(current_elem->text, NULL, 16) * KMH_TO_MS / 10.0;
			}
			current_elem = current_elem->next;
		}
		else
		{
			break;
		}
		/* That's all folks. */
		break;
	} while ( 0 );
	fapint_clear_llist(parts);

	return retval;
}



int fapint_parse_dao(fap_packet_t* packet, char input[3])
{
	double lon_off = 0.0, lat_off = 0.0;

	/* Datum character is the first character and also defines how the rest is interpreted. */
	if ( 'A' <= input[0] && input[0] <= 'Z' && isdigit(input[1]) && isdigit(input[2]) )
	{
		/* Human readable. */
		packet->dao_datum_byte = input[0];
		if ( packet->pos_resolution == NULL )
		{
			packet->pos_resolution = malloc(sizeof(double));
			if ( !packet->pos_resolution ) return 0;
		}
		*packet->pos_resolution = fapint_get_pos_resolution(3);
		lat_off = (input[1]-48.0) * 0.001 / 60.0;
		lon_off = (input[2]-48.0) * 0.001 / 60.0;
	}
	else if ( 'a' <= input[0] && input[0] <= 'z' &&
	          0x21 <= input[1] && input[1] <= 0x7b &&
                  0x21 <= input[2] && input[2] <= 0x7b )
	{
		/* Base-91. */
		packet->dao_datum_byte = toupper(input[0]); /* Save in uppercase. */
		if ( packet->pos_resolution == NULL )
		{
			packet->pos_resolution = malloc(sizeof(double));
			if ( !packet->pos_resolution ) return 0;
		}
		*packet->pos_resolution = fapint_get_pos_resolution(4);
		/* Scale base-91. */
		lat_off = (input[1]-33.0)/91.0 * 0.01 / 60.0;
		lon_off = (input[2]-33.0)/91.0 * 0.01 / 60.0;
	}
	else if ( 0x21 <= input[0] && input[0] <= 0x7b &&
	          input[1] == ' ' && input[2] == ' ' )
	{
		/* Only datum information, no lat/lon digits. */
		if ( 'a' <= input[0] && input[0] <= 'z' )
		{
			packet->dao_datum_byte = toupper(input[0]);
		}
		else
		{
			packet->dao_datum_byte = input[0];
		}    
	}
	else
	{
		/* Invalid !DAO! */
		return 0;
	}
	
	/* Cautiously check N/S and E/W. */
	if ( packet->latitude )
	{
		if ( *packet->latitude < 0 )
		{
			*packet->latitude -= lat_off;
		}
		else
		{
			*packet->latitude += lat_off;
		}
	}
	if ( packet->longitude )
	{
		if ( *packet->longitude < 0 )
		{
			*packet->longitude -= lon_off;
		}
		else
		{
			*packet->longitude += lon_off;
		}      
	}
	
	return 1;
}



char* fapint_check_kiss_callsign(char* input)
{
	unsigned int matchcount = 3;
	regmatch_t matches[matchcount];
	
	int len;
	char* tmp_str;
	
	
	if ( !input ) return NULL;
	
	if ( regexec(&fapint_regex_kiss_callsign, input, matchcount, (regmatch_t*)&matches, 0) == 0 )
	{
		/* Check ssid if given. */
		len = matches[2].rm_eo - matches[2].rm_so;
		if ( len > 0 )
		{
			tmp_str = malloc(len+1);
			if ( !tmp_str ) return NULL;
			memcpy(tmp_str, input+matches[2].rm_so, len);
			tmp_str[len] = 0;
			if ( atoi(tmp_str) < -15 )
			{
				free(tmp_str);
				return NULL;
			}
			free(tmp_str);
		}
		
		/* Combine as result. */
		len += matches[1].rm_eo - matches[1].rm_so;
		tmp_str = malloc(len+1);
		if ( !tmp_str ) return NULL;
		memcpy(tmp_str, input+matches[1].rm_so, matches[1].rm_eo - matches[1].rm_so);
		memcpy(tmp_str+matches[1].rm_eo, input+matches[2].rm_so, matches[2].rm_eo - matches[2].rm_so);
		tmp_str[len] = 0;
		
		return tmp_str;
	}
	
	return NULL;
}



/* Implementation-specific helpers for fap.c. */



fap_packet_t* fapint_create_packet()
{
	fap_packet_t* result = malloc(sizeof(fap_packet_t));
	if ( !result ) return NULL;

	/* Prepare result object. */
	result->error_code = NULL;
	result->type = NULL;
	
	result->orig_packet = NULL;
	result->orig_packet_len = 0;

	result->header = NULL;
	result->body = NULL;  
	result->body_len = 0; 
	result->src_callsign = NULL;
	result->dst_callsign = NULL;
	result->path = NULL; 
	result->path_len = 0;
	
	result->latitude = NULL;    
	result->longitude = NULL;
	result->format = NULL;
	result->pos_resolution = NULL;
	result->pos_ambiguity = NULL;
	result->dao_datum_byte = 0;
	
	result->altitude = NULL;
	result->course = NULL;  
	result->speed = NULL;   

	result->symbol_table = 0;
	result->symbol_code = 0; 
	
	result->messaging = NULL;
	result->destination = NULL;
	result->message = NULL;
	result->message_ack = NULL;
	result->message_nack = NULL;
	result->message_id = NULL;
	result->comment = NULL;
	result->comment_len = 0;
	
	result->object_or_item_name = NULL;
	result->alive = NULL;

	result->gps_fix_status = NULL;
	result->radio_range = NULL;
	result->phg = NULL;
	result->timestamp = NULL;
	result->raw_timestamp = NULL;
	result->nmea_checksum_ok = NULL;
	
	result->wx_report = NULL;
	result->telemetry = NULL;

	result->messagebits = NULL;
	result->status = NULL;
	result->status_len = 0;
	result->capabilities = NULL;
	result->capabilities_len = 0;
	
	/* Return results. */
	return result;
}
