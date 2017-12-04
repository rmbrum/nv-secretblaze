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
--! @file sb_bs.vhd                                      					
--! @brief SecretBlaze Barrel Shifter Implementation
--! @author Lyonel Barthe
--! @version 1.1
--                                                                 
-----------------------------------------------------------------
-----------------------------------------------------------------

--
-- Revision History
--
-- Version 1.1 16/05/2010 by Lyonel Barthe
-- Optional area optimized version (ASIC)
--
-- Version 1.0 15/05/2010 by Lyonel Barthe
-- Speed optimized version (ASIC)
--
-- Version 0.1 15/02/2010 by Lyonel Barthe
-- Initial release
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
--! This module implements the 32-bit barrel shifter primitives of the processor.
--

--! SecretBlaze Barrel Shifter Primitives Entity
entity sb_bs is

  generic
    (
      USE_BS    : natural := USER_USE_BS --! 0 -> no barrel shifter, 1 -> size-opt, 2 -> speed-opt
    );    

  port
    (   
      data_i    : in data_t;             --! barrel input
      res_o     : out data_t;            --! barrel output
      shift_i   : in bs_shift_t;         --! barrel shift input
      control_i : in bs_control_t        --! barrel control input
    );  
  
end sb_bs;

--! SecretBlaze Barrel Shifter Primitives Architecture
architecture be_sb_bs of sb_bs is
  
  -- //////////////////////////////////////////
  --               INTERNAL WIRES
  -- //////////////////////////////////////////

  signal data_ext_s : bs_data_ext_t;  
  signal res_s      : data_t;
   
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
    -- DATA EXTEND
    --
    --! This process sets up the data to shift according to the 
    --! type of the shift operation. Note that the signed extension 
    --! is required to handle any shift operations.
    COMB_DATA_EXT: process(data_i,
                           control_i)

      variable data_v : data_t;

    begin

      case control_i is

        when BS_SLL => 
          data_v := reverse_bit(data_i); -- invert all bits
          data_ext_s <= '0' & data_v;

        when BS_SRL =>
          data_v := data_i;
          data_ext_s <= '0' & data_v; 

        when BS_SRA =>
          data_v := data_i;
          data_ext_s <= data_v(data_t'left) & data_v; 

        when others =>
          data_ext_s <= (others => 'X'); -- force X for speed & area optimization / unsafe implementation 
          report "barrel shifter: control code undefined" severity warning;

      end case;

    end process COMB_DATA_EXT;

    --
    -- BARREL SHIFTER PRIMITIVE
    --
    --! This process implements an arithmetic right shifter for 
    --! left/right logical/arithmetic shift operations. 
    COMB_BS: process(data_ext_s,
                     control_i,
                     shift_i)

      variable bs_res_v : bs_data_ext_t;

    begin

      case shift_i is 
            
        when "00000" =>
          bs_res_v := std_ulogic_vector(shift_right(signed(data_ext_s),0));
          
        when "00001" =>
          bs_res_v := std_ulogic_vector(shift_right(signed(data_ext_s),1));
          
        when "00010" =>
          bs_res_v := std_ulogic_vector(shift_right(signed(data_ext_s),2));
          
        when "00011" =>
          bs_res_v := std_ulogic_vector(shift_right(signed(data_ext_s),3));
          
        when "00100" =>
          bs_res_v := std_ulogic_vector(shift_right(signed(data_ext_s),4));
          
        when "00101" =>
          bs_res_v := std_ulogic_vector(shift_right(signed(data_ext_s),5));
          
        when "00110" =>
          bs_res_v := std_ulogic_vector(shift_right(signed(data_ext_s),6));
          
        when "00111" =>
          bs_res_v := std_ulogic_vector(shift_right(signed(data_ext_s),7));
          
        when "01000" =>
          bs_res_v := std_ulogic_vector(shift_right(signed(data_ext_s),8));
          
        when "01001" =>
          bs_res_v := std_ulogic_vector(shift_right(signed(data_ext_s),9));
          
        when "01010" =>
          bs_res_v := std_ulogic_vector(shift_right(signed(data_ext_s),10));
          
        when "01011" =>
          bs_res_v := std_ulogic_vector(shift_right(signed(data_ext_s),11));
          
        when "01100" =>
          bs_res_v := std_ulogic_vector(shift_right(signed(data_ext_s),12));
          
        when "01101" =>
          bs_res_v := std_ulogic_vector(shift_right(signed(data_ext_s),13));
          
        when "01110" =>
          bs_res_v := std_ulogic_vector(shift_right(signed(data_ext_s),14));
          
        when "01111" =>
          bs_res_v := std_ulogic_vector(shift_right(signed(data_ext_s),15));
          
        when "10000" =>
          bs_res_v := std_ulogic_vector(shift_right(signed(data_ext_s),16));
          
        when "10001" =>
          bs_res_v := std_ulogic_vector(shift_right(signed(data_ext_s),17));
          
        when "10010" =>
          bs_res_v := std_ulogic_vector(shift_right(signed(data_ext_s),18));
          
        when "10011" =>
          bs_res_v := std_ulogic_vector(shift_right(signed(data_ext_s),19));
          
        when "10100" =>
          bs_res_v := std_ulogic_vector(shift_right(signed(data_ext_s),20));
          
        when "10101" =>
          bs_res_v := std_ulogic_vector(shift_right(signed(data_ext_s),21));
          
        when "10110" =>
          bs_res_v := std_ulogic_vector(shift_right(signed(data_ext_s),22));
          
        when "10111" =>
          bs_res_v := std_ulogic_vector(shift_right(signed(data_ext_s),23));
          
        when "11000" =>
          bs_res_v := std_ulogic_vector(shift_right(signed(data_ext_s),24));
          
        when "11001" =>
          bs_res_v := std_ulogic_vector(shift_right(signed(data_ext_s),25));
          
        when "11010" =>
          bs_res_v := std_ulogic_vector(shift_right(signed(data_ext_s),26));
          
        when "11011" =>
          bs_res_v := std_ulogic_vector(shift_right(signed(data_ext_s),27));
          
        when "11100" =>
          bs_res_v := std_ulogic_vector(shift_right(signed(data_ext_s),28));
          
        when "11101" =>
          bs_res_v := std_ulogic_vector(shift_right(signed(data_ext_s),29));
          
        when "11110" =>
          bs_res_v := std_ulogic_vector(shift_right(signed(data_ext_s),30));
          
        when "11111" =>
          bs_res_v := std_ulogic_vector(shift_right(signed(data_ext_s),31));
          
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
      
    end process COMB_BS;

  end generate GEN_SIZE_BS;

  GEN_SPEED_BS: if(USE_BS > 1) generate 

    --
    -- BARREL SHIFTER PRIMITIVES
    --
    --! This process implements three shifter primitives: 
    --!   - a logical left shifter,
    --!   - a logical right shifter, and 
    --!   - an arithmetic right shifter. 
    COMB_BS: process(data_i,
                     shift_i,
                     control_i)
    begin
	
      case control_i is

        when BS_SLL =>
          
          case shift_i is 
            
            when "00000" =>
              res_s <= std_ulogic_vector(shift_left(unsigned(data_i),0));
              
            when "00001" =>
              res_s <= std_ulogic_vector(shift_left(unsigned(data_i),1));
              
            when "00010" =>
              res_s <= std_ulogic_vector(shift_left(unsigned(data_i),2));
              
            when "00011" =>
              res_s <= std_ulogic_vector(shift_left(unsigned(data_i),3));
              
            when "00100" =>
              res_s <= std_ulogic_vector(shift_left(unsigned(data_i),4));
              
            when "00101" =>
              res_s <= std_ulogic_vector(shift_left(unsigned(data_i),5));
              
            when "00110" =>
              res_s <= std_ulogic_vector(shift_left(unsigned(data_i),6));
              
            when "00111" =>
              res_s <= std_ulogic_vector(shift_left(unsigned(data_i),7));
              
            when "01000" =>
              res_s <= std_ulogic_vector(shift_left(unsigned(data_i),8));
              
            when "01001" =>
              res_s <= std_ulogic_vector(shift_left(unsigned(data_i),9));
              
            when "01010" =>
              res_s <= std_ulogic_vector(shift_left(unsigned(data_i),10));
              
            when "01011" =>
              res_s <= std_ulogic_vector(shift_left(unsigned(data_i),11));
              
            when "01100" =>
              res_s <= std_ulogic_vector(shift_left(unsigned(data_i),12));
              
            when "01101" =>
              res_s <= std_ulogic_vector(shift_left(unsigned(data_i),13));
              
            when "01110" =>
              res_s <= std_ulogic_vector(shift_left(unsigned(data_i),14));
              
            when "01111" =>
              res_s <= std_ulogic_vector(shift_left(unsigned(data_i),15));
              
            when "10000" =>
              res_s <= std_ulogic_vector(shift_left(unsigned(data_i),16));
              
            when "10001" =>
              res_s <= std_ulogic_vector(shift_left(unsigned(data_i),17));
              
            when "10010" =>
              res_s <= std_ulogic_vector(shift_left(unsigned(data_i),18));
              
            when "10011" =>
              res_s <= std_ulogic_vector(shift_left(unsigned(data_i),19));
              
            when "10100" =>
              res_s <= std_ulogic_vector(shift_left(unsigned(data_i),20));
              
            when "10101" =>
              res_s <= std_ulogic_vector(shift_left(unsigned(data_i),21));
              
            when "10110" =>
              res_s <= std_ulogic_vector(shift_left(unsigned(data_i),22));
              
            when "10111" =>
              res_s <= std_ulogic_vector(shift_left(unsigned(data_i),23));
              
            when "11000" =>
              res_s <= std_ulogic_vector(shift_left(unsigned(data_i),24));
              
            when "11001" =>
              res_s <= std_ulogic_vector(shift_left(unsigned(data_i),25));
              
            when "11010" =>
              res_s <= std_ulogic_vector(shift_left(unsigned(data_i),26));
              
            when "11011" =>
              res_s <= std_ulogic_vector(shift_left(unsigned(data_i),27));
              
            when "11100" =>
              res_s <= std_ulogic_vector(shift_left(unsigned(data_i),28));
              
            when "11101" =>
              res_s <= std_ulogic_vector(shift_left(unsigned(data_i),29));  
       
            when "11110" =>
              res_s <= std_ulogic_vector(shift_left(unsigned(data_i),30));
              
            when "11111" =>
              res_s <= std_ulogic_vector(shift_left(unsigned(data_i),31));
              
            when others =>
              null; 
              
          end case;
          
        when BS_SRL =>
          
          case shift_i is 
            
            when "00000" =>
              res_s <= std_ulogic_vector(shift_right(unsigned(data_i),0));
              
            when "00001" =>
              res_s <= std_ulogic_vector(shift_right(unsigned(data_i),1));
              
            when "00010" =>
              res_s <= std_ulogic_vector(shift_right(unsigned(data_i),2));
              
            when "00011" =>
              res_s <= std_ulogic_vector(shift_right(unsigned(data_i),3));
              
            when "00100" =>
              res_s <= std_ulogic_vector(shift_right(unsigned(data_i),4));
              
            when "00101" =>
              res_s <= std_ulogic_vector(shift_right(unsigned(data_i),5));
              
            when "00110" =>
              res_s <= std_ulogic_vector(shift_right(unsigned(data_i),6));
              
            when "00111" =>
              res_s <= std_ulogic_vector(shift_right(unsigned(data_i),7));
              
            when "01000" =>
              res_s <= std_ulogic_vector(shift_right(unsigned(data_i),8));
              
            when "01001" =>
              res_s <= std_ulogic_vector(shift_right(unsigned(data_i),9));
              
            when "01010" =>
              res_s <= std_ulogic_vector(shift_right(unsigned(data_i),10));
              
            when "01011" =>
              res_s <= std_ulogic_vector(shift_right(unsigned(data_i),11));
              
            when "01100" =>
              res_s <= std_ulogic_vector(shift_right(unsigned(data_i),12));
              
            when "01101" =>
              res_s <= std_ulogic_vector(shift_right(unsigned(data_i),13));
              
            when "01110" =>
              res_s <= std_ulogic_vector(shift_right(unsigned(data_i),14));
              
            when "01111" =>
              res_s <= std_ulogic_vector(shift_right(unsigned(data_i),15));
              
            when "10000" =>
              res_s <= std_ulogic_vector(shift_right(unsigned(data_i),16));
              
            when "10001" =>
              res_s <= std_ulogic_vector(shift_right(unsigned(data_i),17));
              
            when "10010" =>
              res_s <= std_ulogic_vector(shift_right(unsigned(data_i),18));    
              
            when "10011" =>
              res_s <= std_ulogic_vector(shift_right(unsigned(data_i),19));
              
            when "10100" =>
              res_s <= std_ulogic_vector(shift_right(unsigned(data_i),20));
              
            when "10101" =>
              res_s <= std_ulogic_vector(shift_right(unsigned(data_i),21));
					
            when "10110" =>
              res_s <= std_ulogic_vector(shift_right(unsigned(data_i),22));
              
            when "10111" =>
              res_s <= std_ulogic_vector(shift_right(unsigned(data_i),23));
              
            when "11000" =>
              res_s <= std_ulogic_vector(shift_right(unsigned(data_i),24));
              
            when "11001" =>
              res_s <= std_ulogic_vector(shift_right(unsigned(data_i),25));
              
            when "11010" =>
              res_s <= std_ulogic_vector(shift_right(unsigned(data_i),26));
              
            when "11011" =>
              res_s <= std_ulogic_vector(shift_right(unsigned(data_i),27));
              
            when "11100" =>
              res_s <= std_ulogic_vector(shift_right(unsigned(data_i),28));
              
            when "11101" =>
              res_s <= std_ulogic_vector(shift_right(unsigned(data_i),29));
              
            when "11110" =>
              res_s <= std_ulogic_vector(shift_right(unsigned(data_i),30));
              
            when "11111" =>
              res_s <= std_ulogic_vector(shift_right(unsigned(data_i),31));
              
            when others =>
              null; 
              
          end case;

        when BS_SRA =>
          
          case shift_i is 
            
            when "00000" =>
              res_s <= std_ulogic_vector(shift_right(signed(data_i),0));
              
            when "00001" =>
              res_s <= std_ulogic_vector(shift_right(signed(data_i),1));
              
            when "00010" =>
              res_s <= std_ulogic_vector(shift_right(signed(data_i),2));
              
            when "00011" =>
              res_s <= std_ulogic_vector(shift_right(signed(data_i),3));
              
            when "00100" =>
              res_s <= std_ulogic_vector(shift_right(signed(data_i),4));
              
            when "00101" =>
              res_s <= std_ulogic_vector(shift_right(signed(data_i),5));
              
            when "00110" =>
              res_s <= std_ulogic_vector(shift_right(signed(data_i),6));
              
            when "00111" =>
              res_s <= std_ulogic_vector(shift_right(signed(data_i),7));
              
            when "01000" =>
              res_s <= std_ulogic_vector(shift_right(signed(data_i),8));
              
            when "01001" =>
              res_s <= std_ulogic_vector(shift_right(signed(data_i),9));
              
            when "01010" =>
              res_s <= std_ulogic_vector(shift_right(signed(data_i),10));
              
            when "01011" =>
              res_s <= std_ulogic_vector(shift_right(signed(data_i),11));
              
            when "01100" =>
              res_s <= std_ulogic_vector(shift_right(signed(data_i),12));
              
            when "01101" =>
              res_s <= std_ulogic_vector(shift_right(signed(data_i),13));
              
            when "01110" =>
              res_s <= std_ulogic_vector(shift_right(signed(data_i),14));
              
            when "01111" =>
              res_s <= std_ulogic_vector(shift_right(signed(data_i),15));
              
            when "10000" =>
              res_s <= std_ulogic_vector(shift_right(signed(data_i),16));
              
            when "10001" =>
              res_s <= std_ulogic_vector(shift_right(signed(data_i),17));
              
            when "10010" =>
              res_s <= std_ulogic_vector(shift_right(signed(data_i),18));
              
            when "10011" =>
              res_s <= std_ulogic_vector(shift_right(signed(data_i),19));
              
            when "10100" =>
              res_s <= std_ulogic_vector(shift_right(signed(data_i),20));
              
            when "10101" =>
              res_s <= std_ulogic_vector(shift_right(signed(data_i),21));
              
            when "10110" =>
              res_s <= std_ulogic_vector(shift_right(signed(data_i),22));
              
            when "10111" =>
              res_s <= std_ulogic_vector(shift_right(signed(data_i),23));
              
            when "11000" =>
              res_s <= std_ulogic_vector(shift_right(signed(data_i),24));
              
            when "11001" =>
              res_s <= std_ulogic_vector(shift_right(signed(data_i),25));
              
            when "11010" =>
              res_s <= std_ulogic_vector(shift_right(signed(data_i),26));
              
            when "11011" =>
              res_s <= std_ulogic_vector(shift_right(signed(data_i),27));
              
            when "11100" =>
              res_s <= std_ulogic_vector(shift_right(signed(data_i),28));
              
            when "11101" =>
              res_s <= std_ulogic_vector(shift_right(signed(data_i),29));
              
            when "11110" =>
              res_s <= std_ulogic_vector(shift_right(signed(data_i),30));
              
            when "11111" =>
              res_s <= std_ulogic_vector(shift_right(signed(data_i),31));
              
            when others =>
              null; 
              
          end case;
          
        when others =>
          res_s <= (others =>'X'); -- force X for speed/area optimization
          report "barrel shifter: control code undefined" severity warning;
	
      end case;
    
    end process COMB_BS;

  end generate GEN_SPEED_BS;
               
end be_sb_bs;

