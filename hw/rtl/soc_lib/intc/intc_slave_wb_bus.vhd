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
--! @file intc_slave_wb_bus.vhd                                					
--! @brief Interrupt Controller and its WISHBONE Bus Slave Interface     				
--! @author Lyonel Barthe
--! @version 1.1
--                                                                
-----------------------------------------------------------------
-----------------------------------------------------------------

--
-- Revision History
--
-- Version 1.1 28/03/2010 by Lyonel Barthe / Remi Busseuil
-- Fixed a bug when reading the status register
-- from the bus (mask values forgotten)
--
-- Version 1.0 13/05/2010 by Lyonel Barthe
-- Stable version
--
-- Version 0.1 10/05/2010 by Lyonel Barthe
-- Initial Release
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library wb_lib;
use wb_lib.wb_pack.all;

library soc_lib;
use soc_lib.intc_pack.all;

library sb_lib;
use sb_lib.sb_core_pack.all;

--
--! The module implements a basic interrupt controller
--! and its synchronous WISHBONE bus slave interface.
--! The interrupt controller is able to arm, mask, and
--! set the polarity of interrupts. By default, the
--! controller supports 8 source of interrupts, although
--! this number could be easily customized.
--! Pending interrupts are indicated into the status
--! register. The software will clear pending interrupts
--! by setting the ack reg to the proper value. 
--! Priority policy is only supported in software.
--! The module supports pipelined read/write mode.
--

--! INTC & WISHBONE Bus Slave Interface Entity
entity intc_slave_wb_bus is

  port
    (
      intc_i   : in intc_i_t;         --! INTERRUPT controller general inputs
      intc_o   : out intc_o_t;        --! INTERRUPT controller general outputs
      wb_bus_i : in wb_slave_bus_i_t; --! WISHBONE slave inputs
      wb_bus_o : out wb_slave_bus_o_t --! WISHBONE slave outputs  
    );

end intc_slave_wb_bus;

