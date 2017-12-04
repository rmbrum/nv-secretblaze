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
--! @file sb_iwb_interface.vhd                            					
--! @brief SecretBlaze Instruction WISHBONE Interface 				
--! @author Lyonel Barthe
--! @version 1.0
--                                                                
-----------------------------------------------------------------
-----------------------------------------------------------------

--
-- Revision History
--
-- Version 1.0 21/01/2012 by Lyonel Barthe
-- Initial release
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library sb_lib;
use sb_lib.sb_core_pack.all;
use sb_lib.sb_memory_unit_pack.all;

library wb_lib;
use wb_lib.wb_pack.all;

library config_lib;
use config_lib.soc_config.all;

--
--! The module implements the WISHBONE interface for instruction memory accesses.
--
  
--! SecretBlaze Instruction WISHBONE Interface Entity
entity sb_iwb_interface is

  generic
    (
      C_S_CLK_DIV     : real := USER_C_S_CLK_DIV --! core/system clock ratio
    );

  port
    (
      iwb_bus_i       : in wb_master_bus_i_t;    --! instruction WISHBONE master bus inputs
      iwb_bus_o       : out wb_master_bus_o_t;   --! instruction WISHBONE master bus outputs
      ic_bus_i        : in ic_bus_i_t;           --! instruction cache bus inputs
      ic_bus_o        : out ic_bus_o_t;          --! instruction cache bus outputs
      ic_req_done_i   : in std_ulogic;           --! instruction cache request done flag
      ic_burst_done_i : in std_ulogic            --! instruction cache burst done flag      
    );

end sb_iwb_interface;

--! SecretBlaze Instruction WISHBONE Interface Architecture
architecture be_sb_iwb_interface of sb_iwb_interface is

  -- //////////////////////////////////////////
  --               INTERNAL REGS
  -- //////////////////////////////////////////

  signal iwb_stb_o_r : std_ulogic;    --! instruction WISHBONE memory ena reg 
  signal iwb_adr_o_r : wb_bus_adr_t;  --! instruction WISHBONE memory data out reg 
  signal iwb_cti_o_r : wb_bus_cti_t;  --! instruction WISHBONE memory bus flag reg 
  signal iwb_cyc_o_r : std_ulogic;    --! instruction WISHBONE memory cyc reg 
  signal iwb_dat_i_r : wb_bus_data_t; --! instruction WISHBONE memory data in reg
  signal iwb_ack_i_r : std_ulogic;    --! instruction WISHBONE memory ack reg 

  -- //////////////////////////////////////////
  --               INTERNAL WIRES
  -- //////////////////////////////////////////
  
  --
  -- WB INTERFACE SIGNALS
  --

  signal iwb_stb_o_s : std_ulogic;
  signal iwb_sel_o_s : wb_bus_sel_t; 
  signal iwb_dat_o_s : wb_bus_data_t;
  signal iwb_adr_o_s : wb_bus_adr_t;  
  signal iwb_we_o_s  : std_ulogic;  
  signal iwb_cti_o_s : wb_bus_cti_t;  
  signal iwb_bte_o_s : wb_bus_bte_t;  
  signal iwb_cyc_o_s : std_ulogic;   
  signal iwb_bl_o_s  : wb_bus_bl_t;

