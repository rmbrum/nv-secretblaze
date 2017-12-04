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
-- Version 1.0 08/2012 by Lyonel Barthe
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
use soc_lib.dram_pack.all;

library tool_lib;
use tool_lib.math_pack.all;

library config_lib;
use config_lib.soc_config.all;
use config_lib.sim_config.all;

library unisim;
use unisim.vcomponents.all;

--! Testbench entity
entity tb_soc is

end tb_soc;

--! Testbench architecture
architecture be_tb_soc of tb_soc is

  component ddr2_model_c3 is
    port
    (
      ck      : in std_logic;  
      ck_n    : in std_logic;
      cke     : in std_logic;
      cs_n    : in std_logic;
      ras_n   : in std_logic;
      cas_n   : in std_logic;
      we_n    : in std_logic;
      dm_rdqs : inout std_logic_vector(1 downto 0);
      ba      : in std_logic_vector(2 downto 0);
      addr    : in std_logic_vector(12 downto 0);
      dq      : inout std_logic_vector(15 downto 0);
      dqs     : inout std_logic_vector(1 downto 0);
      dqs_n   : inout std_logic_vector(1 downto 0);
      rdqs_n  : inout std_logic_vector(1 downto 0);
      odt     : in std_logic
    );
  end component;
 
  -- //////////////////////////////////////////
  --                  CONSTANTS
  -- //////////////////////////////////////////
  
  constant clk_i_period_c       : time := USER_CCLK_PERIOD_NS * 1 ns; 
  
  -- //////////////////////////////////////////
  --               INTERNAL REGS
  -- //////////////////////////////////////////
  
  signal clk_i_r                : std_ulogic := '0';
  signal clk_fx_i_r             : std_ulogic := '0';
  signal clk_div_i_r            : std_ulogic := '0';
  signal rst_n_i_r              : std_ulogic := '0';
  signal mcb3_ena_1_r           : std_ulogic := '0';
  signal mcb3_ena_2_r           : std_ulogic := '0';  

  -- //////////////////////////////////////////
  --               INTERNAL WIRES
  -- //////////////////////////////////////////
  
  signal uart_rx_s              : uart_i_t;
  signal uart_tx_s              : uart_o_t;
  signal gpo_s                  : gpio_o_t;
  signal gpi_s                  : gpio_i_t;
  signal dram_in_o_s            : dram_i_t;
  signal ddr2dq_io_s            : dram_data_t;         
  signal ddr2rzq_io_s           : std_logic;
  signal ddr2zio_io_s           : std_logic;
  signal ddr2udqs_p_io_s        : std_logic;
  signal ddr2udqs_n_io_s        : std_logic;
  signal ddr2ldqs_p_io_s        : std_logic;
  signal ddr2ldqs_n_io_s        : std_logic;
  signal dqs_s                  : std_logic_vector(1 downto 0);
  signal dqs_n_s                : std_logic_vector(1 downto 0);
  signal mcb3_cmd_s             : std_ulogic_vector(2 downto 0);
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
      uart_i                => uart_rx_s,
      uart_o                => uart_tx_s,
      gpio_i                => gpi_s,
      gpio_o                => gpo_s,
      dram_in_o             => dram_in_o_s,              
      dram_io.ddr2dq_io     => ddr2dq_io_s,  
      dram_io.ddr2rzq_io    => ddr2rzq_io_s,  
      dram_io.ddr2zio_io    => ddr2zio_io_s,  
      dram_io.ddr2udqs_p_io => ddr2udqs_p_io_s,  
      dram_io.ddr2udqs_n_io => ddr2udqs_n_io_s,  
      dram_io.ddr2ldqs_p_io => ddr2ldqs_p_io_s,  
      dram_io.ddr2ldqs_n_io => ddr2ldqs_n_io_s,  
      sclk_i                => clk_div_i_r,
      cclk_i                => clk_i_r,
      mclk_i                => clk_fx_i_r,
      rst_n_i               => rst_n_i_r
    );

  VIRTUAL_UART: entity soc_lib.uart_controller(be_uart_controller)
    port map
    ( 
      rx_i                  => uart_tx_s.tx_o,	
      tx_o                  => uart_rx_s.rx_i,
      tx_dat_i              => tx_dat_s,
      rx_dat_o              => rx_dat_s,
      tx_send_i             => tx_send_s,
      tx_busy_o             => tx_busy_s,
      rx_ready_o            => rx_ready_s,
      clk_i                 => clk_div_i_r,
      rst_n_i               => rst_n_i_r
     );
	
  VIRTUAL_DDR2: ddr2_model_c3
    port map
    (
      ck                    => dram_in_o_s.ddr2clk_p_i,  
      ck_n                  => dram_in_o_s.ddr2clk_n_i,
      cke                   => dram_in_o_s.ddr2clke_i,
      cs_n                  => '0',
      ras_n                 => dram_in_o_s.ddr2rasn_i,
      cas_n                 => dram_in_o_s.ddr2casn_i,
      we_n                  => dram_in_o_s.ddr2wen_i,
      dm_rdqs(1)            => dram_in_o_s.ddr2udm_i,
      dm_rdqs(0)            => dram_in_o_s.ddr2ldm_i,      
      ba                    => dram_in_o_s.ddr2ba_i,
      addr                  => dram_in_o_s.ddr2a_i,
      dq                    => ddr2dq_io_s,
      dqs                   => dqs_s,
      dqs_n                 => dqs_n_s,
      rdqs_n                => open,
      odt                   => dram_in_o_s.ddr2odt_i
    );

  ZIO_PULLDOWN: PULLDOWN 
    port map
    (
      O => ddr2zio_io_s
    );
    
  RZQ_PULLDOWN: PULLDOWN 
    port map
    (
      O => ddr2rzq_io_s
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

  --  
  -- DDR2 
  --
 
  mcb3_cmd_s         <= (dram_in_o_s.ddr2rasn_i & dram_in_o_s.ddr2casn_i & dram_in_o_s.ddr2wen_i);

  DDR2_TRIST_CTR: process(dram_in_o_s.ddr2clk_p_i)
  begin
    if(dram_in_o_s.ddr2clk_p_i'event and dram_in_o_s.ddr2clk_p_i = '1') then
      if(rst_n_i_r = '0') then
        mcb3_ena_1_r <= '0';
        mcb3_ena_2_r <= '0';
        
      elsif(mcb3_cmd_s = "100") then -- next read
        mcb3_ena_1_r <= '0';
        mcb3_ena_2_r <= mcb3_ena_1_r;        
      
      elsif(mcb3_cmd_s = "101") then -- next write
        mcb3_ena_1_r <= '1';
        mcb3_ena_2_r <= mcb3_ena_1_r;        
                
      else
        mcb3_ena_2_r <= mcb3_ena_1_r;                
        
      end if;
    end if;
  end process;    
   
  -- tristates for read operations
  dqs_s              <= (ddr2udqs_p_io_s & ddr2ldqs_p_io_s) when (mcb3_ena_1_r = '0' and mcb3_ena_2_r = '0') else "ZZ";
  dqs_n_s            <= (ddr2udqs_n_io_s & ddr2ldqs_n_io_s) when (mcb3_ena_1_r = '0' and mcb3_ena_2_r = '0') else "ZZ";
  
  -- tristates for write operations
  ddr2ldqs_p_io_s    <= dqs_s(0) when (mcb3_ena_2_r = '1') else 'Z';
  ddr2udqs_p_io_s    <= dqs_s(1) when (mcb3_ena_2_r = '1') else 'Z';
  ddr2ldqs_n_io_s    <= dqs_n_s(0) when (mcb3_ena_2_r = '1') else 'Z';
  ddr2udqs_n_io_s    <= dqs_n_s(1) when (mcb3_ena_2_r = '1') else 'Z';                                                        

  --  
  -- GPI
  --
    
  gpi_s.gpi_i        <= (others =>'0');

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

