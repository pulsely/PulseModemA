
/* Copyright 2015 Philip Heron <phil@sanslogic.co.uk>                    */
/*                                                                       */
/* This program is free software: you can redistribute it and/or modify  */
/* it under the terms of the GNU General Public License as published by  */
/* the Free Software Foundation, either version 3 of the License, or     */
/* (at your option) any later version.                                   */
/*                                                                       */
/* This program is distributed in the hope that it will be useful,       */
/* but WITHOUT ANY WARRANTY; without even the implied warranty of        */
/* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         */
/* GNU General Public License for more details.                          */
/*                                                                       */
/* You should have received a copy of the GNU General Public License     */
/* along with this program.  If not, see <http://www.gnu.org/licenses/>. */

#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <stdlib.h>
#include <stdarg.h>
#include <unistd.h>
#include <math.h>
#include "ax25.h"

/* Default configuration */
#define AX25_AFSK1200_SAMPLERATE     (48000)
#define AX25_AFSK1200_BITRATE        (1200)
#define AX25_AFSK1200_FREQ1          (1200)
#define AX25_AFSK1200_FREQ2          (2200)
#define AX25_AFSK1200_PREAMBLE_BYTES (25)
#define AX25_AFSK1200_REST_BYTES     (5)

#define AX25_AFSK2400_SAMPLERATE     (48000)
#define AX25_AFSK2400_BITRATE        (2400)
#define AX25_AFSK2400_FREQ1          (2400)
#define AX25_AFSK2400_FREQ2          (4400)
#define AX25_AFSK2400_PREAMBLE_BYTES (25)
#define AX25_AFSK2400_REST_BYTES     (5)

char *ax25_base91enc(char *s, uint8_t n, uint32_t v)
{
	/* Creates a Base-91 representation of the value in v in the string */
	/* pointed to by s, n-characters long. String length should be n+1. */
	
	for(s += n, *s = '\0'; n; n--)
	{
		*(--s) = v % 91 + 33;
		v /= 91;
	}
	
	return(s);
}

/* This function is taken from avr-libc */
static uint16_t _crc_ccitt_update(uint16_t crc, uint8_t data)
{
	data ^= crc & 0xFF;
	data ^= data << 4;
	
	return((((uint16_t) data << 8) | (crc >> 8)) ^ (uint8_t) (data >> 4) 
	       ^ ((uint16_t) data << 3));
}

static uint8_t *_ax25_callsign(uint8_t *s, char *callsign)
{
	char ssid;
	char i;
	for(i = 0; i < 6; i++)
	{
		if(*callsign && *callsign != '-') *(s++) = *(callsign++) << 1;
		else *(s++) = ' ' << 1;
	}
	
	if(*callsign == '-') ssid = atoi(callsign + 1);
	else ssid = 0;
	
	*(s++) = ('0' + ssid) << 1;
	return(s);
}

static size_t _ax25_txbit(ax25_t *ax25, int16_t **wav, uint8_t bit, uint8_t no_padding)
{
	size_t len = ax25->samplerate / ax25->bitrate;
	int i;
	
	/* A zero bit is encoded by a change in frequency */
	if(!bit) ax25->freq ^= ax25->freq1 ^ ax25->freq2;
	
	/* Generate the symbol */
	for(i = 0; i < len; i++)
	{
		*((*wav)++) = (0.75 * 32768.0 * sin(ax25->phase));
		ax25->phase += 2 * M_PI * ax25->freq / ax25->samplerate;
	}
	
	if(!no_padding)
	{
		/* If we have sent 5 one bits, stuff a zero bit in */
		if(bit) ax25->bc++; else ax25->bc = 0;
		if(ax25->bc == 5) len += _ax25_txbit(ax25, wav, 0, 0);
	}
	else ax25->bc = 0;
	
	return(len);
}

static size_t _ax25_txbyte(ax25_t *ax25, int16_t **wav, uint8_t byte, uint8_t no_padding)
{
	int i;
	size_t len = 0;
	
	for(i = 0; i < 8; i++)
	{
		len += _ax25_txbit(ax25, wav, byte & 1, no_padding);
		byte >>= 1;
	}
	
	return(len);
}

