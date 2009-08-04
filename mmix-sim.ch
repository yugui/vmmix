line 592
@x
the remainder in~|aux|.

@<Sub...@>=
@y
the remainder in~|aux|.

@<Using Sub...@>=
@z

line 721
@x
typedef struct {
  tetra tet; /* the tetrabyte of simulated memory */
  tetra freq; /* the number of times it was obeyed as an instruction */
  unsigned char bkpt; /* breakpoint information for this tetrabyte */
  unsigned char file_no; /* source file number, if known */
  unsigned short line_no; /* source line number, if known */
} mem_tetra;
@y
typedef struct {
  tetra tet; /* the tetrabyte of simulated memory */
} mem_tetra;
@z

line 1359
@x
  if (resuming) loc=incr(inst_ptr,-4), inst=g[rX].l;
  else @<Fetch the next instruction@>;
@y
  if (resuming) loc=incr(inst_ptr,-4), inst=g[rX+resume_z].l;
  else @<Fetch the next instruction@>;
  iptrace(loc, inst);
@z

line 1369
@x
  w=oplus(y,z);
  if (loc.h>=0x20000000) goto privileged_inst;
  switch(op) {
@y
  w=oplus(y,z);
  switch(op) {
@z

line 1375
@x
  @<Trace the current instruction, if requested@>;
  if (resuming && op!=RESUME) resuming=false;
@y
check_hw_interrupts:
  if (resuming && op!=RESUME) resuming=false;
  @<Check for HW interrupts@>;
@z

line 1394
@x
bool halted; /* did the program come to a halt? */
bool breakpoint; /* should we pause after the current instruction? */
bool tracing; /* should we trace the current instruction? */
bool stack_tracing; /* should we trace details of the register stack? */
bool interacting; /* are we in interactive mode? */
bool interact_after_break; /* should we go into interactive mode? */
@y
@z

line 1410
@x
register char *p; /* current place in a string */
@y
@z

line 1412
@x
@ @<Fetch the next instruction@>=
{
  loc=inst_ptr;
  ll=mem_find(loc);
  inst=ll->tet;
  cur_file=ll->file_no;
  cur_line=ll->line_no;
  ll->freq++;
  if (ll->bkpt&exec_bit) breakpoint=true;
  tracing=breakpoint||(ll->bkpt&trace_bit)||(ll->freq<=trace_threshold);
  inst_ptr=incr(inst_ptr,4);
}
@y
@ @<Fetch the next instruction@>=
{
  loc=inst_ptr;
  ll=mem_translate(loc, PROT_EXEC);
  inst=ll->tet;
  inst_ptr=incr(inst_ptr,4);
}
@z

line 1782
@x
octa *l; /* local registers */
int lring_size; /* the number of local registers (a power of 2) */
int lring_mask; /* one less than |lring_size| */
@y
octa l[256]; /* local registers */
#define	lring_size	256
#define	lring_mask	(lring_size-1)
@z

line 1842
@x
  sprintf(lhs,"$%d=g[%d]",xx,xx);
@y
@z

line 1846
@x
  sprintf(lhs,"$%d=l[%d]",xx,(O+xx)&lring_mask);
@y
@z

line 1861
@x
@d test_store_bkpt(ll) if ((ll)->bkpt&write_bit) breakpoint=tracing=true

@<Sub...@>=
void stack_store @,@,@[ARGS((void))@];@+@t}\6{@>
void stack_store()
{
  register mem_tetra *ll=mem_find(g[rS]);
  register int k=S&lring_mask;
  ll->tet=l[k].h;@+test_store_bkpt(ll);
  (ll+1)->tet=l[k].l;@+test_store_bkpt(ll+1);
  if (stack_tracing) {
    tracing=true;
    if (cur_line) show_line();
    printf("             M8[#%08x%08x]=l[%d]=#%08x%08x, rS+=8\n",
              g[rS].h,g[rS].l,k,l[k].h,l[k].l);
  }
  g[rS]=incr(g[rS],8),  S++;
}
@y
@d test_store_bkpt(ll)

@<Using Sub...@>=
void stack_store @,@,@[ARGS((void))@];@+@t}\6{@>
void stack_store()
{
  register mem_tetra *ll=mem_translate(g[rS], PROT_WRITE);
  register int k=S&lring_mask;
  ll->tet=l[k].h;@+test_store_bkpt(ll);
  (ll+1)->tet=l[k].l;@+test_store_bkpt(ll+1);
  g[rS]=incr(g[rS],8),  S++;
}
@z

line 1882
@x
@d test_load_bkpt(ll) if ((ll)->bkpt&read_bit) breakpoint=tracing=true

@<Sub...@>=
void stack_load @,@,@[ARGS((void))@];@+@t}\6{@>
void stack_load()
{
  register mem_tetra *ll;
  register int k;
  S--, g[rS]=incr(g[rS],-8);
  ll=mem_find(g[rS]);
  k=S&lring_mask;
  l[k].h=ll->tet;@+test_load_bkpt(ll);
  l[k].l=(ll+1)->tet;@+test_load_bkpt(ll+1);
  if (stack_tracing) {
    tracing=true;
    if (cur_line) show_line();
    printf("             rS-=8, l[%d]=M8[#%08x%08x]=#%08x%08x\n",
              k,g[rS].h,g[rS].l,l[k].h,l[k].l);
  }
}
@y
@d test_load_bkpt(ll)

@<Using Sub...@>=
void stack_load @,@,@[ARGS((void))@];@+@t}\6{@>
void stack_load()
{
  register mem_tetra *ll;
  register int k;
  S--, g[rS]=incr(g[rS],-8);
  ll=mem_translate(g[rS], PROT_READ);
  k=S&lring_mask;
  l[k].h=ll->tet;@+test_load_bkpt(ll);
  l[k].l=(ll+1)->tet;@+test_load_bkpt(ll+1);
}
@z

line 2064
@x
octabyte satisfies the condition of a given opcode.

@<Sub...@>=
int register_truth @,@,@[ARGS((octa,mmix_opcode))@];@+@t}\6{@>
@y
octabyte satisfies the condition of a given opcode.

@<Using Sub...@>=
int register_truth @,@,@[ARGS((octa,mmix_opcode))@];@+@t}\6{@>
@z

line 2128
@x
fin_ld: ll=mem_find(w);@+test_load_bkpt(ll);
 x.h=ll->tet;
 x=shift_right(shift_left(x,j),i,op&0x2);
check_ld:@+if (w.h&sign_bit) goto privileged_inst;
@y
fin_ld: ll=mem_translate(w,PROT_READ);@+test_load_bkpt(ll);
 x.h=ll->tet;
 x=shift_right(shift_left(x,j),i,op&0x2);
check_ld:
@z

line 2133
@x
case LDO: case LDOI: case LDOU: case LDOUI: case LDUNC: case LDUNCI:
 w.l&=-8;@+ ll=mem_find(w);
@y
case LDO: case LDOI: case LDOU: case LDOUI: case LDUNC: case LDUNCI:
 w.l&=-8;@+ ll=mem_translate(w, PROT_READ);
@z

line 2138
@x
case LDSF: case LDSFI: ll=mem_find(w);@+test_load_bkpt(ll);
@y
case LDSF: case LDSFI: ll=mem_translate(w, PROT_READ);@+test_load_bkpt(ll);
@z

line 2148
@x
fin_pst: ll=mem_find(w);
 if ((op&0x2)==0) {
   a=shift_right(shift_left(b,i),i,0);
   if (a.h!=b.h || a.l!=b.l) exc|=V_BIT;
 }
 ll->tet^=(ll->tet^(b.l<<(i-32-j))) & ((((tetra)-1)<<(i-32))>>j);
 goto fin_st;
case STSF: case STSFI: ll=mem_find(w);
 ll->tet=store_sf(b);@+exc=exceptions;
 goto fin_st;
case STHT: case STHTI: ll=mem_find(w);@+ ll->tet=b.h;
fin_st: test_store_bkpt(ll);
 w.l&=-8;@+ll=mem_find(w);
 a.h=ll->tet;@+ a.l=(ll+1)->tet; /* for trace output */
 goto check_st; 
case STCO: case STCOI: b.l=xx;
case STO: case STOI: case STOU: case STOUI: case STUNC: case STUNCI:
 w.l&=-8;@+ll=mem_find(w);
 test_store_bkpt(ll);@+ test_store_bkpt(ll+1);
 ll->tet=b.h;@+ (ll+1)->tet=b.l;
check_st:@+if (w.h&sign_bit) goto privileged_inst;
@y
fin_pst: ll=mem_translate(w,PROT_WRITE);
 if ((op&0x2)==0) {
   a=shift_right(shift_left(b,i),i,0);
   if (a.h!=b.h || a.l!=b.l) exc|=V_BIT;
 }
 ll->tet^=(ll->tet^(b.l<<(i-32-j))) & ((((tetra)-1)<<(i-32))>>j);
 goto fin_st;
case STSF: case STSFI: ll=mem_translate(w,PROT_WRITE);
 ll->tet=store_sf(b);@+exc=exceptions;
 goto fin_st;
case STHT: case STHTI: ll=mem_translate(w,PROT_WRITE);@+ ll->tet=b.h;
fin_st: test_store_bkpt(ll);
 goto check_st; 
case STCO: case STCOI: b.l=xx;
case STO: case STOI: case STOU: case STOUI: case STUNC: case STUNCI:
 w.l&=-8;@+ll=mem_translate(w,PROT_WRITE);
 test_store_bkpt(ll);@+ test_store_bkpt(ll+1);
 ll->tet=b.h;@+ (ll+1)->tet=b.l;
check_st:if(last_io.h) check_io();
@z

line 2175
@x
case CSWAP: case CSWAPI: w.l&=-8;@+ll=mem_find(w);
 test_load_bkpt(ll);@+test_load_bkpt(ll+1);
 a=g[rP];
 if (ll->tet==a.h && (ll+1)->tet==a.l) {
   x.h=0, x.l=1;
   test_store_bkpt(ll);@+test_store_bkpt(ll+1);
   ll->tet=b.h, (ll+1)->tet=b.l;
   strcpy(rhs,"M8[%#w]=%#b");
 }@+else {
   b.h=ll->tet, b.l=(ll+1)->tet;
   g[rP]=b;
   strcpy(rhs,"rP=%#b");
 }
 goto check_ld;
@y
case CSWAP: case CSWAPI: w.l&=-8;@+ll=mem_translate(w, PROT_READ);
 test_load_bkpt(ll);@+test_load_bkpt(ll+1);
 a=g[rP];
 if (ll->tet==a.h && (ll+1)->tet==a.l) {
   x.h=0, x.l=1;
   test_store_bkpt(ll);@+test_store_bkpt(ll+1);
   ll=mem_translate(w, PROT_WRITE);
   ll->tet=b.h, (ll+1)->tet=b.l;
 }@+else {
   b.h=ll->tet, b.l=(ll+1)->tet;
   g[rP]=b;
 }
 goto check_ld;
@z

line 2194
@x
case GET:@+if (yy!=0 || zz>=32) goto illegal_inst;
  x=g[zz];
  goto store_x;
case PUT: case PUTI:@+ if (yy!=0 || xx>=32) goto illegal_inst;
  strcpy(rhs,"%z = %#z");
  if (xx>=8) {
    if (xx<=11) goto illegal_inst; /* can't change rC, rN, rO, rS */
    if (xx<=18) goto privileged_inst;
    if (xx==rA) @<Get ready to update rA@>@;
    else if (xx==rL) @<Set $L=z=\min(z,L)$@>@;
    else if (xx==rG) @<Get ready to update rG@>;
  }
  g[xx]=z;@+zz=xx;@+break;
@y
case GET:@+if (yy!=0 || zz>=32) goto illegal_inst;
  if (zz == rN) @<Get extended register@>@;
  x=g[zz];
  goto store_x;
case PUT: case PUTI:@+ if (yy!=0 || xx>=32) goto illegal_inst;
  if (xx>=8) {
    if ((xx==rN) && (!(g[rK].h & 0x00000010))) @<Put extended register@>@;
    if (xx<=11) goto illegal_inst; /* can't change rC, rN, rO, rS */
    if (xx<=18) {
      if (g[rK].h & 0x00000010) goto privileged_inst;
    }
    if (xx==rA) @<Get ready to update rA@>@;
    else if (xx==rL) @<Set $L=z=\min(z,L)$@>@;
    else if (xx==rG) @<Get ready to update rG@>@;
	else if (xx==rV) {
	  flush_tlb(neg_one);
	}
	else if (xx==rQ) {
	  g[rQ].h &= 0xffffff00;
	  z.h     &= 0x000000ff;
	  g[rQ].h |= z.h;
	  break;
	}
	else if (xx==rI) {
	  g[rQ].l &= ~0x00000080;
	}
  }
  g[xx]=z;@+zz=xx;@+break;
@z

line 2210
@x
  x=z;@+ strcpy(rhs,z.h? "min(rL,%#x) = %z": "min(rL,%x) = %z");
@y
  x=z;
@z

line 2240
@x
   xx=L++;
   if (((S-O-L)&lring_mask)==0) stack_store();
@y
   if (((S-O-L-1)&lring_mask)==0) stack_store();
   xx=L++;
@z

line 2244
@x
 sprintf(lhs,"l[%d]=%d, ",(O+xx)&lring_mask,xx);
@y
@z

line 2257
@x
   if (y.h) sprintf(lhs,"l[%d]=#%x%08x, ",(O-1)&lring_mask,y.h,y.l);
   else sprintf(lhs,"l[%d]=#%x, ",(O-1)&lring_mask,y.l);
 }@+else lhs[0]='\0';
@y
 }
