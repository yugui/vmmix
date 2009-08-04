/*
 * mmu.cpp
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
#include "vmmmix.h"

#define	PTP_VALID(ptp)	((ptp) & 0x8000000000000000)
#define	PTP_SPACE(ptp)	((ptp) & 0x0000000000001ff8)
#define	PTP_DATA(ptp)	((ptp) & 0x7fffffffffffe000)

#define	PTE_SPACE(pte)	((pte) & 0x0000000000001ff8)
#define	PTE_ADDR(pte)	((pte) & pte_addr_mask)

#define	PAGE_OFFSET(va)	((va) & page_offset_mask)

#define	SEG(va)	((va) >> 61)
#define	PAGE_NUM(va)	((va) & 0x1fffffffffffffff) >> s
#define	A0(va)	((va) & 0x3ff)
#define	A1(va)	(((va) >> 10) & 0x3ff)
#define	A2(va)	(((va) >> 20) & 0x3ff)
#define	A3(va)	(((va) >> 30) & 0x3ff)
#define	A4(va)	(((va) >> 40) & 0x3ff)

typedef	__int64	pa;
typedef	__int64	va;

__int64	rv;
int b[5];
int	s;
__int64 r;
__int64 n;
__int64 f;
__int64 pte_addr_mask;
__int64 page_offset_mask;

///TLB

struct tlb_entry {
	struct tlb_entry *next;
	struct tlb_entry *prev;
	__int64	vaddr;
	__int64 paddr;
	int		prot;
};

#define	NUM_TLB_ENTRIES	16

struct tlb_entry tlb_head;
struct tlb_entry tlb_entries[NUM_TLB_ENTRIES];

inline void list_enter(struct tlb_entry *head, struct tlb_entry *entry)
{
	head->next->prev = entry;
	entry->prev = head;

	entry->next = head->next;
	head->next = entry;
}

inline void list_remove(struct tlb_entry *entry)
{
	entry->next->prev = entry->prev;
	entry->prev->next = entry->next;
}

void init_tlb(void)
{
	int i;

	tlb_head.next = &tlb_head;
	tlb_head.prev = &tlb_head;

	for (i = 0; i < NUM_TLB_ENTRIES; i++) {
		struct tlb_entry *entry = tlb_entries + i;

		entry->vaddr = -1;
		list_enter(&tlb_head, entry);
	}
}

#if	1
__int64 lookup_tlb(__int64 vaddr, int prot)
{
	struct tlb_entry *entry;

	for (entry = tlb_head.next; entry != &tlb_head; entry = entry->next) {
		if (entry->vaddr == (vaddr & 0xffffffffffffe000)) {
			if (entry != tlb_head.next) {
				list_remove(entry);
				list_enter(&tlb_head, entry);
			}
			if (!(entry->prot & prot)) {
				longjmp(env_trap, 1);
			}
			return entry->paddr + (vaddr & 0x1fff);
		}
	}
	return -1;
}

void enter_tlb(__int64 vaddr, __int64 paddr, int prot)
{
	struct tlb_entry *entry = tlb_head.prev;

	list_remove(entry);
	entry->vaddr = vaddr & 0xffffffffffffe000;
	entry->paddr = paddr & 0xffffffffffffe000;
	entry->prot = prot;
	list_enter(&tlb_head, entry);
}

int flush_tlb(octa _vaddr)
{
	__int64 vaddr = octato64(_vaddr);
	struct tlb_entry *entry;

	if (vaddr == -1) {
		for (entry = tlb_head.next; entry != &tlb_head; entry = entry->next)
			entry->vaddr = -1;
		return 0;
	}

	for (entry = tlb_head.next; entry != &tlb_head; entry = entry->next) {
		if (entry->vaddr == (vaddr & 0xffffffffffffe000)) {
			list_remove(entry);
			entry->vaddr = -1;
			list_enter(tlb_head.prev, entry);
		}
	}
	return 0;
}
#else
struct tlb_entry tlb = { 0, 0, -1, -1, 0};

__int64 lookup_tlb(__int64 vaddr, int prot)
{
	if (tlb.vaddr == (vaddr & 0xffffffffffffe000)) {
		if (!(tlb.prot & prot)) {
			g[rYY] = vaddr;
			g[rQ] |= (unsigned __int64)prot << 32;
			longjmp(env_trap, 1);
		}
		return tlb.paddr + (vaddr & 0x1fff);
	}
	return -1;
}

void enter_tlb(__int64 vaddr, __int64 paddr, int prot)
{
	tlb.vaddr = vaddr & 0xffffffffffffe000;
	tlb.paddr = paddr & 0xffffffffffffe000;
	tlb.prot = prot;
}

int flush_tlb(__int64 vaddr)
{
	tlb.vaddr = -1;
	return 0;
}
#endif

/////
int pte_level(__int64 pfn)
{
	if (pfn & 0xcff0000000000)
		return 4;
	if (pfn & 0x000ffc0000000)
		return 3;
	if (pfn & 0x000003ff00000)
		return 2;
	if (pfn & 0x00000000ffc00)
		return 1;
	return 0;
}

pa get_ptp(pa loc, int pfn)
{
	__int64 entry;
	octa *table = (octa *)((int)physical_memory + loc);
	
	entry = octato64(table[pfn]);
	if (!PTP_VALID(entry))
		longjmp(env_trap, 1);
	if (PTP_SPACE(entry) != n)
		longjmp(env_trap, 1);
	return PTP_DATA(entry);
}

__int64 get_pte(pa loc, int pfn)
{
	octa *table = (octa *)((int)physical_memory + loc);
	
	return octato64(table[pfn]);
}

pa phisub(int seg, va vaddr, int prot)
{
	__int64 pfn;
	
	pfn = PAGE_NUM(vaddr);
	int level = pte_level(pfn);

	if (level >= (b[seg + 1] - b[seg]))
		page_fault();

	__int64 ptl = r + (b[seg] + level) * 0x2000;
	switch (level) {
	case 4:
		ptl = get_ptp(ptl, A4(pfn));
	case 3:
		ptl = get_ptp(ptl, A3(pfn));
	case 2:
		ptl = get_ptp(ptl, A2(pfn));
	case 1:
		ptl = get_ptp(ptl, A1(pfn));
	case 0:
		ptl = get_pte(ptl, A0(pfn));
		break;
	}
	if (PTE_SPACE(ptl) != n) {
		longjmp(env_trap, 1);
	}
	if (!(ptl & prot)) {
		longjmp(env_trap, 1);
	}
	enter_tlb(vaddr, PTE_ADDR(ptl), ptl & 7);
	return PTE_ADDR(ptl)|PAGE_OFFSET(vaddr);
}


octa phi(octa _vaddr, int prot)
{
	__int64 vaddr = octato64(_vaddr);

	if (vaddr < 0) {
		if (g[rK].h & 0x00000010) {
			g[rQ].h |= 0x00000010;
			page_fault();
		}
		return octafrom64(vaddr & 0x7fffffffffffffff);
	}

	__int64 paddr = lookup_tlb(vaddr, prot);
	if (paddr >= 0)
		return octafrom64(paddr);

	int seg = SEG(vaddr);

	if (rv != octato64(g[rV])) {
		rv = octato64(g[rV]);

		b[0] = 0;
		b[1] = (rv >> 60) & 0x0f;
		b[2] = (rv >> 56) & 0x0f;
		b[3] = (rv >> 52) & 0x0f;
		b[4] = (rv >> 48) & 0x0f;
		s = (rv >> 40) & 0xff;
		r = rv & 0x000000ffffffe000;
		n = rv & 0x0000000000001ff8;
		f = rv & 0x0000000000000007;
		
		pte_addr_mask = 0x0000ffffffffffff;
		pte_addr_mask >>= s;
		pte_addr_mask <<= s;

		page_offset_mask = ~((~0L) << s);

		flush_tlb(neg_one);
	}
	return octafrom64(phisub(seg, vaddr, prot));
}