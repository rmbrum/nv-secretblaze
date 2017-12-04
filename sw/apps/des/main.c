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

/**
 * \file main.c
 * \brief DES testbench 
 * \author LIRMM - Lyonel Barthe
 * \version 1.0
 * \date 10/01/2010
 */

#include "des.h"
#include "sb_types.h"
#include "sb_uart.h"

int main(void)
{
    
  sb_int32_t i;

  sb_uint64_t data;
  sb_uint64_t key;
  sb_uint64_t cipher;

  sb_uint8_t rx_uart_buffer[16];

  while(sb_true)
  {
        
    /* RESET DATA */
    data = 0;
    key  = 0;
		
    /* GET DATA */
    for(i=0;i<16;i++)
    {
      uart_get(&rx_uart_buffer[i]);
    }
		
    /* DATA & KEY EXTRACTION */
    for (i=0;i<8;i++)
    {
      data |= ((sb_uint64_t)((sb_uint8_t)rx_uart_buffer[i])   << i*8);
      key  |= ((sb_uint64_t)((sb_uint8_t)rx_uart_buffer[i+8]) << i*8);
    }
				
    /* DES COMPUTATION */
    cipher = do_des(data,key,MODE_CIPHER);
			
    /* SEND DATA */
    for (i=0;i<8;i++)
    {
      uart_put((sb_uint8_t)(cipher >> i*8));
    }

  }

  return 0;
}

