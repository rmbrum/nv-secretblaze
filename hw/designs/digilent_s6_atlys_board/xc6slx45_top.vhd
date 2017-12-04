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
--! @file xc6slx45_top.vhd                                					
--! @brief Digilent Spartan-6 Atlys Board Top Level Entity		
--! @author Lyonel Barthe
--! @version 1.0
--                                                                 
-----------------------------------------------------------------
-----------------------------------------------------------------

--
-- Revision History
--
-- Version 1.0 20/01/2012 by Lyonel Barthe
-- Initial Release
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

--! Spartan-6 Clock Divider Entity
entity s6_clk_div is

  generic 
  (
    CLK_PERIOD_NS : real    := 10.000;
    CLK_DIV       : real    := 2.0;
    CLK_FX        : natural := 4
  );
  port
  (
    clkin_i       : in  std_ulogic; 
    clk0_o        : out std_ulogic;
    clkfx_o       : out std_ulogic;
    clkdiv_o      : out std_ulogic
  );
  
end s6_clk_div;

--! Spartan-6 Clock Divider Architecture
architecture be_s6_clk_div of s6_clk_div is

  signal gbuf_o       : std_ulogic;
  signal clkfbout     : std_ulogic;
  signal clkfbout_buf : std_ulogic;
  signal clkout0      : std_ulogic;
  signal clkout1      : std_ulogic;
  signal clkout2      : std_ulogic;

begin

  BUF_IN_INST: IBUFG
    port map
    (
      I => clkin_i,
      O => gbuf_o
    );

  PLL_INST: PLL_BASE
  generic map
    (
      BANDWIDTH          => "OPTIMIZED",
      CLK_FEEDBACK       => "CLKFBOUT",
      COMPENSATION       => "SYSTEM_SYNCHRONOUS",
      DIVCLK_DIVIDE      => 1,
      CLKFBOUT_MULT      => CLK_FX, 
      CLKFBOUT_PHASE     => 0.000,
      CLKOUT0_DIVIDE     => CLK_FX, 
      CLKOUT0_PHASE      => 0.000,
      CLKOUT0_DUTY_CYCLE => 0.500,
      CLKOUT1_DIVIDE     => natural((real(CLK_FX)*CLK_DIV)), 
      CLKOUT1_PHASE      => 0.000,
      CLKOUT1_DUTY_CYCLE => 0.500,
      CLKOUT2_DIVIDE     => 1,
      CLKOUT2_PHASE      => 0.000,
      CLKOUT2_DUTY_CYCLE => 0.500,
      CLKIN_PERIOD       => CLK_PERIOD_NS,
      REF_JITTER         => 0.010
    )
  port map
    (
      CLKFBOUT           => clkfbout,
      CLKOUT0            => clkout0,
      CLKOUT1            => clkout1,
      CLKOUT2            => clkout2,
      CLKOUT3            => open,
      CLKOUT4            => open,
      CLKOUT5            => open,
      LOCKED             => open,
      RST                => '0',
      CLKFBIN            => clkfbout_buf,
      CLKIN              => gbuf_o
    );
      
  CLKF_BUF_INST: BUFG
  port map
    (
      O => clkfbout_buf,
      I => clkfbout
    );


  CLK0_BUFG_INST: BUFG
  port map
    (
      O => clk0_o,
      I => clkout0
    );

  CLKDIV_BUFG_INST: BUFG
  port map
    (
      O => clkdiv_o,
      I => clkout1
    );

  CLKFX_BUFG_INST: BUFG
  port map
    (
      O => clkfx_o,
      I => clkout2
    );

end be_s6_clk_div;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library soc_lib;
use soc_lib.gpio_pack.all;
use soc_lib.uart_pack.all;
use soc_lib.dram_pack.all;

library config_lib;
use config_lib.soc_config.all;

library tool_lib;

library unisim;
use unisim.vcomponents.all;

--
--! This is the top level module of the SecretBlaze platform,
--! which has been made for a Digilent Spartan-6 ATLYS Board. 
--

