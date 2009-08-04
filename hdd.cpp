/*
 * hdd.cpp
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

int hddQh;

struct {
	unsigned int status;
	unsigned int command;
	octa capacity;
	octa blk_addr;
	octa blk_count;
	struct {
		octa addr;
		octa count;
	} dma[16];
} hdd;

static HANDLE hDiskImage;
static HANDLE hCommand;

static void IORoutine(void)
{
	LARGE_INTEGER fileOffset;

	fileOffset.HighPart = hdd.blk_addr.h;
	fileOffset.LowPart = hdd.blk_addr.l;
	fileOffset.QuadPart *= 512;

	SetFilePointer(hDiskImage, fileOffset.LowPart, &fileOffset.HighPart, FILE_BEGIN);

	DWORD total = hdd.blk_count.l * 512;
	int	i;

	for (i = 0; total > 0; i++) {
		DWORD count = hdd.dma[i].count.l;
		char *mem = (char *)physical_memory + hdd.dma[i].addr.l;

		while (count) {
			DWORD numIO;
			char buf[512];
			int io_count;

			if (count > 512)
				io_count = 512;
			else
				io_count = count;

			if (hdd.command == 1) {
				ReadFile(hDiskImage, buf, io_count, &numIO, NULL);
				copyin(mem, buf, io_count);
			} else {
				copyout(buf, mem, io_count);
				WriteFile(hDiskImage, buf, io_count, &numIO, NULL);
			}
			mem += io_count;
			count -= io_count;
		}

		total -= hdd.dma[i].count.l;
	}
}

static DWORD WINAPI IoThread(LPVOID param)
{
	for (;;) {
		WaitForSingleObject(hCommand, INFINITE);
		IORoutine();

		hdd.command = 0;
		hdd.status = 1;
		hddQh = 0x00000200;
	}
	return 0;
}

void init_hdd(char *hdd_image)
{
	hDiskImage = CreateFileA(
					hdd_image,
					GENERIC_READ|GENERIC_WRITE,
					0,
					NULL,
					OPEN_EXISTING,
					FILE_ATTRIBUTE_NORMAL,
					NULL);
	if (hDiskImage == INVALID_HANDLE_VALUE)
		return;

	LARGE_INTEGER	fileSize;
	if (!GetFileSizeEx(hDiskImage, &fileSize)) {
		CloseHandle(hDiskImage);
		return;
	}
	fileSize.QuadPart /= 512;
	hdd.capacity.h = fileSize.HighPart;
	hdd.capacity.l = fileSize.LowPart;

	hCommand = CreateSemaphore(NULL, 0, 1, NULL);
	CloseHandle(CreateThread(NULL, 0, IoThread, 0, 0, NULL));
}

static int prev_command;

void *hdd_mem(int pa)
{
	prev_command = hdd.command;

	pa &= 0xff;

	return (char *)&hdd + pa;
}
void hdd_check(int pa)
{
	if (!(hdd.status & 1))
		hddQh = 0;

	if (!prev_command && hdd.command)
		ReleaseSemaphore(hCommand, 1, NULL);
}