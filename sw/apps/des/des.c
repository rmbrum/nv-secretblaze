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

#include "des.h"

/**
 * \fn sb_uint64_t do_perm(const sb_uint64_t data, const sb_uint8_t *const table, const sb_uint32_t size_data_in, const sb_uint32_t size_data_out)
 * \brief Compute permutation for a given input vector
 * \param[in] data Input
 * \param[in] table Permutation Table
 * \param[in] size_data_in Size Input
 * \param[in] size_data_out Size Output
 * \return sb_uint64_t Result 
 */
sb_uint64_t do_perm(const sb_uint64_t data, const sb_uint8_t *const table, const sb_uint32_t size_data_in, const sb_uint32_t size_data_out)
{
  sb_uint32_t i;
  sb_uint8_t data_tmp;
	
  sb_uint64_t data_res = 0; 
	
  /* COMPUTE PERM */
  for(i=0;i<size_data_out;i++)
  {
    SEL_BIT(data,data_tmp,(size_data_in-table[i]));
    data_res |= ((sb_uint64_t)data_tmp << (size_data_out-1-i));
  }
	
  return data_res;
}

/**
 * \fn sb_uint64_t do_key(sb_uint64_t *const key, const sb_uint32_t round, const sb_uint32_t mode)
 * \brief DES key generator
 * \param[in,out] key 56-bit input/output key
 * \param[in] round Current DES round 
 * \param[in] mode DES mode
 * \return sb_uint64_t 48-bit subkey 
 */
sb_uint64_t do_key(sb_uint64_t *const key, const sb_uint32_t round, const sb_uint32_t mode)
{
  sb_uint32_t key_l,key_r;

  sb_uint64_t subkey = 0; 

  /* RIGHT */
  key_r = (sb_uint32_t)(*key & KEY_BIT_WIDTH_2_MASK);
	
  /* LEFT */
  key_l = (sb_uint32_t)(*key >> KEY_BIT_WIDTH_2);
	
  switch (mode) 
  {

    case MODE_CIPHER:		
      key_r = ((key_r << encrypt_rotate_tab[round]) | (key_r >> (KEY_BIT_WIDTH_2 - encrypt_rotate_tab[round]))) & KEY_BIT_WIDTH_2_MASK;
      key_l = ((key_l << encrypt_rotate_tab[round]) | (key_l >> (KEY_BIT_WIDTH_2 - encrypt_rotate_tab[round]))) & KEY_BIT_WIDTH_2_MASK;
      break;

    case MODE_DECIPHER:
      key_r = ((key_r >> decrypt_rotate_tab[round]) | (key_r << (KEY_BIT_WIDTH_2 - decrypt_rotate_tab[round]))) & KEY_BIT_WIDTH_2_MASK;
      key_l = ((key_l >> decrypt_rotate_tab[round]) | (key_l << (KEY_BIT_WIDTH_2 - decrypt_rotate_tab[round]))) & KEY_BIT_WIDTH_2_MASK;
      break;

    default:
      /* assert(0); */
      break;
  } 
	
  /* UPDATE KEY */
  *key = (((sb_uint64_t)key_l << KEY_BIT_WIDTH_2) | key_r);
	
  /* SUB KEY */
  subkey = do_perm(*key, pc2_table_c, KEY_BIT_WIDTH, SUBKEY_BIT_WIDTH);
	
  return subkey;
}

/**
 * \fn void do_round(sb_uint64_t *const data, const sb_uint64_t key)
 * \brief DES round implementation
 * \param[in,out] data 64-bit input/output vector
 * \param[in] key 48-bit subkey
 */
void do_round(sb_uint64_t *const data, const sb_uint64_t key)
{
  sb_uint32_t left,right;
  sb_uint32_t new_left, new_right;
	
  left = (sb_uint32_t)(*data >> DATA_BIT_WIDTH_2);
  right = (sb_uint32_t)(*data & DATA_BIT_WIDTH_2_MASK);
	
  /* UPDATE LEFT */ 
  new_left = right;
	
  /* UPDATE RIGHT */
  do_feistel(&right, key);
  new_right = right^left;
	
  /* RES */
  *data = (((sb_uint64_t)new_left << DATA_BIT_WIDTH_2)) | new_right;
}

/**
 * \fn void do_feistel(sb_uint32_t *const data, const sb_uint64_t key)
 * \brief DES Feistel implementation
 * \param[in,out] data 64-bit input/output vector
 * \param[in] key 48-bit subkey
 */
