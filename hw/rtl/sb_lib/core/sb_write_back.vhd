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
--! @file sb_write_back.vhd                                   					
--! @brief SecretBlaze Write Back Stage Implementation                           				
--! @author Lyonel Barthe
--! @version 1.1
--                                                                 
-----------------------------------------------------------------
-----------------------------------------------------------------

--
-- Revision History
--
-- Version 1.1 14/11/2010 by Lyonel Barthe
-- Changed XILBRAM template coding style 
--
-- Version 1.0 13/05/2010 by Lyonel Barthe
-- Stable version
--
-- Version 0.2 8/04/2010 by Lyonel Barthe
-- Clean up version
--
-- Version 0.1 15/02/2010 by Lyonel Barthe
-- Initial release
--

library ieee;
use ieee.std_logic_1164.all;

library sb_lib;
use sb_lib.sb_core_pack.all;
use sb_lib.sb_isa.all;

--
--! The Write-Back (WB) stage implements the last step of the 
--! SecretBlaze’s pipeline. It handles the write of the result 
--! into the register file of the processor. The data alignment 
--! process is particularly implemented in this stage for load 
--! instructions, which allows to support byte, half-word, and 
--! word memory operations.
--

--! SecretBlaze Write Back Entity
entity sb_write_back is

  port
    (
      wb_i        : in wb_stage_i_t;  --! write-back inputs
      wb_o        : out wb_stage_o_t; --! write-back outputs
      halt_core_i : in std_ulogic;    --! halt core signal
      clk_i       : in std_ulogic     --! core clock
    );

end sb_write_back;

--! SecretBlaze Write Back Architecture
architecture be_sb_write_back of sb_write_back is
  
  -- //////////////////////////////////////////
  --               INTERNAL REGS
  -- //////////////////////////////////////////

  signal res_a_r   : data_t; --! write-back register (op a)
  signal res_b_r   : data_t; --! write-back register (op b)
  signal res_d_r   : data_t; --! write-back register (op d)

  -- //////////////////////////////////////////
  --              INTERNAL WIRES
  -- //////////////////////////////////////////

  signal mem_res_s : data_t;
  signal res_s     : data_t;

begin

  -- //////////////////////////////////////////
  --                COMB PROCESS
  -- //////////////////////////////////////////

  --
  -- ASSIGN OUTPUTS
  --
  
  -- registered signals
  wb_o.rf_res_a_o   <= res_a_r;
  wb_o.rf_res_b_o   <= res_b_r;
  wb_o.rf_res_d_o   <= res_d_r;
  -- combinatorial signals
  wb_o.rd_o         <= wb_i.rd_i;
  wb_o.we_control_o <= wb_i.we_control_i;
  wb_o.res_o        <= res_s; 

  --
  -- LOAD ALIGNMENT
  --
  --! This process manages the load alignment: aligned BYTE, HALFWORD and WORD data are supported.
  COMB_LOAD_ALIGN: process(wb_i)

    constant byte_pad_c  : std_ulogic_vector(data_t'length*3/4 - 1 downto 0) := (others =>'0'); 
    constant hword_pad_c : std_ulogic_vector(data_t'length*2/4 - 1 downto 0) := (others =>'0');          
    alias byte_sel_a     : std_ulogic_vector(1 downto 0) is wb_i.res_i(1 downto 0);

  begin

    case wb_i.mem_sel_control_i is

      when BYTE =>

        case byte_sel_a is

          when "00" =>
            mem_res_s <= byte_pad_c & wb_i.mem_data_i(data_t'length - 1 downto data_t'length*3/4);
            
          when "01" =>
            mem_res_s <= byte_pad_c & wb_i.mem_data_i(data_t'length*3/4 - 1 downto data_t'length*2/4);
            
          when "10" =>
            mem_res_s <= byte_pad_c & wb_i.mem_data_i(data_t'length*2/4 - 1 downto data_t'length/4);
            
          when "11" =>
            mem_res_s <= byte_pad_c & wb_i.mem_data_i(data_t'length/4 - 1 downto 0);
            
          when others =>
            null; 

        end case;

      when HALFWORD =>

        case byte_sel_a is

          when "00" =>
            mem_res_s <= hword_pad_c & wb_i.mem_data_i(data_t'length - 1 downto data_t'length*2/4);
            
          when "10" =>
            mem_res_s <= hword_pad_c & wb_i.mem_data_i(data_t'length*2/4 - 1 downto 0);

          when others =>
            mem_res_s <= (others => 'X'); -- force X for speed & area optimization / unsafe implementation             
            -- synthesis translate_off
            if(wb_i.ls_control_i = LOAD) then
              report "align load process: illegal alignment" severity warning;
            end if;
            -- synthesis translate_on

        end case;

      when WORD =>
        mem_res_s <= wb_i.mem_data_i;
        
      when others =>
        mem_res_s <= (others => 'X'); -- force X for speed & area optimization / unsafe implementation
        report "align load process: illegal mem sel control code" severity warning;

    end case;

  end process COMB_LOAD_ALIGN;
  
  --
  -- WRITE BACK MUX
  --
  --! This process handles the control of the result 
  --! to store into the register file of the processor. 
  COMB_WB_MUX: process(wb_i,
                       mem_res_s)    
  begin       

    case wb_i.ls_control_i is 

      when STORE =>
        res_s <= (others => 'X'); -- force X for speed & area optimization / unsafe implementation 	 

      when LOAD =>
        res_s <= mem_res_s;      

      when LS_NOP =>
        res_s <= wb_i.res_i;  

      when others =>
        res_s <= (others => 'X'); -- force X for speed & area optimization / unsafe implementation
        report "write-back mux: illegal load/store control code" severity warning;

    end case;

  end process COMB_WB_MUX;

  -- //////////////////////////////////////////
  --               CYCLE PROCESS
  -- //////////////////////////////////////////

  --
  -- WRITE-BACK REGISTER (OP A)
  --
  --! This process implements the WB/RF result register. This register is used 
  --! to implement the data forwarding feature for the operand A.
  CYCLE_WB_RF_A_RES: process(clk_i)
  begin

    -- clock event
    if(clk_i'event and clk_i = '1') then
 
      if(halt_core_i = '0' and wb_i.rf_res_a_lock_i = '0') then
        res_a_r <= res_s;
      end if;

    end if;

  end process CYCLE_WB_RF_A_RES; 

  --
  -- WRITE-BACK REGISTER (OP B)
  --
  --! This process implements the WB/RF result register. This register is used 
  --! to implement the data forwarding feature for the operand B.
  CYCLE_WB_RF_B_RES: process(clk_i)
  begin

    -- clock event
    if(clk_i'event and clk_i = '1') then
 
      if(halt_core_i = '0' and wb_i.rf_res_b_lock_i = '0') then
        res_b_r <= res_s;
      end if;

    end if;

  end process CYCLE_WB_RF_B_RES;

  --
  -- WRITE-BACK REGISTER (OP D)
  --
  --! This process implements the WB/RF result register. This register is used 
  --! to implement the data forwarding feature for the operand D.
  CYCLE_WB_RF_D_RES: process(clk_i)
  begin

    -- clock event
    if(clk_i'event and clk_i = '1') then
 
      if(halt_core_i = '0' and wb_i.rf_res_d_lock_i = '0') then
        res_d_r <= res_s;
      end if;

    end if;

  end process CYCLE_WB_RF_D_RES;

                
end be_sb_write_back;

