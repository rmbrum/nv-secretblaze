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

#include "aes.h"

void RotWord(sb_uint8_t w[4])
{
  sb_uint8_t buf;

  /* << 1 */
  buf  = w[0];
  w[0] = w[1];
  w[1] = w[2];
  w[2] = w[3];
  w[3] = buf;
}

void SubWord(sb_uint8_t w[4])
{
  w[0] = Sbox[w[0]];
  w[1] = Sbox[w[1]];
  w[2] = Sbox[w[2]];
  w[3] = Sbox[w[3]];
}

void KeyExpansion(const sb_uint8_t key[4*Nk], sb_uint8_t w[4][Nb*(Nr+1)])
{
  sb_int32_t i;
  sb_uint8_t temp[4];

  i = 0;
  while(i < Nk)
  {
    w[0][i] = key[4*i];
    w[1][i] = key[4*i+1];
    w[2][i] = key[4*i+2];
    w[3][i] = key[4*i+3];
    i++;
  }

  i = Nk;
  while(i < Nb * (Nr+1))
  {
    temp[0] = w[0][i-1];
    temp[1] = w[1][i-1];
    temp[2] = w[2][i-1];
    temp[3] = w[3][i-1];

    if(i % Nk == 0)
    {
      RotWord(temp);
      SubWord(temp);
      temp[0] ^= Rcon[i/Nk];
    }
    else if(Nk > 6 && (i % Nk == 4))
    {
      SubWord(temp);
    }

    w[0][i] = w[0][i-Nk] ^ temp[0];
    w[1][i] = w[1][i-Nk] ^ temp[1];
    w[2][i] = w[2][i-Nk] ^ temp[2];
    w[3][i] = w[3][i-Nk] ^ temp[3];
	 	
    i++;
  }
}

void Cipher(const sb_uint8_t dat_i[4*Nb], sb_uint8_t dat_o[4*Nb], sb_uint8_t w[4][Nb*(Nr+1)])
{
  sb_int32_t i,j;
  sb_uint8_t state[4][Nb];

  /* PROLOGUE */	
  for(i=0;i<Nb;i++)
  {
    for(j=0;j<4;j++)
    {
      state[j][i] = dat_i[i*Nb+j];
    }	
  }

  /* KERNEL */
  AddRoundKey(state,w,0);

  for(i=1;i<Nr;i++)
  {
    SubBytes(state);
    ShiftRows(state);
    MixColumns(state);
    AddRoundKey(state,w,i);
  }

  SubBytes(state);
  ShiftRows(state);
  AddRoundKey(state,w,Nr);

  /* EPILOGUE */	
  for(i=0;i<Nb;i++)
  {
    for(j=0;j<4;j++)
    {
      dat_o[i*Nb+j] = state[j][i];
    }	
  }
}

void SubBytes(sb_uint8_t state[4][Nb])
{
  sb_int32_t i,j;

  for(i=0;i<Nb;i++)
  {
    for(j=0;j<4;j++)
    {
      state[j][i] = Sbox[state[j][i]];
    }	
  }
}

void AddRoundKey(sb_uint8_t state[4][Nb], sb_uint8_t w[4][Nb*(Nr+1)], const sb_int32_t round)
{
  sb_int32_t i,j;

  for(i=0;i<Nb;i++)
  {
    for(j=0;j<4;j++)
    {
      state[j][i] ^= w[j][round*Nb+i];
    }	
  }	
}


void ShiftRows(sb_uint8_t state[4][Nb])
{
  sb_uint8_t buf;

  /* << 1 */
  buf         = state[1][0];
  state[1][0] = state[1][1];
  state[1][1] = state[1][2];
  state[1][2] = state[1][3];
  state[1][3] = buf;

  /* << 2 */
  buf         = state[2][0];
  state[2][0] = state[2][2];
  state[2][2] = buf;
  buf         = state[2][1];
  state[2][1] = state[2][3];
  state[2][3] = buf;

  /* << 3 */
  buf         = state[3][0];
  state[3][0] = state[3][3];
  state[3][3] = state[3][2];
  state[3][2] = state[3][1];
  state[3][1] = buf;
}