void do_feistel(sb_uint32_t *const data, const sb_uint64_t key)
{
  sb_uint64_t data_xor_key,exp_data;
  sb_uint8_t ind;

  sb_uint64_t sbox_out = 0;

  /* EXP */
  exp_data = do_perm((sb_uint64_t)(*data), exp_table_c, DATA_BIT_WIDTH_2, EXP_BIT_WIDTH);
	
  /* XOR */
  data_xor_key = (exp_data^key);
	
  /* SBOX */
  ind = data_xor_key & SBOX_IN_BIT_WIDTH_MASK;
  ind = ((ind & 0x20) | ((ind & 0x1) << 4) | ((ind & 0x1E) >> 1));
  sbox_out |= sbox8[ind];
	
  ind = (data_xor_key >> SBOX_IN_BIT_WIDTH) & SBOX_IN_BIT_WIDTH_MASK;
  ind = ((ind & 0x20) | ((ind & 0x1) << 4) | ((ind & 0x1E) >> 1));
  sbox_out |= sbox7[ind] << SBOX_OUT_BIT_WIDTH;
	
  ind = (data_xor_key >> 2*SBOX_IN_BIT_WIDTH) & SBOX_IN_BIT_WIDTH_MASK;
  ind = ((ind & 0x20) | ((ind & 0x1) << 4) | ((ind & 0x1E) >> 1));
  sbox_out |= sbox6[ind] << 2*SBOX_OUT_BIT_WIDTH;
	
  ind = (data_xor_key >> 3*SBOX_IN_BIT_WIDTH) & SBOX_IN_BIT_WIDTH_MASK;
  ind = ((ind & 0x20) | ((ind & 0x1) << 4) | ((ind & 0x1E) >> 1));
  sbox_out |= sbox5[ind] << 3*SBOX_OUT_BIT_WIDTH;
	
  ind = (data_xor_key >> 4*SBOX_IN_BIT_WIDTH) & SBOX_IN_BIT_WIDTH_MASK;
  ind = ((ind & 0x20) | ((ind & 0x1) << 4) | ((ind & 0x1E) >> 1));
  sbox_out |= sbox4[ind] << 4*SBOX_OUT_BIT_WIDTH;
	
  ind = (data_xor_key >> 5*SBOX_IN_BIT_WIDTH) & SBOX_IN_BIT_WIDTH_MASK;
  ind = ((ind & 0x20) | ((ind & 0x1) << 4) | ((ind & 0x1E) >> 1));
  sbox_out |= sbox3[ind] << 5*SBOX_OUT_BIT_WIDTH;
	
  ind = (data_xor_key >> 6*SBOX_IN_BIT_WIDTH) & SBOX_IN_BIT_WIDTH_MASK;
  ind = ((ind & 0x20) | ((ind & 0x1) << 4) | ((ind & 0x1E) >> 1));
  sbox_out |= sbox2[ind] << 6*SBOX_OUT_BIT_WIDTH;

  ind = (data_xor_key >> 7*SBOX_IN_BIT_WIDTH) & SBOX_IN_BIT_WIDTH_MASK;
  ind = ((ind & 0x20) | ((ind & 0x1) << 4) | ((ind & 0x1E) >> 1));
  sbox_out |= sbox1[ind] << 7*SBOX_OUT_BIT_WIDTH;
	
  /* PERM */
  *data = do_perm(sbox_out, sbox_p_table_c, DATA_BIT_WIDTH_2, DATA_BIT_WIDTH_2);
	
}

/**
 * \fn sb_uint64_t do_des(const sb_uint64_t data, const sb_uint64_t key, const sb_uint32_t mode)
 * \brief DES algorithm
 * \param[in] data 64-bit input vector
 * \param[in] key 64-bit key
 * \param[in] mode DES mode
 * \return sb_uint64_t Output vector
 */
sb_uint64_t do_des(const sb_uint64_t data, const sb_uint64_t key, const sb_uint32_t mode)
{
  sb_uint64_t data_res;
  sb_uint64_t key_56;
  sb_uint64_t subkey[NB_ROUND],data_tmp;
  sb_uint32_t swap_l,swap_r;
  sb_uint32_t i;
	
  /* 
     KEY PROCESS
  */
	
  /* PERM CHOICE 1 */
  key_56 = do_perm(key, pc1_table_c, DATA_BIT_WIDTH, PC1_BIT_WIDTH);
	
  /* KEY SCHED */
  for(i=0;i<NB_ROUND;i++)
  {
    subkey[i] = do_key(&key_56,i,mode);
  }
	
  /*
    DATA PROCESS
  */
	
  /* INITIAL PERMUTATION */
  data_tmp = do_perm(data, ip_table_c, DATA_BIT_WIDTH, IP_BIT_WIDTH);
	
  /* 16 ROUND */
  for(i=0;i<NB_ROUND;i++)
  {

    /* DATA COMPUTATION */
    do_round(&data_tmp, subkey[i]);
  }
	
  /* SWAP */
  swap_r = (data_tmp >> DATA_BIT_WIDTH_2);
  swap_l = (data_tmp & DATA_BIT_WIDTH_2_MASK);
  data_tmp = ((sb_uint64_t)swap_l << DATA_BIT_WIDTH_2) | swap_r;
	
  /* FINAL PERMUTATION */
  data_res = do_perm(data_tmp, fp_table_c, DATA_BIT_WIDTH, FP_BIT_WIDTH);
	
  return data_res;
}



