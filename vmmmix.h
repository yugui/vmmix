/*
 * vmmmix.h
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

#ifndef	_VMMMIX_H_
#define	_VMMMIX_H_

#include <setjmp.h>

#ifdef  __cplusplus
extern "C" {
#endif

#ifndef	INCLUDE_FROM_MMIX_SIM_C
/////
typedef unsigned int tetra;
typedef struct {
	tetra h, l;
} octa;
#endif

extern octa neg_one;

/////
extern jmp_buf	env_trap;

#define	PROT_READ	0x4
#define	PROT_WRITE	0x2
#define	PROT_EXEC	0x1

#ifndef	INCLUDE_FROM_MMIX_SIM_C
typedef enum {
	rB,rD,rE,rH,rJ,rM,rR,rBB,
	rC,rN,rO,rS,rI,rT,rTT,rK,rQ,rU,rV,rG,rL,
	rA,rF,rP,rW,rX,rY,rZ,rWW,rXX,rYY,rZZ
} special_reg;
#endif

extern void *physical_memory;
extern octa g[256];

extern octa phi(octa vaddr, int prot);
extern void init_tlb(void);
extern int flush_tlb(octa vaddr);
extern void page_fault();

__inline octa octafrom64(__int64 val)
{
	octa o;
	unsigned __int32 *m = (unsigned __int32 *)&val;

	o.l = m[0];
	o.h = m[1];
	return o;
}

__inline __int64 octato64(octa o)
{
	__int64 val;

	val = o.h;
	val <<= 32;
	val |= o.l;
	return val;
}

__inline void copyin(void *dst, const void *src, int len)
{
	int d = (int)dst;
	char *s = (char *)src;

	while (len--)
		*(char *)(d++ ^ 3) = *s++;
}

__inline void copyout(void *dst, const void *src, int len)
{
	char *d = (char *)dst;
	int s = (int)src;

	while (len--)
		*d++ = *(char *)(s++ ^ 3);
}

//// I/O
// console
__inline int is_cons_addr(int pa)
{
	return ((pa >= 0x00000000) && (pa < 0x00000010));
}
void init_cons();
extern int consQh;
void *cons_mem(int pa);
void cons_check(int pa);

// rtc
__inline int is_rtc_addr(int pa)
{
	return (pa >= 0x00000010) && (pa < 0x00000028);
}
void *rtc_mem(int pa);
void rtc_check(int pa);

// enet
__inline int is_enet_addr(int pa)
{
	return (pa >= 0x00010000) && (pa < 0x00020000);
}
void init_enet(char *enet_opt, char *if_opt);
extern int enetQl;
void *enet_mem(int pa);
void enet_check(int pa);

// hdd
__inline int is_hdd_addr(int pa)
{
	return (pa >= 0x00001000) && (pa < 0x00002000);
}
void init_hdd(char *hdd_image);
extern int hddQh;
void *hdd_mem(int va);
void hdd_check(int pa);

#ifdef  __cplusplus
}
#endif

#endif	// _VMMMIX_H_