@z

line 2268
@x
case SAVE:@+if (xx<G || yy!=0 || zz!=0) goto illegal_inst;
 l[(O+L)&lring_mask].l=L, L++;
@y
case SAVE:@+if (xx<G || yy!=0 || zz!=0) goto illegal_inst;
 @<Save user stack to kernel area@>@;
 @<Probe stack for SAVE@>@;
 l[(O+L)&lring_mask].l=L, L++;
@z

line 2288
@x
@<Store |g[k]| in the register stack...@>=
ll=mem_find(g[rS]);
@y
@<Store |g[k]| in the register stack...@>=
ll=mem_translate(g[rS],PROT_WRITE);
@z

line 2294
@x
if (stack_tracing) {
  tracing=true;
  if (cur_line) show_line();
  if (k>=32) printf("             M8[#%08x%08x]=g[%d]=#%08x%08x, rS+=8\n",
            g[rS].h,g[rS].l,k,x.h,x.l);
  else printf("             M8[#%08x%08x]=%s=#%08x%08x, rS+=8\n",
            g[rS].h,g[rS].l,k==rZ+1? "(rG,rA)": special_name[k],x.h,x.l);
}
@y
@z

line 2304
@x
case UNSAVE:@+if (xx!=0 || yy!=0) goto illegal_inst;
 z.l&=-8;@+g[rS]=incr(z,8);
