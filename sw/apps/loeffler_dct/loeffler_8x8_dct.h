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
 *  Original code from the XVID MPEG-4 VIDEO CODEC Lib.
 *
 *  XVID MPEG-4 VIDEO CODEC
 *  - Forward DCT  -
 *
 *  These routines are from Independent JPEG Group's free JPEG software
 *  Copyright (C) 1991-1998, Thomas G. Lane (see the file README.IJG)
 *
 *  This program is free software ; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation ; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY ; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program ; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307 USA
 *
 */

#ifndef _LOEFFLER_DCT_H
#define _LOEFFLER_DCT_H

/**
 * \file loeffler_8x8_dct.h
 * \brief 8x8 Fixed Point Discrete Cosine Transform Loeffler Implementation
 * \author LIRMM - Lyonel Barthe
 * \version 1.0
 * \date 18/05/2011 
 */

#include "sb_types.h"

/**
 * \def N
 * Row size matrix.
 */
#define N 8	

/**
 * \def M
 * Matrix size.
 */
#define M (N*N)	

/* MACROS */
#define RIGHT_SHIFT(x, shft)  ((x) >> (shft))
#define MULTIPLY(var,cons)  ((int32_t) RIGHT_SHIFT((var) * (cons), CONST_BITS))
#define DESCALE(x, n)  RIGHT_SHIFT((x) + ( 1 << ((n) - 1)), n) 		

/* LOEFFLER SETTINGS */
#define PASS1_BITS 2 											
#define CONST_BITS 13											
#define MULT_SCALE (CONST_BITS - PASS1_BITS)
#define MULT_SCALE_2 (CONST_BITS + PASS1_BITS)

/* Scaling factor is N = 13 
   Q(3.13) format */
#define FIX_0_298631336  ((sb_int16_t)  2446) /* FIX(0.298631336) */ 
#define FIX_0_390180644  ((sb_int16_t)  3196) /* FIX(0.390180644) */ 
#define FIX_0_541196100  ((sb_int16_t)  4433) /* FIX(0.541196100) */ 
#define FIX_0_765366865  ((sb_int16_t)  6270) /* FIX(0.765366865) */ 
#define FIX_0_899976223  ((sb_int16_t)  7373) /* FIX(0.899976223) */ 
#define FIX_1_175875602  ((sb_int16_t)  9633) /* FIX(1.175875602) */ 
#define FIX_1_501321110  ((sb_int16_t) 12299) /* FIX(1.501321110) */ 
#define FIX_1_847759065  ((sb_int16_t) 15137) /* FIX(1.847759065) */ 
#define FIX_1_961570560  ((sb_int16_t) 16069) /* FIX(1.961570560) */ 
#define FIX_2_053119869  ((sb_int16_t) 16819) /* FIX(2.053119869) */ 
#define FIX_2_562915447  ((sb_int16_t) 20995) /* FIX(2.562915447) */ 
#define FIX_3_072711026  ((sb_int16_t) 25172) /* FIX(3.072711026) */ 

/* PROTOTYPE */

/**
 * \fn void loeffler_8x8_dct(sb_int16_t *const block)
 * \brief 8x8 DCT function
 * \param[in,out] data pointer to a 64 * 2 bytes array
 *
 * This function computes the DCT of a 8x8 data block
 * using the Loeffler's algorithm.
 *   
 */
extern void loeffler_8x8_dct(sb_int16_t *const block);

#endif /* _LOEFFLER_DCT_H */

