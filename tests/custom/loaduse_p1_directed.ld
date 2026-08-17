ENTRY(_start)

SECTIONS
{
  . = 0x80000000;
  .text.start : { *(.text.start) }

  . = 0x80002000;
  .data : { *(.data) }
  . = 0x80002800;
  .data.dirty0 : { *(.data.dirty0) }
  . = 0x80003000;
  .data.dirty1 : { *(.data.dirty1) }
  . = 0x80003800;
  .data.dirty2 : { *(.data.dirty2) }
  . = 0x80004000;
  .data.dirty3 : { *(.data.dirty3) }
  . = 0x80004800;
  .data.dirty4 : { *(.data.dirty4) }
}