--! Digilent S6-Atlys Top Level Entity
entity xc6slx45_top is

  port
    (   
      -- I/O pads
      rx_i          : in std_ulogic;                        --! UART rx
      tx_o          : out std_ulogic;                       --! UART tx
      led_o         : out std_ulogic_vector(7 downto 0);    --! GPIO outputs
      but_i         : in std_ulogic_vector(7 downto 0);     --! GPIO inputs
      ddr2clk_p_o   : out std_logic;                        --! DDR2 clk P 
      ddr2clk_n_o   : out std_logic;                        --! DDR2 clk N
      ddr2clke_o    : out std_logic;                        --! DDR2 clk enable
      ddr2rasn_o    : out std_logic;                        --! DDR2 row address strobe
      ddr2casn_o    : out std_logic;                        --! DDR2 column address strobe 
      ddr2wen_o     : out std_logic;                        --! DDR2 write enable
      ddr2ba_o      : out std_logic_vector(2 downto 0);     --! DDR2 bank address
      ddr2a_o       : out std_logic_vector(12 downto 0);    --! DDR2 memory address
      ddr2ldm_o     : out std_logic;                        --! DDR2 lower data mask
      ddr2udm_o     : out std_logic;                        --! DDR2 upper data mask
      ddr2odt_o     : out std_logic;                        --! DDR2 on die termination control
      ddr2dq_io     : inout std_logic_vector(15 downto 0);  --! DDR2 data 
      ddr2rzq_io    : inout std_logic;                      --! DDR2 RZQ calibration pin
      ddr2zio_io    : inout std_logic;                      --! DDR2 ZIO calibration pin
      ddr2udqs_p_io : inout std_logic;                      --! DDR2 upper data strobe P
      ddr2udqs_n_io : inout std_logic;                      --! DDR2 upper data strobe N
      ddr2ldqs_p_io : inout std_logic;                      --! DDR2 lower data strobe P
      ddr2ldqs_n_io : inout std_logic;                      --! DDR2 lower data strobe N
      clk_i         : in std_ulogic;                        --! board input clock
      rst_i         : in std_ulogic                         --! board reset signal 
    );

end xc6slx45_top;

--! Digilent S6-Atlys Top Level Architeture
architecture be_xc6slx45_top of xc6slx45_top is

  -- //////////////////////////////////////////
  --               INTERNAL REGS
  -- //////////////////////////////////////////

  signal deb_clk_div_r  : std_ulogic_vector(17 downto 0); --! debounce clock divider reg  
  signal rst_buf_1_r    : std_ulogic;                     --! first reset buffer
  signal rst_buf_2_r    : std_ulogic;                     --! second reset buffer
  signal rst_buf_3_r    : std_ulogic;                     --! third reset buffer                  
  signal rst_n_r        : std_ulogic;                     --! system reset reg 

  -- //////////////////////////////////////////
  --              INTERNAL WIRES
  -- //////////////////////////////////////////

  signal uart_i_s       : uart_i_t;
  signal uart_o_s       : uart_o_t;
  signal gpio_i_s       : gpio_i_t;
  signal gpio_o_s       : gpio_o_t;
  signal dram_in_o_s    : dram_i_t;
  
  signal clk0_s         : std_ulogic;
  signal clkdiv_s       : std_ulogic;
  signal clkfx_s        : std_ulogic;   
  signal sclk_s         : std_ulogic;
  signal cclk_s         : std_ulogic;
  signal mclk_s         : std_ulogic;

  signal rst_i_s        : std_ulogic_vector(0 downto 0);
  signal rst_deb_s      : std_ulogic_vector(0 downto 0);
  signal gpio_deb_i_s   : gpi_data_t;
  signal deb_ena_s      : std_ulogic;
 
  attribute KEEP : string; 
  attribute KEEP of clk0_s   : signal is "TRUE";
  attribute KEEP of clkdiv_s : signal is "TRUE";
  attribute KEEP of clkfx_s  : signal is "TRUE";  
          