static size_t _ax25_tx(ax25_t *ax25, int16_t *wav, uint8_t *frame, size_t length)
{
	int i;
	size_t len = 0;

	for(i = 0; i < ax25->preamble; i++) len += _ax25_txbyte(ax25, &wav, 0x7E, 1);
	for(i = 0; i < length; i++)         len += _ax25_txbyte(ax25, &wav, frame[i], 0);
	for(i = 0; i < ax25->rest; i++)     len += _ax25_txbyte(ax25, &wav, 0x7E, 1);
    
	return(len);
}

ax25_t *ax25_init(ax25_t *ax25, ax25_mode_t mode)
{
	switch(mode)
	{
	case AX25_AFSK1200:
		ax25->samplerate = AX25_AFSK1200_SAMPLERATE;
		ax25->bitrate    = AX25_AFSK1200_BITRATE;
		ax25->freq1      = AX25_AFSK1200_FREQ1;
		ax25->freq2      = AX25_AFSK1200_FREQ2;
		ax25->preamble   = AX25_AFSK1200_PREAMBLE_BYTES;
		ax25->rest       = AX25_AFSK1200_REST_BYTES;
		break;
	case AX25_AFSK2400:
		ax25->samplerate = AX25_AFSK2400_SAMPLERATE;
		ax25->bitrate    = AX25_AFSK2400_BITRATE;
		ax25->freq1      = AX25_AFSK2400_FREQ1;
		ax25->freq2      = AX25_AFSK2400_FREQ2;
		ax25->preamble   = AX25_AFSK2400_PREAMBLE_BYTES;
		ax25->rest       = AX25_AFSK2400_REST_BYTES;
		break;
	}
	
	ax25->audio_callback = NULL;
	ax25->audio_callback_data = NULL;
	
	ax25->phase = 0;
	ax25->freq = ax25->freq1;
	ax25->bc = 0;
	
	return(ax25);
}

void ax25_set_audio_callback(ax25_t *ax25, void (*audio_callback)(void *, int16_t *, size_t, uint8_t *), void *audio_callback_data)
{
	ax25->audio_callback = audio_callback;
	ax25->audio_callback_data = audio_callback_data;
}

int ax25_frame(ax25_t *ax25, char *scallsign, char *dcallsign, char *path1, char *path2, char *data, ...)
{
	uint8_t frame[AX25_MAX_LEN + 1];
	int16_t *wav;
	size_t wav_len;
	uint8_t *s;
	uint16_t x;
	va_list va;
	
	va_start(va, data);
    
	/* Write in the callsigns and paths */
	s = _ax25_callsign(frame, dcallsign);
	s = _ax25_callsign(s, scallsign);
	if(path1) s = _ax25_callsign(s, path1);
	if(path2) s = _ax25_callsign(s, path2);

	/* Mark the end of the callsigns */
	s[-1] |= 1;
	
	*(s++) = 0x03; /* Control, 0x03 = APRS-UI frame */
	*(s++) = 0xF0; /* Protocol ID: 0xF0 = no layer 3 data */

	/* The maximum message length is AX25_MAX_LEN - callsigns - CRC */
    
	/* 1 is added to allow room for vsnprintf's \0 at the end */
	vsnprintf((char *) s, AX25_MAX_LEN - (s - frame) - 2 + 1, data, va);
	va_end(va);

	/* Calculate and append the checksum */
	for(x = 0xFFFF, s = frame; *s; s++)
		x = _crc_ccitt_update(x, *s);

	*(s++) = ~(x & 0xFF);
	*(s++) = ~((x >> 8) & 0xFF);
    
	/* Allocate memory for the audio data */
	wav_len  = (s - frame + ax25->preamble + ax25->rest) * 8; /* Number of bits */
	wav_len += wav_len / 5 + 1; /* Stuffing bits, worst case */
	wav_len *= ax25->samplerate / ax25->bitrate; /* Samples per bit */
    
    //wav_len += 1024;

	wav = calloc(wav_len, sizeof(int16_t));
    if(!wav) {
        return(AX25_OUT_OF_MEMORY);
    }
    
	/* Generate the tones */
	wav_len = _ax25_tx(ax25, wav, frame, s - frame);
    printf("APRS: %s", frame);
    
	/* Fire the callback to play/save the audio data */
	if(ax25->audio_callback) (*ax25->audio_callback)(ax25->audio_callback_data, wav, wav_len, frame);

	free(wav);
	
	return(AX25_OK);
}

