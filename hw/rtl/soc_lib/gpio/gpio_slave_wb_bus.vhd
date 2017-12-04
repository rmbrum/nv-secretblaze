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
--! @file gpio_slave_wb_bus.vhd                                					
--! @brief GPIO Controller and its WISHBONE Bus Slave Interface  				
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
-- Version 0.1 12/02/2010 by Lyonel Barthe
-- Initial Release
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library wb_lib;
use wb_lib.wb_pack.all;

library soc_lib;
use soc_lib.gpio_pack.all;

--
--! The module implements a basic GPIO IP and its 
--! synchronous WISHBONE bus slave interface. Note that
--! the GPI register is a read only "sticky" register, 
--! i.e it keeps the value until the next read from 
--! the bus (for each input). The module supports 
--! pipelined read/write mode.
--

--! GPIO WISHBONE Bus Slave Interface Entity
entity gpio_slave_wb_bus is

  port
    (
      gpio_i   : in gpio_i_t;         --! GPIO general inputs
      gpio_o   : out gpio_o_t;        --! GPIO general outputs
      wb_bus_i : in wb_slave_bus_i_t; --! WISHBONE slave inputs
      wb_bus_o : out wb_slave_bus_o_t --! WISHBONE slave outputs  
    );

end gpio_slave_wb_bus;

--! GPIO Wishbone Bus Slave Interface Architecture
architecture be_gpio_slave_wb_bus of gpio_slave_wb_bus is
     
  -- //////////////////////////////////////////
  --                INTERNAL REGS
  -- //////////////////////////////////////////

  -- Nota: UNUSED BIT WON'T BE IMPLEMENTED!
  -- in order to save FFs.
  
  -- gpo_r : BASE_ADDRESS + 0x0 (read/write)
  -- MSB                                 LSB
  -- +-------------------------------------+
  -- |     31 ... 8       |   7 ...   0    |
  -- +-------------------------------------+
  -- |      unused        |      data      |
  -- +-------------------------------------+   
  signal gpo_r      : gpo_data_t; --! gpo reg

  -- gpi_r : BASE_ADDRESS + 0x4 (read only)
  -- MSB                                 LSB
  -- +-------------------------------------+
  -- |     31 ... 12      |    7 ...  0    |
  -- +-------------------------------------+
  -- |      unused        |      data      |
  -- +-------------------------------------+   
  signal gpi_r      : gpi_data_t; --! gpi reg

  signal wb_ack_o_r : std_ulogic;                                     --! WISHBONE single read/write ack reg
  signal wb_dat_o_r : std_ulogic_vector(MAX_SLV_GPIO_W - 1 downto 0); --! WISHBONE data bus reg

  -- //////////////////////////////////////////
  --              INTERNAL WIRES
  -- //////////////////////////////////////////
  
  --
  -- SLAVE INTERFACE SIGNALS
  -- 
  
  signal slv_read_s      : wb_bus_data_t;
  signal slv_write_gpo_s : wb_bus_data_t;  

  --
  -- WB SIGNALS
  -- 

  signal wb_we_s         : std_ulogic;
  signal wb_re_s         : std_ulogic;
  signal wb_reg_adr_s    : wb_gpio_reg_adr_t;
  signal wb_ack_s        : std_ulogic;
     
