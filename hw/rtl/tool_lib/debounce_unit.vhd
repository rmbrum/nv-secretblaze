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
--! @file debounce_unit.vhd                                					
--! @brief Basic Debounce Unit			
--! @author Lyonel Barthe
--! @version 1.0
--                                                                
-----------------------------------------------------------------
-----------------------------------------------------------------

--
-- Revision History
--
-- Version 1.0 1/10/2010 by Lyonel Barthe
-- Initial Release
--

--
--! The entity implements a basic debounce unit.
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library tool_lib;
use tool_lib.math_pack.all;

--! Debounce Unit Entity
entity debounce_unit is

  generic
    (
      DATA_W : natural := 1                                --! data width
    );
  port
    (
      ena_i  : in std_ulogic;                              --! debounce enable signal 
      dat_i  : in std_ulogic_vector(DATA_W - 1 downto 0);  --! data input
      dat_o  : out std_ulogic_vector(DATA_W - 1 downto 0); --! data output
      clk_i  : in std_ulogic                               --! system clock
    ); 

end debounce_unit;

--! Debounce Unit Architecture
architecture be_debounce_unit of debounce_unit is

  -- //////////////////////////////////////////
  --               INTERNAL REGS
  -- //////////////////////////////////////////

  signal dat_i_r       : std_ulogic_vector(DATA_W - 1 downto 0); --! data input register
  signal dat_i_sync_r  : std_ulogic_vector(DATA_W - 1 downto 0); --! data input sync register
  signal dat_sampled_r : std_ulogic_vector(DATA_W - 1 downto 0); --! data sampled register
  signal dat_o_r       : std_ulogic_vector(DATA_W - 1 downto 0); --! data output register

begin

  -- //////////////////////////////////////////
  --                COMB PROCESS
  -- //////////////////////////////////////////

  --
  -- ASSIGN OUTPUT
  --

  dat_o <= dat_o_r; 

  -- //////////////////////////////////////////
  --               CYCLE PROCESS
  -- //////////////////////////////////////////

  --
  -- SYNCHRONIZER REGISTERS
  --
  --! This cycle process implement synchronizer registers to deal with 
  --! (fast) asynchronous inputs.
  CYCLE_DEB_REGISTERED_IN: process(clk_i)
  begin

    -- clock event
    if(clk_i'event and clk_i = '1') then
      dat_i_r      <= dat_i;
      dat_i_sync_r <= dat_i_r;
    end if;

  end process CYCLE_DEB_REGISTERED_IN;

  --
  -- DATA REGS
  --
  --! This cycle process implements data registers of the debounce unit.
  CYCLE_DEB_DATA_REG: process(clk_i)
  begin

    -- clock event
    if(clk_i'event and clk_i = '1') then
      if(ena_i = '1') then
        dat_sampled_r <= dat_i_sync_r;
        
        if(dat_sampled_r = dat_i_sync_r) then
          dat_o_r <= dat_i_sync_r;
          
        end if;
      end if;
    end if;

  end process CYCLE_DEB_DATA_REG;

end be_debounce_unit;


