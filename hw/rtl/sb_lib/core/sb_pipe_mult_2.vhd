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
--! @file sb_pipe_mult_2.vhd                                      					
--! @brief SecretBlaze Second Stage Pipelined Multiplier Unit 
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
--! This module implements the second stage of the pipelined 32/64-bit 
--! multiplier using 17x17 signed multipliers. Within this stage, the 
--! result of the multiplication is computed from partial products.
--!
--! More detailed information about its implementation are given in:
--! Lyonel Barthe et al., "Optimizing an Open-Source Processor for FPGAs: 
--! A Case Study," FPL, pp. 551-556, 2011.
--

--! SecretBlaze Second Stage Pipelined Multiplier Entity
entity sb_pipe_mult_2 is

  generic
    (
      USE_MULT   : natural := USER_USE_MULT --! 0 -> no HW mult, 1 -> LSW HW mult, 2 -> full HW mult
    );  

  port
    (  
      part_res_i : in pipe_mult_t;          --! mult partial results input
      res_o      : out data_t;              --! mult result output
      control_i  : in mult_control_t        --! mult control input   
    );  
  
end sb_pipe_mult_2;

--! SecretBlaze Second Stage Pipelined Multiplier Architecture
architecture be_sb_pipe_mult_2 of sb_pipe_mult_2 is

  -- //////////////////////////////////////////
  --               INTERNAL WIRES
  -- //////////////////////////////////////////
   
  signal res_s : data_t;

begin

  -- //////////////////////////////////////////
  --                COMB PROCESS
  -- //////////////////////////////////////////

  --
  -- ASSIGN OUTPUT SIGNAL
  --
  
  res_o <= res_s;

  GEN_MULT_LSW: if(USE_MULT = 1) generate

    --
    -- MULT COMB
    -- 
    --! This process computes the result for LSW multiplications by summing partial products.
    --! Formula: A (A1A0) * B (B1B0) = (A0*B0) + 2**16(A1*B0 + A0*B1) 
    COMB_PIPE_MULT_2: process(part_res_i)

      variable l_res_v  : std_ulogic_vector(data_t'length/2 - 1 downto 0);
      variable u1_res_v : std_ulogic_vector(data_t'length/2 - 1 downto 0);
      variable u2_res_v : std_ulogic_vector(data_t'length/2 - 1 downto 0);

    begin

      l_res_v  := part_res_i.part_ll_res(data_t'length/2 - 1 downto 0);
      -- use 16-bit adders / ignore overflow
      u1_res_v := std_ulogic_vector(unsigned(part_res_i.part_ll_res(data_t'length - 1 downto data_t'length/2)) + unsigned(part_res_i.part_ul_res(data_t'length/2 - 1 downto 0))); 
      u2_res_v := std_ulogic_vector(unsigned(u1_res_v) + unsigned(part_res_i.part_lu_res(data_t'length/2 - 1 downto 0))); 

      -- truncated mult result
      res_s <= u2_res_v & l_res_v;

    end process COMB_PIPE_MULT_2;

  end generate GEN_MULT_LSW;

  GEN_MULT_FULL: if(USE_MULT > 1) generate

    --
    -- MULT COMB
    -- 
    --! This process computes the result for LSW/MSW  multiplications by summing partial products.
    --! Formula: A (A1A0) * B (B1B0) = (A0*B0) + 2**16(A1*B0 + A0*B1) + 2**32(A1*B1)
    COMB_PIPE_MULT_2: process(part_res_i,
                              control_i)

      variable l_res_v    : std_ulogic_vector(data_t'length/2 - 1 downto 0);
      variable m1_res_v   : std_ulogic_vector(data_t'length/2 downto 0);
      variable m2_res_v   : std_ulogic_vector(data_t'length/2 downto 0);
      variable u_op_ul_v  : data_t;
      variable u_op_lu_v  : data_t;
      variable u1_res_v   : data_t;
      variable u2_res_v   : data_t;
      variable mult_res_v : mult_res_t;
		
    begin

      l_res_v    := part_res_i.part_ll_res(data_t'length/2 - 1 downto 0);
      -- use one 16-bit adder with carry out and one 17-bit adder
      m1_res_v   := std_ulogic_vector(unsigned('0' & part_res_i.part_ll_res(data_t'length - 1 downto data_t'length/2)) + unsigned('0' & part_res_i.part_ul_res(data_t'length/2 - 1 downto 0)));
      m2_res_v   := std_ulogic_vector(unsigned(m1_res_v) + unsigned('0' & part_res_i.part_lu_res(data_t'length/2 - 1 downto 0)));
                                                                                                                       
      -- use one 32-bit adder with carry in and one 32-bit adder / ignore overflow
      u_op_ul_v  := std_ulogic_vector(resize(signed(part_res_i.part_ul_res(mult_part_res_t'length - 1 downto data_t'length/2)),data_t'length));
      u_op_lu_v  := std_ulogic_vector(resize(signed(part_res_i.part_lu_res(mult_part_res_t'length - 1 downto data_t'length/2)),data_t'length));
      u1_res_v   := std_ulogic_vector(unsigned(u_op_lu_v) + unsigned(u_op_ul_v) + unsigned(m2_res_v(m2_res_v'left downto m2_res_v'left)));
      u2_res_v   := std_ulogic_vector(unsigned(part_res_i.part_uu_res(data_t'length - 1 downto 0)) + unsigned(u1_res_v));

      -- 64-bit mult result / ignore overflow
      mult_res_v := u2_res_v & m2_res_v(data_t'length/2 - 1 downto 0) & l_res_v;

      case control_i is
 
        when MULT_LSW =>
          res_s <= mult_res_v(data_t'length - 1 downto 0);

        when MULT_HSW_SS | MULT_HSW_SU | MULT_HSW_UU =>
          res_s <= mult_res_v(data_t'length*2 - 1 downto data_t'length);

        when others =>
          res_s <= (others => 'X'); 
          report "mult entity: illegal mult control code" severity warning; 

      end case;   

    end process COMB_PIPE_MULT_2;

  end generate GEN_MULT_FULL;
           
end be_sb_pipe_mult_2;

