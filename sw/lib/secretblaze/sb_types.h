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

#ifndef _SB_TYPES_H
#define _SB_TYPES_H

/**
 * \file sb_types.h
 * \brief Type declarations
 * \author LIRMM - Lyonel Barthe
 * \version 1.0
 * \date 25/04/2010 
 */

/* function pointer type */
typedef void (*sb_fn_p_t)  (void);

/* unsigned integer types */
typedef unsigned long long sb_uint64_t;
typedef unsigned int       sb_uint32_t;
typedef unsigned short     sb_uint16_t;
typedef unsigned char      sb_uint8_t;

/* signed integer types */
typedef signed long long   sb_int64_t;
typedef signed int         sb_int32_t;
typedef signed short       sb_int16_t;
typedef signed char        sb_int8_t;

/* floating point types */
typedef double             sb_float64_t;
typedef float              sb_float32_t;

/* bool type */
typedef enum
{
  sb_false = 0,
  sb_true      
} sb_bool_t;

/* status type */
typedef enum
{
  STATUS_SUCCESS = 0,
  STATUS_FAILED      
} sb_status_t;

#endif /* _SB_TYPES_H */