begin

  -- //////////////////////////////////////////
  --                COMB PROCESS
  -- //////////////////////////////////////////

  --
  -- ASSIGN OUTPUTS
  --
  
  wb_bus_o.ack_o   <= wb_ack_o_r;                                                                            
  wb_bus_o.dat_o   <= std_ulogic_vector(resize(unsigned(wb_dat_o_r),wb_bus_data_t'length)); 
  wb_bus_o.err_o   <= '0'; -- not implemented
  wb_bus_o.rty_o   <= '0'; -- not implemented
  wb_bus_o.stall_o <= '0'; -- not implemented 
  gpio_o.gpo_o     <= gpo_r;
  
  --
  -- ASSIGN INTERNAL SIGNALS
  --
  
  --
  -- WB SIGNALS
  --

  wb_we_s      <= (wb_bus_i.stb_i and wb_bus_i.cyc_i and wb_bus_i.we_i);                                   -- write bus operation          
  wb_re_s      <= (wb_bus_i.stb_i and wb_bus_i.cyc_i and not(wb_bus_i.we_i));                              -- read bus operation 
  wb_reg_adr_s <= (wb_bus_i.adr_i(wb_gpio_reg_adr_t'length + WB_WORD_ADR_OFF - 1 downto WB_WORD_ADR_OFF)); -- register address
  wb_ack_s     <= (wb_bus_i.stb_i and wb_bus_i.cyc_i);                                                     -- pipelined read/write ack
                                                               
  
  --
  -- COMB SLAVE READ REG
  --
  --! This process implements the behaviour of a bus read operation.
  COMB_SLAVE_READ_REG: process(wb_bus_i,
                               gpi_r,
                               gpo_r,
                               wb_re_s,
                               wb_reg_adr_s)
    
    variable gpi_v : wb_bus_data_t;
    variable gpo_v : wb_bus_data_t;

  begin

    gpo_v      := std_ulogic_vector(resize(unsigned(gpo_r),wb_bus_data_t'length));
    gpi_v      := std_ulogic_vector(resize(unsigned(gpi_r),wb_bus_data_t'length));    

    -- default
    slv_read_s <= (others =>'X');
    
    -- read enable
    if(wb_re_s = '1') then
      
      -- decode reg address 
      case wb_reg_adr_s is 
          
        when GPO_OFF =>

          for i in 0 to (wb_bus_data_t'length/8)-1 loop
            if (wb_bus_i.sel_i(i) = '1') then
              slv_read_s(8*(i+1) - 1 downto 8*i) <= gpo_v(8*(i+1) - 1 downto 8*i);
            end if;
          end loop;

        when GPI_OFF =>
                    
          for i in 0 to (wb_bus_data_t'length/8)-1 loop
            if (wb_bus_i.sel_i(i) = '1') then
              slv_read_s(8*(i+1) - 1 downto 8*i) <= gpi_v(8*(i+1) - 1 downto 8*i);
            end if;
          end loop;
          
        when others =>
          report "gpio's slave read process: illegal address" severity warning;
          
      end case;
      
    end if;

  end process COMB_SLAVE_READ_REG;

  --
  -- COMB SLAVE WRITE REG
  --
  --! This process implements the behaviour of a bus write operation.
  COMB_SLAVE_WRITE_REG: process(wb_bus_i,
                                gpo_r,
                                wb_we_s,
                                wb_reg_adr_s)
    
  begin
    
    -- default 
    slv_write_gpo_s <= std_ulogic_vector(resize(unsigned(gpo_r),wb_bus_data_t'length));

    -- write enable
    if(wb_we_s = '1') then
      
      -- decode address 
      case wb_reg_adr_s is 
        
        when GPO_OFF =>

          for i in 0 to (wb_bus_data_t'length/8)-1 loop
            if (wb_bus_i.sel_i(i) = '1') then
              slv_write_gpo_s(8*(i+1) - 1 downto 8*i) <= wb_bus_i.dat_i(8*(i+1) - 1 downto 8*i);
            end if;
          end loop;
          
        when others =>
          report "gpio's slave write process: illegal address" severity warning;
          
      end case;
      
    end if;

  end process COMB_SLAVE_WRITE_REG;

  -- //////////////////////////////////////////
  --               CYCLE PROCESS
  -- //////////////////////////////////////////

  --
  -- WB SLAVE BUS REGISTERED OUTPUTS
  --
  --! This process implements WISHBONE slave output registers.
  CYCLE_GPIO_WB_OUT_REG: process(wb_bus_i.clk_i)
  begin
    
    -- clock event 
    if(wb_bus_i.clk_i'event and wb_bus_i.clk_i = '1') then
      
      -- sync reset
      if(wb_bus_i.rst_i = '1') then
        wb_ack_o_r <= '0';
        
      else
        wb_ack_o_r <= wb_ack_s; 
        wb_dat_o_r <= slv_read_s(MAX_SLV_GPIO_W - 1 downto 0);
        
      end if;
      
    end if;

  end process CYCLE_GPIO_WB_OUT_REG;

  --
  -- READ/WRITE BUFFERS
  --
  --! This process implements read/write registers
  --! of the WISHBONE bus slave interface.
  CYCLE_READ_WRITE_REG: process(wb_bus_i.clk_i)
  begin

    -- clock event 
    if(wb_bus_i.clk_i'event and wb_bus_i.clk_i = '1') then
      
      -- sync reset
      if(wb_bus_i.rst_i = '1') then
        gpo_r <= (others =>'0');
        
      else
        gpo_r <= slv_write_gpo_s(GPO_W - 1 downto 0);
        
      end if;
      
    end if;

  end process CYCLE_READ_WRITE_REG;

  --
  -- READ BUFFERS
  --
  --! This process implements read only registers
  --! of the WISHBONE bus slave interface.
  CYCLE_READ_REG: process(wb_bus_i.clk_i)
  begin
    
    -- clock event
    if(wb_bus_i.clk_i'event and wb_bus_i.clk_i = '1') then
      
      -- sync reset
      if(wb_bus_i.rst_i = '1') then
        gpi_r <= (others =>'0');
        
        -- new values 
      elsif(wb_ack_s = '1') then  
        gpi_r <= gpio_i.gpi_i;
      
        -- keep values until next read 
      else   
        gpi_r <= (gpi_r or gpio_i.gpi_i); 
        
      end if;
      
    end if;

  end process CYCLE_READ_REG;
  
end be_gpio_slave_wb_bus;

