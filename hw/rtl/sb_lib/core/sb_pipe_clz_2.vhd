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
--! @file sb_pipe_clz_2.vhd                                      					
--! @brief SecretBlaze Second Stage Pipelined Count Leading Zeros Unit
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
--! This module implements the second stage of the pipelined count leading zeros unit.
--

--! SecretBlaze Second Stage Pipelined CLZ Entity
entity sb_pipe_clz_2 is

  port
    (
      part_data_i : in clz_part_data_t; --! clz partial data input
      part_res_i  : in clz_part_res_t;  --! clz partial result input
      res_o       : out data_t          --! clz result output
    );  
  
end sb_pipe_clz_2;

--! SecretBlaze Second Stage Pipelined CLZ Architecture
architecture be_sb_pipe_clz_2 of sb_pipe_clz_2 is
  
  -- //////////////////////////////////////////
  --               INTERNAL WIRE
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

  --
  -- COUNT LEADING ZEROS
  --
  --! This process implements the clz instruction using a divide / multiplexor scheme.
  COMB_PIPE_CLZ_2: process(part_data_i,
                           part_res_i)

    constant zero8_c : std_ulogic_vector(7 downto 0) := (others => '0');
    constant zero4_c : std_ulogic_vector(3 downto 0) := (others => '0');
    constant zero2_c : std_ulogic_vector(1 downto 0) := (others => '0');    
    variable tmp8_v  : std_ulogic_vector(7 downto 0);
    variable tmp4_v  : std_ulogic_vector(3 downto 0);
    variable tmp2_v  : std_ulogic_vector(1 downto 0);

  begin

    -- special case: input is NULL / Rd <- 32
    if(part_res_i(5) = '1') then
      res_s      <= std_ulogic_vector(resize(unsigned(part_res_i),data_t'length));

    else
      res_s      <= std_ulogic_vector(resize(unsigned(part_res_i),data_t'length));

      -- count LZ for the next 8 bits
      if(part_data_i(15 downto 8) = zero8_c) then
        res_s(3) <= '1';
        tmp8_v   := part_data_i(7 downto 0);

      else
        tmp8_v   := part_data_i(15 downto 8);

      end if;

      -- count LZ for the next 4 bits
      if(tmp8_v(7 downto 4) = zero4_c) then
        res_s(2) <= '1';
        tmp4_v   := tmp8_v(3 downto 0);

      else
        tmp4_v   := tmp8_v(7 downto 4);

      end if; 

      -- count LZ for the next 2 bits
      if(tmp4_v(3 downto 2) = zero2_c) then
        res_s(1) <= '1';
        tmp2_v   := tmp4_v(1 downto 0);

      else
        tmp2_v   := tmp4_v(3 downto 2);

      end if; 

      -- count LZ for the last bit
      if(tmp2_v(1) = '0') then
        res_s(0) <= '1';
      end if;
 
    end if;

  end process COMB_PIPE_CLZ_2;
           
end be_sb_pipe_clz_2;

