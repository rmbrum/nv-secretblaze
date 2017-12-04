/*
 *
 *    ADAC Research Group - LIRMM - University of Montpellier / CNRS 
 *    contact: adac@lirmm.fr
 *
 *    This file is part of SecretBlaze.
 *
 *    SecretBlaze is free software: you can redistribute it and/or modify
 *    it under the terms of the GNU Lesser General Public License as published by
 *    the Free Software Foundation, either version 3 of the License, or
 *    (at your option) any later version.
 *
 *    SecretBlaze is distributed in the hope that it will be useful,
 *    but WITHOUT ANY WARRANTY; without even the implied warranty of
 *    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *    Lesser GNU General Public License for more details.
 *
 *    You should have received a copy of the GNU Lesser General Public License
 *    along with SecretBlaze.  If not, see <http://www.gnu.org/licenses/>.
 */

/*
 * processor_cacheable_ram_link_file.ld
 *
 * Cacheable RAM Linker Description File
 * Section comments come from Xilinx EDK Manual (10.1/SP3).
 * 
 * Company    : LIRMM
 * Engineer   : Lyonel Barthe
 * Version    : 1.2
 *
 * Revision History :
 *   Version 1.2 - 21/06/2012 by Lyonel Barthe
 *     Minor fix in the .dtors section to
 *     support mg-gcc from ISE 14
 *   Version 1.1b - 5/09/2010 by Lyonel Barthe
 *     Program version
 *   Version 1.0 - 22/04/2010 by Lyonel Barthe
 *
 */

/* STACK & HEAP DEFAULT SIZE */
_STACK_SIZE = DEFINED(_STACK_SIZE) ? _STACK_SIZE : 0x100;
_HEAP_SIZE  = DEFINED(_HEAP_SIZE)  ? _HEAP_SIZE  : 0x100;

/* MEMORY MAPPING */
MEMORY
{
    /* vector table */
    vec_res : ORIGIN = 0x10000000, LENGTH = 0x00000008
    vec_swe : ORIGIN = 0x10000008, LENGTH = 0x0000000F
    vec_int : ORIGIN = 0x10000010, LENGTH = 0x0000000F
    vec_hwe : ORIGIN = 0x10000020, LENGTH = 0x0000002F

    /* ~1 MB program RAM */
    ca_ram  : ORIGIN = 0x10000050, LENGTH = 0x000FFFB0
}

ENTRY(_start)

