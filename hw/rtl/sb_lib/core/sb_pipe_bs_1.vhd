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
--! @file sb_pipe_bs_1.vhd                                      					
--! @brief SecretBlaze First Stage Pipelined Barrel Shifter Unit 
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

library tool_lib;
use tool_lib.math_pack.all;

library config_lib;
use config_lib.sb_config.all;

--
--! This module implements the first stage of the pipelined barrel shifter unit.
--

--! SecretBlaze First Stage Pipelined Barrel Shifter Entity
entity sb_pipe_bs_1 is

  generic
    (
      USE_BS       : natural := USER_USE_BS --! 0 -> no barrel shifter, 1 -> size-opt, 2 -> speed-opt
    );  

  port
    (  
      data_i       : in data_t;             --! barrel input
      part_res_o   : out bs_data_ext_t;     --! barrel partial result output
      part_shift_o : out bs_part_shift_t;   --! barrel partial shift output
      shift_i      : in bs_shift_t;         --! barrel shift input
      control_i    : in bs_control_t        --! barrel control input
    );  
  
end sb_pipe_bs_1;

--! SecretBlaze Second Stage Pipelined Barrel Shifter Architecture
architecture be_sb_pipe_bs_1 of sb_pipe_bs_1 is

  -- //////////////////////////////////////////
  --               INTERNAL WIRES
  -- //////////////////////////////////////////

  signal data_ext_s : bs_data_ext_t;  
  signal part_res_s : bs_data_ext_t;
   
begin

  -- //////////////////////////////////////////
  --                COMB PROCESS
  -- //////////////////////////////////////////

  --
  -- ASSIGN OUTPUT SIGNALS
  --

  part_res_o   <= part_res_s;
  part_shift_o <= shift_i(4 downto 3);

  GEN_SIZE_BS: if(USE_BS = 1) generate

    --
    -- DATA EXTEND
    --
    --! This process sets up the data to shift according to the type of the shift operation.
    --! Note that the signed extension is required to handle any shift operations.
    COMB_DATA_EXT: process(data_i,
                           control_i)

      variable data_v : data_t;

    begin

      case control_i is

        when BS_SLL => 
          data_v     := reverse_bit(data_i); -- invert all bits
          data_ext_s <= '0' & data_v;

        when BS_SRL =>
          data_v     := data_i;
          data_ext_s <= '0' & data_v; 

        when BS_SRA =>
          data_v     := data_i;
          data_ext_s <= data_v(data_t'left) & data_v; 

        when others =>
          data_ext_s <= (others => 'X'); -- force X for speed & area optimization / unsafe implementation 
          report "barrel shifter: control code undefined" severity warning;

      end case;

    end process COMB_DATA_EXT;

    --
    -- FIRST BARREL SHIFTER PRIMITIVE
    --
    --! This process implements the first part of an arithmetic right shifter for left/right 
    --! logical/arithmetic shift operations. 
    COMB_PIPE_BS_1: process(data_ext_s,
                            control_i,
                            shift_i)

    begin

      case shift_i(2 downto 0) is 
            
        when "000" =>
          part_res_s <= std_ulogic_vector(shift_right(signed(data_ext_s),0));
          
        when "001" =>
          part_res_s <= std_ulogic_vector(shift_right(signed(data_ext_s),1));
          
        when "010" =>
          part_res_s <= std_ulogic_vector(shift_right(signed(data_ext_s),2));
          
        when "011" =>
          part_res_s <= std_ulogic_vector(shift_right(signed(data_ext_s),3));

        when "100" =>
          part_res_s <= std_ulogic_vector(shift_right(signed(data_ext_s),4));
          
        when "101" =>
          part_res_s <= std_ulogic_vector(shift_right(signed(data_ext_s),5));
          
        when "110" =>
          part_res_s <= std_ulogic_vector(shift_right(signed(data_ext_s),6));
          
        when "111" =>
          part_res_s <= std_ulogic_vector(shift_right(signed(data_ext_s),7));
          
        when others =>
          null; 
          
      end case;
		
    end process COMB_PIPE_BS_1;

  end generate GEN_SIZE_BS;

  GEN_SPEED_BS: if(USE_BS > 1) generate

    COMB_REPORT: process(data_i,
                         control_i,
                         shift_i)
    begin
	 
      report "barrel shifter: USE_BS > 1 configuration not supported using the pipelined mode" severity error;
		
    end process COMB_REPORT;

  end generate GEN_SPEED_BS;        

end be_sb_pipe_bs_1;