@y
case UNSAVE:@+if (xx!=0 || yy!=0) goto illegal_inst;
 @<Restore user stack from kernel area@>@;
 @<Probe stack for UNSAVE@>@;
 z.l&=-8;@+g[rS]=incr(z,8);
@z

line 2325
@x
ll=mem_find(g[rS]);
@y
ll=mem_translate(g[rS], PROT_READ);
@z

line 2329
@x
if (stack_tracing) {
  tracing=true;
  if (cur_line) show_line();
  if (k>=32) printf("             rS-=8, g[%d]=M8[#%08x%08x]=#%08x%08x\n",
            k,g[rS].h,g[rS].l,ll->tet,(ll+1)->tet);
  else if (k==rZ+1) printf("             (rG,rA)=M8[#%08x%08x]=#%08x%08x\n",
            g[rS].h,g[rS].l,ll->tet,(ll+1)->tet);
  else printf("             rS-=8, %s=M8[#%08x%08x]=#%08x%08x\n",
            special_name[k],g[rS].h,g[rS].l,ll->tet,(ll+1)->tet);
}
@y
@z

line 2353
@x
case SYNC:@+if (xx!=0 || yy!=0 || zz>7) goto illegal_inst;
 if (zz<=3) break;
case LDVTS: case LDVTSI: privileged_inst: strcpy(lhs,"!privileged");
 goto break_inst;
