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

#include "e_printf.h"

int e_printf(const char *format, ...)
{ 
  int *varg = (int *)((char **)&format);
  return print(0,varg);
}

int e_sprintf(char *out, const char *format, ...)
{
  int *varg = (int *)((char **)&format);
  return print(&out,varg);
}

void outbyte(char **str, char c)
{
  if(str) 
  {
    **str = c;
    ++(*str);
  }
  else 
  {
    uart_put((sb_uint8_t)c); /* UART for standart output */
  }
}

int prints(char **out, const char *string, int width, int pad)
{
  int pc = 0, padchar = ' ';

  if(width > 0)  
  {
    int len = 0;
    const char *ptr;
    for (ptr = string; *ptr; ++ptr) ++len;
    if (len >= width) 
    {
      width = 0;
    }
    else 
    {
      width -= len;
    }
    if(pad & PAD_ZERO) 
    {
      padchar = '0';
    }
  }
  
  if(!(pad & PAD_RIGHT)) 
  {
    for(;width > 0;--width) 
    {
      outbyte(out,padchar);
      ++pc;
    }
  }
  
  for(;*string;++string) 
  {
    outbyte(out,*string);
    ++pc;
   }
   
  for(;width > 0;--width) 
  {
    outbyte(out,padchar);
    ++pc;
  }

  return pc;
}

int printi(char **out, int i, int b, int sg, int width, int pad, int letbase)
{
  char print_buf[PRINT_BUF_LEN];
  char *s;
  int t, neg = 0, pc = 0;
  unsigned int u = i;

  if(i == 0) 
  {
    print_buf[0] = '0';
    print_buf[1] = '\0';
    return prints(out,print_buf,width,pad);
  }

  if(sg && b == 10 && i < 0) 
  {
    neg = 1;
    u = -i;
  }

  s = print_buf + PRINT_BUF_LEN-1;
  *s = '\0';

  while(u) 
  {
    t = u % b;
    if(t >= 10)
    {
      t += letbase - '0' - 10;
    }
    *--s = t + '0';
    u /= b;
  }

  if(neg) 
  {
    if(width && (pad & PAD_ZERO)) 
    {
      outbyte(out, '-');
      ++pc;
     --width;
    }
    else 
    {
      *--s = '-';
    }
  }

	return pc + prints(out,s,width,pad);
}

int print(char **out, int *varg)
{
  int width, pad;
  int pc = 0;
  char *format = (char *)(*varg++);
  char scr[2];

  for(;*format != 0;++format) 
  {
    if(*format == '%') 
    {
      ++format;
      width = pad = 0;
      if(*format == '\0') 
      {
        break;
      }
      if(*format == '%') 
      {
        goto out;
      }
      if(*format == '-') 
      {
        ++format;
        pad = PAD_RIGHT;
      }
      while (*format == '0') 
      {
        ++format;
        pad |= PAD_ZERO;
      }
      for (;*format >= '0' && *format <= '9';++format) 
      {
        width *= 10;
        width += *format - '0';
      }
      if(*format == 's') 
      {
        char *s = *((char **)varg++);
        pc += prints(out, s?s:"(null)",width,pad);
        continue;
      }  
      if(*format == 'd') 
      {
        pc += printi(out,*varg++,10,1,width,pad,'a');
        continue;
      }
      if(*format == 'x') 
      {
        pc += printi(out,*varg++,16,0,width,pad,'a');
        continue;
      } 
      if(*format == 'X') 
      {
        pc += printi (out,*varg++,16,0,width,pad,'A');
        continue;
      }
      if( *format == 'u' ) 
      {
        pc += printi(out,*varg++,10,0,width,pad,'a');
        continue;
      }
      if(*format == 'c') 
      {
        scr[0] = *varg++;
        scr[1] = '\0';
        pc += prints(out,scr,width,pad);
        continue;
       }
     }
     else 
     {
       out:
       outbyte(out,*format);
       ++pc;
     }
   }
   
   if(out) 
   {
     **out = '\0';
   }
   
   return pc;
}

