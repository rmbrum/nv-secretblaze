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
--! @file sb_pipe_bs_2.vhd                                      					
--! @brief SecretBlaze Second Stage Barrel Shifter Unit 
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

library tool_lib;
use tool_lib.math_pack.all;

--
--! This module implements the second stage of the pipelined barrel shifter unit.
--

--! SecretBlaze Second Stage Pipelined Barrel Shifter Entity
entity sb_pipe_bs_2 is

  generic
    (
      USE_BS       : natural := USER_USE_BS --! 0 -> no barrel shifter, 1 -> size-opt, 2 -> speed-opt
    );  

  port
    (  
      part_res_i   : in bs_data_ext_t;      --! bs partial results input
      res_o        : out data_t;            --! bs result output
      part_shift_i : in bs_part_shift_t;    --! barrel shift input
      control_i    : in bs_control_t        --! bs control input   
    );  
  
end sb_pipe_bs_2;

--! SecretBlaze Second Stage Pipelined Barrel Shifter Architecture
architecture be_sb_pipe_bs_2 of sb_pipe_bs_2 is

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

  GEN_SIZE_BS: if(USE_BS = 1) generate

    --
    -- SECOND BARREL SHIFTER PRIMITIVE
    --
    --! This process implements the second part of the arithmetic right shifter for left/right 
    --! logical/arithmetic shift operations. 
    COMB_PIPE_BS_2: process(part_res_i,
                            control_i,
                            part_shift_i)

      variable bs_res_v : bs_data_ext_t;

    begin

      case part_shift_i is 
            
        when "00" =>
          bs_res_v := std_ulogic_vector(shift_right(signed(part_res_i),0));
          
        when "01" =>
          bs_res_v := std_ulogic_vector(shift_right(signed(part_res_i),8));
          
        when "10" =>
          bs_res_v := std_ulogic_vector(shift_right(signed(part_res_i),16));
          
        when "11" =>
          bs_res_v := std_ulogic_vector(shift_right(signed(part_res_i),24));
          
        when others =>
          null; 
          
      end case;

      -- set-up result
      case control_i is

        when BS_SLL => 
          res_s <= reverse_bit(bs_res_v)(bs_data_ext_t'length - 1 downto 1); -- re-invert all bits

        when BS_SRL | BS_SRA =>
          res_s <= bs_res_v(data_t'length - 1 downto 0);

        when others =>
          res_s <= (others => 'X'); -- force X for speed & area optimization / unsafe implementation 
          report "barrel shifter: control code undefined" severity warning;

      end case;
		
    end process COMB_PIPE_BS_2;

  end generate GEN_SIZE_BS;

  GEN_SPEED_BS: if(USE_BS > 1) generate

    COMB_REPORT: process(part_res_i,
                         control_i,
                         part_shift_i)
    begin
	 
      report "barrel shifter: USE_BS > 1 configuration not supported using the pipelined mode" severity error;
		
    end process COMB_REPORT;

  end generate GEN_SPEED_BS;    
           
end be_sb_pipe_bs_2;