begin

  -- //////////////////////////////////////////
  --              COMPONENTS LINK
  -- //////////////////////////////////////////

  -- //////////////////////////////////////////
  --              CLOCK MANAGEMENT
  -- //////////////////////////////////////////

  CLK_GEN: entity work.s6_clk_div(be_s6_clk_div)
    port map
    ( 
      clkin_i  => clk_i,
      clk0_o   => clk0_s,  
      clkfx_o  => clkfx_s,
      clkdiv_o => clkdiv_s       
    );  
    
  cclk_s <= clk0_s;
  sclk_s <= clkdiv_s;
  mclk_s <= clkfx_s;                  

  -- //////////////////////////////////////////
  --               DEBOUNCE UNITS
  -- //////////////////////////////////////////

  DEB_RESET: entity tool_lib.debounce_unit(be_debounce_unit)
    generic map
    (
      DATA_W => 1
    )
    port map
    (
      ena_i  => deb_ena_s,
      dat_i  => rst_i_s,
      dat_o  => rst_deb_s,
      clk_i  => clk0_s
    );

  DEB_GPI: entity tool_lib.debounce_unit(be_debounce_unit)
    generic map
    (
      DATA_W => GPI_W
    )
    port map
    (
      ena_i  => deb_ena_s,
      dat_i  => but_i,
      dat_o  => gpio_deb_i_s,
      clk_i  => clk0_s
    );

  -- //////////////////////////////////////////
  --           SECRETBLAZE-BASED SOC
  -- //////////////////////////////////////////

  SECRETBLAZE_SOC: entity soc_lib.soc(be_soc)
    port map
    (   
      uart_i                => uart_i_s,      
      uart_o                => uart_o_s, 
      gpio_i                => gpio_i_s,              
      gpio_o                => gpio_o_s,  
      dram_in_o             => dram_in_o_s,  
      dram_io.ddr2dq_io     => ddr2dq_io,    
      dram_io.ddr2rzq_io    => ddr2rzq_io,            
      dram_io.ddr2zio_io    => ddr2zio_io,            
      dram_io.ddr2udqs_p_io => ddr2udqs_p_io,            
      dram_io.ddr2udqs_n_io => ddr2udqs_n_io, 
      dram_io.ddr2ldqs_p_io => ddr2ldqs_p_io,            
      dram_io.ddr2ldqs_n_io => ddr2ldqs_n_io,                                                  
      sclk_i                => sclk_s, 
      cclk_i                => cclk_s,  
      mclk_i                => mclk_s,                
      rst_n_i               => rst_n_r   
    );

  -- //////////////////////////////////////////
  --               ASSIGN WIRES
  -- //////////////////////////////////////////

  --
  -- ASSIGN INPUT/OUTPUT PADS
  --

  rst_i_s(0)                   <= rst_i;
  uart_i_s.rx_i                <= rx_i;
  tx_o                         <= uart_o_s.tx_o;
  gpio_i_s.gpi_i               <= gpio_deb_i_s;
  led_o                        <= gpio_o_s.gpo_o;
  ddr2clk_p_o                  <= dram_in_o_s.ddr2clk_p_i;
  ddr2clk_n_o                  <= dram_in_o_s.ddr2clk_n_i;
  ddr2clke_o                   <= dram_in_o_s.ddr2clke_i;
  ddr2rasn_o                   <= dram_in_o_s.ddr2rasn_i;
  ddr2casn_o                   <= dram_in_o_s.ddr2casn_i;
  ddr2wen_o                    <= dram_in_o_s.ddr2wen_i;
  ddr2ba_o                     <= dram_in_o_s.ddr2ba_i;
  ddr2a_o                      <= dram_in_o_s.ddr2a_i;
  ddr2ldm_o                    <= dram_in_o_s.ddr2ldm_i;
  ddr2udm_o                    <= dram_in_o_s.ddr2udm_i;
  ddr2odt_o                    <= dram_in_o_s.ddr2odt_i;               
   
  -- 
  -- ASSIGN INTERNAL SIGNAL
  --

  deb_ena_s                    <= '1' when (to_integer(unsigned(deb_clk_div_r)) = 0) else '0'; 

  -- //////////////////////////////////////////
  --               CYCLE PROCESS
  -- //////////////////////////////////////////

  --
  -- DEBOUNCE CLK DIVIDER
  --
  --! This cycle process implements a clock divider for debounce units.
  CYCLE_DEB_DIV_REG: process(sclk_s)		
  begin
    
    -- clock event
    if(sclk_s'event and sclk_s = '1') then
      deb_clk_div_r <= std_ulogic_vector(unsigned(deb_clk_div_r) + 1);
    end if;
    
  end process CYCLE_DEB_DIV_REG;

  --
  -- RESET SYSTEM REGISTER
  --
  --! This cycle process implements reset buffers and the 
  --! reset register of the system. The reset is active 
  --! when the push button is released.
  CYCLE_RESET_REGS: process(sclk_s)		
  begin
    
    -- clock event 
    if(sclk_s'event and sclk_s = '1') then

      if(deb_ena_s = '1') then
        rst_buf_1_r <= rst_deb_s(0);
        rst_buf_2_r <= rst_buf_1_r;
        rst_buf_3_r <= rst_buf_2_r;
        rst_n_r     <= not(not(rst_buf_1_r) and rst_buf_2_r and rst_buf_3_r); 
      end if;

    end if;
    
  end process CYCLE_RESET_REGS;

end be_xc6slx45_top;


