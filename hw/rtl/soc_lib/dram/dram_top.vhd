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
--! @file dram_top.vhd                                					
--! @brief DRAM Top Level Entity      				
--! @author Lyonel Barthe
--! @version 1.0
--                                                                
-----------------------------------------------------------------
-----------------------------------------------------------------

--
-- Revision History
--
-- Version 1.0 08/2012 by Lyonel Barthe
-- Initial Release
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library wb_lib;
use wb_lib.wb_pack.all;

library soc_lib;
use soc_lib.dram_pack.all;

library tool_lib;
use tool_lib.math_pack.all;

library config_lib;
use config_lib.soc_config.all;
use config_lib.sim_config.all;

--
--! The module implements the top level entity of Xilinx's 
--! MIG DRAM controller with its WISHBONE slave interface.
--! It should be compatible with all Spartan-6 devices.  
--

--! DRAM Top Level Entity
entity dram_top is

  generic
    (
      SIMULATION_MODE : string  := USER_SIMULATION_MODE; --! simulation mode setting
      DCLK_PERIOD_PS  : natural := USER_DCLK_PERIOD_PS;  --! DRAM memory clock period 
      DRAM_DATA_PIN_W : natural := USER_DRAM_DATA_PIN_W; --! DRAM external memory data width
      DRAM_ADR_W      : natural := USER_DRAM_ADR_W;      --! DRAM external memory address width
      DRAM_ROW_W      : natural := USER_DRAM_ROW_W;      --! DRAM external memory bank address width
      USE_CALIB_SOFT  : string  := USER_USE_CALIB_SOFT   --! DRAM controller calibration logic setting
    );

  port
    ( 
      dram_in_o       : out dram_i_t;                    --! DRAM interface control inputs 
      dram_io         : inout dram_io_t;                 --! DRAM inout data and control signals
      wb_bus_i        : in wb_slave_bus_i_t;             --! WISHBONE slave inputs
      wb_bus_o        : out wb_slave_bus_o_t;            --! WISHBONE slave outputs
      clk_i           : in std_logic;                    --! internal controller clock
      rst_n_i         : in std_logic                     --! active-low reset signal   
    );

end dram_top;

--! DRAM Top Level Architecture
architecture be_dram_top of dram_top is
    
  -- //////////////////////////////////////////
  --              INTERNAL WIRES
  -- //////////////////////////////////////////

  signal c3_p0_cmd_en_in_s        : std_logic;
  signal c3_p0_cmd_instr_in_s     : mig_inst_t;
  signal c3_p0_cmd_bl_in_s        : mig_bl_t;    
  signal c3_p0_cmd_byte_addr_in_s : mig_adr_t;
  signal c3_p0_cmd_empty_out_s    : std_logic;   
  signal c3_p0_cmd_full_out_s     : std_logic;     
  signal c3_p0_wr_en_in_s         : std_logic;  
  signal c3_p0_wr_mask_in_s       : mig_mask_t;
  signal c3_p0_wr_data_in_s       : mig_data_t;
  signal c3_p0_wr_count_out_s     : mig_counter_t;    
  signal c3_p0_wr_full_out_s      : std_logic;
  signal c3_p0_wr_empty_out_s     : std_logic; 
  signal c3_p0_rd_en_in_s         : std_logic;   
  signal c3_p0_rd_empty_out_s     : std_logic;
  signal c3_p0_rd_full_out_s      : std_logic;  
  signal c3_p0_rd_data_out_s      : mig_data_t; 
  signal c3_p0_rd_count_out_s     : mig_counter_t;        
    
