ENTRY(_start)

SECTIONS
{
  . = 0x80000000;
  .text.start : { *(.text.start) }

  . = 0x80000400;
  .text.icache_line_0 : { *(.text.icache_line_0) }
  . = 0x80000800;
  .text.icache_line_1 : { *(.text.icache_line_1) }
  . = 0x80000c00;
  .text.icache_line_2 : { *(.text.icache_line_2) }
  . = 0x80001000;
  .text.icache_line_3 : { *(.text.icache_line_3) }
  . = 0x80001400;
  .text.icache_line_4 : { *(.text.icache_line_4) }
}
