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
--! @file xc3s1000_top.vhd                                					
--! @brief Digilent Spartan-3 SKB Top Level Entity		
--! @author Lyonel Barthe
--! @version 1.2
--                                                                 
-----------------------------------------------------------------
-----------------------------------------------------------------

--
-- Revision History
-- 
-- Version 1.2 24/10/2010 by Lyonel Barthe
-- Changed clock management
--
-- Version 1.1 1/10/2010 by Lyonel Barthe
-- Added debounce units for buttons
--
-- Version 1.0 9/04/2010 by Lyonel Barthe
-- Initial Release
--

-- //////////////////////////////////////////
--           SPARTAN-3 CLOCK DIVIDER
-- //////////////////////////////////////////

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library unisim;
use unisim.vcomponents.ALL;

--! Spartan-3 Clock Divider Entity
entity s3_clk_div is

  generic 
  (
    CLK_PERIOD_NS : real    := 20.000;
    CLK_DIV       : real    := 2.0;
    CLK_FX        : natural := 2
  );
  port
  (
    clkin_i       : in  std_ulogic; 
    clk0_o        : out std_ulogic;
    clkfx_o       : out std_ulogic;
    clkdiv_o      : out std_ulogic
  );

end s3_clk_div;

--! Spartan-3 Clock Divider Architecture
architecture be_s3_clk_div of s3_clk_div is

   signal gbuf_o      : std_ulogic;
   signal clkfb_in    : std_ulogic;
   signal clkdv_buf   : std_ulogic;
   signal clk0_buf    : std_ulogic;
   signal clkfx_buf   : std_ulogic;
   signal gnd_bit     : std_ulogic;

begin

  gnd_bit <= '0';
  clk0_o  <= clkfb_in;
    
  BUF_IN_INST: IBUFG
    port map
    (
      I => clkin_i,
      O => gbuf_o
    );

  CLK0_BUFG_INST: BUFG
    port map 
    (
      I => clk0_buf,
      O => clkfb_in
    );

  CLKFX_BUFG_INST: BUFG
    port map
    (
      I => clkfx_buf,
      O => clkfx_o
    );

  CLKDV_BUFG_INST: BUFG
    port map 
    (
      I => clkdv_buf,
      O => clkdiv_o
    );

  DCM_INST: DCM
    generic map
    ( 
      clk_feedback          => "1X",
      clkdv_divide          => CLK_DIV,
      clkfx_divide          => 1,
      clkfx_multiply        => CLK_FX,
      clkin_divide_by_2     => false,
      clkin_period          => CLK_PERIOD_NS,
      clkout_phase_shift    => "NONE",
      deskew_adjust         => "SYSTEM_SYNCHRONOUS",
      dfs_frequency_mode    => "LOW",
      dll_frequency_mode    => "LOW",
      duty_cycle_correction => true,
      factory_jf            => x"8080",
      phase_shift           => 0,
      startup_wait          => true
    )
    port map 
    (
      clkfb     => clkfb_in,
      clkin     => gbuf_o,
      dssen     => gnd_bit,
      psclk     => gnd_bit,
      psen      => gnd_bit,
      psincdec  => gnd_bit,
      rst       => open,
      clkdv     => clkdv_buf,
      clkfx     => clkfx_buf,
      clkfx180  => open,
      clk0      => clk0_buf,
      clk2x     => open,
      clk2x180  => open,
      clk90     => open,
      clk180    => open,
      clk270    => open,
      locked    => open,
      psdone    => open,
      status    => open
     );
   
end be_s3_clk_div;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library soc_lib;
use soc_lib.gpio_pack.all;
use soc_lib.uart_pack.all;
use soc_lib.sram_pack.all;

library config_lib;
use config_lib.soc_config.all;

library tool_lib;

library unisim;
use unisim.vcomponents.all;

--
--! This is the top level module of the SecretBlaze platform,
--! which has been made for a Digilent Spartan-3 1000 Starter 
--! Kit Board.
--

--! Digilent S3SKB Top Level Entity
entity xc3s1000_top is

  port
    (   
      -- I/O pads
      rx_i     : in std_ulogic;                        --! UART rx
      tx_o     : out std_ulogic;                       --! UART tx
      led_o    : out std_ulogic_vector(7 downto 0);    --! GPIO outputs
      but_i    : in std_ulogic_vector(7 downto 0);     --! GPIO inputs
      ce1_n_o  : out std_ulogic;                       --! SRAM chip 1 enable control signal 
      ce2_n_o  : out std_ulogic;                       --! SRAM chip 2 enable control signal 
      we_n_o   : out std_ulogic;                       --! SRAM write enable control signal 
      oe_n_o   : out std_ulogic;                       --! SRAM output enable control signal 
      ub1_n_o  : out std_ulogic;                       --! SRAM upper 1 byte enable control signal 
      lb1_n_o  : out std_ulogic;                       --! SRAM lower 1 byte enable control signal 
      ub2_n_o  : out std_ulogic;                       --! SRAM upper 2 byte enable control signal 
      lb2_n_o  : out std_ulogic;                       --! SRAM lower 2 byte enable control signal 
      a_o      : out std_ulogic_vector(17 downto 0);   --! SRAM address signal
      data_io  : inout std_logic_vector(31 downto 0);  --! SRAM read/write data
      clk_i    : in std_ulogic;                        --! board input clock
      rst_i    : in std_ulogic                         --! board reset signal 
    );

