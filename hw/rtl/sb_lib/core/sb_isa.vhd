--
--    ADAC Research Group - LIRMM - University of Montpellier / CNRS 
--    contact: adac@lirmm.fr
--
--    This file is part of SecretBlaze.
--
--    SecretBlaze is free software: you can redistribute it and/or modify
--    it under the terms of the GNU General Public License as published by
--    the Free Software Foundation, either version 3 of the License, or
--    (at your option) any later version.
--
--    SecretBlaze is distributed in the hope that it will be useful,
--    but WITHOUT ANY WARRANTY; without even the implied warranty of
--    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--    GNU General Public License for more details.
--
--    You should have received a copy of the GNU General Public License
--    along with SecretBlaze.  If not, see <http://www.gnu.org/licenses/>.
--

-----------------------------------------------------------------
-----------------------------------------------------------------
--                                                             
--! @file sb_isa.vhd                                					
--! @brief SecretBlaze Instruction Set Assembly Defines    				
--! @author Lyonel Barthe
--! @version 1.0
--                                                                
-----------------------------------------------------------------
-----------------------------------------------------------------

--
-- Revision History
--
-- Version 1.0 13/05/2010 by Lyonel Barthe
-- Stable version
--
-- Version 0.1 12/02/2010 by Lyonel Barthe
-- Initial release
--

library ieee;
use ieee.std_logic_1164.all;

--
--! The package implements usefull defines for the SecretBlaze/MicroBlaze 
--! Instruction Set Assembly (ISA).
--