void MixColumns(sb_uint8_t state[4][Nb])
{
  sb_int32_t i; 
  sb_uint8_t buf0,buf1,buf2,buf3;

  for(i=0;i<4;i++)
  {
    buf0 = state[0][i];
    buf1 = state[1][i];
    buf2 = state[2][i];
    buf3 = state[3][i];
    state[0][i] = Mult2GF(buf0) ^ Mult3GF(buf1) ^ buf2 ^ buf3;
    state[1][i] = buf0 ^ Mult2GF(buf1) ^ Mult3GF(buf2) ^ buf3;
    state[2][i] = buf0 ^ buf1 ^ Mult2GF(buf2) ^ Mult3GF(buf3);
    state[3][i] = Mult3GF(buf0) ^ buf1 ^ buf2 ^ Mult2GF(buf3);
  }
}

void InvCipher(const sb_uint8_t dat_i[4*Nb], sb_uint8_t dat_o[4*Nb], sb_uint8_t w[4][Nb*(Nr+1)])
{
  sb_int32_t i,j;
  sb_uint8_t state[4][Nb];

  /* PROLOGUE */	
  for(i=0;i<Nb;i++)
  { 
    for(j=0;j<4;j++)
    {
      state[j][i] = dat_i[i*Nb+j];
    }	
  }

  /* KERNEL */
  AddRoundKey(state,w,Nr);

  for(i=(Nr-1);i>0;i--)
  {
    InvShiftRows(state);
    InvSubBytes(state);
    AddRoundKey(state,w,i);
    InvMixColumns(state);
  }

  InvShiftRows(state);
  InvSubBytes(state);
  AddRoundKey(state,w,0);

  /* EPILOGUE */	
  for(i=0;i<Nb;i++)
  {
    for(j=0;j<4;j++)
    {
      dat_o[i*Nb+j] = state[j][i];
    }	
  }
}

void InvSubBytes(sb_uint8_t state[4][Nb])
{
  sb_int32_t i,j;

  for(i=0;i<Nb;i++)
  {
    for(j=0;j<4;j++)
    {
      state[j][i] = InvSbox[state[j][i]];
    }
  }
}

void InvShiftRows(sb_uint8_t state[4][Nb])
{
  sb_uint8_t buf;

  /* >> 1 */
  buf         = state[1][3];
  state[1][3] = state[1][2];
  state[1][2] = state[1][1];
  state[1][1] = state[1][0];
  state[1][0] = buf;

  /* >> 2 */
  buf         = state[2][2];
  state[2][2] = state[2][0];
  state[2][0] = buf;
  buf         = state[2][1];
  state[2][1] = state[2][3];
  state[2][3] = buf;

  /* >> 3 */
  buf         = state[3][1];
  state[3][1] = state[3][2];
  state[3][2] = state[3][3];
  state[3][3] = state[3][0];
  state[3][0] = buf;
}

void InvMixColumns(sb_uint8_t state[4][Nb])
{
  sb_int32_t i;
  sb_uint8_t buf0,buf1,buf2,buf3;

  for(i=0;i<4;i++)
  {
    buf0 = state[0][i];
    buf1 = state[1][i];
    buf2 = state[2][i];
    buf3 = state[3][i];
    state[0][i] = MultGF(buf0,0xE) ^ MultGF(buf1,0xB) ^ MultGF(buf2,0xD) ^ MultGF(buf3,0x9);
    state[1][i] = MultGF(buf0,0x9) ^ MultGF(buf1,0xE) ^ MultGF(buf2,0xB) ^ MultGF(buf3,0xD);
    state[2][i] = MultGF(buf0,0xD) ^ MultGF(buf1,0x9) ^ MultGF(buf2,0xE) ^ MultGF(buf3,0xB);
    state[3][i] = MultGF(buf0,0xB) ^ MultGF(buf1,0xD) ^ MultGF(buf2,0x9) ^ MultGF(buf3,0xE);
  }
}

sb_uint8_t Mult2GF(const sb_uint8_t val)
{
  return ((val<<1) ^ (((val>>7) & 1) * 0x1b));
}

sb_uint8_t Mult3GF(const sb_uint8_t val)
{	
  return (Mult2GF(val) ^ val);
}

sb_uint8_t MultGF(const sb_uint8_t a, const sb_uint8_t b)
{
  sb_int32_t i;
  sb_uint8_t res = 0;
  sb_uint8_t a_buf = a;
  sb_uint8_t b_buf = b;
  sb_uint8_t sign_a;

  for(i=0;i<8;i++) 
  {
    if((b_buf & 1) == 1)
    { 
      res ^= a_buf;
    }

    sign_a = (a_buf & 0x80);
    a_buf <<= 1;

    if((sign_a == 0x80))
    {
      a_buf ^= 0x1b;
    } 

    b_buf >>= 1;
  }

  return res;
}


