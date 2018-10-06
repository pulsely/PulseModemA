
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

#ifndef _AX25_H
#define _AX25_H
#ifdef __cplusplus
extern "C" {
#endif

#define AX25_OK            (0)
#define AX25_OUT_OF_MEMORY (1)

/* AX.25 does not define a maximum packet size */
/* I set one here to keep things sensible */
#define AX25_MAX_LEN (4096) // (512)

typedef enum {
	AX25_AFSK1200 = 0,
	AX25_AFSK2400,
} ax25_mode_t;

typedef struct {
	
	/* Configuration */
	uint16_t samplerate;
	ax25_mode_t mode;
	uint16_t bitrate;
	uint16_t freq1;
	uint16_t freq2;
	uint8_t preamble;
	uint8_t rest;
	
	/* Audio callback */
	void (*audio_callback)(void *, int16_t *, size_t, uint8_t *);
	void *audio_callback_data;
	
	/* State */
	double phase;
	uint16_t freq;
	uint8_t bc;
	
} ax25_t;

extern char *ax25_base91enc(char *s, uint8_t n, uint32_t v);
extern ax25_t *ax25_init(ax25_t *ax25, ax25_mode_t mode);
extern void ax25_set_audio_callback(ax25_t *ax25, void (*audio_callback)(void *, int16_t *, size_t, uint8_t *), void *audio_callback_data);
extern int ax25_frame(ax25_t *ax25, char *scallsign, char *dcallsign, char *path1, char *path2, char *data, ...);

#ifdef __cplusplus
}
#endif
#endif

