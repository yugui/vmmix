/*
 * rtc.cpp
 *
 *   Copyright (C) 2008-2009 Eiji Yoshiya (eiji-y@pb3.so-net.ne.jp)
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA
 */

#include <windows.h>
#include <vmmmix.h>

static struct {
	octa	dummy;
	octa	sec;	/* seconds */
	octa	usec;	/* microseconds */
} rtc_dev;

void *rtc_mem(int pa)
{
	pa &= 0x3f;
	pa -= 0x10;
	return (char *)&rtc_dev + pa;
}

void rtc_check(int pa)
{
	if (rtc_dev.dummy.l & 1) {
		rtc_dev.dummy.l &= ~1;

		FILETIME now;
		LARGE_INTEGER li;

		GetSystemTimeAsFileTime(&now);
		li.LowPart = now.dwLowDateTime;
		li.HighPart = now.dwHighDateTime;
		li.QuadPart /= 10;
		li.QuadPart -= ((1970 - 1601) * 365LL + 89) * 24 * 60 * 60 * 1000000;
		rtc_dev.sec = octafrom64(li.QuadPart / 1000000);
		rtc_dev.usec = octafrom64(li.QuadPart % 1000000);
	}
}