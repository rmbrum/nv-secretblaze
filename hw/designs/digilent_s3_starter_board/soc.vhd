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
--! @file soc.vhd                                         					
--! @brief System-on-Chip Entity
--! @author Lyonel Barthe
--! @version 1.0
--                                                                 
-----------------------------------------------------------------
-----------------------------------------------------------------

--
-- Revision History
--
-- Version 1.0 9/04/2010 by Lyonel Barthe
-- Initial Release
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library sb_lib;
use sb_lib.sb_core_pack.all;

library wb_lib;
use wb_lib.wb_pack.all;

library soc_lib;
use soc_lib.intc_pack.all;
use soc_lib.gpio_pack.all;
use soc_lib.uart_pack.all;
use soc_lib.timer_pack.all;
use soc_lib.sram_pack.all;

library config_lib;
use config_lib.soc_config.all;
use config_lib.sb_config.all;

--
--! The entity implements a SecretBlaze-based SoC entity.
--

--! SoC Entity
entity soc is

  port
    (   
      uart_i       : in uart_i_t;     --! UART general inputs
      uart_o       : out uart_o_t;    --! UART general outputs
      gpio_i       : in gpio_i_t;     --! GPIO general inputs
      gpio_o       : out gpio_o_t;    --! GPIO general outputs
      sram_in_o    : out sram_i_t;    --! SRAM general inputs
      sram_data_io : inout sram_io_t; --! SRAM data in/out
      sclk_i       : in std_ulogic;   --! system clock
      cclk_i       : in std_ulogic;   --! core clock
      mclk_i       : in std_ulogic;   --! memory controller clock
      rst_n_i      : in std_ulogic    --! active-low reset signal 
    );

end soc;

--! SecretBlaze SoC Architecture
architecture be_soc of soc is

  -- //////////////////////////////////////////
  --              INTERNAL WIRES
  -- //////////////////////////////////////////

  --
  -- CONTROL SIGNAL
  -- 
 
  signal halt_sb_s        : std_ulogic;

  --
  -- WB BUS
  -- 

  signal wb_master_i_s    : wb_master_vector_i_t(0 to USER_NUMBER_MASTERS - 1);
  signal wb_master_o_s    : wb_master_vector_o_t(0 to USER_NUMBER_MASTERS - 1);
  signal wb_slave_i_s     : wb_slave_vector_i_t(0 to USER_NUMBER_SLAVES - 1);
  signal wb_slave_o_s     : wb_slave_vector_o_t(0 to USER_NUMBER_SLAVES - 1);
  signal wb_grant_s       : std_ulogic_vector(0 to USER_NUMBER_MASTERS - 1);  
  signal wb_next_grant_s  : std_ulogic_vector(0 to USER_NUMBER_MASTERS - 1);  

  --
  -- INTERRUPT SIGNALS
  --
  
  signal intc_i_s         : intc_i_t;
  signal intc_o_s         : intc_o_t;
  signal uart_it_s        : uart_int_vector_t;
  signal timer_it_s       : timer_int_vector_t;

