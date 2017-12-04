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

#include "loeffler_8x8_dct.h"

/**
 * \fn void loeffler_8x8_dct(sb_int16_t *const block)
 * \brief 8x8 DCT function
 * \param[in,out] data pointer to a 64 * 2 bytes array
 *
 * This function computes the DCT of a 8x8 data block
 * using the Loeffler's algorithm.
 *   
 */
void loeffler_8x8_dct(sb_int16_t *const block)
{
  sb_int32_t tmp0, tmp1, tmp2, tmp3, tmp4, tmp5, tmp6, tmp7;
  sb_int32_t tmp10, tmp11, tmp12, tmp13;
  sb_int32_t z1, z2, z3, z4, z5;
  sb_int16_t *dataptr;		
  sb_int32_t i;

  /* ROW PROCESS */
  dataptr = block;
  for (i=N;i>0;i--) 
  {
    /* first stage */
    tmp0 = dataptr[0] + dataptr[7];	
    tmp7 = dataptr[0] - dataptr[7];
    tmp1 = dataptr[1] + dataptr[6];
    tmp6 = dataptr[1] - dataptr[6];
    tmp2 = dataptr[2] + dataptr[5];
    tmp5 = dataptr[2] - dataptr[5];
    tmp3 = dataptr[3] + dataptr[4];
    tmp4 = dataptr[3] - dataptr[4];

    /* second stage */
    tmp10 = tmp0 + tmp3;	
    tmp13 = tmp0 - tmp3;
    tmp11 = tmp1 + tmp2;
    tmp12 = tmp1 - tmp2;
    dataptr[0] = (tmp10 + tmp11) << PASS1_BITS;
    dataptr[4] = (tmp10 - tmp11) << PASS1_BITS;
    z1 = (tmp12 + tmp13) * FIX_0_541196100;		
    dataptr[2] = DESCALE(z1 + tmp13 * FIX_0_765366865,MULT_SCALE);
    dataptr[6] = DESCALE(z1 + tmp12 * (-FIX_1_847759065),MULT_SCALE);

    /* third stage */
    z1 = tmp4 + tmp7; 
    z2 = tmp5 + tmp6;
    z3 = tmp4 + tmp6;
    z4 = tmp5 + tmp7;
    z5 = (z3 + z4) * FIX_1_175875602;	
    tmp4 *= FIX_0_298631336; 
    tmp5 *= FIX_2_053119869;
    tmp6 *= FIX_3_072711026;	
    tmp7 *= FIX_1_501321110;
    z1 *= -FIX_0_899976223;	
    z2 *= -FIX_2_562915447;	
    z3 *= -FIX_1_961570560;	
    z4 *= -FIX_0_390180644;	
    z3 += z5;	
    z4 += z5;

    /* fourth stage */
    dataptr[7] = DESCALE(tmp4 + z1 + z3, MULT_SCALE);
    dataptr[5] = DESCALE(tmp5 + z2 + z4, MULT_SCALE);
    dataptr[3] = DESCALE(tmp6 + z2 + z3, MULT_SCALE);
    dataptr[1] = DESCALE(tmp7 + z1 + z4, MULT_SCALE);

    /* next row */
    dataptr += 8;		
  }

  /* COLUMN PROCESS */
  dataptr = block;
  for (i=N;i>0;i--)  
  {
    /* first stage */
    tmp0 = dataptr[0] + dataptr[56];
    tmp7 = dataptr[0] - dataptr[56];
    tmp1 = dataptr[8] + dataptr[48];
    tmp6 = dataptr[8] - dataptr[48];
    tmp2 = dataptr[16] + dataptr[40];
    tmp5 = dataptr[16] - dataptr[40];
    tmp3 = dataptr[24] + dataptr[32];
    tmp4 = dataptr[24] - dataptr[32];

    /* second stage */
    tmp10 = tmp0 + tmp3;	
    tmp13 = tmp0 - tmp3;
    tmp11 = tmp1 + tmp2;
    tmp12 = tmp1 - tmp2;
    dataptr[0] =  DESCALE((tmp10 + tmp11),PASS1_BITS);
    dataptr[32] = DESCALE((tmp10 - tmp11),PASS1_BITS);
    z1 = (tmp12 + tmp13) * FIX_0_541196100;							
    dataptr[16] =	DESCALE(z1 + tmp13 * FIX_0_765366865, MULT_SCALE_2);
    dataptr[48] = DESCALE(z1 + tmp12 * (-FIX_1_847759065), MULT_SCALE_2);

    /* third stage */
    z1 = tmp4 + tmp7; 
    z2 = tmp5 + tmp6;
    z3 = tmp4 + tmp6;
    z4 = tmp5 + tmp7;
    z5 = (z3 + z4) * FIX_1_175875602;	
    tmp4 *= FIX_0_298631336;
    tmp5 *= FIX_2_053119869;
    tmp6 *= FIX_3_072711026;	
    tmp7 *= FIX_1_501321110;	
    z1 *= -FIX_0_899976223;
    z2 *= -FIX_2_562915447;	
    z3 *= -FIX_1_961570560;	
    z4 *= -FIX_0_390180644;	
    z3 += z5;	
    z4 += z5;

    /* fourth stage */
    dataptr[56] = DESCALE(tmp4 + z1 + z3, MULT_SCALE_2);
    dataptr[40] = DESCALE(tmp5 + z2 + z4, MULT_SCALE_2);
    dataptr[24] = DESCALE(tmp6 + z2 + z3, MULT_SCALE_2);
    dataptr[8] = DESCALE(tmp7 + z1 + z4, MULT_SCALE_2);

    ++dataptr;	
  }

  /* normalise results */
  for (i = 0; i < M; i++)
  {
    block[i] = (sb_int16_t)DESCALE(block[i], 3);
  }
}