--! SecretBlaze ISA Package
package sb_isa is 

  -- //////////////////////////////////////////////////////////////////
  --
  -- A-type:
  --

  --  0         5 6     10 11      15 16     20 21                   31
  -- +----------------------------------------------------------------+
  -- |  opcode   |   rd   |   rsa    |   rsb   |         ext          |
  -- +----------------------------------------------------------------+
  --
  -- //////////////////////////////////////////////////////////////////

  -- //////////////////////////////////////////////////////////////////
  --
  -- B-type:
  --
  
  --  0         5 6     10 11     15 16                              31
  -- +----------------------------------------------------------------+
  -- |  opcode   |   rd   |   rsa   |               imm16             |
  -- +----------------------------------------------------------------+
  --
  -- //////////////////////////////////////////////////////////////////

  --
  -- ISA constants
  --

  constant OP_CODE_W : natural := 6;   
  constant OP_R_W    : natural := 5;   
  constant OP_IMM_W  : natural := 16;
  constant OP_EXT_W  : natural := 10;
  
  --
  -- ISA subtypes
  --
  
  subtype opcode_t is std_ulogic_vector(OP_CODE_W - 1 downto 0); --! cpu opcode type
  subtype op_reg_t is std_ulogic_vector(OP_R_W - 1 downto 0);    --! cpu register id type
  subtype op_imm_t is std_ulogic_vector(OP_IMM_W - 1 downto 0);  --! cpu imm content type
  subtype op_ext_t is std_ulogic_vector(OP_EXT_W - 1 downto 0);  --! cpu ext type 

  --
  -- ISA opcodes
  --
  
  -- logical
  constant op_or     : opcode_t := "100000";
  constant op_and    : opcode_t := "100001";
  constant op_xor    : opcode_t := "100010";
  constant op_andn   : opcode_t := "100011";  
  constant op_ori    : opcode_t := "101000";
  constant op_andi   : opcode_t := "101001";
  constant op_xori   : opcode_t := "101010";
  constant op_andni  : opcode_t := "101011";  

  -- arith
  constant op_add    : opcode_t := "000000";
  constant op_rsub   : opcode_t := "000001";
  constant op_addc   : opcode_t := "000010";
  constant op_rsubc  : opcode_t := "000011";
  constant op_addk   : opcode_t := "000100";  
  constant op_rsubk  : opcode_t := "000101";
  constant op_addkc  : opcode_t := "000110";
  constant op_rsubkc : opcode_t := "000111";
  constant op_addi   : opcode_t := "001000";
  constant op_rsubi  : opcode_t := "001001";
  constant op_addci  : opcode_t := "001010";
  constant op_rsubci : opcode_t := "001011";
  constant op_addki  : opcode_t := "001100";  
  constant op_rsubki : opcode_t := "001101";
  constant op_addkci : opcode_t := "001110";
  constant op_rsubkci: opcode_t := "001111";
  constant op_cmp    : opcode_t := "000101";  -- op_rsubk
  constant op_cmpu   : opcode_t := "000101";  -- op_rsubk
  constant op_mul    : opcode_t := "010000";
  constant op_mulh   : opcode_t := "010000";  -- op_mul
  constant op_mulhu  : opcode_t := "010000";  -- op_mul
  constant op_mulhsu : opcode_t := "010000";  -- op_mul
  constant op_muli   : opcode_t := "011000";
  constant op_idiv   : opcode_t := "010010";  
  constant op_idivu  : opcode_t := "010010";  -- op_idiv

  -- pattern
  constant op_pcmpbf : opcode_t := "100000";  -- op_or
  constant op_pcmpeq : opcode_t := "100010";  -- op_xor
  constant op_pcmpne : opcode_t := "100011";  -- op_andn
  constant op_clz    : opcode_t := "100100";  -- op_sra

  -- shift
  constant op_bsra   : opcode_t := "010001";
  constant op_bsll   : opcode_t := "010001";  -- op_bsll
  constant op_bsrli  : opcode_t := "011001";  
  constant op_bsrai  : opcode_t := "011001";  -- op_bsrli
  constant op_bslli  : opcode_t := "011001";  -- op_bsrli
  constant op_sra    : opcode_t := "100100";
  constant op_src    : opcode_t := "100100";  -- op_sra
  constant op_srl    : opcode_t := "100100";  -- op_sra

  -- sign ext
  constant op_sext8  : opcode_t := "100100";  -- op_sra
  constant op_sext16 : opcode_t := "100100";  -- op_sra

  -- imm
  constant op_imm    : opcode_t := "101100";

  -- branch
  constant op_br     : opcode_t := "100110";
  constant op_brd    : opcode_t := "100110";  -- op_br
  constant op_brld   : opcode_t := "100110";  -- op_br
  constant op_bra    : opcode_t := "100110";  -- op_br
  constant op_brad   : opcode_t := "100110";  -- op_br
  constant op_brald  : opcode_t := "100110";  -- op_br
  -- constant op_brk    : opcode_t := "100110";  -- op_br / not implemented
  constant op_beq    : opcode_t := "100111";
  constant op_bne    : opcode_t := "100111";  -- op_beq
  constant op_blt    : opcode_t := "100111";  -- op_beq
  constant op_ble    : opcode_t := "100111";  -- op_beq
  constant op_bgt    : opcode_t := "100111";  -- op_beq
  constant op_bge    : opcode_t := "100111";  -- op_beq
  constant op_beqd   : opcode_t := "100111";  -- op_beq
  constant op_bned   : opcode_t := "100111";  -- op_beq
  constant op_bltd   : opcode_t := "100111";  -- op_beq
  constant op_bled   : opcode_t := "100111";  -- op_beq
  constant op_bgtd   : opcode_t := "100111";  -- op_beq
  constant op_bged   : opcode_t := "100111";  -- op_beq
  constant op_bri    : opcode_t := "101110";
  constant op_brid   : opcode_t := "101110";  -- op_bri
  constant op_brlid  : opcode_t := "101110";  -- op_bri
  constant op_brai   : opcode_t := "101110";  -- op_bri
  constant op_braid  : opcode_t := "101110";  -- op_bri
  constant op_bralid : opcode_t := "101110";  -- op_bri
  -- constant op_brki   : opcode_t := "101110"; -- op_bri / not implemented
  constant op_beqi   : opcode_t := "101111";
  constant op_bnei   : opcode_t := "101111";  -- op_beqi
  constant op_blti   : opcode_t := "101111";  -- op_beqi
  constant op_blei   : opcode_t := "101111";  -- op_beqi
  constant op_bgti   : opcode_t := "101111";  -- op_beqi
  constant op_bgei   : opcode_t := "101111";  -- op_beqi
  constant op_beqid  : opcode_t := "101111";  -- op_beqi
  constant op_bneid  : opcode_t := "101111";  -- op_beqi
  constant op_bltid  : opcode_t := "101111";  -- op_beqi
  constant op_bleid  : opcode_t := "101111";  -- op_beqi
  constant op_bgtid  : opcode_t := "101111";  -- op_beqi
  constant op_bgeid  : opcode_t := "101111";  -- op_beqi

  -- load/store
  constant op_lbu    : opcode_t := "110000";
  constant op_lhu    : opcode_t := "110001";
  constant op_lw     : opcode_t := "110010";
  -- constant op_lwx    : opcode_t := "110010"; -- not implemented
  constant op_sb     : opcode_t := "110100";
  constant op_sh     : opcode_t := "110101";
  constant op_sw     : opcode_t := "110110";
  -- constant op_swx    : opcode_t := "110110"; -- not implemented
  constant op_lbui   : opcode_t := "111000";
  constant op_lhui   : opcode_t := "111001";
  constant op_lwi    : opcode_t := "111010";
  constant op_sbi    : opcode_t := "111100";
  constant op_shi    : opcode_t := "111101";
  constant op_swi    : opcode_t := "111110";

  -- return
  constant op_rtid   : opcode_t := "101101";  
  constant op_rtsd   : opcode_t := "101101";  -- op_rtid 

  -- special purpose register instructions 
  constant op_mfs    : opcode_t := "100101";   
  constant op_mts    : opcode_t := "100101";  -- op_mfs 
  constant op_msrclr : opcode_t := "100101";  -- op_mfs 
  constant op_msrset : opcode_t := "100101";  -- op_mfs 

  -- special cache instructions
  constant op_wdc    : opcode_t := "100100";  -- op_sra
  constant op_wic    : opcode_t := "100100";  -- op_sra

end package sb_isa;