illegal_inst: strcpy(lhs,"!illegal");
break_inst: breakpoint=tracing=true;
 if (!interacting && !interact_after_break) halted=true;
 break;
@y
case SYNC:@+if (xx!=0 || yy!=0 || zz>7) goto illegal_inst;
 if (zz<=3) break;
 if (g[rK].h & 0x00000010) goto privileged_inst;
 break;
case LDVTS: case LDVTSI:
 if (g[rK].h & 0x00000010) goto privileged_inst;
 x.l = flush_tlb(w);
 goto store_x;
@z

line 2376
@x
case TRAP:@+if (xx!=0 || yy>max_sys_call) goto privileged_inst;
 strcpy(rhs,trap_format[yy]);
 g[rWW]=inst_ptr;
 g[rXX].h=sign_bit, g[rXX].l=inst;
 g[rYY]=y, g[rZZ]=z;
 z.h=0, z.l=zz;
 a=incr(b,8);
 @<Prepare memory arguments $|ma|={\rm M}[a]$ and $|mb|={\rm M}[b]$ if needed@>;
 switch (yy) {
case Halt: @<Either halt or print warning@>;@+g[rBB]=g[255];@+break;
case Fopen: g[rBB]=mmix_fopen((unsigned char)zz,mb,ma);@+break;
case Fclose: g[rBB]=mmix_fclose((unsigned char)zz);@+break;
case Fread: g[rBB]=mmix_fread((unsigned char)zz,mb,ma);@+break;
case Fgets: g[rBB]=mmix_fgets((unsigned char)zz,mb,ma);@+break;
case Fgetws: g[rBB]=mmix_fgetws((unsigned char)zz,mb,ma);@+break;
case Fwrite: g[rBB]=mmix_fwrite((unsigned char)zz,mb,ma);@+break;
case Fputs: g[rBB]=mmix_fputs((unsigned char)zz,b);@+break;
case Fputws: g[rBB]=mmix_fputws((unsigned char)zz,b);@+break;
case Fseek: g[rBB]=mmix_fseek((unsigned char)zz,b);@+break;
case Ftell: g[rBB]=mmix_ftell((unsigned char)zz);@+break;
}
 x=g[255]=g[rBB];@+break;
