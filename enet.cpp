/*
 * enet.cpp
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

#include <stdio.h>
#include <pcap.h>
#include "vmmmix.h"

int enetQl;

struct _dev {
	octa status;
	octa command;
	unsigned char mac_addr[6];
	unsigned char pad[2];
	octa rx_buf[16];
	octa tx_buf[16];
} enet;

static int cur_tx, cur_rx;

pcap_t *adhandle = NULL;
HANDLE	hThread;

void packet_handler(u_char *param, const struct pcap_pkthdr *header, const u_char *pkt_data)
{
//	printf("packet received\n");

	octa desc = enet.rx_buf[cur_rx];
	if (desc.h & 0x80000000) {
//		memcpy((unsigned char *)physical_memory + (desc & 0x0000ffffffffffff), pkt_data, header->len);
		copyin((unsigned char *)physical_memory + desc.l, pkt_data, header->len);
		desc.h |= (header->len) << 16;
		desc.h &= ~0x80000000;
		enet.rx_buf[cur_rx] = desc;

		cur_rx++;
		if (cur_rx == 16)
			cur_rx = 0;

		enetQl = 0x00000100;
	}
}

static DWORD WINAPI receiver(LPVOID param)
{
	pcap_loop(adhandle, 0, packet_handler, NULL);
	return 0;
}

void init_enet(char *enet_opt, char *if_opt)
{
	int	addr[6];
	int i;
	int if_no;
	char errbuf[PCAP_ERRBUF_SIZE];
	pcap_if_t *alldevs, *d;

	if (!enet_opt)
		return;
	
	if (!if_opt) {
		fprintf(stderr, "Please specify Interface Number using -i option.\n");
	} else {
		if_no = atoi(if_opt);
	}

	if (pcap_findalldevs(&alldevs, errbuf) == -1) {
		fprintf(stderr, "pcap_findalldevs_ex() failed. Ethernet device is disabled\n");
		return;
	}
	i = 0;
	for (d = alldevs; d; d = d->next) {
		i++;
		if (!if_opt) {
			printf("%d. %s\n", i, d->name);
		} else if (i == if_no) {
			adhandle = pcap_open_live(d->name, 65535, 1, 10, errbuf);
		}
	}
	pcap_freealldevs(alldevs);

	if (!if_opt && !adhandle) {
		fprintf(stderr, "Specified Interface not found.\n");
		return;
	}

	char filter[128];
	struct bpf_program fcode;

	sprintf(filter, "ether dst %s or FF:FF:FF:FF:FF:FF", enet_opt);
	if (pcap_compile(adhandle, &fcode, filter, 1, 0) < 0) {
		fprintf(stderr, "pcap_compile() failed. Ethernet device is disabled\n");
		pcap_close(adhandle);
		return;
	}
	if (pcap_setfilter(adhandle, &fcode) < 0) {
		fprintf(stderr, "pcap_setfilter() failed. Ethernet device is disabled\n");
		pcap_freecode(&fcode);
		pcap_close(adhandle);
		return;
	}
//	pcap_freecode(&fcode);

	enet.status.l = 0x1;
	sscanf(enet_opt, "%02x:%02x:%02x:%02x:%02x:%02x",
		&addr[0], &addr[1], &addr[2], 
		&addr[3], &addr[4], &addr[5]);
	for (i = 0; i < 6; i++)
		enet.mac_addr[i^3] = (unsigned char)addr[i];
}

void *enet_mem(int pa)
{
	pa &= 0xffff;

	return (char *)&enet + pa;
}

void enet_check(int pa)
{
	if (enet.command.l & 1) {
		cur_tx = 0;
		cur_rx = 0;
		enet.command.l &= ~1;
		DWORD threadId;

		if (!hThread)
			hThread = CreateThread(NULL, 0, receiver, adhandle, 0, &threadId);
	}

	octa desc = enet.tx_buf[cur_tx];

	enetQl = 0x00000000;
#if	1
	if (hThread) {
		int prev_rx = cur_rx -1;
		if (prev_rx < 0)
			prev_rx = 15;
		if (!(enet.rx_buf[prev_rx].h & 0x80000000)) {

			enetQl |= 0x00000100;
		}
	}
#endif
	if (desc.h & 0x80000000) {
		u_char *buf = (u_char *)physical_memory + desc.l;
		int	size = (desc.h >> 16) & 0x7fff;
		void *swapbuf = malloc(size + 3);

		copyout(swapbuf, buf, size);

		pcap_sendpacket(adhandle, (u_char *)swapbuf, size);
		free(swapbuf);
		enet.tx_buf[cur_tx].h &= ~0x80000000;
		cur_tx++;
		if (cur_tx == 16)
			cur_tx = 0;
		enetQl |= 0x00000100;
	}
}