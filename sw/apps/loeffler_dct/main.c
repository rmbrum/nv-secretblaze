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
 * \brief 8x8 DCT testbench 
 * \author LIRMM - Lyonel Barthe
 * \version 1.0
 * \date 17/05/2011
 */

#include "sb_types.h"
#include "sb_def.h"
#include "sb_timer.h"
#include "sb_uart.h"

#include "loeffler_8x8_dct.h"

#include "e_printf.h" /* embedded printf */

#define TIMER_MAX_VALUE 0xFFFFFFFF

static const sb_int16_t test_case[64] =		
{
  0,255,0,255,0,255,0,255,
  255,0,255,0,255,0,255,0,
  0,255,0,255,0,255,0,255,
  255,0,255,0,255,0,255,0,
  0,255,0,255,0,255,0,255,
  255,0,255,0,255,0,255,0,
  0,255,0,255,0,255,0,255,
  255,0,255,0,255,0,255,0	
};

int main(void)
{
    
  sb_int32_t  i;
  sb_int16_t  buf[64];
  sb_uint32_t end_time;
  sb_uint8_t  dummy;

  while(sb_true)
  {

    /* DISPLAY INPUT MATRIX */
    e_printf("\nInput = {\n  ");
    for(i=0;i<64;i++)
    {
      if(i%8 == 0 && i != 0)
      {
        e_printf("\n  ");
      }

      e_printf("%d ",test_case[i]);

      buf[i] = test_case[i];
    }
    e_printf("\n}\n\n");

    /* BENCH */
    timer_1_reset();
    timer_1_init(TIMER_MAX_VALUE);
    timer_1_enable();

    /* DCT */
    loeffler_8x8_dct(buf);

    /* END BENCH */
    end_time = timer_1_getval();
    timer_1_disable();

    /* DISPLAY OUTPUT MATRIX */
    e_printf("Output = {\n  ");
    for(i=0;i<64;i++)
    {
      if(i%8 == 0 && i != 0)
      {
        e_printf("\n  ");
      }

      e_printf("%d ",buf[i]);
    }
    e_printf("\n}\n\n");

     /* DISPLAY BENCH RESULT */
    e_printf("%d ticks\n",end_time*C_S_CLK_DIV);

    uart_get(&dummy);

  }

  return 0;
}

