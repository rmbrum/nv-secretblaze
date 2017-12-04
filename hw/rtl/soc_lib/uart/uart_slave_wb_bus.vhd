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
--! @file uart_slave_wb_bus.vhd                                					
--! @brief WISHBONE Bus Slave Interface for the UART Controller    				
--! @author Lyonel Barthe
--! @version 1.0b
--                                                                
-----------------------------------------------------------------
-----------------------------------------------------------------

--
-- Revision History
--
-- Version 1.0b 28/09/2010 by Lyonel Barthe
-- Changed to a pipelined interface
--
-- Version 1.0a 13/05/2010 by Lyonel Barthe
-- Stable version
--
-- Version 0.1 12/02/2010 by Lyonel Barthe
-- Initial Release
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library soc_lib;
use soc_lib.uart_pack.all;

library tool_lib;
use tool_lib.math_pack.all;

library wb_lib;
use wb_lib.wb_pack.all;

--
--! The module implements a basic synchronous slave
--! interface of the WISHBONE bus for the UART IP.
--! Standard status, control, and data slave registers 
--! are implemented. The status reg is a read only
--! "sticky" register, i.e, it keeps the value until
--! the next read from the bus. The control reg is
--! implemented as a pulse command register. 
--! The module supports pipelined read/write mode.
--

--! UART WISHBONE Bus Slave Interface Entity
entity uart_slave_wb_bus is

  port
    (
      uart_int_o     : out uart_int_vector_t; --! UART interrupt vector outputs
      wb_bus_i       : in wb_slave_bus_i_t;   --! WISHBONE slave inputs
      wb_bus_o       : out wb_slave_bus_o_t;  --! WISHBONE slave outputs 
      tx_dat_in_o    : out uart_data_t;       --! tx data to send	
      rx_dat_out_i   : in uart_data_t;        --! rx data received
      tx_send_in_o   : out std_ulogic;        --! start tx com
      tx_busy_out_i  : in std_ulogic;         --! tx com ready			
      rx_ready_out_i : in std_ulogic          --! rx com ready
    );
  
end uart_slave_wb_bus;

--! UART WISHBONE Bus Slave Interface Architecture
architecture be_uart_slave_wb_bus of uart_slave_wb_bus is
   
  -- //////////////////////////////////////////
  --              INTERNAL REGS
  -- //////////////////////////////////////////

  -- Nota: UNUSED BIT WON'T BE IMPLEMENTED!
  -- in order to to save FFs

  -- status_r : BASE_ADDRESS + 0x0 (read only)
  -- MSB                                 LSB
  -- +-------------------------------------+
  -- |    31 ... 2    |    1    |     0    |
  -- +-------------------------------------+
  -- |     unused     | tx_busy | rx_ready |
  -- +-------------------------------------+
  signal status_r   : std_ulogic_vector(1 downto 0); --! status reg
  
  -- control_r : BASE_ADDRESS + 0x8 (write only)
  -- MSB                                 LSB
  -- +-------------------------------------+
  -- |         31 ... 1         |     0    |
  -- +-------------------------------------+
  -- |          unused          |  tx_send |
  -- +-------------------------------------+  
  signal control_r  : std_ulogic;                    --! control reg
  
  -- tx_dat_r : BASE_ADDRESS + 0xc (write only)
  -- MSB                                 LSB
  -- +-------------------------------------+
  -- |     31 ... 8       |   7 ...   0    |
  -- +-------------------------------------+
  -- |      unused        |    TX  data    |
  -- +-------------------------------------+   
  signal tx_dat_r  : uart_data_t;                    --! data to send reg
  
  -- rx_dat_r : BASE_ADDRESS + 0x4 (read only)
  -- MSB                                 LSB
  -- +-------------------------------------+
  -- |     31 ... 8       |   7 ...   0    |
  -- +-------------------------------------+
  -- |       unused       |    RX  data    |
  -- +-------------------------------------+ 
  signal rx_dat_r : uart_data_t;                     --! data received reg

  signal wb_ack_o_r : std_ulogic;                                     --! WISHBONE single read/write ack reg
  signal wb_dat_o_r : std_ulogic_vector(MAX_SLV_UART_W - 1 downto 0); --! WISHBONE data bus reg

  -- //////////////////////////////////////////
  --              INTERNAL WIRES
  -- //////////////////////////////////////////
  
  --
  -- SLAVE INTERFACE SIGNALS
  -- 
  
  signal slv_read_s          : wb_bus_data_t;
  signal slv_write_control_s : wb_bus_data_t;
  signal slv_write_tx_dat_s  : wb_bus_data_t;

  --
  -- WB SIGNALS
  --

  signal wb_we_s             : std_ulogic;
  signal wb_re_s             : std_ulogic;
  signal wb_reg_adr_s        : wb_uart_reg_adr_t;
  signal wb_ack_s            : std_ulogic;
     
