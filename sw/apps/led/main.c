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

#include "sb_io.h"
#include "sb_def.h"
#include "sb_types.h"

/**
 * \file main.c
 * \brief LED testbench
 * \author LIRMM - Lyonel Barthe
 * \version 1.0
 * \date 10/01/2010
 */

int main()
{
  
  sb_int32_t led_o;
  sb_int32_t but_i;
  sb_int32_t i;

  /* initial value  */
  led_o = GPIO_LED0_BIT;

  while(sb_true)
  {

    /* write led */
    WRITE_REG32(GPIO_LED_REG,(led_o & GPIO_LED_BANK));

    /* wait */
    for(i=0;i<0xFFFFF;i++)
    {
      __asm__ __volatile__ ("NOP;");
    }

    /* read direction */
    but_i = READ_REG32(GPIO_BUT_REG);

    if((but_i & GPIO_BUT0_BIT) == GPIO_BUT0_BIT)
    {
      led_o >>= 1;

      if(led_o == 0x0)
      {
        led_o = GPIO_LED7_BIT;
      }
    }
    else
    {
      led_o <<= 1;

      if(led_o == 0x100)
      {
        led_o = GPIO_LED0_BIT;
      }
    }
  }

  return 0;
}

