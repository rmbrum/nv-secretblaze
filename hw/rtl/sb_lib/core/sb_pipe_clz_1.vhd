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
--! @file sb_pipe_clz_1.vhd                                      					
--! @brief SecretBlaze First Stage Pipelined Count Leading Zeros Unit
--! @author Lyonel Barthe
--! @version 1.0
--                                                                 
-----------------------------------------------------------------
-----------------------------------------------------------------

--
-- Revision History
--
-- Version 1.0 18/03/2011 by Lyonel Barthe
-- Initial Release 
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library sb_lib;
use sb_lib.sb_core_pack.all;

--
--! This module implements the first stage of the pipelined count leading zeros unit.
--

--! SecretBlaze First Stage Pipelined CLZ Entity
entity sb_pipe_clz_1 is

  port
    (
      op_a_i      : in data_t;           --! clz operand input
      part_data_o : out clz_part_data_t; --! clz partial data output
      part_res_o  : out clz_part_res_t   --! clz partial result output
    );  
  
end sb_pipe_clz_1;

--! SecretBlaze First Stage Pipelined CLZ Architecture
architecture be_sb_pipe_clz_1 of sb_pipe_clz_1 is
  
  -- //////////////////////////////////////////
  --               INTERNAL WIRES
  -- //////////////////////////////////////////
  
  signal part_res_s  : clz_part_res_t;    
  signal part_data_s : clz_part_data_t; 
   
begin

  -- //////////////////////////////////////////
  --                COMB PROCESS
  -- //////////////////////////////////////////

  --
  -- ASSIGN OUTPUT SIGNALS
  --
  
  part_res_o  <= part_res_s;
  part_data_o <= part_data_s;

  --
  -- COUNT LEADING ZEROS
  --
  --! This process implements the clz instruction using a divide / multiplexor scheme. 
  --! This process sets up the two MSB of the result.
  COMB_PIPE_CLZ_1: process(op_a_i)

    constant thirtytwo_c : std_ulogic_vector(5 downto 0)  := "100000";
    constant zero32_c    : std_ulogic_vector(31 downto 0) := (others => '0');
    constant zero16_c    : std_ulogic_vector(15 downto 0) := (others => '0');

  begin

    -- special case: input is NULL / Rd <- 32
    if(op_a_i = zero32_c) then
      part_res_s      <= thirtytwo_c;
      part_data_s     <= (others => 'X'); 

    else
      part_res_s      <= (others => '0');

      -- count LZ in the top 16 bits
      if(op_a_i(31 downto 16) = zero16_c) then
        part_res_s(4) <= '1';
        part_data_s   <= op_a_i(15 downto 0);

      else
        part_data_s   <= op_a_i(31 downto 16);

      end if; 
 
    end if;

  end process COMB_PIPE_CLZ_1;
           
end be_sb_pipe_clz_1;