--! INTC & WISHBONE Bus Slave Interface Architecture
architecture be_intc_slave_wb_bus of intc_slave_wb_bus is
  
  -- //////////////////////////////////////////
  --               INTERNAL REGS
  -- //////////////////////////////////////////

  -- Nota: UNUSED BIT WON'T BE IMPLEMENTED!
  -- in order to save FFS.

  -- status_r : BASE_ADDRESS + 0x0 (read only)
  -- MSB                                 LSB
  -- +-------------------------------------+
  -- |    31 ... 8    |    7    ...      0 |
  -- +-------------------------------------+
  -- |     unused     | id 7    ...   id 0 |
  -- +-------------------------------------+
  signal status_r : intc_data_t;              --! status reg 
   
  -- ack_r : BASE_ADDRESS + 0x4 (write only)
  -- MSB                                 LSB
  -- +-------------------------------------+
  -- |    31 ... 8    |    7    ...      0 |
  -- +-------------------------------------+
  -- |     unused     | id 7    ...   id 0 |
  -- +-------------------------------------+
  signal ack_r    : intc_data_t;              --! ack reg   
  
  -- mask_r : BASE_ADDRESS + 0x8 (read/write)
  -- MSB                                 LSB
  -- +-------------------------------------+
  -- |    31 ... 8    |    7    ...      0 |
  -- +-------------------------------------+
  -- |     unused     | id 7    ...   id 0 |
  -- +-------------------------------------+  
  signal mask_r   : intc_data_t;              --! mask reg 
  
  -- arm_r : BASE_ADDRESS + 0xc (read/write)
  -- MSB                                 LSB
  -- +-------------------------------------+
  -- |    31 ... 8    |    7    ...      0 |
  -- +-------------------------------------+
  -- |     unused     | id 7    ...   id 0 |
  -- +-------------------------------------+
  signal arm_r    : intc_data_t;              --! arm reg 
  
  -- pol_r : BASE_ADDRESS + 0x10 (read/write)
  -- MSB                                 LSB
  -- +-------------------------------------+
  -- |    31 ... 8    |    7    ...      0 |
  -- +-------------------------------------+
  -- |     unused     | id 7    ...   id 0 |
  -- +-------------------------------------+
  signal pol_r    : intc_data_t;              --! pol reg 
  
  signal wb_ack_o_r : std_ulogic;                                     --! WISHBONE simple read/write ack reg
  signal wb_dat_o_r : std_ulogic_vector(MAX_SLV_INTC_W - 1 downto 0); --! WISHBONE data bus reg
  signal cpu_int_r  : std_ulogic;                                     --! INTC output reg

  -- //////////////////////////////////////////
  --              INTERNAL WIRES
  -- //////////////////////////////////////////

  --
  -- SLAVE INTERFACE SIGNALS
  --   

  signal slv_read_s       : wb_bus_data_t;  
  signal slv_write_ack_s  : wb_bus_data_t;
  signal slv_write_mask_s : wb_bus_data_t;
  signal slv_write_arm_s  : wb_bus_data_t;
  signal slv_write_pol_s  : wb_bus_data_t;

  --
  -- WB SIGNALS
  -- 

  signal wb_we_s          : std_ulogic;
  signal wb_re_s          : std_ulogic;
  signal wb_reg_adr_s     : wb_intc_reg_adr_t;
  signal wb_ack_s         : std_ulogic;
  
  --
  -- IP SIGNALS
  --
    
  signal status_s         : intc_data_t;
  signal cpu_int_s        : std_ulogic;
     
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
  intc_o.cpu_int_o <= cpu_int_r;

  --
  -- ASSIGN INTERNAL SIGNALS
  --
  
  --
  -- WB SIGNALS
  --

  wb_we_s      <= (wb_bus_i.stb_i and wb_bus_i.cyc_i and wb_bus_i.we_i);                                   -- write bus operation          
  wb_re_s      <= (wb_bus_i.stb_i and wb_bus_i.cyc_i and not(wb_bus_i.we_i));                              -- read bus operation 
  wb_reg_adr_s <= (wb_bus_i.adr_i(wb_intc_reg_adr_t'length + WB_WORD_ADR_OFF - 1 downto WB_WORD_ADR_OFF)); -- register address
  wb_ack_s     <= (wb_bus_i.stb_i and wb_bus_i.cyc_i);                                                     -- pipelined read/write ack

  --
  -- COMB STATUS 
  --
  --! This process implements the behaviour of the status control logic. 
  --! To catch the interrupt, the arm register must be set. If the 
  --! interrupt is acknowledged, the status signal is cleared. 
  COMB_STATUS_SIGNAL: process(intc_i.int_sources_i,
                              ack_r,
                              status_r,
                              pol_r,
                              arm_r)

  begin

    for i in 0 to INTC_NB_SOURCES - 1 loop

      -- ack 
      if(ack_r(i) = '1') then
        -- armed
        if(arm_r(i) = '1') then
          -- active high interrupt
          if(pol_r(i) = '1') then
            status_s(i) <= (intc_i.int_sources_i(i)); 
          
           -- active low interrupt
          else
            status_s(i) <= (not(intc_i.int_sources_i(i)));
          
          end if;

          -- not armed
        else
          status_s(i) <= '0'; -- clear pending interrupt

        end if;

        -- not ack
      else
        -- armed
        if(arm_r(i) = '1') then
          -- active high interrupt
          if(pol_r(i) = '1') then
            status_s(i) <= (intc_i.int_sources_i(i) or status_r(i));
          
           -- active low interrupt
          else
            status_s(i) <= (not(intc_i.int_sources_i(i)) or status_r(i));
          
          end if;

          -- not armed
        else   
          status_s(i) <= status_r(i); -- keep pending interrupt

        end if;        

      end if;

    end loop;

  end process COMB_STATUS_SIGNAL;

  --
  -- COMB CPU INT
  --
  --! This process implements the cpu interrupt signal. To activate the interrupt, 
  --! the mask register should be cleared. 
  COMB_MST_INT_SIGNAL: process(mask_r,
                               status_r)
    
    variable cpu_int_v : std_ulogic;
    
  begin
    
    -- default
    cpu_int_v := '0';
    
    for i in 0 to INTC_NB_SOURCES - 1 loop

      if(mask_r(i) = '0') then
        cpu_int_v := (cpu_int_v or status_r(i));
      end if;

    end loop;
    
    -- assign output
    cpu_int_s <= cpu_int_v;
    
  end process COMB_MST_INT_SIGNAL;

  --
  -- COMB SLAVE READ REG
  --
  --! This process implements the behaviour of a bus read operation.
  COMB_SLAVE_READ_REG: process(wb_bus_i,
                               status_r,
                               mask_r,
                               arm_r,
                               pol_r,
                               wb_re_s,
                               wb_reg_adr_s)
    
    variable status_v   : wb_bus_data_t;
    variable mask_v     : wb_bus_data_t;
    variable arm_v      : wb_bus_data_t;
    variable pol_v      : wb_bus_data_t;

  begin

    status_v   := std_ulogic_vector(resize(unsigned(status_r),wb_bus_data_t'length));
    mask_v     := std_ulogic_vector(resize(unsigned(mask_r),wb_bus_data_t'length));
    arm_v      := std_ulogic_vector(resize(unsigned(arm_r),wb_bus_data_t'length));
    pol_v      := std_ulogic_vector(resize(unsigned(pol_r),wb_bus_data_t'length));    

    -- default
    slv_read_s <= (others =>'X');
    
    -- read enable
    if(wb_re_s = '1') then
      
      -- decode reg address 
      case wb_reg_adr_s is 
        
        when STATUS_OFF =>
                    
          for i in 0 to (wb_bus_data_t'length/8)-1 loop
            if (wb_bus_i.sel_i(i) = '1') then
              slv_read_s(8*(i+1) - 1 downto 8*i) <= status_v(8*(i+1) - 1 downto 8*i) and (not(mask_v(8*(i+1) - 1 downto 8*i)));
            end if;
          end loop;
          
        when MASK_OFF =>

          for i in 0 to (wb_bus_data_t'length/8)-1 loop
            if (wb_bus_i.sel_i(i) = '1') then
              slv_read_s(8*(i+1) - 1 downto 8*i) <= mask_v(8*(i+1) - 1 downto 8*i);
            end if;
          end loop;

        when ARM_OFF =>

          for i in 0 to (wb_bus_data_t'length/8)-1 loop
            if (wb_bus_i.sel_i(i) = '1') then
              slv_read_s(8*(i+1) - 1 downto 8*i) <= arm_v(8*(i+1) - 1 downto 8*i);
            end if;
          end loop;

        when POL_OFF =>

          for i in 0 to (wb_bus_data_t'length/8)-1 loop
            if (wb_bus_i.sel_i(i) = '1') then
              slv_read_s(8*(i+1) - 1 downto 8*i) <= pol_v(8*(i+1) - 1 downto 8*i);
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
                                ack_r,
                                mask_r,
                                arm_r,
                                pol_r,
                                wb_we_s,
                                wb_reg_adr_s,
                                wb_ack_s)
  
  begin
    
    -- default 
    slv_write_ack_s  <= (others =>'0'); -- pulse command register
    slv_write_mask_s <= std_ulogic_vector(resize(unsigned(mask_r),wb_bus_data_t'length));
    slv_write_arm_s  <= std_ulogic_vector(resize(unsigned(arm_r),wb_bus_data_t'length));
    slv_write_pol_s  <= std_ulogic_vector(resize(unsigned(pol_r),wb_bus_data_t'length));

    -- write enable
    if(wb_we_s = '1') then
      
      -- decode address 
      case wb_reg_adr_s is 

        when ARM_OFF =>

          for i in 0 to (wb_bus_data_t'length/8)-1 loop
            if (wb_bus_i.sel_i(i) = '1') then
              slv_write_arm_s(8*(i+1) - 1 downto 8*i) <= wb_bus_i.dat_i(8*(i+1) - 1 downto 8*i);
            end if;
          end loop;

        when POL_OFF =>

          for i in 0 to (wb_bus_data_t'length/8)-1 loop
            if (wb_bus_i.sel_i(i) = '1') then
              slv_write_pol_s(8*(i+1) - 1 downto 8*i) <= wb_bus_i.dat_i(8*(i+1) - 1 downto 8*i);
            end if;
          end loop;
          
        when MASK_OFF =>

          for i in 0 to (wb_bus_data_t'length/8)-1 loop
            if (wb_bus_i.sel_i(i) = '1') then
              slv_write_mask_s(8*(i+1) - 1 downto 8*i) <= wb_bus_i.dat_i(8*(i+1) - 1 downto 8*i);
            end if;
          end loop;

        when ACK_OFF =>

          for i in 0 to (wb_bus_data_t'length/8)-1 loop
            if (wb_bus_i.sel_i(i) = '1') then
              slv_write_ack_s(8*(i+1) - 1 downto 8*i) <= wb_bus_i.dat_i(8*(i+1) - 1 downto 8*i);
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
  CYCLE_INT_WB_OUT_REG: process(wb_bus_i.clk_i)
  begin
    
    -- clock event 
    if(wb_bus_i.clk_i'event and wb_bus_i.clk_i = '1') then
      
      -- sync reset
      if(wb_bus_i.rst_i = '1') then
        wb_ack_o_r <= '0';
        
      else
        wb_ack_o_r <= wb_ack_s; 
        wb_dat_o_r <= slv_read_s(MAX_SLV_INTC_W - 1 downto 0);
        
      end if;
      
    end if;

  end process CYCLE_INT_WB_OUT_REG;

  --
  -- WRITE BUFFERS
  --
  --! This process implements write only registers.
  CYCLE_WRITE_REG: process(wb_bus_i.clk_i)
  begin

    -- clock event 
    if(wb_bus_i.clk_i'event and wb_bus_i.clk_i = '1') then
      
      -- sync reset
      if(wb_bus_i.rst_i = '1') then
        ack_r <= (others =>'0');
        
      else
        ack_r <= slv_write_ack_s(INTC_NB_SOURCES - 1 downto 0);
        
      end if;
      
    end if;

  end process CYCLE_WRITE_REG;
  
  --
  -- READ BUFFERS
  --
  --! This process implements read only registers.
  CYCLE_READ_REG: process(wb_bus_i.clk_i)
  begin

    -- clock event 
    if(wb_bus_i.clk_i'event and wb_bus_i.clk_i = '1') then
      
      -- sync reset
      if(wb_bus_i.rst_i = '1') then
        status_r <= (others =>'0');
        
      else
        status_r <= status_s;
        
      end if;
      
    end if;

  end process CYCLE_READ_REG;
    
  --
  -- READ/WRITE BUFFERS
  --
  --! This process implements read/write registers
  CYCLE_READ_WRITE_REG: process(wb_bus_i.clk_i)
  begin
    
    -- clock event
    if(wb_bus_i.clk_i'event and wb_bus_i.clk_i = '1') then
      
      -- sync reset
      if(wb_bus_i.rst_i = '1') then
        mask_r <= (others =>'1');       -- mask interrupts
        arm_r  <= (others =>'0');       -- disable interrupts
        pol_r  <= (others =>'1');       -- active high interrupts
        
      else
        mask_r <= slv_write_mask_s(INTC_NB_SOURCES - 1 downto 0);
        arm_r  <= slv_write_arm_s(INTC_NB_SOURCES - 1 downto 0);
        pol_r  <= slv_write_pol_s(INTC_NB_SOURCES - 1 downto 0);
        
      end if;
      
    end if;

  end process CYCLE_READ_WRITE_REG;

  --
  -- INT REG
  --
  --! This process implements the interrupt controller output register.
  CYCLE_INT_OUT_REG: process(wb_bus_i.clk_i)
  begin

    -- clock event
    if(wb_bus_i.clk_i'event and wb_bus_i.clk_i = '1') then
      
      -- sync reset
      if(wb_bus_i.rst_i = '1') then
        cpu_int_r <= '0'; 
              
      else
        cpu_int_r <= cpu_int_s;
        
      end if;
      
    end if;

  end process CYCLE_INT_OUT_REG;
  
end be_intc_slave_wb_bus;

