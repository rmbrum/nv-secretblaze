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
--! @file sb_memory_unit.vhd                            					
--! @brief SecretBlaze Memory Unit 				
--! @author Lyonel Barthe
--! @version 1.4b
--                                                                
-----------------------------------------------------------------
-----------------------------------------------------------------

--
-- Revision History
--
-- Version 1.4b 01/09/2011 by Lyonel Barthe
-- Added the mem_busy signal to indicate memory operations
--
-- Version 1.4 03/10/2010 by Lyonel Barthe
-- Separate instruction and data memory unit version
-- Optional cache memories 
--
-- Version 1.3 23/10/2010 by Lyonel Barthe
-- wb_stall_i signals are now supported
--
-- Version 1.2 11/10/2010 by Lyonel Barthe
-- Added internal memories management
-- Changed internal decoder coding style
--
-- Version 1.1 28/09/2010 by Lyonel Barthe
-- IO accesses use now the WB pipelined protocol (REV B4)
--
-- Version 1.0 13/05/2010 by Lyonel Barthe
-- Stable version
--
-- Version 0.1 12/02/2010 by Lyonel Barthe
-- Initial Release
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
--! This is the top level module of the memory sub-system that plays 
--! a key role in overall performance. It is especially responsible for 
--! handling accesses to memories and I/O devices requested by the processor. 
--! As a modified Harvard architecture, the SecretBlaze is structured with 
--! separate instruction and data buses. It uses 32-bit addresses providing 
--! a 4 GB linear address space with 32-bit word-length. Like most embedded 
--! processors, the memory-mapped I/O method is implemented to ensure the communication 
--! with peripheral devices. To achieve an efficient and cost-effective system, 
--! the memory architecture of the SecretBlaze is organised in four main components:
--!   - local on-chip memories, 
--!   - cache memories, 
--!   - external memory interfaces, and 
--!   - a memory sub-system controller.
--!
--! The pipelined WISHBONE bus interface was implemented to allow the connection
--! of additional peripheral devices. The major feature of the pipelined mode is 
--! that a master interface does not wait for the acknowledgement before outputting 
--! next address and data on the bus, which increases the throughput of advanced 
--! memory integrated circuits such as DDR-SDRAM chips. Hence, the SecretBlaze 
--! provides two pipelined Wishbone master interfaces; one for the instruction 
--! memory bus and one for the data memory bus. To increase the bandwidth efficiency, 
--! the burst mode is supported for cache memories in accordance with the WISHBONE 
--! standard. As regards other peripherals, the data interface implements pipelined 
--! WISHBONE single write and read operations.
--! Both single and burst protocols are illustrated below.
--! 
--! SINGLE PIPELINED PROTOCOL:
--!                 _   _   _   _   _   _   _   _   _   _ 
--! SCLK          _| |_| |_| |_| |_| |_| |_| |_| |_| |_|
--!                         ___________
--! GRANT_I       _________|           |_________________
--!                     ___________
--! CYC_O         _____|           |_____________________
--!                     _______
--! STB_O         _____|       |_________________________
--!
--! COUNT         -----|   1   |-------------------------
--!                             ___
--! ACK_I         _____________|   |_____________________
--! 
--!
--! BURST PIPELINED PROTOCOL:
--!                 _   _   _   _   _   _   _   _   _   _
--! SCLK          _| |_| |_| |_| |_| |_| |_| |_| |_| |_|
--!                     _______________________
--! NEXT_GRANT_I  _____|                       |_________
--!                         _______________________
--! GRANT_I       _________|                       |_____
--!                     _______________________
--! CYC_O         _____|                       |_________
--!                     ___________________
--! STB_O         _____|                   |_____________
--!
--! COUNT         -----|   1   | 2 | 3 | 4 |-------------
--!                             _______________
--! ACK_I         _____________|               |_________
--!
--
  
