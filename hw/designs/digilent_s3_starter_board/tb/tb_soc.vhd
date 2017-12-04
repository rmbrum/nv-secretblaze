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
--! @file tb_soc.vhd                                					
--! @brief BOOT Testbench    				
--! @author Lyonel Barthe
--! @version 1.0
--                                                                
-----------------------------------------------------------------
-----------------------------------------------------------------

--
-- Revision History
--
-- Version 1.0 30/05/2011 by Lyonel Barthe / Remi Busseuil
-- Write UART output into a text file
--
-- Version 0.1 15/02/2010 by Lyonel Barthe
-- Initial Release
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.textio.all;

library soc_lib;
use soc_lib.gpio_pack.all;
use soc_lib.uart_pack.all;
use soc_lib.sram_pack.all;

library tool_lib;
use tool_lib.math_pack.all;

library config_lib;
use config_lib.soc_config.all;
use config_lib.sim_config.all;

--! Testbench entity
entity tb_soc is

end tb_soc;

--! Testbench architecture
architecture be_tb_soc of tb_soc is
  
  -- //////////////////////////////////////////
  --                  CONSTANT
  -- //////////////////////////////////////////
  
  constant clk_i_period_c       : time := USER_CCLK_PERIOD_NS * 1 ns; 
  
  -- //////////////////////////////////////////
  --               INTERNAL REGS
  -- //////////////////////////////////////////
  
  signal clk_i_r                : std_ulogic := '0';
  signal clk_fx_i_r             : std_ulogic := '0';
  signal clk_div_i_r            : std_ulogic := '0';
  signal rst_n_i_r              : std_ulogic := '0';

  -- //////////////////////////////////////////
  --               INTERNAL WIRES
  -- //////////////////////////////////////////
  
  signal uart_rx_s              : uart_i_t;
  signal uart_tx_s              : uart_o_t;
  signal gpo_s                  : gpio_o_t;
  signal gpi_s                  : gpio_i_t;
  signal sram_in_o_s            : sram_i_t;    
  signal sram_data_io_s         : sram_io_t;  
  signal rx_dat_s               : uart_data_t := (others => '0');			
  signal tx_dat_s               : uart_data_t := (others => '0');		
  signal rx_dat_text_s          : uart_data_t := (others => '0');		
  signal tx_send_s              : std_ulogic  := '0';				
  signal tx_busy_s              : std_ulogic  := '0';				
  signal rx_ready_s             : std_ulogic  := '0';	
  
begin
 
  -- //////////////////////////////////////////
  --              COMPONENT LINKS
  -- //////////////////////////////////////////
  
  SECRETBLAZE_SOC: entity soc_lib.soc(be_soc)
    port map
    (
      uart_i       => uart_rx_s,
      uart_o       => uart_tx_s,
      gpio_i       => gpi_s,
      gpio_o       => gpo_s,
      sram_in_o    => sram_in_o_s,      
      sram_data_io => sram_data_io_s,    
      sclk_i       => clk_div_i_r,
      cclk_i       => clk_i_r,
      mclk_i       => clk_fx_i_r,
      rst_n_i      => rst_n_i_r
    );

  VIRTUAL_UART: entity soc_lib.uart_controller(be_uart_controller)
    port map
    ( 
      rx_i         => uart_tx_s.tx_o,	
      tx_o         => uart_rx_s.rx_i,
      tx_dat_i     => tx_dat_s,
      rx_dat_o     => rx_dat_s,
      tx_send_i    => tx_send_s,
      tx_busy_o    => tx_busy_s,
      rx_ready_o   => rx_ready_s,
      clk_i        => clk_div_i_r,
      rst_n_i      => rst_n_i_r
     );

  VIRTUAL_SRAM: entity work.async_sram(be_async_sram)
    generic map
    (
      MEM_FILE     => USER_ASRAM_FILE,
      RAM_W        => 32,                                
      RAM_S        => USER_ASRAM_SIM_S                           
    )
    port map
    (
      ce_n_i       => sram_in_o_s.ce1_n_i, 
      sel_n_i(3)   => sram_in_o_s.ub1_n_i,
      sel_n_i(2)   => sram_in_o_s.lb1_n_i,
      sel_n_i(1)   => sram_in_o_s.ub2_n_i,
      sel_n_i(0)   => sram_in_o_s.lb2_n_i,      
      we_n_i       => sram_in_o_s.we_n_i,
      oe_n_i       => sram_in_o_s.oe_n_i,
      a_i          => sram_in_o_s.a_i(log2(USER_ASRAM_SIM_S) - 1 downto 0),
      data_io      => sram_data_io_s,
      clk_i        => clk_fx_i_r
    );

  -- //////////////////////////////////////////
  --              CLOCK GENERATIONS
  -- //////////////////////////////////////////
      
  CLK_GEN: process
  begin
  
    clk_i_r <= '1';
    wait for clk_i_period_c/2;
    clk_i_r <= '0';
    wait for clk_i_period_c/2;
    
  end process CLK_GEN;

  CLK_FX_GEN: process
  begin
  
    clk_fx_i_r <= '1';
    wait for clk_i_period_c/(2*natural(USER_M_C_CLK_DIV));
    clk_fx_i_r <= '0';
    wait for clk_i_period_c/(2*natural(USER_M_C_CLK_DIV));
    
  end process CLK_FX_GEN;

  CLK_DIV_GEN: process
  begin

    clk_div_i_r <= '1';
    wait for clk_i_period_c*natural(USER_C_S_CLK_DIV)/2;    
    clk_div_i_r <= '0';
    wait for clk_i_period_c*natural(USER_C_S_CLK_DIV)/2;

  end process CLK_DIV_GEN;    

  -- //////////////////////////////////////////
  --             VIRTUAL INTERFACES
  -- //////////////////////////////////////////

  gpi_s.gpi_i <= (others =>'0'); -- default

  -- //////////////////////////////////////////
  --                BOOT TESTBENCH
  -- //////////////////////////////////////////
  
  --
  -- BOOT 
  --
  --! This process starts the SecretBlaze-SoC platform.
  BOOT_TB: process   
  begin
    
    -- reset
    rst_n_i_r <= '0';
    wait for 101 us;
    
    -- start system
    rst_n_i_r <= '1';

    wait;
    
  end process BOOT_TB;

  -- //////////////////////////////////////////
  --                UART REPORT
  -- //////////////////////////////////////////

  rx_dat_text_s <= rx_dat_s when rx_ready_s = '1'; 

  --
  -- UART REPORT
  --
  --! This process writes the UART output into a text file.
  UART_REPORT: process(clk_div_i_r,
                       rst_n_i_r)
    file store_file    : text;
    variable file_line : line;
    variable char      : character;
    variable fstatus   : FILE_OPEN_STATUS;

  begin
    if(rst_n_i_r) = '0' then
      file_open(fstatus, store_file,USER_UART_OUT_FILE,write_mode);
      file_close(store_file);

    elsif(clk_div_i_r'event and clk_div_i_r = '1') then
      if(rx_ready_s = '1') then
          file_open(fstatus, store_file,USER_UART_OUT_FILE,append_mode);
          -- read incoming chars
          char := character'val(to_integer(unsigned(rx_dat_s)));
          -- write chars 
          if rx_dat_s /= X"0A" then
              write(file_line, char);

            -- EOL / write line into the file
          else
              writeline(store_file, file_line);

          end if;
          file_close(store_file);

      end if;
    end if;
  end process UART_REPORT; 

end be_tb_soc;

