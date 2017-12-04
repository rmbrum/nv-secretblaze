/*
 *
 *    ADAC Research Group - LIRMM - University of Montpellier / CNRS 
 *    contact: adac@lirmm.fr
 *
 *    This file is part of SecretBlaze.
 *
 *    SecretBlaze is free software: you can redistribute it and/or modify
 *    it under the terms of the GNU General Public License as published by
 *    the Free Software Foundation, either version 3 of the License, or
 *    (at your option) any later version.
 *
 *    SecretBlaze is distributed in the hope that it will be useful,
 *    but WITHOUT ANY WARRANTY; without even the implied warranty of
 *    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *    GNU General Public License for more details.
 *
 *    You should have received a copy of the GNU General Public License
 *    along with SecretBlaze.  If not, see <http://www.gnu.org/licenses/>.
 */
 
/*
 *    Original code from Georges Menie
 *
 *    Copyright 2001, 2002 Georges Menie (www.menie.org)
 *
 *    This program is free software; you can redistribute it and/or modify
 *    it under the terms of the GNU Lesser General Public License as published by
 *    the Free Software Foundation; either version 2 of the License, or
 *    (at your option) any later version.
 * 
 *    This program is distributed in the hope that it will be useful,
 *    but WITHOUT ANY WARRANTY; without even the implied warranty of
 *    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *    GNU Lesser General Public License for more details.
 *
 *    You should have received a copy of the GNU Lesser General Public License
 *    along with this program; if not, write to the Free Software
 *    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *    
 */

#ifndef _E_PRINTF_H
#define _E_PRINTF_H

/**
 * \file eprintf.h
 * \brief Embedded printf for integer, string, and character formats
 * \author LIRMM - Lyonel Barthe
 * \version 1.0
 * \date 13/01/2012
 */

#include "sb_uart.h" /* UART as standard output */

#define PAD_RIGHT      1
#define PAD_ZERO       2
#define PRINT_BUF_LEN 16

/* PROTOTYPES */

extern int e_printf(const char *format, ...);
extern int e_sprintf(char *out, const char *format, ...);
extern void outbyte(char **str, char c);
extern int prints(char **out, const char *string, int width, int pad);
extern int printi(char **out, int i, int b, int sg, int width, int pad, int letbase);
extern int print(char **out, int *varg);

#endif /* _E_PRINTF_H */