SECTIONS
{

    /* ***************************************************
     *
     *                     Vectors
     *
     * ***************************************************/

    .vectors.reset : 
    {
        *(.vectors.reset)
    } > vec_res

    .vectors.sw_exception : 
    {
        *(.vectors.sw_exception)
    } > vec_swe

    .vectors.interrupt : 
    {
        *(.vectors.interrupt)
    } > vec_int

    .vectors.hw_exception : 
    {
        *(.vectors.hw_exception)
    } > vec_hwe

    /* ***************************************************
     *
     * .text
     * This section contains executable code. This section 
     * has the x (executable), r (read-only) and i
     * (initialized) flags. 
     *
     *
     * .init
     * This section contains language initialization code 
     * and has the same flags as .text. It must be mapped 
     * to initialized ROM.
     *
     * ***************************************************/

    .text : 
    {
       *(.text)
       *(.text.*)
       *(.gnu.linkonce.t.*)
    } > ca_ram

    .init : 
    {
       KEEP (*(.init))
    } > ca_ram

    .fini : 
    {
       KEEP (*(.fini))
    } > ca_ram

    /* ***************************************************
     *
     * .rodata
     * This section contains read-only data. This section 
     * has the r (read-only) and the i (initialized) flags. 
     * Like the .text section, this section can also be 
     * assigned to an initialized, read-only memory that 
     * is addressable from the processor data bus.
     *
     * .sdata2
     * This section is similar to the .rodata section. 
     * It contains small read-only data of size less
     * than 8 bytes. All data in this section is accessed 
     * with reference to the read-only small data anchor. 
     * This ensures that all the contents of this section
     * are accessed using a single instruction. You can 
     * change the size of the data going into this section 
     * with the -G option to the compiler. This section 
     * has the r (read-only) and the i (initialized) flags.
     *
     * .sbss2
     * This section contains small, read-only un-initialized 
     * data of a size less than 8 bytes. You can change the 
     * size of the data going into this section with the -G 
     * option. This section has the r (read) flag and can be 
     * mapped to ROM.
     *
     * .data
     * This section contains read-write data and has the w 
     * (read-write) and the i (initialized) flags. It must 
     * be mapped to initialized random access memory (RAM). 
     * It cannot be mapped to a ROM.
     *
     * .gotx
     * This section contains pointers to program data, 
     * the same flags as .data, and it must be mapped to 
     * initialized RAM.
     *
     * .ctors
     * This section contains a list of functions that must 
     * be invoked at program startup and the same flags as 
     * .data and must be mapped to initialized RAM.
     *
     * .dtors
     * This section contains a list of functions that must 
     * be invoked at program end, the same flags as .data, 
     * and it must be mapped to initialized RAM.
     *
     * .eh_frame
     * This section contains frame unwind information 
     * for exception handling. It contains the same flags 
     * as .rodata, and can be mapped to initialized ROM.
     *
     * .jcr
     * This section contains information necessary for 
     * registering compiled Java classes. The contents are 
     * compiler-specific and used by compiler initialization 
     * functions. This section must be mapped to initialized RAM.
     *
     * .gcc_except_table
     * This section holds language specific data. This section 
     * must be mapped to initialized RAM.
     *
     * .sdata
     * This section contains small read-write data of a 
     * size less than 8 bytes. You can change the size of the data 
     * going into this section with the -G option. All data in this section is
     * accessed with reference to the read-write small data anchor. 
     * This ensures that all contents of the section can be accessed 
     * using a single instruction. This section has the w (read-write)
     * and the i (initialized) flags and must be mapped to initialized RAM.
     *
     * .sbss
     * This section contains small un-initialized data of 
     * a size less than 8 bytes. You can change the size of 
     * the data going into this section with the -G option. 
     * This section has the w (read-write) flag and must be mapped to RAM.
     * 
     * .tdata
     * This section holds initialized thread-local data that 
     * contribute to the program memory image. This section 
     * must be mapped to initialized RAM.
     *
     * .tbss
     * This section holds uninitialized thread-local data 
     * that contribute to the program memory image. This section 
     * has the same flags as .bss, and it must be mapped to RAM.
     *
     * .bss
     * This section contains un-initialized data. This section 
     * has the w (read-write) flag and must be mapped to RAM.
     *
     * .heap
     * This section contains uninitialized data that is used as 
     * the global program heap. Dynamic memory allocation routines 
     * allocate memory from this section. This section must be
     * mapped to RAM.
     *
     * .stack
     * This section contains uninitialized data that is used as 
     * the program stack. This section must be mapped to RAM. 
     * This section is typically laid out right after the .heap 
     * section. In some versions of the linker, the .stack and .heap 
     * sections might appear merged together into
     * a section named .bss_stack.
     *
     * ***************************************************/

    .rodata : 
    {
       __rodata_start = .;
       *(.rodata)
       *(.rodata.*)
       *(.gnu.linkonce.r.*)
       __rodata_end = .;
    } > ca_ram

    .sdata2 : 
    {
       . = ALIGN(8);
       __sdata2_start = .;
       *(.sdata2)
       *(.sdata2.*)
       *(.gnu.linkonce.s2.*)
       . = ALIGN(8);
       __sdata2_end = .;
    } > ca_ram

    .sbss2 : 
    {
       __sbss2_start = .;
       *(.sbss2)
       *(.sbss2.*)
       *(.gnu.linkonce.sb2.*)
       __sbss2_end = .;
    } > ca_ram

    .data : 
    {
       . = ALIGN(4);
       __data_start = .;
       *(.data)
       *(.data.*)
       *(.gnu.linkonce.d.*)
       __data_end = .;
    } > ca_ram 

    .got : 
    {
       *(.got)
    } > ca_ram

    .got1 : 
    {
       *(.got1)
    } > ca_ram

    .got2 : 
    {
       *(.got2)
    } > ca_ram

    .ctors : 
    {
       __CTOR_LIST__ = .;
       ___CTORS_LIST___ = .;
       KEEP (*crtbegin.o(.ctors))
       KEEP (*(EXCLUDE_FILE(*crtend.o) .ctors))
       KEEP (*(SORT(.ctors.*)))
       KEEP (*(.ctors))
       __CTOR_END__ = .;
       ___CTORS_END___ = .;
    } > ca_ram

    .dtors : 
    {
       __DTOR_LIST__ = .;
       ___DTORS_LIST___ = .;
       KEEP (*crtbegin.o(.dtors))
       KEEP (*(EXCLUDE_FILE(*crtend.o) .dtors))
       KEEP (*(SORT(.dtors.*)))
       KEEP (*(.dtors))
       PROVIDE(__DTOR_END__ = .);
       PROVIDE(___DTORS_END___ = .);
    } > ca_ram

    .eh_frame : 
    {
       *(.eh_frame)
    } > ca_ram

    .jcr : 
    {
       *(.jcr)
    } > ca_ram

    .gcc_except_table : 
    {
       *(.gcc_except_table)
    } > ca_ram

    .sdata : 
    {
       . = ALIGN(8);
       __sdata_start = .;
       *(.sdata)
       *(.sdata.*)
       *(.gnu.linkonce.s.*)
       __sdata_end = .;
    } > ca_ram

    .sbss : 
    {
       . = ALIGN(4);
       __sbss_start = .;
       *(.sbss)
       *(.sbss.*)
       *(.gnu.linkonce.sb.*)
       . = ALIGN(8);
       __sbss_end = .;
    } > ca_ram

    .tdata : 
    {
       __tdata_start = .;
       *(.tdata)
       *(.tdata.*)
       *(.gnu.linkonce.td.*)
       __tdata_end = .;
    } > ca_ram

    .tbss : 
    {
       __tbss_start = .;
       *(.tbss)
       *(.tbss.*)
       *(.gnu.linkonce.tb.*)
       __tbss_end = .;
    } > ca_ram

    .bss : 
    {
       . = ALIGN(4);
       __bss_start = .;
       *(.bss)
       *(.bss.*)
       *(.gnu.linkonce.b.*)
       *(COMMON)
       . = ALIGN(4);
       __bss_end = .;
    } > ca_ram

    /* ***************************************************
     *
     *                  Alignement Management
     *
     * • Ensure that the _SDA2_BASE_ variable points to the 
     * center of the .sdata2 area, and that _SDA2_BASE_ is aligned 
     * on a word boundary.
     *
     * • Ensure that the .sdata and the .sbss sections are 
     * contiguous, that the _SDA_BASE_variable points to the 
     * center of this section, and that _SDA_BASE_ is aligned on a word
     * boundary.
     *
     * ***************************************************/

    _SDA_BASE_ = __sdata_start + ((__sbss_end - __sdata_start) / 2 );
    _SDA2_BASE_ = __sdata2_start + ((__sbss2_end - __sdata2_start) / 2 );

    /* ***************************************************
     *
     *                     Heap & Stack
     *
     * ***************************************************/

    .heap : 
    {
       . = ALIGN(8);
       _heap = .;
       _heap_start = .;
       . += _HEAP_SIZE;
       _heap_end = .;
    } > ca_ram

    .stack : 
    {
       _stack_end = .;
       . += _STACK_SIZE;
       . = ALIGN(8);
       _stack = .;
       __stack = _stack;
    } > ca_ram

}