@y
case TRAP:
	g[rK] = zero_octa;
	g[rWW]= inst_ptr;
	g[rXX].h= sign_bit;
	g[rXX].l= inst;
	g[rYY].h= 0;
	g[rYY].l= yy;
	g[rZZ].h= 0;
	g[rZZ].l= zz;
	z.h= 0,z.l= zz;
	a= incr(b,8);

	g[rBB] = g[255];
	g[255] = g[rJ];
	inst_ptr = g[rT];
	break;
@z

line 2506
@x
into the simulated memory starting at address |addr|.

@<Sub...@>=
void mmputchars @,@,@[ARGS((unsigned char*,int,octa))@];@+@t}\6{@>
@y
into the simulated memory starting at address |addr|.

@<Using Sub...@>=
void mmputchars @,@,@[ARGS((unsigned char*,int,octa))@];@+@t}\6{@>
@z

line 2519
@x
  register unsigned char *p;
  register int m;
  register mem_tetra *ll;
  octa a;
  for (p=buf,m=0,a=addr; m<size;) {
    ll=mem_find(a);@+test_store_bkpt(ll);
    if ((a.l&0x3) || m>size-4) @<Load and write one byte@>@;
@y
  register unsigned char *p;
  register int m;
  register mem_tetra *ll;
  octa a;
  for (p=buf,m=0,a=addr; m<size;) {
    ll=mem_translate(a, PROT_WRITE);@+test_store_bkpt(ll);
    if ((a.l&0x3) || m>size-4) @<Load and write one byte@>@;
@z

line 2581
@x
  if (exc&tracing_exceptions) tracing=true;
@y
@z

line 2604
@x
case RESUME:@+if (xx || yy || zz) goto illegal_inst;
inst_ptr=z=g[rW];
b=g[rX];
@y
case RESUME:@+if (xx || yy) goto illegal_inst;
	if (zz == 0) {
		inst_ptr= z= g[rW];
		b= g[rX];
		resume_z = 0;
	} else if (zz == 1) {
		if (!(loc.h & sign_bit))
			goto illegal_inst;
		inst_ptr= z= g[rWW];
		b= g[rXX];
		g[rK] = g[255];
		g[255] = g[rBB];
		resume_z = 4;
	} else {
		goto illegal_inst;
	}
@z

line 2632
@x
@ @<Install special operands when resuming an interrupted operation@>=
if (rop==RESUME_SET) {
    op=ORI;
    y=g[rZ];
    z=zero_octa;
    exc=g[rX].h&0xff00;
    f=X_is_dest_bit;
}@+else { /* |RESUME_CONT| */
  y=g[rY];
  z=g[rZ];
}
@y
@ @<Install special operands when resuming an interrupted operation@>=
if (rop==RESUME_SET) {
    op=ORI;
    y=g[rZ+resume_z];
    z=zero_octa;
    exc=g[rX+resume_z].h&0xff00;
    f=X_is_dest_bit;
}@+else { /* |RESUME_CONT| */
  y=g[rY+resume_z];
  z=g[rZ+resume_z];
}
@z

line 2646
@x
  if (g[rI].l==0 && g[rI].h==0) tracing=breakpoint=true;
@y
  if (g[rI].l==0 && g[rI].h==0) g[rQ].l |= 0x00000080;
@z

line 2842
@x
char left_paren[]={0,'[','^','_','('}; /* denotes the rounding mode */
char right_paren[]={0,']','^','_',')'}; /* denotes the rounding mode */
char switchable_string[48]; /* holds |rhs|; position 0 is ignored */
 /* |switchable_string| must be able to hold any |trap_format| */
char lhs[32];
int good_guesses, bad_guesses; /* branch prediction statistics */
@y
int good_guesses, bad_guesses; /* branch prediction statistics */
@z

line 2871
@x
@<Preprocessor macros@>@;
@<Type declarations@>@;
@<Global variables@>@;
@<Subroutines@>@;
@#
int main(argc,argv)
  int argc;
  char *argv[];
{
  @<Local registers@>;
  mmix_io_init();
  @<Process the command line@>;
  @<Initialize everything@>;
  @<Load the command line arguments@>;
  @<Get ready to \.{UNSAVE} the initial context@>;
  while (1) {
    if (interrupt && !breakpoint) breakpoint=interacting=true, interrupt=false;
    else {
      breakpoint=false;
      if (interacting) @<Interact with the user@>;
    }
    if (halted) break;
    do @<Perform one instruction@>@;
    while ((!interrupt && !breakpoint) || resuming);
    if (interact_after_break) interacting=true, interact_after_break=false;
  }
 end_simulation:@+if (profiling) @<Print all the frequency counts@>;
  if (interacting || profiling || showing_stats) show_stats(true);
  return g[255].l; /* provide rudimentary feedback for non-interactive runs */
}
@y
#include <setjmp.h>
@<Preprocessor macros@>@;
@<Type declarations@>@;
#define	INCLUDE_FROM_MMIX_SIM_C
#include "vmmmix.h"
@<Prototypes@>@;
@<Global variables@>@;
@<Using Subroutines@>@;
@#
int main(argc,argv)
  int argc;
  char *argv[];
{
  @<Local registers@>;
  @<Parse and process command line@>;
  @<Init and load image@>;
  while (1) {
    @<Perform one instruction@>@;
  }
  free(physical_memory);
}
@z

line 3424
@x
@* Index.
@y
@i vmmmix.w

@* Index.
@z