begin

  -- //////////////////////////////////////////
  --                COMB PROCESS
  -- //////////////////////////////////////////

  --
  -- ASSIGN OUTPUTS
  --

  --
  -- WB -> MAIN MEMORY
  -- 

  iwb_bus_o.adr_o <= iwb_adr_o_s;
  iwb_bus_o.sel_o <= iwb_sel_o_s;
  iwb_bus_o.we_o  <= iwb_we_o_s;
  iwb_bus_o.stb_o <= iwb_stb_o_s;
  iwb_bus_o.cyc_o <= iwb_cyc_o_s;
  iwb_bus_o.dat_o <= iwb_dat_o_s;
  iwb_bus_o.cti_o <= iwb_cti_o_s;
  iwb_bus_o.bte_o <= iwb_bte_o_s;
  iwb_bus_o.bl_o  <= iwb_bl_o_s;
  
  --
  -- WB -> CACHE
  --

  ic_bus_o.dat_o  <= iwb_dat_i_r;
  ic_bus_o.ack_o  <= iwb_ack_i_r;

  --
  -- INST WB MASTER OUTPUT LOGIC
  --
  --! This process implements the instruction WISHBONE master output interface.
  COMB_INST_WB_OUT_LOGIC: process(iwb_cyc_o_r,
                                  iwb_stb_o_r,
                                  iwb_adr_o_r,
                                  iwb_cti_o_r,
                                  iwb_bus_i)
  begin

    -- support read mode only
    iwb_we_o_s  <= '0';
    iwb_dat_o_s <= (others => '0');
    iwb_bte_o_s <= WB_LINEAR_BURST;
    iwb_cyc_o_s <= iwb_cyc_o_r; 
    iwb_stb_o_s <= iwb_stb_o_r;
    iwb_adr_o_s <= iwb_adr_o_r;
    iwb_sel_o_s <= WB_WORD_SEL;
    iwb_cti_o_s <= iwb_cti_o_r;
    iwb_bl_o_s  <= std_ulogic_vector(to_unsigned((IC_LINE_WORD_S - 1),wb_bus_bl_t'length));    

  end process COMB_INST_WB_OUT_LOGIC;

  -- //////////////////////////////////////////
  --               CYCLE PROCESS
  -- //////////////////////////////////////////

  --
  -- SCLK CLOCK REGION
  --

  --
  -- INST MASTER BUS REGISTERED OUTPUTS 
  -- 
  --! This process implements instruction WISHBONE master output registers.
  CYCLE_INST_WB_MST_OUT_REG: process(iwb_bus_i.clk_i)
  begin
  
    -- clock event
    if(iwb_bus_i.clk_i'event and iwb_bus_i.clk_i = '1') then
  
      -- sync reset
      if(iwb_bus_i.rst_i = '1') then
        iwb_stb_o_r   <= '0';
        iwb_cyc_o_r   <= '0';
      
      elsif(iwb_bus_i.stall_i = '0') then
        iwb_adr_o_r   <= ic_bus_i.adr_i;
        iwb_stb_o_r   <= ic_bus_i.ena_i;
        if(ic_burst_done_i = '1') then 
          iwb_cyc_o_r <= '0';

        elsif(iwb_cyc_o_r = '0') then
          iwb_cyc_o_r <= ic_bus_i.ena_i;

        end if;
        if(ic_burst_done_i = '1') then
          iwb_cti_o_r <= WB_INC_BURST_CYCLE;  

        elsif(ic_req_done_i = '1') then
          iwb_cti_o_r <= WB_END_OF_BURST;   

        else
          iwb_cti_o_r <= WB_INC_BURST_CYCLE;  

        end if;
        
      end if;
    
    end if;

  end process CYCLE_INST_WB_MST_OUT_REG;

  --
  -- INST MASTER BUS REGISTERED INPUTS
  --
  --! This process implements instruction WISHBONE master input registers.
  CYCLE_INST_WB_MST_IN_REG: process(iwb_bus_i.clk_i)
  begin
  
    -- clock event
    if(iwb_bus_i.clk_i'event and iwb_bus_i.clk_i = '1') then
  
      -- sync reset
      if(iwb_bus_i.rst_i = '1') then
        iwb_ack_i_r   <= '0';
      
      else
        iwb_dat_i_r   <= iwb_bus_i.dat_i;
        if(iwb_cyc_o_r = '1') then 
          iwb_ack_i_r <= iwb_bus_i.ack_i;
        end if;
        
      end if;

    end if;
  
  end process CYCLE_INST_WB_MST_IN_REG;
    
end be_sb_iwb_interface;

