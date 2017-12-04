##
##
##    ADAC Research Group - LIRMM - University of Montpellier / CNRS 
##    contact: adac@lirmm.fr
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
#   Version 1.0 - 1/03/2010 by Lyonel Barthe                #
#       Initial Release                                     #
#                                                           #
#-----------------------------------------------------------#
#############################################################

# sources
SRCS=../../lib/secretblaze/sb_uart.c \
     ../../lib/e_lib/e_printf.c      \
     main.c

# project name
NAME_PROJ=hello_world

# set compiler
CC=mb-gcc

#XILFLAGS=-mxl-soft-div -msoft-float -mno-xl-pattern-compare -mno-xl-barrel-shift -mxl-soft-mul -mno-xl-multiply-high
XILFLAGS=-mno-xl-soft-div -msoft-float -mxl-pattern-compare -mxl-barrel-shift -mno-xl-soft-mul -mno-xl-multiply-high 
CXXFLAGS=-g -O3 -pedantic -Wall -std=c99 
LINKFILE=../../bsp/$(BSP_PARAM)/processor_cacheable_ram_link_file.ld
LNKFLAGS=-T 
LIBFLAGS=
INCFLAGS=-I../../lib/secretblaze \
         -I../../lib/e_lib \
         -I../../bsp/$(BSP_PARAM)

cc:
	$(CC) $(XILFLAGS) $(CXXFLAGS) $(LNKFLAGS) $(LINKFILE) $(LIBFLAGS) $(INCFLAGS) $(CCFLAGS) $(SRCS) -o $(NAME_PROJ).elf

dump: cc
	mb-objdump -DSCz $(NAME_PROJ).elf > $(NAME_PROJ).dump

bin: cc
	mb-objcopy -O binary $(NAME_PROJ).elf $(NAME_PROJ).bin

all: cc dump bin

clean:
	rm -f *~ *.bak $(NAME_PROJ).elf $(NAME_PROJ).dump $(NAME_PROJ).bin

