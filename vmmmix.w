@ @d show_line()

@ Address translate Subroutines.

@<Proto...@>=
mem_tetra *mem_translate(octa addr, int prot);

@ @<Using Sub...@>=
#define	r_BIT	0x80
#define	w_BIT	0x40
#define	x_BIT	0x20

static octa last_io = { 0, 0 };

void check_io()
{
	int pa = last_io.l;

	last_io = zero_octa;

	if (is_rtc_addr(pa))	/* rtc */
		rtc_check(pa);
	else if (is_cons_addr(pa)) /* tty */
		cons_check(pa);
	else if (is_hdd_addr(pa))
		hdd_check(pa);
	else if (is_enet_addr(pa))
		enet_check(pa);
}

mem_tetra *mem_translate(octa addr, int prot)
{
	octa pa;
	addr.l &= ~0x3;

	fault_addr = addr;
	fault_prot = prot;
	
	pa = phi(addr, prot);

	if ((pa.h == 0) && (pa.l < MEMORY_SIZE)) {
		return (mem_tetra *)((int)physical_memory + pa.l);
	} else if (pa.h >= 0x00010000) {
		if (prot == PROT_WRITE)
			last_io = pa;
		if (is_rtc_addr(pa.l))	/* rtc */
			return (mem_tetra *)rtc_mem(pa.l);
		else if (is_cons_addr(pa.l)) /* tty */
			return (mem_tetra *)cons_mem(pa.l);
		else if (is_hdd_addr(pa.l))
			return (mem_tetra *)hdd_mem(pa.l);
		else if (is_enet_addr(pa.l))
			return (mem_tetra *)enet_mem(pa.l);
	}
	page_fault();
}

void page_fault()
{
	printf("PAGE FAULT\n");
	exit(1);
}

@ @<Glob...@>=
jmp_buf	env_trap;
int program;
octa fault_addr;
int fault_prot;

@ Physical Memory

@<Glob...@>=
#define	MEMORY_SIZE	0x20000000
void *physical_memory;

@ Extended register.

@<Glob...@>=
#define	N_EXTI_REGS	2
octa ext[N_EXTI_REGS];

@ @<Get extended register@>=
{
	if (g[rK].h & 0x00000010)
	  x = ext[0];
	else
	  x = ext[g[rN].l];
    goto store_x;
}

@ @<Put extended register@>=
{
  if (z.l & 1) {
    g[rN] = shift_right(z,1,0);
  } else if (g[rN].l && (g[rN].l < N_EXTI_REGS)) {
    ext[g[rN].l] = z;
  }
  break;
}

@ @<Local...@>=
	int resume_z;
	char *image_file = 0;
	char *kernel_opt = "";
	char *enet_opt = 0;
	char *if_opt = 0;
	char *hdd_opt = 0;

@ @<Parse and process command line@>=
	while (--argc) {
		char *ap = *++argv;
		if (ap[0] == '-') {
			char sw = ap[1];
			
			ap += 2;
			if (!*ap) {
				if (!argc)
					break;
				--argc;
				ap = *++argv;
			}
			switch (sw) {
			case 'e':
				enet_opt = ap;
				break;
			case 'i':
				if_opt = ap;
				break;
			case 'd':
				hdd_opt = ap;
				break;
			default:
				printf("unknown option %c\n", sw);
				break;
			}
		} else {
			if (!image_file)
				image_file = ap;
			else
				kernel_opt = ap;
		}
	}
	
	init_tlb();
	init_enet(enet_opt, if_opt);
	init_cons();
	init_hdd(hdd_opt);

@ @<Init and load image@>=
	physical_memory = malloc(MEMORY_SIZE);	/* 256MB */
	
	{
		FILE *image;
		octa addr;
		unsigned char buf[4];
		
		image = fopen(image_file, "rb");
		if (!image)
			exit(1);

		addr.h = 0x80000000;
		addr.l = 0x01000000;
		mmputchars(kernel_opt, strlen(kernel_opt)+1, addr);

		ll = (mem_tetra *)physical_memory;
		while (fread(buf, 1, 4, image) > 0) {
			(ll++)->tet= (((buf[0]<<8)+buf[1])<<16)+(buf[2]<<8)+buf[3];
		}
		fclose(image);
	}

	inst_ptr.h = 0x80000000;
	inst_ptr.l = 0x00000000;
	g[rG].l = G = 32;
	L = 0;
	ext[0].h= (VERSION<<24)+(SUBVERSION<<16)+(SUBSUBVERSION<<8);
	ext[0].l= ABSTIME;

	if (setjmp(env_trap)) {
		y = fault_addr;
		program = fault_prot << 5;
		goto check_hw_interrupts;
	}

@ @<Cases for ind...@>=
illegal_inst:
			printf("illegal instruction %02x\n", op);
			exit(1);
privileged_inst:
			printf("privilileged instruction %02x\n", op);
			exit(1);
		default:
			printf("Unknown Opcode %02x\n", op);
			exit(1);