begin

  -- //////////////////////////////////////////
  --              COMPONENTS LINK
  -- //////////////////////////////////////////

  DRAM_CTR: entity soc_lib.mig_37
    generic map 
    (
      C3_P0_MASK_SIZE          => 4,
      C3_P0_DATA_PORT_SIZE     => 32,
      C3_P1_MASK_SIZE          => 4,
      C3_P1_DATA_PORT_SIZE     => 32,  
      DEBUG_EN                 => 0,
      C3_MEMCLK_PERIOD         => DCLK_PERIOD_PS,
      C3_CALIB_SOFT_IP         => USE_CALIB_SOFT,
      C3_SIMULATION            => SIMULATION_MODE,
      C3_RST_ACT_LOW           => 1,
      C3_INPUT_CLK_TYPE        => "SINGLE_ENDED",
      C3_MEM_ADDR_ORDER        => "BANK_ROW_COLUMN",
      C3_NUM_DQ_PINS           => DRAM_DATA_PIN_W,
      C3_MEM_ADDR_WIDTH        => DRAM_ADR_W,
      C3_MEM_BANKADDR_WIDTH    => DRAM_ROW_W
    )
    port map 
    (  
      mcb3_dram_dq             => dram_io.ddr2dq_io,   
      mcb3_dram_a              => dram_in_o.ddr2a_i, 
      mcb3_dram_ba             => dram_in_o.ddr2ba_i, 
      mcb3_dram_ras_n          => dram_in_o.ddr2rasn_i,       
      mcb3_dram_cas_n          => dram_in_o.ddr2casn_i,     
      mcb3_dram_we_n           => dram_in_o.ddr2wen_i,
      mcb3_dram_odt            => dram_in_o.ddr2odt_i,             
      mcb3_dram_cke            => dram_in_o.ddr2clke_i,      
      mcb3_dram_dm             => dram_in_o.ddr2ldm_i,
      mcb3_dram_udqs           => dram_io.ddr2udqs_p_io,
      mcb3_dram_udqs_n         => dram_io.ddr2udqs_n_io,      
      mcb3_rzq                 => dram_io.ddr2rzq_io,
      mcb3_zio                 => dram_io.ddr2zio_io,      
      mcb3_dram_udm            => dram_in_o.ddr2udm_i,
      c3_sys_clk               => clk_i,
      c3_sys_rst_n             => rst_n_i,    
      c3_calib_done            => open,          
      c3_clk0                  => open,
      c3_rst0                  => open,
      mcb3_dram_dqs            => dram_io.ddr2ldqs_p_io, 
      mcb3_dram_dqs_n          => dram_io.ddr2ldqs_n_io,        
      mcb3_dram_ck             => dram_in_o.ddr2clk_p_i,
      mcb3_dram_ck_n           => dram_in_o.ddr2clk_n_i,       
      c3_p0_cmd_clk            => wb_bus_i.clk_i,
      c3_p0_cmd_en             => c3_p0_cmd_en_in_s,  
      c3_p0_cmd_instr          => c3_p0_cmd_instr_in_s,   
      c3_p0_cmd_bl             => c3_p0_cmd_bl_in_s,   
      c3_p0_cmd_byte_addr      => c3_p0_cmd_byte_addr_in_s,
      c3_p0_cmd_empty          => c3_p0_cmd_empty_out_s,
      c3_p0_cmd_full           => c3_p0_cmd_full_out_s,             
      c3_p0_wr_clk             => wb_bus_i.clk_i,
      c3_p0_wr_en              => c3_p0_wr_en_in_s,
      c3_p0_wr_mask            => c3_p0_wr_mask_in_s,
      c3_p0_wr_data            => c3_p0_wr_data_in_s,
      c3_p0_wr_full            => c3_p0_wr_full_out_s,
      c3_p0_wr_empty           => c3_p0_wr_empty_out_s,
      c3_p0_wr_count           => c3_p0_wr_count_out_s,
      c3_p0_wr_underrun        => open,
      c3_p0_wr_error           => open,
      c3_p0_rd_clk             => wb_bus_i.clk_i,
      c3_p0_rd_en              => c3_p0_rd_en_in_s,
      c3_p0_rd_data            => c3_p0_rd_data_out_s,
      c3_p0_rd_full            => c3_p0_rd_full_out_s,
      c3_p0_rd_empty           => c3_p0_rd_empty_out_s,
      c3_p0_rd_count           => c3_p0_rd_count_out_s,
      c3_p0_rd_overflow        => open,
      c3_p0_rd_error           => open   
    );
    
  WB_SLV_DRAM: entity soc_lib.dram_slave_wb_bus(be_dram_slave_wb_bus)
    port map
    (
      wb_bus_i                 => wb_bus_i,
      wb_bus_o                 => wb_bus_o,
      c3_p0_cmd_en_in_o        => c3_p0_cmd_en_in_s,
      c3_p0_cmd_instr_in_o     => c3_p0_cmd_instr_in_s,
      c3_p0_cmd_bl_in_o        => c3_p0_cmd_bl_in_s,
      c3_p0_cmd_byte_addr_in_o => c3_p0_cmd_byte_addr_in_s,
      c3_p0_cmd_full_out_i     => c3_p0_cmd_full_out_s,
      c3_p0_cmd_empty_out_i    => c3_p0_cmd_empty_out_s,
      c3_p0_wr_en_in_o         => c3_p0_wr_en_in_s,
      c3_p0_wr_mask_in_o       => c3_p0_wr_mask_in_s,
      c3_p0_wr_data_in_o       => c3_p0_wr_data_in_s,
      c3_p0_wr_full_out_i      => c3_p0_wr_full_out_s,
      c3_p0_wr_empty_out_i     => c3_p0_wr_empty_out_s,
      c3_p0_wr_count_out_i     => c3_p0_wr_count_out_s,
      c3_p0_rd_en_in_o         => c3_p0_rd_en_in_s,     
      c3_p0_rd_data_out_i      => c3_p0_rd_data_out_s,
      c3_p0_rd_full_out_i      => c3_p0_rd_full_out_s,      
      c3_p0_rd_empty_out_i     => c3_p0_rd_empty_out_s,
      c3_p0_rd_count_out_i     => c3_p0_rd_count_out_s      
    );   

end be_dram_top;

