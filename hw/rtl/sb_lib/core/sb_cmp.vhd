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
--! @file sb_cmp.vhd                                      					
--! @brief SecretBlaze Compare Unit
--! @author Lyonel Barthe
--! @version 1.0
--                                                                 
-----------------------------------------------------------------
-----------------------------------------------------------------

--
-- Revision History
--
-- Version 1.0 29/03/2011 by Lyonel Barthe
-- Initial Release 
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library sb_lib;
use sb_lib.sb_core_pack.all;

--
--! This module implements the compare unit of the SecretBlaze. 
--! It uses a 33-bit adder to handle the overflow, required for 
--! both CMP and CMPU instructions.
--

--! SecretBlaze Compare Entity
entity sb_cmp is

  port
    (
      op_a_i    : in data_t;       --! first operand input
      op_b_i    : in data_t;       --! second operand input
      res_o     : out data_t;      --! cmp result output
      control_i : in cmp_control_t --! cmp control input
    );  
  
end sb_cmp;

--! SecretBlaze Compare Architecture
architecture be_sb_cmp of sb_cmp is
  
  -- //////////////////////////////////////////
  --               INTERNAL WIRES
  -- //////////////////////////////////////////
 
  signal res_s      : data_t;    
  signal op_a_ext_s : cmp_data_ext_t;
  signal op_b_ext_s : cmp_data_ext_t;
   
begin

  -- //////////////////////////////////////////
  --                COMB PROCESS
  -- //////////////////////////////////////////

  --
  -- ASSIGN OUTPUT SIGNAL
  --
  
  res_o <= res_s;

  --
  -- SIGNED EXTEND
  -- 
  --! This process implements the sign extension of operands to support 
  --! both signed and unsigned comparisons. The first operand is also 
  --! complemented to set up the substraction correctly.
  COMB_OP_EXT: process(op_a_i,
                       op_b_i,
                       control_i)
  begin

    case control_i is

      when CMP_S =>        
        op_a_ext_s <= not((op_a_i(data_t'left) & op_a_i));
        op_b_ext_s <= (op_b_i(data_t'left) & op_b_i);
                    
      when CMP_U =>        
        op_a_ext_s <= ('0' & not(op_a_i));
        op_b_ext_s <= ('0' & op_b_i);
      
      when others =>
        op_a_ext_s <= (others => 'X');
        op_b_ext_s <= (others => 'X');
        report "cmp entity: illegal cmp control code" severity warning;
      
    end case;

  end process COMB_OP_EXT;

  --
  -- COMPARE ADDER
  --
  --! This process implements the adder used to perform the comparison 
  --! between the two operands. Note that the signed extension prevents 
  --! the overflow.
  COMB_CMP_ADD: process(op_a_ext_s,
                        op_b_ext_s,
                        control_i)
							 
    variable cmp_res_v : cmp_res_ext_t;  

  begin
   
    -- use a 33-bit adder with carry in
    cmp_res_v := std_ulogic_vector(unsigned(op_a_ext_s) + unsigned(op_b_ext_s) + 1);

    -- set up the result 
    res_s(data_t'left - 1 downto 0) <= cmp_res_v(data_t'left - 1 downto 0);

    -- set MSB
    case control_i is

      when CMP_S =>
        res_s(data_t'left) <= cmp_res_v(cmp_res_ext_t'left);
                    
      when CMP_U =>
        res_s(data_t'left) <= not(cmp_res_v(cmp_res_ext_t'left));
      
      when others =>
        res_s(data_t'left) <= 'X';
        report "cmp entity: illegal cmp control code" severity warning;
      
    end case;

  end process COMB_CMP_ADD;
           
end be_sb_cmp;