--! SecretBlaze Memory Unit Entity
entity sb_memory_unit is

  generic
    (
      LM_TYPE          : string  := USER_LM_TYPE;       --! LM implementation type 
      LM_FILE_1        : string  := USER_LM_FILE_1;     --! LM init file LSB
      LM_FILE_2        : string  := USER_LM_FILE_2;     --! LM init file LSB+
      LM_FILE_3        : string  := USER_LM_FILE_3;     --! LM init file MSB-
      LM_FILE_4        : string  := USER_LM_FILE_4;     --! LM init file MSB
      C_S_CLK_DIV      : real    := USER_C_S_CLK_DIV;   --! core/system clock ratio
      USE_DCACHE       : boolean := USER_USE_DCACHE;    --! if true, it will implement the data cache
      DC_MEM_TYPE      : string  := USER_DC_MEM_TYPE;   --! DC memory implementation type  
      DC_TAG_TYPE      : string  := USER_DC_TAG_TYPE;   --! DC tag implementation type  
      DC_MEM_FILE_1    : string  := USER_DC_MEM_FILE_1; --! DC memory init file LSB
      DC_MEM_FILE_2    : string  := USER_DC_MEM_FILE_2; --! DC memory init file LSB+
      DC_MEM_FILE_3    : string  := USER_DC_MEM_FILE_3; --! DC memory init file MSB-
      DC_MEM_FILE_4    : string  := USER_DC_MEM_FILE_4; --! DC memory init file MSB  
      DC_TAG_FILE      : string  := USER_DC_TAG_FILE;   --! DC tag init file
      USE_WRITEBACK    : boolean := USER_USE_WRITEBACK; --! if true, use write-back policy
      USE_ICACHE       : boolean := USER_USE_ICACHE;    --! if true, it will implement the instruction cache
      IC_MEM_TYPE      : string  := USER_IC_MEM_TYPE;   --! IC memory implementation type 
      IC_TAG_TYPE      : string  := USER_IC_TAG_TYPE;   --! IC tag implementation type 
      IC_MEM_FILE      : string  := USER_IC_MEM_FILE;   --! IC memory init file
      IC_TAG_FILE      : string  := USER_IC_TAG_FILE    --! IC tag init file  
    );

  port
    (
      iwb_bus_i        : in wb_master_bus_i_t;          --! instruction WISHBONE master bus inputs
      iwb_bus_o        : out wb_master_bus_o_t;         --! instruction WISHBONE master bus outputs
      iwb_grant_i      : in std_ulogic;                 --! instruction WISHBONE grant signal input
      iwb_next_grant_i : in std_ulogic;                 --! instruction WISHBONE next grant signal input
      dwb_bus_i        : in wb_master_bus_i_t;          --! data WISHBONE master bus inputs
      dwb_bus_o        : out wb_master_bus_o_t;         --! data WISHBONE master bus outputs
      dwb_grant_i      : in std_ulogic;                 --! data WISHBONE grant signal input
      dwb_next_grant_i : in std_ulogic;                 --! data WISHBONE next grant signal input
      im_bus_i         : in im_bus_i_t;                 --! instruction L1 bus inputs (core side)
      im_bus_o         : out im_bus_o_t;                --! instruction L1 bus outputs (core side)
      dm_bus_i         : in dm_bus_i_t;                 --! data L1 bus inputs (core side)
      dm_bus_o         : out dm_bus_o_t;                --! data L1 bus outputs (core side)
      wdc_i            : in wdc_control_t;              --! wdc control input
      wic_i            : in wic_control_t;              --! wic control input
      mem_busy_o       : out std_ulogic;                --! memory busy control signal
      halt_core_o      : out std_ulogic;                --! halt core control signal
      halt_sb_i        : in std_ulogic;                 --! halt processor signal
      clk_i            : in std_ulogic;                 --! core clock
      rst_n_i          : in std_ulogic                  --! active-low reset signal 
    );

end sb_memory_unit;

--! SecretBlaze Memory Unit Architecture
architecture be_sb_memory_unit of sb_memory_unit is

  -- //////////////////////////////////////////
  --               INTERNAL WIRES
  -- //////////////////////////////////////////

  --
  -- LOCAL MEMORY BUSSES
  --

  signal dm_l_bus_in_s  : dm_bus_i_t;
  signal dm_l_bus_out_s : dm_bus_o_t;  
  signal im_l_bus_in_s  : im_bus_i_t;
  signal im_l_bus_out_s : im_bus_o_t;

  --
  -- CONTROL SIGNALS
  --
  
  signal dc_busy_s      : std_ulogic;
  signal ic_busy_s      : std_ulogic;
  signal io_busy_s      : std_ulogic;
  signal halt_ic_s      : std_ulogic;
  signal halt_ic_req_s  : std_ulogic; 
  signal halt_dc_s      : std_ulogic; 
  signal halt_dc_req_s  : std_ulogic;
  signal halt_io_s      : std_ulogic;
  signal halt_core_s    : std_ulogic;                   
      
