#!/usr/bin/env python3
import argparse
from pathlib import Path

REG = {'zero':0,'ra':1,'sp':2,'gp':3,'tp':4,'t0':5,'t1':6,'t2':7,
       's0':8,'s1':9,'a0':10,'a1':11,'a2':12,'a3':13,'a4':14,'a5':15,
       'a6':16,'a7':17,'s2':18,'s3':19,'s4':20,'s5':21,'s6':22,'s7':23,
       's8':24,'s9':25,'s10':26,'s11':27,'t3':28,'t4':29,'t5':30,'t6':31}

def rtype(f7, rs2, rs1, f3, rd, op=0x33): return (f7<<25)|(rs2<<20)|(rs1<<15)|(f3<<12)|(rd<<7)|op
def itype(imm, rs1, f3, rd, op=0x13): return ((imm&0xfff)<<20)|(rs1<<15)|(f3<<12)|(rd<<7)|op
def stype(imm, rs2, rs1, f3):
    u=imm&0xfff; return ((u>>5)<<25)|(rs2<<20)|(rs1<<15)|(f3<<12)|((u&31)<<7)|0x23
def btype(imm, rs2, rs1, f3):
    u=imm&0x1fff
    return (((u>>12)&1)<<31)|(((u>>5)&0x3f)<<25)|(rs2<<20)|(rs1<<15)|(f3<<12)|(((u>>1)&0xf)<<8)|(((u>>11)&1)<<7)|0x63
def utype(imm20, rd, op=0x37): return ((imm20&0xfffff)<<12)|(rd<<7)|op
def jtype(imm, rd):
    u=imm&0x1fffff
    return (((u>>20)&1)<<31)|(((u>>1)&0x3ff)<<21)|(((u>>11)&1)<<20)|(((u>>12)&0xff)<<12)|(rd<<7)|0x6f

class Asm:
    def __init__(self): self.words=[]; self.labels={}; self.fix=[]
    @property
    def pc(self): return 0x80000000 + 4*len(self.words)
    def label(self,n): self.labels[n]=self.pc
    def emit(self,w): self.words.append(w&0xffffffff)
    def addi(self,rd,rs,imm): self.emit(itype(imm,REG[rs],0,REG[rd]))
    def andi(self,rd,rs,imm): self.emit(itype(imm,REG[rs],7,REG[rd]))
    def add(self,rd,a,b): self.emit(rtype(0,REG[b],REG[a],0,REG[rd]))
    def sub(self,rd,a,b): self.emit(rtype(0x20,REG[b],REG[a],0,REG[rd]))
    def xor(self,rd,a,b): self.emit(rtype(0,REG[b],REG[a],4,REG[rd]))
    def lbu(self,rd,imm,rs): self.emit(itype(imm,REG[rs],4,REG[rd],0x03))
    def sb(self,rs2,imm,rs1): self.emit(stype(imm,REG[rs2],REG[rs1],0))
    def sd(self,rs2,imm,rs1): self.emit(stype(imm,REG[rs2],REG[rs1],3))
    def csrr_cycle(self,rd): self.emit((0xc00<<20)|(0<<15)|(2<<12)|(REG[rd]<<7)|0x73)
    def branch(self,kind,a,b,label): self.fix.append((len(self.words),kind,label,REG[a],REG[b])); self.emit(0)
    def jal(self,rd,label): self.fix.append((len(self.words),'jal',label,REG[rd],0)); self.emit(0)
    def ret(self): self.emit(itype(0,REG['ra'],0,REG['zero'],0x67))
    def li(self,rd,val):
        val &= 0xffffffff
        signed = val if val < 0x80000000 else val-0x100000000
        if -2048 <= signed <= 2047: self.addi(rd,'zero',signed); return
        hi=(val+0x800)>>12; lo=val-(hi<<12)
        self.emit(utype(hi,REG[rd])); self.addi(rd,rd,lo)
    def mv(self,rd,rs): self.addi(rd,rs,0)
    def resolve(self):
        f3={'beq':0,'bne':1,'blt':4,'bge':5}
        for idx,k,l,a,b in self.fix:
            off=self.labels[l]-(0x80000000+4*idx)
            self.words[idx]=jtype(off,a) if k=='jal' else btype(off,b,a,f3[k])

def emit_marker(a,event,payload_reg=None):
    if payload_reg is not None: a.sd(payload_reg,8,'t6')
    a.li('t5',event); a.sd('t5',0,'t6')