begin

  -- //////////////////////////////////////////
  --                COMB PROCESS
  -- //////////////////////////////////////////

  --
  -- ASSIGN OUTPUTS
  --
  
  wb_bus_o.ack_o   <= wb_ack_o_r;                                                                             
  wb_bus_o.dat_o   <= std_ulogic_vector(resize(unsigned(wb_dat_o_r),wb_bus_data_t'length));
  wb_bus_o.err_o   <= '0';                         -- not implemented
  wb_bus_o.rty_o   <= '0';                         -- not implemented
  wb_bus_o.stall_o <= '0';                         -- not implemented 
  uart_int_o       <= not(tx_busy_out_i) & rx_ready_out_i; -- UART interrupt vector  
  tx_dat_in_o      <= tx_dat_r;
  tx_send_in_o     <= control_r;

  --
  -- ASSIGN INTERNAL SIGNALS
  --
  
  --
  -- WB SIGNALS
  --

  wb_we_s      <= (wb_bus_i.stb_i and wb_bus_i.cyc_i and wb_bus_i.we_i);                                   -- write bus operation          
  wb_re_s      <= (wb_bus_i.stb_i and wb_bus_i.cyc_i and not(wb_bus_i.we_i));                              -- read bus operation 
  wb_reg_adr_s <= (wb_bus_i.adr_i(wb_uart_reg_adr_t'length + WB_WORD_ADR_OFF - 1 downto WB_WORD_ADR_OFF)); -- register address
  wb_ack_s     <= (wb_bus_i.stb_i and wb_bus_i.cyc_i);                                                     -- pipelined read/write ack
 
  --
  -- COMB SLAVE READ REG
  --
  --! This process implements the behaviour of a bus read operation.
  COMB_SLAVE_READ_REG: process(wb_bus_i,
                               status_r,
                               rx_dat_r,
                               wb_re_s,
                               wb_reg_adr_s)
    
    variable status_v : wb_bus_data_t;
    variable rx_dat_v : wb_bus_data_t;

  begin

    status_v := std_ulogic_vector(resize(unsigned(status_r),wb_bus_data_t'length));
    rx_dat_v := std_ulogic_vector(resize(unsigned(rx_dat_r),wb_bus_data_t'length));    

    -- default 
    slv_read_s <= (others =>'X'); 

    -- read enable
    if(wb_re_s = '1') then
      
      -- decode reg address 
      case wb_reg_adr_s is 
        
        when STATUS_OFF =>
          
          for i in 0 to (wb_bus_data_t'length/8)-1 loop
            if (wb_bus_i.sel_i(i) = '1') then
              slv_read_s(8*(i+1) - 1 downto 8*i) <= status_v(8*(i+1) - 1 downto 8*i);
            end if;
          end loop;
          
        when RX_DAT_OFF =>
                   
          for i in 0 to (wb_bus_data_t'length/8)-1 loop
            if (wb_bus_i.sel_i(i) = '1') then
              slv_read_s(8*(i+1) - 1 downto 8*i) <= rx_dat_v(8*(i+1) - 1 downto 8*i);
            end if;
          end loop;
          
        when others =>
          
      end case;
      
    end if;

  end process COMB_SLAVE_READ_REG;
  
  --
  -- COMB SLAVE WRITE REG
  --
  --! This process implements the behaviour of a bus write operation.
  COMB_SLAVE_WRITE_REG: process(wb_bus_i,
                                wb_we_s,
                                tx_dat_r,
                                wb_reg_adr_s,
                                wb_ack_s)
    
  begin
    
    -- default 
    slv_write_control_s <= (others =>'0'); -- pulse command register
    slv_write_tx_dat_s  <= std_ulogic_vector(resize(unsigned(tx_dat_r),wb_bus_data_t'length));
    
    -- write enable
    if(wb_we_s = '1') then
      
      -- decode address 
      case wb_reg_adr_s is 
        
        when CONTROL_OFF =>
          
          for i in 0 to (wb_bus_data_t'length/8)-1 loop
            if (wb_bus_i.sel_i(i) = '1') then
              slv_write_control_s(8*(i+1) - 1 downto 8*i) <= wb_bus_i.dat_i(8*(i+1) - 1 downto 8*i);
            end if;
          end loop;
          
        when TX_DAT_OFF =>

          for i in 0 to (wb_bus_data_t'length/8)-1 loop
            if (wb_bus_i.sel_i(i) = '1') then
              slv_write_tx_dat_s(8*(i+1) - 1 downto 8*i) <= wb_bus_i.dat_i(8*(i+1) - 1 downto 8*i);
            end if;
          end loop;
          
        when others =>
          
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
  CYCLE_UART_WB_SLV_OUT_REG: process(wb_bus_i.clk_i)
  begin
    
    -- clock event 
    if(wb_bus_i.clk_i'event and wb_bus_i.clk_i = '1') then
      
      -- sync reset
      if(wb_bus_i.rst_i = '1') then
        wb_ack_o_r <= '0';
        
      else
        wb_ack_o_r <= wb_ack_s; 
        wb_dat_o_r <= slv_read_s(MAX_SLV_UART_W - 1 downto 0);
        
      end if;
      
    end if;

  end process CYCLE_UART_WB_SLV_OUT_REG;

  --
  -- WRITE BUFFERS
  --
  --! This process implements write only registers
  --! of the WISHBONE bus slave interface.
  CYCLE_UART_WRITE_REG: process(wb_bus_i.clk_i)
  begin

    -- clock event 
    if(wb_bus_i.clk_i'event and wb_bus_i.clk_i = '1') then
      
      -- sync reset
      if(wb_bus_i.rst_i = '1') then
        control_r <= '0';
        
      else
        control_r <= slv_write_control_s(0);
        tx_dat_r  <= slv_write_tx_dat_s(UART_DATA_W - 1 downto 0);

      end if;
      
    end if;

  end process CYCLE_UART_WRITE_REG;
    
  --
  -- READ BUFFERS
  --
  --! This process implements read only registers
  --! of the WISHBONE bus slave interface.
  CYCLE_UART_READ_REG: process(wb_bus_i.clk_i)
  begin
    
    -- clock event
    if(wb_bus_i.clk_i'event and wb_bus_i.clk_i = '1') then
      
      -- sync reset
      if(wb_bus_i.rst_i = '1') then
        status_r   <= (others =>'0');
        
      else
        rx_dat_r   <= rx_dat_out_i;

        -- new values
        if(wb_ack_s = '1') then
          status_r <= tx_busy_out_i & rx_ready_out_i;

          -- keep values until next read
        else
          status_r <= ((tx_busy_out_i & rx_ready_out_i) or status_r); 

        end if;
        
      end if;
	  
    end if;

  end process CYCLE_UART_READ_REG;
  
end be_uart_slave_wb_bus;