begin

  -- //////////////////////////////////////////
  --             COMPONENTS LINK
  -- //////////////////////////////////////////

  INST_MEMORY_UNIT: entity sb_lib.sb_imemory_unit(be_sb_imemory_unit)
    generic map
    (
      C_S_CLK_DIV      => C_S_CLK_DIV,
      USE_ICACHE       => USE_ICACHE,
      IC_MEM_TYPE      => IC_MEM_TYPE,
      IC_TAG_TYPE      => IC_TAG_TYPE,
      IC_MEM_FILE      => IC_MEM_FILE,
      IC_TAG_FILE      => IC_TAG_FILE
    )
    port map
    (
      iwb_bus_i        => iwb_bus_i,
      iwb_bus_o        => iwb_bus_o,
      iwb_grant_i      => iwb_grant_i,
      iwb_next_grant_i => iwb_next_grant_i,
      im_bus_i         => im_bus_i,
      im_bus_o         => im_bus_o,
      im_l_bus_in_o    => im_l_bus_in_s,
      im_l_bus_out_i   => im_l_bus_out_s,
      wic_i            => wic_i,
      wic_adr_i        => dm_bus_i.adr_i,
      ic_busy_o        => ic_busy_s,
      halt_ic_i        => halt_ic_s,
      halt_ic_req_i    => halt_ic_req_s,
      halt_core_i      => halt_core_s,
      clk_i            => clk_i,
      rst_n_i          => rst_n_i
    );
    
  DATA_MEMORY_UNIT: entity sb_lib.sb_dmemory_unit(be_sb_dmemory_unit)
    generic map
    (
      C_S_CLK_DIV      => C_S_CLK_DIV,
      USE_DCACHE       => USE_DCACHE,
      DC_MEM_TYPE      => DC_MEM_TYPE,
      DC_TAG_TYPE      => DC_TAG_TYPE,
      DC_MEM_FILE_1    => DC_MEM_FILE_1,
      DC_MEM_FILE_2    => DC_MEM_FILE_2,
      DC_MEM_FILE_3    => DC_MEM_FILE_3,
      DC_MEM_FILE_4    => DC_MEM_FILE_4,
      DC_TAG_FILE      => DC_TAG_FILE,
      USE_WRITEBACK    => USE_WRITEBACK
    )
    port map
    (
      dwb_bus_i        => dwb_bus_i,
      dwb_bus_o        => dwb_bus_o,
      dwb_grant_i      => dwb_grant_i,
      dwb_next_grant_i => dwb_next_grant_i,
      dm_bus_i         => dm_bus_i,
      dm_bus_o         => dm_bus_o,
      dm_l_bus_in_o    => dm_l_bus_in_s,
      dm_l_bus_out_i   => dm_l_bus_out_s,
      wdc_i            => wdc_i,
      dc_busy_o        => dc_busy_s,
      io_busy_o        => io_busy_s,
      halt_dc_i        => halt_dc_s,
      halt_dc_req_i    => halt_dc_req_s,
      halt_io_i        => halt_io_s,
      halt_core_i      => halt_core_s,
      clk_i            => clk_i,
      rst_n_i          => rst_n_i
    );
  
  MEMORY_UNIT_CTR: entity sb_lib.sb_memory_unit_controller(be_sb_memory_unit_controller)
    generic map
    (
      USE_DCACHE       => USE_DCACHE,
      USE_ICACHE       => USE_ICACHE
    )
    port map
    (
      ic_busy_i        => ic_busy_s,
      dc_busy_i        => dc_busy_s,
      io_busy_i        => io_busy_s,
      iwb_stall_i      => iwb_bus_i.stall_i,
      dwb_stall_i      => dwb_bus_i.stall_i,
      halt_sb_i        => halt_sb_i,
      halt_ic_o        => halt_ic_s,
      halt_ic_req_o    => halt_ic_req_s,
      halt_dc_o        => halt_dc_s,
      halt_dc_req_o    => halt_dc_req_s,
      halt_io_o        => halt_io_s,
      halt_core_o      => halt_core_s   
    );
    
  LOCAL_MEMORY: entity sb_lib.sb_lmemory(be_sb_lmemory)
    generic map
    (
      LM_TYPE          => LM_TYPE, 
      LM_FILE_1        => LM_FILE_1, 
      LM_FILE_2        => LM_FILE_2, 
      LM_FILE_3        => LM_FILE_3, 
      LM_FILE_4        => LM_FILE_4
    )
    port map
    (
      dm_l_bus_i       => dm_l_bus_in_s,
      dm_l_bus_o       => dm_l_bus_out_s,
      im_l_bus_i       => im_l_bus_in_s,
      im_l_bus_o       => im_l_bus_out_s,
      halt_core_i      => halt_core_s, 
      clk_i            => clk_i
    );

  -- //////////////////////////////////////////
  --                COMB PROCESS
  -- //////////////////////////////////////////

  --
  -- ASSIGN OUTPUTS
  --

  halt_core_o <= halt_core_s;
  mem_busy_o  <= (dc_busy_s or ic_busy_s or io_busy_s);
  
end be_sb_memory_unit;