end xc3s1000_top;

--! Digilent S3SKB op Level Architeture
architecture be_xc3s1000_top of xc3s1000_top is

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
  signal sram_in_o_s    : sram_i_t;

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
  
begin

  -- //////////////////////////////////////////
  --              COMPONENTS LINK
  -- //////////////////////////////////////////

  -- //////////////////////////////////////////
  --              CLOCK MANAGEMENT
  -- //////////////////////////////////////////

  CLK_1_1: if(USER_C_S_CLK_DIV = 1.0 and USER_M_C_CLK_DIV = 1.0) generate

    BUF_IN_INST: IBUFG
      port map
      (
        I => clk_i,
        O => clk0_s
      );

    cclk_s <= clk0_s;
    sclk_s <= clk0_s;
    mclk_s <= clk0_s;   

  end generate CLK_1_1;

  CLK_1_X: if(USER_C_S_CLK_DIV = 1.0 and USER_M_C_CLK_DIV > 1.0) generate

    CLOCK_GENERATOR: entity work.s3_clk_div(be_s3_clk_div)
      generic map
      (
        CLK_PERIOD_NS => USER_CCLK_PERIOD_NS,
        CLK_DIV       => 2.0, 
        CLK_FX        => natural(USER_M_C_CLK_DIV)
      )
      port map
      ( 
        clkin_i       => clk_i,
        clk0_o        => clk0_s,  
        clkfx_o       => clkfx_s,
        clkdiv_o      => clkdiv_s  
      );

    cclk_s <= clk0_s;
    sclk_s <= clk0_s;
    mclk_s <= clkfx_s;   

  end generate CLK_1_X;

  CLK_X_1: if(USER_C_S_CLK_DIV > 1.0 and USER_M_C_CLK_DIV = 1.0) generate

    CLOCK_GENERATOR: entity work.s3_clk_div(be_s3_clk_div)
      generic map
      (
        CLK_PERIOD_NS => USER_CCLK_PERIOD_NS,
        CLK_DIV       => USER_C_S_CLK_DIV,
        CLK_FX        => 2
      )
      port map
      ( 
        clkin_i       => clk_i,
        clk0_o        => clk0_s,  
        clkfx_o       => clkfx_s,
        clkdiv_o      => clkdiv_s  
      );

    cclk_s <= clk0_s;
    sclk_s <= clkdiv_s;
    mclk_s <= clk0_s;   

  end generate CLK_X_1;

  CLK_X_X: if(USER_C_S_CLK_DIV > 1.0 and USER_M_C_CLK_DIV > 1.0) generate

    CLOCK_GENERATOR: entity work.s3_clk_div(be_s3_clk_div)
      generic map
      (
        CLK_PERIOD_NS => USER_CCLK_PERIOD_NS,
        CLK_DIV       => USER_C_S_CLK_DIV,
        CLK_FX        => natural(USER_M_C_CLK_DIV)
      )
      port map
      ( 
        clkin_i       => clk_i,
        clk0_o        => clk0_s,  
        clkfx_o       => clkfx_s,
        clkdiv_o      => clkdiv_s  
      );

    cclk_s <= clk0_s;
    sclk_s <= clkdiv_s;
    mclk_s <= clkfx_s;   

  end generate CLK_X_X;

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
      clk_i  => sclk_s
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
      clk_i  => sclk_s
    );

  -- //////////////////////////////////////////
  --           SECRETBLAZE-BASED SOC
  -- //////////////////////////////////////////

  SECRETBLAZE_SOC: entity soc_lib.soc(be_soc)
    port map
    (   
      uart_i       => uart_i_s,      
      uart_o       => uart_o_s, 
      gpio_i       => gpio_i_s,              
      gpio_o       => gpio_o_s,  
      sram_in_o    => sram_in_o_s,              
      sram_data_io => data_io,                
      sclk_i       => sclk_s, 
      cclk_i       => cclk_s,  
      mclk_i       => mclk_s,                
      rst_n_i      => rst_n_r   
    );

  -- //////////////////////////////////////////
  --               ASSIGN WIRES
  -- //////////////////////////////////////////

  --
  -- ASSIGN INPUT/OUTPUT PADS
  --

  rst_i_s(0)        <= rst_i;
  uart_i_s.rx_i     <= rx_i;
  tx_o              <= uart_o_s.tx_o;
  gpio_i_s.gpi_i    <= gpio_deb_i_s;
  led_o             <= gpio_o_s.gpo_o;
  ce1_n_o           <= sram_in_o_s.ce1_n_i;
  ce2_n_o           <= sram_in_o_s.ce2_n_i;
  we_n_o            <= sram_in_o_s.we_n_i;
  oe_n_o            <= sram_in_o_s.oe_n_i;
  ub1_n_o           <= sram_in_o_s.ub1_n_i;
  lb1_n_o           <= sram_in_o_s.lb1_n_i;
  ub2_n_o           <= sram_in_o_s.ub2_n_i;
  lb2_n_o           <= sram_in_o_s.lb2_n_i;
  a_o               <= sram_in_o_s.a_i;

  -- 
  -- ASSIGN INTERNAL SIGNAL
  --

  deb_ena_s        <= '1' when (to_integer(unsigned(deb_clk_div_r)) = 0) else '0'; 

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

end be_xc3s1000_top;