begin

  -- //////////////////////////////////////////
  --             COMPONENTS LINK
  -- //////////////////////////////////////////
  
  -- //////////////////////////////////////////
  --               WISHBONE BUS
  -- //////////////////////////////////////////

  WB_BUS: entity wb_lib.wb_top(be_wb_top)
    generic map
    ( 
      MEM_MAP            => USER_WB_MEM_MAP,
      ADDRESS_DEC_W      => USER_WB_ADDRESS_DEC_W,
      NB_OF_SLAVES       => USER_NUMBER_SLAVES,
      NB_OF_MASTERS      => USER_NUMBER_MASTERS
    )
    port map
    (
      wb_master_out_i    => wb_master_o_s,
      wb_master_in_o     => wb_master_i_s,
      wb_slave_out_i     => wb_slave_o_s,
      wb_slave_in_o      => wb_slave_i_s,
      wb_grant_o         => wb_grant_s,
      wb_next_grant_o    => wb_next_grant_s,
      clk_i              => sclk_i,
      rst_n_i            => rst_n_i
    ); 
  
  -- //////////////////////////////////////////
  --           SECRETBLAZE PROCESSOR
  -- //////////////////////////////////////////

  SECRETBLAZE: entity sb_lib.sb_cpu(be_sb_cpu)
    generic map
    (
      RF_TYPE            => USER_RF_TYPE,
      USE_BTC            => USER_USE_BTC,
      BTC_MEM_FILE       => USER_BTC_MEM_FILE,
      BTC_TAG_FILE       => USER_BTC_TAG_FILE,
      BTC_MEM_TYPE       => USER_BTC_MEM_TYPE,
      LM_TYPE            => USER_LM_TYPE,
      LM_FILE_1          => USER_LM_FILE_1,
      LM_FILE_2          => USER_LM_FILE_2,
      LM_FILE_3          => USER_LM_FILE_3,
      LM_FILE_4          => USER_LM_FILE_4,
      C_S_CLK_DIV        => USER_C_S_CLK_DIV,
      USE_PC_RET         => USER_USE_PC_RET,
      USE_DCACHE         => USER_USE_DCACHE,
      DC_MEM_TYPE        => USER_DC_MEM_TYPE,
      DC_TAG_TYPE        => USER_DC_TAG_TYPE,
      DC_MEM_FILE_1      => USER_DC_MEM_FILE_1,
      DC_MEM_FILE_2      => USER_DC_MEM_FILE_2,
      DC_MEM_FILE_3      => USER_DC_MEM_FILE_3,
      DC_MEM_FILE_4      => USER_DC_MEM_FILE_4,
      DC_TAG_FILE        => USER_DC_TAG_FILE,
      USE_WRITEBACK      => USER_USE_WRITEBACK,
      USE_ICACHE         => USER_USE_ICACHE,
      IC_MEM_TYPE        => USER_IC_MEM_TYPE,
      IC_TAG_TYPE        => USER_IC_TAG_TYPE,
      IC_MEM_FILE        => USER_IC_MEM_FILE,
      IC_TAG_FILE        => USER_IC_TAG_FILE,
      USE_INT            => USER_USE_INT,
      USE_SPR            => USER_USE_SPR,
      USE_MULT           => USER_USE_MULT,
      USE_PIPE_MULT      => USER_USE_PIPE_MULT,
      USE_BS             => USER_USE_BS,
      USE_PIPE_BS        => USER_USE_PIPE_BS,
      USE_DIV            => USER_USE_DIV,
      USE_PAT            => USER_USE_PAT,
      USE_CLZ            => USER_USE_CLZ,
      USE_PIPE_CLZ       => USER_USE_PIPE_CLZ,
      STRICT_HAZ         => USER_STRICT_HAZ,
      FW_IN_MULT         => USER_FW_IN_MULT,
      FW_LD              => USER_FW_LD
    )
    port map
    (		
      iwb_bus_i          => wb_master_i_s(USER_MST_SB_IC_C),
      iwb_bus_o          => wb_master_o_s(USER_MST_SB_IC_C),
      iwb_grant_i        => wb_grant_s(USER_MST_SB_IC_C),
      iwb_next_grant_i   => wb_next_grant_s(USER_MST_SB_IC_C),
      dwb_bus_i          => wb_master_i_s(USER_MST_SB_DC_C),
      dwb_bus_o          => wb_master_o_s(USER_MST_SB_DC_C),
      dwb_grant_i        => wb_grant_s(USER_MST_SB_DC_C),
      dwb_next_grant_i   => wb_next_grant_s(USER_MST_SB_DC_C),
      int_i              => intc_o_s.cpu_int_o,
      halt_sb_i          => halt_sb_s,
      clk_i              => cclk_i,                 
      rst_n_i            => rst_n_i      
    );

  halt_sb_s <= '0'; -- by default, always running

  -- //////////////////////////////////////////
  --              CACHEABLE MEMORY
  -- //////////////////////////////////////////

  -- //////////////////////////////////////////
  --              CACHEABLE MEMORY
  -- //////////////////////////////////////////

  GEN_SRAM: if(USER_USE_SRAM = true) generate 

    SRAM: entity soc_lib.sram_top(be_sram_top)
      generic map
      (
        M_S_CLK_DIV      => USER_M_S_CLK_DIV
      )
      port map
      (
        sram_in_o        => sram_in_o,
        sram_data_io     => sram_data_io,
        wb_bus_i         => wb_slave_i_s(USER_SLV_SRAM_ID_C),
        wb_bus_o         => wb_slave_o_s(USER_SLV_SRAM_ID_C),
        clk_i            => mclk_i,
        rst_n_i          => rst_n_i  
      );

  end generate GEN_SRAM;
  
  GEN_NO_SRAM: if(USER_USE_SRAM = false) generate

    -- force slave signals to NULL
    wb_slave_o_s(USER_SLV_SRAM_ID_C).ack_o   <= '0';
    wb_slave_o_s(USER_SLV_SRAM_ID_C).err_o   <= '0';
    wb_slave_o_s(USER_SLV_SRAM_ID_C).rty_o   <= '0';
    wb_slave_o_s(USER_SLV_SRAM_ID_C).dat_o   <= (others => '0');
    wb_slave_o_s(USER_SLV_SRAM_ID_C).stall_o <= '0';

  end generate GEN_NO_SRAM;

  -- //////////////////////////////////////////
  --            INTERRUPT CONTROLLER  
  -- //////////////////////////////////////////

  -- +---------------------------------------------------------------+
  -- |  ID7  |  ID6  |  ID5  |  ID4  |  ID3  |  ID2  |  ID1  |  ID0  |
  -- +---------------------------------------------------------------+
  -- |                  unused       |  TIMER 2 & 1  |  UTX  |  URX  |
  -- +---------------------------------------------------------------+
  
  GEN_INTC: if(USER_USE_INTC = true) generate 

    intc_i_s.int_sources_i(INTC_ID_7 downto INTC_ID_4) <= (others =>'0');
    intc_i_s.int_sources_i(INTC_ID_3 downto INTC_ID_2) <= timer_it_s;
    intc_i_s.int_sources_i(INTC_ID_1 downto INTC_ID_0) <= uart_it_s;

    INTC: entity soc_lib.intc_slave_wb_bus(be_intc_slave_wb_bus)
      port map
        (
          intc_i         => intc_i_s,
          intc_o         => intc_o_s,    
          wb_bus_i       => wb_slave_i_s(USER_SLV_INTC_ID_C), 
          wb_bus_o       => wb_slave_o_s(USER_SLV_INTC_ID_C)   
        );

  end generate GEN_INTC;

  GEN_NO_INTC: if(USER_USE_INTC = false) generate

    -- force slave signals to NULL 
    wb_slave_o_s(USER_SLV_INTC_ID_C).ack_o   <= '0';
    wb_slave_o_s(USER_SLV_INTC_ID_C).err_o   <= '0';
    wb_slave_o_s(USER_SLV_INTC_ID_C).rty_o   <= '0';
    wb_slave_o_s(USER_SLV_INTC_ID_C).dat_o   <= (others => '0');
    wb_slave_o_s(USER_SLV_INTC_ID_C).stall_o <= '0';

  end generate GEN_NO_INTC;
  
  -- //////////////////////////////////////////
  --                   UART
  -- //////////////////////////////////////////
  
  GEN_UART: if(USER_USE_UART = true) generate 

    UART: entity soc_lib.uart_top(be_uart_top)
      port map
      (
        uart_i           => uart_i,
        uart_o           => uart_o,
        uart_int_o       => uart_it_s,
        wb_bus_i         => wb_slave_i_s(USER_SLV_UART_ID_C),
        wb_bus_o         => wb_slave_o_s(USER_SLV_UART_ID_C)
      );

  end generate GEN_UART;

  GEN_NO_UART: if(USER_USE_UART = false) generate

    -- force slave signals to NULL 
    wb_slave_o_s(USER_SLV_UART_ID_C).ack_o   <= '0';
    wb_slave_o_s(USER_SLV_UART_ID_C).err_o   <= '0';
    wb_slave_o_s(USER_SLV_UART_ID_C).rty_o   <= '0';
    wb_slave_o_s(USER_SLV_UART_ID_C).dat_o   <= (others => '0');
    wb_slave_o_s(USER_SLV_UART_ID_C).stall_o <= '0';

  end generate GEN_NO_UART;

  -- //////////////////////////////////////////
  --                   GPIO
  -- //////////////////////////////////////////

  GEN_GPIO: if(USER_USE_GPIO = true) generate 

    GPIO: entity soc_lib.gpio_slave_wb_bus(be_gpio_slave_wb_bus)
      port map
      (
        gpio_i           => gpio_i,
        gpio_o           => gpio_o,
        wb_bus_i         => wb_slave_i_s(USER_SLV_GPIO_ID_C),
        wb_bus_o         => wb_slave_o_s(USER_SLV_GPIO_ID_C)
      );

  end generate GEN_GPIO;

  GEN_NO_GPIO: if(USER_USE_GPIO = false) generate

    -- force slave signals to NULL
    wb_slave_o_s(USER_SLV_GPIO_ID_C).ack_o   <= '0';
    wb_slave_o_s(USER_SLV_GPIO_ID_C).err_o   <= '0';
    wb_slave_o_s(USER_SLV_GPIO_ID_C).rty_o   <= '0';
    wb_slave_o_s(USER_SLV_GPIO_ID_C).dat_o   <= (others => '0');
    wb_slave_o_s(USER_SLV_GPIO_ID_C).stall_o <= '0';

  end generate GEN_NO_GPIO;

  -- //////////////////////////////////////////
  --                   TIMER
  -- //////////////////////////////////////////

  GEN_TIMER: if(USER_USE_TIMER = true) generate 

    TIMER: entity soc_lib.timer_slave_wb_bus(be_timer_slave_wb_bus)
      port map
      (
        timer_int_o      => timer_it_s,
        wb_bus_i         => wb_slave_i_s(USER_SLV_TIMER_ID_C),
        wb_bus_o         => wb_slave_o_s(USER_SLV_TIMER_ID_C)                 
      );

  end generate GEN_TIMER;

  GEN_NO_TIMER: if(USER_USE_TIMER = false) generate

    -- force slave signals to NULL 
    wb_slave_o_s(USER_SLV_TIMER_ID_C).ack_o   <= '0';
    wb_slave_o_s(USER_SLV_TIMER_ID_C).err_o   <= '0';
    wb_slave_o_s(USER_SLV_TIMER_ID_C).rty_o   <= '0';
    wb_slave_o_s(USER_SLV_TIMER_ID_C).dat_o   <= (others => '0');
    wb_slave_o_s(USER_SLV_TIMER_ID_C).stall_o <= '0';

  end generate GEN_NO_TIMER;

end architecture be_soc;

