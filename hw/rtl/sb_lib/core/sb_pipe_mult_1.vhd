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
--! @file sb_pipe_mult_1.vhd                                      					
--! @brief SecretBlaze First Stage Pipelined Multiplier Unit 
--! @author Lyonel Barthe
--! @version 1.0
--                                                                 
-----------------------------------------------------------------
-----------------------------------------------------------------

--
-- Revision History
--
-- Version 1.0 22/02/2011 by Lyonel Barthe
-- Initial Release 
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library sb_lib;
use sb_lib.sb_core_pack.all;

library config_lib;
use config_lib.sb_config.all;

--
--! This module implements the first stage of the pipelined 32/64-bit 
--! multiplier using 17x17 signed multipliers. Partial 16-bit products 
--! are computed in this stage.
--!
--! More detailed information about its implementation are given in:
--! Lyonel Barthe et al., "Optimizing an Open-Source Processor for FPGAs: 
--! A Case Study," FPL, pp. 551-556, 2011.
--

--! SecretBlaze First Stage Pipelined Multiplier Entity
entity sb_pipe_mult_1 is

  generic
    (
      USE_MULT   : natural := USER_USE_MULT --! 0 -> no HW mult, 1 -> LSW HW mult, 2 -> full HW mult
    );  

  port
    (  
      op_a_i     : in data_t;               --! mult first operand input
      op_b_i     : in data_t;               --! mult second operand input 
      part_res_o : out pipe_mult_t;         --! mult partial results output
      control_i  : in mult_control_t        --! mult control input   
    );  
  
end sb_pipe_mult_1;

--! SecretBlaze Second Stage Pipelined Multiplier Architecture
architecture be_sb_pipe_mult_1 of sb_pipe_mult_1 is

  -- //////////////////////////////////////////
  --               INTERNAL WIRES
  -- //////////////////////////////////////////

  signal part_ll_res_s : mult_part_res_t;
  signal part_lu_res_s : mult_part_res_t;
  signal part_ul_res_s : mult_part_res_t;
  signal part_uu_res_s : mult_part_res_t;
  signal op_a_u_ext_s  : mult_part_data_ext_t;
  signal op_a_l_ext_s  : mult_part_data_ext_t;
  signal op_b_u_ext_s  : mult_part_data_ext_t;
  signal op_b_l_ext_s  : mult_part_data_ext_t;
   
begin

  -- //////////////////////////////////////////
  --                COMB PROCESS
  -- //////////////////////////////////////////

  --
  -- ASSIGN OUTPUT SIGNALS
  --
  
  part_res_o.part_ll_res <= part_ll_res_s;
  part_res_o.part_lu_res <= part_lu_res_s;
  part_res_o.part_ul_res <= part_ul_res_s;
  part_res_o.part_uu_res <= part_uu_res_s;

  GEN_MULT_LSW: if(USE_MULT = 1) generate

    --
    -- PARTIAL OP SIGNED EXTEND
    -- 
    --! This process implements the sign extension process of operands to implement 
    --! pipelined 32-bit multiplications using 17x17 bit SIGNED multipliers.
    COMB_PART_OP_EXT: process(op_a_i,
                              op_b_i,
                              control_i)
    begin

        op_a_u_ext_s <= (op_a_i(data_t'left) & op_a_i(data_t'length - 1 downto data_t'length/2));
        op_a_l_ext_s <= ('0' & op_a_i(data_t'length/2 - 1 downto 0));
        op_b_u_ext_s <= (op_b_i(data_t'left) & op_b_i(data_t'length - 1 downto data_t'length/2));
        op_b_l_ext_s <= ('0' & op_b_i(data_t'length/2 - 1 downto 0));

    end process COMB_PART_OP_EXT;

    --
    -- MULT PARTIAL RESULTS
    -- 
    --! This process computes mult partial results for signed 32-bit multiplications. 
    --! Note that the MSB product is not required there.
    COMB_PIPE_MULT_1: process(op_a_l_ext_s,
                              op_a_u_ext_s,
                              op_b_l_ext_s,
                              op_b_u_ext_s)

    begin

      part_ll_res_s <= std_ulogic_vector(signed(op_a_l_ext_s) * signed(op_b_l_ext_s));
      part_lu_res_s <= std_ulogic_vector(signed(op_a_l_ext_s) * signed(op_b_u_ext_s));
      part_ul_res_s <= std_ulogic_vector(signed(op_a_u_ext_s) * signed(op_b_l_ext_s));
      part_uu_res_s <= (others => 'X'); 

    end process COMB_PIPE_MULT_1;

  end generate GEN_MULT_LSW;

  GEN_MULT_FULL: if(USE_MULT > 1) generate

    --
    -- PARTIAL OP SIGNED EXTEND
    -- 
    --! This process implements the sign extension process of operands to implement pipelined 64-bit
    --! multiplications using 17x17 bit SIGNED multipliers.
    COMB_PART_OP_EXT: process(op_a_i,
                              op_b_i,
                              control_i)
    begin

      op_a_l_ext_s <= ('0' & op_a_i(data_t'length/2 - 1 downto 0));
      op_b_l_ext_s <= ('0' & op_b_i(data_t'length/2 - 1 downto 0));

      case control_i is

        when MULT_LSW | MULT_HSW_SS =>
          op_a_u_ext_s <= (op_a_i(data_t'left) & op_a_i(data_t'length - 1 downto data_t'length/2));
          op_b_u_ext_s <= (op_b_i(data_t'left) & op_b_i(data_t'length - 1 downto data_t'length/2));
                      
        when MULT_HSW_SU =>
          op_a_u_ext_s <= (op_a_i(data_t'left) & op_a_i(data_t'length - 1 downto data_t'length/2));
          op_b_u_ext_s <= ('0' & op_b_i(data_t'length - 1 downto data_t'length/2));
                      
        when MULT_HSW_UU =>
          op_a_u_ext_s <= ('0' & op_a_i(data_t'length - 1 downto data_t'length/2));
          op_b_u_ext_s <= ('0' & op_b_i(data_t'length - 1 downto data_t'length/2));
        
        when others =>
          op_a_u_ext_s <= (others => 'X');
          op_a_u_ext_s <= (others => 'X');
          report "mult entity: illegal mult control code!" severity warning;
        
      end case;

    end process COMB_PART_OP_EXT;

    --
    -- MULT PARTIAL RESULTS
    -- 
    --! This process computes mult partial results for both unsigned/signed 64-bit multiplications. 
    COMB_PIPE_MULT_1: process(op_a_l_ext_s,
                              op_a_u_ext_s,
                              op_b_l_ext_s,
                              op_b_u_ext_s)

    begin

      part_ll_res_s <= std_ulogic_vector(signed(op_a_l_ext_s) * signed(op_b_l_ext_s));
      part_lu_res_s <= std_ulogic_vector(signed(op_a_l_ext_s) * signed(op_b_u_ext_s));
      part_ul_res_s <= std_ulogic_vector(signed(op_a_u_ext_s) * signed(op_b_l_ext_s));
      part_uu_res_s <= std_ulogic_vector(signed(op_a_u_ext_s) * signed(op_b_u_ext_s)); 

    end process COMB_PIPE_MULT_1;

  end generate GEN_MULT_FULL;
           
end be_sb_pipe_mult_1;

