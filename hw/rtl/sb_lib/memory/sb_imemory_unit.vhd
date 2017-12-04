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
--! @file sb_imemory_unit.vhd                            					
--! @brief SecretBlaze Instruction Memory Unit 				
--! @author Lyonel Barthe
--! @version 1.1
--                                                                
-----------------------------------------------------------------
-----------------------------------------------------------------

--
-- Revision History
--
-- Version 1.1 02/09/2011 by Lyonel Barthe
-- Changed WISHBONE stalls management
-- Added the halt_ic_req control signal
--
-- Version 1.0 03/11/2010 by Lyonel Barthe
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

library tool_lib;
use tool_lib.math_pack.all;

library config_lib;
use config_lib.sb_config.all;
use config_lib.soc_config.all;

--
--! The module implements the management unit of the instruction memory. 
--
  
--! SecretBlaze Instruction Memory Unit Entity
entity sb_imemory_unit is

  generic
    (
      C_S_CLK_DIV      : real    := USER_C_S_CLK_DIV; --! core/system clock ratio
      USE_ICACHE       : boolean := USER_USE_ICACHE;  --! if true, it will implement the instruction cache
      IC_MEM_TYPE      : string  := USER_IC_MEM_TYPE; --! IC memory implementation type  
      IC_TAG_TYPE      : string  := USER_IC_TAG_TYPE; --! IC tag implementation type  
      IC_MEM_FILE      : string  := USER_IC_MEM_FILE; --! IC memory init file
      IC_TAG_FILE      : string  := USER_IC_TAG_FILE  --! IC tag init file  
    );

  port
    (
      iwb_bus_i        : in wb_master_bus_i_t;        --! instruction WISHBONE master bus inputs
      iwb_bus_o        : out wb_master_bus_o_t;       --! instruction WISHBONE master bus outputs
      iwb_grant_i      : in std_ulogic;               --! instruction WISHBONE grant signal input
      iwb_next_grant_i : in std_ulogic;               --! instruction WISHBONE next grant signal input
      im_bus_i         : in im_bus_i_t;               --! instruction L1 bus inputs
      im_bus_o         : out im_bus_o_t;              --! instruction L1 bus outputs
      im_l_bus_in_o    : out im_bus_i_t;              --! instruction L1 bus inputs (local memory side)
      im_l_bus_out_i   : in im_bus_o_t;               --! instruction L1 bus outputs (local memory side)
      wic_i            : in wic_control_t;            --! wic control input
      wic_adr_i        : in im_bus_adr_t;             --! wic address input
      ic_busy_o        : out std_ulogic;              --! instruction cache busy signal 
      halt_ic_i        : in std_ulogic;               --! instruction cache stall control signal
      halt_ic_req_i    : in std_ulogic;               --! instruction cache stall request process control signal
      halt_core_i      : in std_ulogic;               --! core stall control signal
      clk_i            : in std_ulogic;               --! core clock
      rst_n_i          : in std_ulogic                --! active-low reset signal 
    );

end sb_imemory_unit;

--! SecretBlaze Instruction Memory Unit Architecture
architecture be_sb_imemory_unit of sb_imemory_unit is

  -- //////////////////////////////////////////
  --               INTERNAL WIRES
  -- //////////////////////////////////////////
  
  --
  -- CONTROL SIGNALS
  --
  
  signal ic_burst_done_s : std_ulogic; 
  signal ic_req_done_s   : std_ulogic;
  
  --
  -- CORE <-> INTERNAL BUSSES
  --
        
  signal im_c_bus_in_s   : im_bus_i_t;
  signal im_c_bus_out_s  : im_bus_o_t;
  
  --
  -- CACHE <-> WB BUSSES
  --

  signal ic_bus_in_s     : ic_bus_i_t;
  signal ic_bus_out_s    : ic_bus_o_t;

begin

  -- //////////////////////////////////////////
  --             COMPONENTS LINK
  -- //////////////////////////////////////////

  IDECODER: entity sb_lib.sb_idecoder(be_sb_idecoder)
    generic map
    (
      USE_ICACHE            => USE_ICACHE
    )    
    port map
    ( 
      im_bus_i              => im_bus_i,
      im_bus_o              => im_bus_o,
      im_l_bus_in_o         => im_l_bus_in_o,
      im_l_bus_out_i        => im_l_bus_out_i,
      im_c_bus_in_o         => im_c_bus_in_s,
      im_c_bus_out_i        => im_c_bus_out_s,
      halt_ic_i             => halt_ic_i,
      halt_core_i           => halt_core_i,
      clk_i                 => clk_i    
    );
      
  GEN_ICACHE: if(USE_ICACHE = true) generate 

    ICACHE: entity sb_lib.sb_icache(be_sb_icache)
      generic map
      (
        C_S_CLK_DIV         => C_S_CLK_DIV,
        IC_MEM_TYPE         => IC_MEM_TYPE,
        IC_TAG_TYPE         => IC_TAG_TYPE,
        IC_MEM_FILE         => IC_MEM_FILE,
        IC_TAG_FILE         => IC_TAG_FILE
      )
      port map
      (
        im_c_bus_i          => im_c_bus_in_s,
        im_c_bus_o          => im_c_bus_out_s,
        wic_i               => wic_i,
        wic_adr_i           => wic_adr_i,
        ic_bus_in_o         => ic_bus_in_s,
        ic_bus_out_i        => ic_bus_out_s,
        ic_bus_next_grant_i => iwb_next_grant_i,
        ic_busy_o           => ic_busy_o,
        ic_req_done_o       => ic_req_done_s,
        ic_burst_done_o     => ic_burst_done_s,
        halt_ic_i           => halt_ic_i,
        halt_ic_req_i       => halt_ic_req_i,
        clk_i               => clk_i,
        rst_n_i             => rst_n_i  
      );
  
  end generate GEN_ICACHE; 
  
  GEN_IWB_INTERFACE: if(USE_ICACHE = true) generate

    IWB_INTERFACE: entity sb_lib.sb_iwb_interface(be_sb_iwb_interface)  
      generic map
      (
        C_S_CLK_DIV         => C_S_CLK_DIV
      )
      port map
      (
        iwb_bus_i           => iwb_bus_i,
        iwb_bus_o           => iwb_bus_o,
        ic_bus_i            => ic_bus_in_s,
        ic_bus_o            => ic_bus_out_s,
        ic_req_done_i       => ic_req_done_s,
        ic_burst_done_i     => ic_burst_done_s    
      );
    
  end generate GEN_IWB_INTERFACE;
    
end be_sb_imemory_unit;