def build(width, height, warmup, measured):
    n=width*height; A=0x80010000; B=A+n; STACK=0x800ff000; MARK=0xa0000100
    a=Asm(); a.label('_start')
    a.li('sp',STACK); a.li('s0',A); a.li('s1',B); a.li('s2',n); a.li('s3',width); a.li('s4',height); a.li('t6',MARK)
    a.csrr_cycle('s5'); emit_marker(a,1)
    a.mv('a0','s0'); a.mv('a1','s1'); a.mv('a2','s2')
    a.label('clear'); a.sb('zero',0,'a0'); a.sb('zero',0,'a1'); a.addi('a0','a0',1); a.addi('a1','a1',1); a.addi('a2','a2',-1); a.branch('bne','a2','zero','clear')
    a.li('a0',A+width+1); a.li('a1',1); a.li('a2',width-1); a.li('a6',height-1)
    a.label('init_row'); a.li('a3',1)
    a.label('init_cell'); a.xor('a4','a3','a1'); a.andi('a4','a4',3); a.branch('bne','a4','zero','init_skip'); a.li('a5',1); a.sb('a5',0,'a0')
    a.label('init_skip'); a.addi('a0','a0',1); a.addi('a3','a3',1); a.branch('blt','a3','a2','init_cell'); a.addi('a0','a0',2); a.addi('a1','a1',1); a.branch('blt','a1','a6','init_row')
    a.csrr_cycle('s6'); a.sub('s6','s6','s5'); emit_marker(a,2,'s6')
    a.li('s7',warmup)
    a.label('warm_loop'); a.branch('beq','s7','zero','warm_done'); a.mv('a0','s0'); a.mv('a1','s1'); a.jal('ra','generation'); a.mv('t0','s0'); a.mv('s0','s1'); a.mv('s1','t0'); a.addi('s7','s7',-1); a.jal('zero','warm_loop')
    a.label('warm_done'); a.csrr_cycle('s5'); emit_marker(a,3); a.li('s7',measured)
    a.label('measure_loop'); a.mv('a0','s0'); a.mv('a1','s1'); a.jal('ra','generation'); a.mv('t0','s0'); a.mv('s0','s1'); a.mv('s1','t0'); a.addi('s7','s7',-1); a.branch('bne','s7','zero','measure_loop')
    a.csrr_cycle('s6'); a.sub('s6','s6','s5'); emit_marker(a,4,'s6')
    a.mv('a0','s0'); a.mv('a1','s2'); a.li('a2',0)
    a.label('checksum'); a.lbu('a3',0,'a0'); a.add('a2','a2','a3'); a.addi('a0','a0',1); a.addi('a1','a1',-1); a.branch('bne','a1','zero','checksum')
    emit_marker(a,5,'a2'); emit_marker(a,6)
    a.label('halt'); a.jal('zero','halt')

    a.label('generation')
    a.li('a4',1); a.addi('a5','s4',-1); a.add('a6','a0','s3'); a.addi('a6','a6',1); a.add('a7','a1','s3'); a.addi('a7','a7',1); a.addi('t5','s3',-1)
    a.label('gen_row'); a.li('t0',1)
    a.label('gen_cell'); a.li('t1',0)
    for off in (-width-1,-width,-width+1,-1,1,width-1,width,width+1): a.lbu('t2',off,'a6'); a.add('t1','t1','t2')
    a.lbu('t2',0,'a6'); a.li('t3',0); a.branch('beq','t2','zero','dead')
    a.li('t4',2); a.branch('beq','t1','t4','set_live'); a.li('t4',3); a.branch('beq','t1','t4','set_live'); a.jal('zero','store')
    a.label('dead'); a.li('t4',3); a.branch('bne','t1','t4','store')
    a.label('set_live'); a.li('t3',1)
    a.label('store'); a.sb('t3',0,'a7'); a.addi('a6','a6',1); a.addi('a7','a7',1); a.addi('t0','t0',1); a.branch('blt','t0','t5','gen_cell'); a.addi('a6','a6',2); a.addi('a7','a7',2); a.addi('a4','a4',1); a.branch('blt','a4','a5','gen_row'); a.ret()
    a.resolve()

    grid=[[0]*width for _ in range(height)]
    for y in range(1,height-1):
        for x in range(1,width-1): grid[y][x]=1 if ((x^y)&3)==0 else 0
    def step(g):
        z=[[0]*width for _ in range(height)]
        for y in range(1,height-1):
            for x in range(1,width-1):
                s=sum(g[y+dy][x+dx] for dy in (-1,0,1) for dx in (-1,0,1) if dx or dy)
                z[y][x]=1 if s==3 or (g[y][x] and s==2) else 0
        return z
    for _ in range(warmup+measured): grid=step(grid)
    return a.words, sum(map(sum,grid)), A, B, STACK

def main():
    p=argparse.ArgumentParser(); p.add_argument('--width',type=int,required=True); p.add_argument('--height',type=int); p.add_argument('--warmup',type=int,default=1); p.add_argument('--measured',type=int,default=3); p.add_argument('--out',required=True); p.add_argument('--meta',required=True); q=p.parse_args()
    height=q.height if q.height is not None else q.width
    words,checksum,grid_a,grid_b,stack=build(q.width,height,q.warmup,q.measured)
    data=b''.join(w.to_bytes(4,'little') for w in words)
    Path(q.out).write_text('\n'.join('{:02x}'.format(x) for x in data)+'\n')
    Path(q.meta).write_text('GRID_WIDTH={}\nGRID_HEIGHT={}\nWARMUP_GENERATIONS={}\nMEASURED_GENERATIONS={}\nEXPECTED_CHECKSUM={}\nPROGRAM_BYTES={}\nPROGRAM_BASE=0x80000000\nPROGRAM_END=0x{:08x}\nGRID_A_BASE=0x{:08x}\nGRID_A_END=0x{:08x}\nGRID_B_BASE=0x{:08x}\nGRID_B_END=0x{:08x}\nSTACK_POINTER=0x{:08x}\nHIGHEST_DATA_ADDRESS=0x{:08x}\n'.format(q.width,height,q.warmup,q.measured,checksum,len(data),0x80000000+len(data),grid_a,grid_a+q.width*height,grid_b,grid_b+q.width*height,stack,max(grid_b+q.width*height-1,stack)))

if __name__=='__main__': main()