@ @<Check for HW interrupts@>=
		g[rQ].h &= 0x000000ff;
		g[rQ].l &= 0x000000ff;
		g[rQ].h |= hddQh|consQh|program;
		g[rQ].l |= enetQl;
		if ((g[rQ].h & g[rK].h) || (g[rQ].l & g[rK].l)) {
			g[rK].h = 0;
			g[rK].l = 0;
			if (resuming) {
				if (resume_z == 0) {
					g[rWW] = g[rW];
					g[rXX] = g[rX];
					g[rYY] = g[rY];
					g[rZZ] = g[rZ];
				}
				resuming = false;
			} else {
				if (program & (r_BIT|w_BIT))
					g[rXX].h = program;
				else
					g[rXX].h = sign_bit|program;
				g[rXX].l = inst;
				g[rYY] = y;
				g[rWW] = inst_ptr;
			}
			g[rBB] = g[255];
			g[255] = g[rJ];
			inst_ptr = g[rTT];
		}
		program = 0;

@ @<Using Sub...@>=
#define	N_IP_TRACE	500

struct {
	octa ip;
	tetra inst;
} iptrace_buf[N_IP_TRACE];
int iptrace_index = 0;

void iptrace(octa ip, tetra inst)
{
	iptrace_buf[iptrace_index].ip = ip;
	iptrace_buf[iptrace_index++].inst = inst;
	if (iptrace_index == N_IP_TRACE)
		iptrace_index = 0;
}

@ @<Save user stack to kernel area@>=
  if ((inst_ptr.h & 0x80000000) && !(g[rS].h & 0x80000000)) {
//	printf("kernel saving user stack\n");
    int i;
    octa va = ext[1];
    mem_tetra *ll;

    /* save local registers */
    for (i = S; ((i - O - L)&lring_mask) != 0; i++) {
      ll = mem_translate(va, PROT_WRITE);
	  ll->tet = l[i&lring_mask].h;
	  (ll+1)->tet = l[i&lring_mask].l;
	  va = incr(va, 8);
    }
    
    va = incr(ext[1], 8 * 256);

    /* save special registers */
#define	SAVE_G(rg) \
    ll = mem_translate(incr(va, rg * 8), PROT_WRITE);\
    ll->tet = g[rg].h;(ll+1)->tet = g[rg].l

    SAVE_G(rB);	SAVE_G(rD);	SAVE_G(rE);	SAVE_G(rH);
    SAVE_G(rJ);	SAVE_G(rM);	SAVE_G(rR);	SAVE_G(rP);
    SAVE_G(rW);	SAVE_G(rX);	SAVE_G(rY);	SAVE_G(rZ);
    SAVE_G(rA);

    g[rL].l = L; SAVE_G(rL);
    g[rG].l = G; SAVE_G(rG);

    SAVE_G(rS); SAVE_G(rO);

    /* save global registers */
    va = incr(va, G * 8);
    for (i = G; i < 256; i++) {
	  ll = mem_translate(va, PROT_WRITE);
	  ll->tet = g[i].h;
	  (ll+1)->tet = g[i].l;
	  va = incr(va, 8);
    }

    x = g[rS];
    goto store_x;
  }

@ @<Restore user stack from kernel area@>=
	if ((inst_ptr.h & 0x80000000) && !(z.h & 0x80000000)) {
		octa va = ext[1];
		mem_tetra *ll;

		ll = mem_translate(incr(va, (256 + rS) * 8), PROT_READ);

		if ((z.h == ll->tet) && (z.l == (ll+1)->tet)) {
//						printf("kernel unsaving user stack\n");
			int i;

			va = incr(ext[1], 8 * 256);

			/* load special registers */
#define	LOAD_G(rg)	\
	ll = mem_translate(incr(va, rg * 8), PROT_READ);\
	g[rg].h = ll->tet;g[rg].l = (ll+1)->tet

			LOAD_G(rB); LOAD_G(rD); LOAD_G(rE); LOAD_G(rH);
			LOAD_G(rJ); LOAD_G(rM); LOAD_G(rR); LOAD_G(rP);
			LOAD_G(rW); LOAD_G(rX); LOAD_G(rY); LOAD_G(rZ);
			LOAD_G(rA);

			LOAD_G(rL); L=g[rL].l;
			LOAD_G(rG); G=g[rG].l;

			g[rS] = z;  S=g[rS].l>>3;
			LOAD_G(rO); O=g[rO].l>>3;

			/* load global registers */
			va = incr(va, G * 8);
			for (i = G; i < 256; i++) {
				ll = mem_translate(va, PROT_READ);
				g[i].h = ll->tet;
				g[i].l = (ll+1)->tet;
				va = incr(va, 8);
			}
			
			/* load local registers */
			va = ext[1];
			for (i = S; ((i - O - L)&lring_mask) != 0; i++) {
				ll = mem_translate(va, PROT_READ);
				l[i&lring_mask].h = ll->tet;
				l[i&lring_mask].l = (ll+1)->tet;
				va = incr(va, 8);
			}
			
			break;
		}
	}

@ @<Probe stack for SAVE@>=
{
  octa top;
  octa sp;
  
  top = incr(g[rO], (L - 1 + 1 + (256 - G) + 13) * 8);
  
  for (sp = g[rS];
       (sp.h < top.l) || ((sp.h == top.h) && (sp.l <= top.l));
       sp = incr(sp, 8192), sp.l &= ~8191)
    mem_translate(sp, PROT_WRITE);
}

@ @<Probe stack for UNSAVE@>=
{
  octa sp;
  mem_tetra *ll;
  int size;

  ll = mem_translate(z, PROT_READ);
  size = (13 + 256 - (ll->tet >> 24)) * 8;
  sp = incr(z, -size);
  ll = mem_translate(sp, PROT_READ);
  sp = incr(sp, -((ll+1)->tet & 0xff) * 8);
  mem_translate(sp, PROT_READ);
}