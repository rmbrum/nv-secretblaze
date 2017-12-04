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
--! @file sb_mult.vhd                                      					
--! @brief SecretBlaze Multiplier Unit
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

library config_lib;
use config_lib.sb_config.all;

--
--! This module implements a basic single cycle 32-bit or 64-bit multiplier.
--

--! SecretBlaze Multiplier Entity
entity sb_mult is

  generic
    (
      USE_MULT  : natural := USER_USE_MULT --! 0 -> no HW mult, 1 -> LSW HW mult, 2 -> full HW mult
    );  

  port
    (  
      op_a_i    : in data_t;               --! mult first operand input
      op_b_i    : in data_t;               --! mult second operand input 
      res_o     : out data_t;              --! mult result output
      control_i : in mult_control_t        --! mult control input   
    );  
  
end sb_mult;

--! SecretBlaze Multiplier Architecture
architecture be_sb_mult of sb_mult is

  -- //////////////////////////////////////////
  --               INTERNAL WIRES
  -- //////////////////////////////////////////

  signal op_a_ext_s : mult_data_ext_t;
  signal op_b_ext_s : mult_data_ext_t;
  signal res_s      : data_t;    
   
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
    -- MULT PROCESS
    -- 
    --! This process implements the signed multiplier for a LSW signed multiplication. 
    --! Signed-extension is not required there.
    COMB_MULT: process(op_a_i,
                       op_b_i)

      variable mult_res_v : mult_res_t;

    begin

      mult_res_v := std_ulogic_vector((signed(op_a_i) * signed(op_b_i)));

      -- truncated mult result
      res_s      <= mult_res_v(data_t'length - 1 downto 0);

    end process COMB_MULT;

  end generate GEN_MULT_LSW;

  GEN_MULT_FULL: if(USE_MULT > 1) generate

    --
    -- SIGNED EXTEND
    -- 
    --! This process implements the sign extension of operands to support both 
    --! signed and unsigned multiplications.
    COMB_OP_EXT: process(op_a_i,
                         op_b_i,
                         control_i)
    begin

      case control_i is

        when MULT_LSW | MULT_HSW_SS =>
          op_a_ext_s <= (op_a_i(data_t'left) & op_a_i);
          op_b_ext_s <= (op_b_i(data_t'left) & op_b_i);
                      
        when MULT_HSW_SU =>
          op_a_ext_s <= (op_a_i(data_t'left) & op_a_i);
          op_b_ext_s <= ('0' & op_b_i);
                      
        when MULT_HSW_UU =>
          op_a_ext_s <= ('0' & op_a_i);
          op_b_ext_s <= ('0' & op_b_i);
        
        when others =>
          op_a_ext_s <= (others => 'X');
          op_b_ext_s <= (others => 'X');
          report "mult entity: illegal mult control code" severity warning;
        
      end case;

    end process COMB_OP_EXT;

    --
    -- MULT PROCESS
    -- 
    --! This process implements the signed multiplier for signed and unsigned multiplications.
    COMB_MULT: process(op_a_ext_s,
                       op_b_ext_s,
                       control_i)

      variable mult_res_v : mult_res_ext_t;

    begin

      -- 66-bit mult result
      mult_res_v := std_ulogic_vector((signed(op_a_ext_s) * signed(op_b_ext_s)));

      case control_i is
 
        when MULT_LSW =>
          res_s <= mult_res_v(data_t'length - 1 downto 0);

        when MULT_HSW_SS | MULT_HSW_SU | MULT_HSW_UU =>
          res_s <= mult_res_v(data_t'length*2 - 1 downto data_t'length);

        when others =>
          res_s <= (others => 'X'); 
          report "mult entity: illegal mult control code" severity warning; 

      end case;    

    end process COMB_MULT;

  end generate GEN_MULT_FULL;
           
end be_sb_mult;

