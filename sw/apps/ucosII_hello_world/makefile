##
##    Copyright (C) 2010 - 2012 Barthe Lyonel <lyonel.barthe@lirmm.fr>
##
##    This file is part of SecretBlaze.
##
##    SecretBlaze is free software: you can redistribute it and/or modify
##    it under the terms of the GNU General Public License as published by
##    the Free Software Foundation, either version 3 of the License, or
##    (at your option) any later version.
##
##    SecretBlaze is distributed in the hope that it will be useful,
##    but WITHOUT ANY WARRANTY; without even the implied warranty of
##    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
##    GNU General Public License for more details.
##
##    You should have received a copy of the GNU General Public License
##    along with SecretBlaze.  If not, see <http://www.gnu.org/licenses/>.
##

#############################################################
#-----------------------------------------------------------#
#                                                           #  
# Company       : LIRMM                                     #
# Engineer      : Lyonel Barthe                             #
# Version       : 1.0                                       #
#                                                           #
# Revision History :                                        #
#                                                           #
#   Version 1.0 - 22/07/2011 by Lyonel Barthe               #
#       Initial Release                                     #
#                                                           #
#-----------------------------------------------------------#
#############################################################

# mb tool-chain
CC=mb-gcc
ASM=mb-as
LD=mb-ld

# project name
NAME_PROJ=ucosII_hello_world

# source files
DRVSRCS=../../lib/secretblaze/sb_uart.c \
        ../../lib/secretblaze/sb_intc.c \
        ../../lib/e_lib/e_printf.c     
       
UCOSIISRCS=../../lib/os/uC_OS-II_v2_90/cpu_core.c \
           ../../lib/os/uC_OS-II_v2_90/lib_*.c \
           ../../lib/os/uC_OS-II_v2_90/os_*.c \
           ../../lib/os/uC_OS-II_v2_90/MicroBlaze/os_*.c                   
     
APPSRCS= bsp.c \
         helloworld.c

# flags
#XILFLAGS=-mxl-soft-div -msoft-float -mno-xl-pattern-compare -mno-xl-barrel-shift -mxl-soft-mul -mno-xl-multiply-high
XILFLAGS=-mno-xl-soft-div -msoft-float -mxl-pattern-compare -mxl-barrel-shift -mno-xl-soft-mul -mno-xl-multiply-high
CXXFLAGS=-g -Os -pedantic -Wall -std=c99 
ASMFLAGS=-g 
LDFLAGS=-T../../bsp/$(BSP_PARAM)/processor_cacheable_ram_link_file.ld
LIBFLAGS=
INCFLAGS=-I../../lib/secretblaze   \
         -I../../lib/e_lib         \
         -I../../lib/os/uC_OS-II_v2_90 \
         -I../../lib/os/uC_OS-II_v2_90/MicroBlaze \
         -I../../bsp/$(BSP_PARAM)
DEFFLAGS=-D DONT_USE_GCC_INTERRUPT_ATTRIBUTE

asm:
	$(ASM) $(ASMFLAGS) ../../lib/os/uC_OS-II_v2_90/MicroBlaze/cpu_a.s -o cpu_a.o 
	$(ASM) $(ASMFLAGS) ../../lib/os/uC_OS-II_v2_90/MicroBlaze/os_cpu_a.s -o os_cpu_a.o 
	  
cc:
	$(CC) $(XILFLAGS) $(CXXFLAGS) $(LDFLAGS) $(LIBFLAGS) $(INCFLAGS) $(CCFLAGS) $(DRVSRCS) \
	$(UCOSIISRCS) $(APPSRCS) $(DEFFLAGS) cpu_a.o os_cpu_a.o -o $(NAME_PROJ).elf

dump: asm cc
	mb-objdump -DSCz $(NAME_PROJ).elf > $(NAME_PROJ).dump

bin: asm cc
	mb-objcopy -O binary $(NAME_PROJ).elf $(NAME_PROJ).bin

all: asm cc dump bin

clean:
	rm -f *~ *.bak $(NAME_PROJ).elf $(NAME_PROJ).dump $(NAME_PROJ).bin cpu_a.o os_cpu_a.o

