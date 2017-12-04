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
--! @file sb_pat.vhd                                      					
--! @brief SecretBlaze Pattern Comparators Unit
--! @author Lyonel Barthe
--! @version 1.0
--                                                                 
-----------------------------------------------------------------
-----------------------------------------------------------------

--
-- Revision History
--
-- Version 1.0 03/11/2010 by Lyonel Barthe
-- Initial Release 
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library sb_lib;
use sb_lib.sb_core_pack.all;

--
--! This module implements the pattern comparators unit of the processor.
--

--! SecretBlaze Pattern Entity
entity sb_pat is

  port
    (
      op_a_i    : in data_t;       --! pat first operand input
      op_b_i    : in data_t;       --! pat second operand input
      res_o     : out data_t;      --! pat result output
      control_i : in pat_control_t --! pat control input
    );  
  
end sb_pat;

--! SecretBlaze Pattern Architecture
architecture be_sb_pat of sb_pat is
  
  -- //////////////////////////////////////////
  --               INTERNAL WIRES
  -- //////////////////////////////////////////
  
  signal pat_byte_cmp_s : pat_byte_cmp_t;
  signal res_s          : data_t;    
   
begin

  -- //////////////////////////////////////////
  --                COMB PROCESS
  -- //////////////////////////////////////////

  --
  -- ASSIGN OUTPUT SIGNAL
  --
  
  res_o <= res_s;

  --
  -- PATTERN COMPARATORS
  --
  --! This process implements byte comparators required to implement pattern instructions.
  COMB_BYTE_CMPS: process(op_a_i,
                          op_b_i)
  begin

    for i in 0 to (pat_byte_cmp_t'length - 1) loop

      if(op_a_i(8*(i+1)-1 downto 8*i) = op_b_i(8*(i+1)-1 downto 8*i)) then
        pat_byte_cmp_s(i) <= '1';

      else
        pat_byte_cmp_s(i) <= '0';

      end if;

    end loop;

  end process COMB_BYTE_CMPS;
  
  --
  -- PATTERN IMPLEMENTATION
  --
  --! This process implements the behaviour of each pattern instructions. 
  COMB_PAT_TYPE: process(pat_byte_cmp_s,
                         control_i)

    constant cmp_one_c  : pat_byte_cmp_t := (others => '1');
    variable eq_v       : std_ulogic;
    constant one_c      : std_ulogic_vector(0 downto 0) := "1";
    constant two_c      : std_ulogic_vector(1 downto 0) := "10";
    constant three_c    : std_ulogic_vector(1 downto 0) := "11";
    constant four_c     : std_ulogic_vector(2 downto 0) := "100";

  begin

    -- compute equal condition
    if(pat_byte_cmp_s = cmp_one_c) then 
      eq_v := '1';

    else
      eq_v := '0';

    end if;

    case control_i is 

      when PAT_BYTE => 
        if(pat_byte_cmp_s(3) = '1') then
          res_s <= std_ulogic_vector(resize(unsigned(one_c),data_t'length));
			 
        elsif(pat_byte_cmp_s(2) = '1') then
          res_s <= std_ulogic_vector(resize(unsigned(two_c),data_t'length));
			 
        elsif(pat_byte_cmp_s(1) = '1') then
          res_s <= std_ulogic_vector(resize(unsigned(three_c),data_t'length));
			 
        elsif(pat_byte_cmp_s(0) = '1') then
          res_s <= std_ulogic_vector(resize(unsigned(four_c),data_t'length));
			 
        else
          res_s <= (others => '0');
			 
        end if;

      when PAT_EQ =>
        if(eq_v = '1') then 
          res_s <= std_ulogic_vector(resize(unsigned(one_c),data_t'length));

        else
          res_s <= (others => '0');

        end if;

      when PAT_NE =>
        if(eq_v = '0') then 
          res_s <= std_ulogic_vector(resize(unsigned(one_c),data_t'length));

        else
          res_s <= (others => '0');

        end if;

      when others =>
        res_s <= (others => 'X');
        report "pat entity: illegal pat control code" severity warning;

    end case;

  end process COMB_PAT_TYPE;
           
end be_sb_pat;

