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
 * \brief AES testbench 
 * \author LIRMM - Lyonel Barthe
 * \version 1.0
 * \date 10/01/2010
 */

#include "aes.h"

#include "sb_types.h"
#include "sb_def.h"
#include "sb_timer.h"
#include "sb_uart.h"
#include "sb_io.h"
#include "sb_cache.h"

#include "e_printf.h" /* embedded printf */

#define TIMER_MAX_VALUE 0xFFFFFFFF

int main(void)
{
    
  sb_int32_t i;

  sb_uint8_t data[4*Nb];
  sb_uint8_t data2[4*Nb];
  sb_uint8_t key[4*Nb];
  sb_uint8_t cipher[4*Nb];
  sb_uint8_t w[4][Nb*(Nr+1)];
  sb_uint8_t rx_uart_buffer[32];
  sb_uint32_t end_time;
  sb_uint8_t led = 0xaa;
  sb_bool_t test;

  while(sb_true)
    {
        
      /* RESET DATA */
      for(i=0;i<16;i++)
      {
        data[i] = 0;
        key[i]  = 0; 
      }

      /* GET DATA */
      for(i=0;i<32;i++)   
      {    
        uart_get(&rx_uart_buffer[i]);   
      }
		
      e_printf("\nInput:\n");

      /* DATA & KEY EXTRACTION */
      for (i=0;i<16;i++)
      {
        data[i] = rx_uart_buffer[i];
        uart_put(data[i]);
        key[i]  = rx_uart_buffer[i+16];
      }
			
      /* BENCH */
      timer_1_reset();
      timer_1_init(TIMER_MAX_VALUE);
      timer_1_enable();

      /* CIPHER */
      KeyExpansion(key,w);
      Cipher(data,cipher,w);

      end_time = timer_1_getval();
      timer_1_disable();

      /* INVCIPHER */
      InvCipher(cipher,data2,w);
			
      e_printf("\nCipher:\n");

      /* SEND DATA */
      for (i=0;i<16;i++)
      {
        uart_put(cipher[i]); 
      }
 
      e_printf("\nDecipher:\n");

      /* SEND DATA */
      test = sb_true;
      for(i=0;i<16;i++)
      {
        uart_put(data2[i]);
        if(data2[i] != data[i])
        {       
          test = sb_false; 
        }
      }

      if(test == sb_true)
      {
        e_printf("\nDone successfully in %d ticks\n",end_time*C_S_CLK_DIV);
      }
      else
      {
        e_printf("\nError...\n");
      }

      WRITE_REG32(GPIO_LED_REG,(led & GPIO_LED_BANK));
      led ^=0xFF;

    }

  return 0;
}

