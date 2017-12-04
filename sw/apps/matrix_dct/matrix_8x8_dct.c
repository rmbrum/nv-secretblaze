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

#include "matrix_8x8_dct.h"

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
void matrix_8x8_dct(sb_int16_t data[M])
{
  sb_int16_t temp[M];	
  sb_int32_t temp1;
  sb_int32_t i,j,k;				

  for(i=0;i<N;i++) 
  {
    for (j=0;j<N;j++) 
    {
      /* prologue */
      temp1 = 0;
      
      /* kernel */
      for (k=0;k<N;k++)
      {
        /* Q(16.0) * Q(1.15) -> Q(17.15) mult && left shift for normalisation */
        temp1 += ((sb_int32_t)(dct_table_c[N*j+k]*data[N*i+k]) << 1);
      } 

      /* epilogue */   
      temp[N*j+i] = (sb_int16_t)(temp1 >> 16); 
    }          
  }

  for(i=0;i<N;i++) 
  {
    for (j=0;j<N;j++) 
    {
      /* prologue */
      temp1 = 0;
      
      /* kernel */
      for (k=0;k<N;k++)
      {
        /* Q(16.0) * Q(1.15) -> Q(17.15) mult && left shift for normalisation */
        temp1 += ((sb_int32_t)(dct_table_c[N*i+ k]*temp[N*j+k]) << 1);
      } 

      /* epilogue */
      data[N*i+j] = (sb_int16_t)(temp1 >> 16);
    }          
  }
}

