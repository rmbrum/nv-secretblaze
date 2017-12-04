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
--! @file soc_config.vhd                                					
--! @brief SoC Configuration Package   				
--! @author Lyonel Barthe
--! @version 1.0
--                                                                
-----------------------------------------------------------------
-----------------------------------------------------------------

--
-- Revision History
--
-- Version 1.0 13/05/2010 by Lyonel Barthe
-- Stable version
--

library ieee;
use ieee.std_logic_1164.all;

library wb_lib;
use wb_lib.wb_pack.all;

--
--! Configuration file of the SecretBlaze-based SoC.
--
--! SoC Configuration Package
package soc_config is

  -- //////////////////////////////////////////
  --               SOC SETTINGS
  -- //////////////////////////////////////////

  --
  -- CLOCK SETTINGS
  --

  -- The memory clock, the system clock, and the core clock should be always in phase

  constant USER_QCLK_PERIOD_NS  : real := 20.000;                                       --! quartz clock period
  constant USER_CCLK_PERIOD_NS  : real := USER_QCLK_PERIOD_NS;                          --! core clock period
  constant USER_C_S_CLK_DIV     : real := 2.0;                                          --! core/system clock ratio (should be a power of 2)
  constant USER_M_C_CLK_DIV     : real := 2.0;                                          --! memory/core clock ratio (should be a power of 2) 

  -- auto-computed
  constant USER_SCLK_PERIOD_NS  : real := USER_CCLK_PERIOD_NS*USER_C_S_CLK_DIV;         --! system clock period
  constant USER_CCLK_MHZ        : natural := natural(1000.0/USER_CCLK_PERIOD_NS);       --! core clock in MHz
  constant USER_SCLK_MHZ        : natural := natural(1000.0/USER_SCLK_PERIOD_NS);       --! system clock in MHz
  constant USER_M_S_CLK_DIV     : real := real(USER_M_C_CLK_DIV*USER_C_S_CLK_DIV);      --! memory/system clock ratio 
  
  --
  -- SRAM GENERAL SETTING
  --

  constant USER_USE_SRAM        : boolean := true;                                      --! if true, it will implement the 32-bit SRAM controller
  constant USER_SRAM_BYTE_S     : natural := 1048576;                                   --! SRAM byte size (default is 1 MB) 

  --
  -- INTERRUPT CONTROLLER GENERAL SETTING
  --

  constant USER_USE_INTC        : boolean := true;                                      --! if true, it will implement the INTERRUPT controller
  constant USER_INTC_NB_SOURCES : natural := 8;                                         --! number of interrupt sources
  constant USER_MAX_SLV_INTC_W  : natural := USER_INTC_NB_SOURCES;                      --! intc read data buffer max width (should be INTC_NB_SOURCES)

  --
  -- UART CONTROLLER GENERAL SETTING
  --

  constant USER_USE_UART        : boolean := true;                                      --! if true, it will implement the UART controller
  constant USER_UART_BAUD_RATE  : natural := 115200;                                    --! UART baud raute
  constant USER_UART_CLK_MHZ    : natural := USER_SCLK_MHZ;                             --! UART clock in MHz

  --
  -- GPIO GENERAL SETTING
  --

  constant USER_USE_GPIO        : boolean := true;                                      --! if true, it will implement the GPIO controller
  constant USER_GPI_W           : natural := 8;                                         --! number of input 
  constant USER_GPO_W           : natural := 8;                                         --! number of output 
  constant USER_MAX_SLV_GPIO_W  : natural := 8;                                         --! gpio read data buffer max width (should be MAX(GPI,GPO))

  --
  -- TIMER GENERAL SETTING
  --

  constant USER_USE_TIMER       : boolean := true;                                      --! if true, it will implement the TIMER controller
  constant USER_TIMER_DATA_W    : natural := 32;                                        --! number of bits of the timer / resolution of the timer 
  constant USER_MAX_SLV_TIMER_W : natural := USER_TIMER_DATA_W;                         --! timer read data buffer max width (should be TIMER_DATA_W)

  --
  -- WISHBONE BUS GENERAL SETTINGS
  --
  
  constant USER_NUMBER_SLAVES    : natural := 5;                                        --! number of slaves
  constant USER_NUMBER_MASTERS   : natural := 2;                                        --! number of masters
  constant USER_WB_ADDRESS_DEC_W : natural := 5;                                        --! set the width of the bus address decoder (starting from MSB)
  constant USER_WB_MEM_MAP       : wb_memory_map_t(0 to 2*USER_NUMBER_SLAVES - 1) := 
    (

      -- ------------------------------------------------------------
      --                     CACHEABLE MEMORY                      --
      -- ------------------------------------------------------------

      -- SRAM
      X"1000_0000",        -- ID 0
      X"1FFF_FFFF",        -- unconstrained

      -- ------------------------------------------------------------
      --                           I/O                             --
      -- ------------------------------------------------------------
  
      -- UART
      X"2000_0000",        -- ID 1             
      X"2FFF_FFFF",        -- unconstrained

      -- GPIO
      X"3000_0000",        -- ID 2      
      X"3FFF_FFFF",        -- unconstrained

      -- INTC
      X"4000_0000",        -- ID 3
      X"4FFF_FFFF",        -- unconstrained

      -- TIMER
      X"5000_0000",        -- ID 4
      X"5FFF_FFFF"         -- unconstrained

      -- ADD EXT THERE
      
    ); --! WB memory map

  -- MASTER ID  
  constant USER_MST_SB_IC_C       : natural := 0;
  constant USER_MST_SB_DC_C       : natural := 1;

  -- SLAVE ID
  constant USER_SLV_SRAM_ID_C     : natural := 0;
  constant USER_SLV_UART_ID_C     : natural := 1;
  constant USER_SLV_GPIO_ID_C     : natural := 2;
  constant USER_SLV_INTC_ID_C     : natural := 3;
  constant USER_SLV_TIMER_ID_C    : natural := 4;

end soc_config;

