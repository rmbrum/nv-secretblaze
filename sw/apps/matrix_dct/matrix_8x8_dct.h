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

#ifndef _MATRIX_DCT_H
#define _MATRIX_DCT_H

/**
 * \file matrix_8x8_dct.h
 * \brief 8x8 Fixed Point Discrete Cosine Transform Matrix Implementation
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

static const sb_int16_t dct_table_c[M] = /* Scaling factor is N = 16 
                                            Q(1.15) format */
{					
  11585,
  11585,
  11585,
  11585,
  11585,
  11585,
  11585,
  11585,
  16069,
  13622,
  9102,
  3196,
  -3196,
  -9102,
  -13622,
  -16069,
  15136,
  6269,
  -6269,
  -15136,
  -15136,
  -6269,
  6269,
  15136,
  13622,
  -3196,
  -16069,
  -9102,
  9102,
  16069,
  3196,
  -13622,
  11585,
  -11585,
  -11585,
  11585,
  11585,
  -11585,
  -11585,
  11585,
  9102,
  -16069,
  3196,
  13622,
  -13622,
  -3196,
  16069,
  -9102,
  6269,
  -15136,
  15136,
  -6269,
  -6269,
  15136,
  -15136,
  6269,
  3196,
  -9102,
  13622,
  -16069,
  16069,
  -13622,
  9102,
  -3196		
};

/* PROTOTYPE */

/**
 * \fn void matrix_8x8_dct(sb_int16_t data[M])
 * \brief 8x8 DCT function
 * \param[in,out] data pointer to a 64 * 2 bytes array
 *
 * This function computes the DCT of a 8x8 data block.
 * The Forward DCT routine implements the matrix function:
 *                     DCT = C * pixels * Ct
 *   
 */
extern void matrix_8x8_dct(sb_int16_t data[M]);

#endif /* _MATRIX_DCT_H */

