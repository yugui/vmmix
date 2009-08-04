/*
 * cons.cpp
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
#include <stdio.h>
#include "vmmmix.h"

int consQh;

struct _cons {
	unsigned int output;
	unsigned int input;
} cons;

static unsigned int prev_input;

static HANDLE hInputFull;

static DWORD WINAPI receiver(LPVOID param)
{
	INPUT_RECORD buf;
	DWORD dwNumEvents;

	for (;;) {
		do {
			ReadConsoleInput(GetStdHandle(STD_INPUT_HANDLE), &buf, 1, &dwNumEvents);
		} while ((buf.EventType != KEY_EVENT) || !buf.Event.KeyEvent.bKeyDown);

		if (buf.Event.KeyEvent.uChar.AsciiChar == 0x0d)
			buf.Event.KeyEvent.uChar.AsciiChar = 0x0a;

		WaitForSingleObject(hInputFull, INFINITE);
		cons.input = 0x0100 | buf.Event.KeyEvent.uChar.AsciiChar;
		consQh = 0x00000100;
	}
	return 0;
}

void init_cons()
{
	hInputFull = CreateSemaphore(NULL, 1, 1, NULL);
	CloseHandle(CreateThread(NULL, 0, receiver, 0, 0, NULL));
}

void *cons_mem(int va)
{
	prev_input = cons.input;

	va &= 0x0f;

	return (char *)&cons + va;
}

void cons_check(int pa)
{
	if (cons.output & 0x0100) {
		printf("%c", cons.output & 0xff);
		cons.output &= ~0x0100;
	}
	if (!(cons.input & 0x0100) && (prev_input & 0x0100)) {
		consQh = 0x00000000;
		ReleaseSemaphore(hInputFull, 1, NULL);
	}
}