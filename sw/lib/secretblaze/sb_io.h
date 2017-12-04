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

#ifndef _SB_IO_H
#define _SB_IO_H

/**
 * \file sb_io.h
 * \brief Input/Output primitives
 * \author LIRMM - Lyonel Barthe
 * \version 1.0
 * \date 25/04/2010 
 */
 
#include "sb_types.h"

/* MACROS */

/**
 * \def READ_REG32
 * 32-bit unsigned read primitive 
 */ 
#define READ_REG32(adr)      (*(volatile sb_uint32_t*)(adr))

/**
 * \def WRITE_REG32
 * 32-bit unsigned write primitive 
 */ 
#define WRITE_REG32(adr,val) (*(volatile sb_uint32_t*)(adr) = val)

/**
 * \def READ_REG16
 * 16-bit unsigned read primitive 
 */ 
#define READ_REG16(adr)      (*(volatile sb_uint16_t*)(adr))

/**
 * \def WRITE_REG16
 * 16-bit unsigned write primitive 
 */ 
#define WRITE_REG16(adr,val) (*(volatile sb_uint16_t*)(adr) = val)

/**
 * \def READ_REG8
 * 8-bit unsigned read primitive 
 */ 
#define READ_REG8(adr)       (*(volatile sb_uint8_t*)(adr))

/**
 * \def WRITE_REG8
 * 8-bit unsigned write primitive 
 */ 
#define WRITE_REG8(adr,val)  (*(volatile sb_uint8_t*)(adr) = val)

#endif /* _SB_IO_H */

