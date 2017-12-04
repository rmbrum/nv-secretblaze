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
--! @file wb_arb.vhd                                					
--! @brief WISHBONE Bus Arbiter    				
--! @author Lyonel Barthe
--! @version 1.0b
--                                                                
-----------------------------------------------------------------
-----------------------------------------------------------------

--
-- Revision History
--
-- Version 1.0b 29/06/2010 by Lyonel Barthe
-- Fixed a bug with the arb grant signal
--
-- Version 1.0a 13/05/2010 by Lyonel Barthe
-- Stable version
--
-- Version 0.1 21/04/2010 by Lyonel Barthe
-- Initial Release
--

--
--! This module implements a basic bus arbiter
--! with fixed based priority. Master 0 got the
--! highest priority. The arbiter can support an
--! unlimited number of master devices. 
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library tool_lib;
use tool_lib.math_pack.all;

--! WISHBONE Bus Arbiter Entity
entity wb_arbiter is
  
  generic
  (
    NB_OF_MASTERS    : natural := 2                                   --! nb of master devices
  );
  port
  (
    arb_req_i        : in std_ulogic_vector(0 to NB_OF_MASTERS - 1);  --! arb bus request inputs 
    arb_grant_reg_o  : out std_ulogic_vector(0 to NB_OF_MASTERS - 1); --! arb registered grant output
    arb_next_grant_o : out std_ulogic_vector(0 to NB_OF_MASTERS - 1); --! arb next grant output
    clk_i            : in std_ulogic;                                 --! arbiter clock
    rst_n_i          : in std_ulogic                                  --! active-low reset signal
  );

end wb_arbiter;

--! WISHBONE Bus Arbiter Architecture
architecture be_wb_arbiter of wb_arbiter is

  -- //////////////////////////////////////////
  --               INTERNAL REG
  -- //////////////////////////////////////////

  signal arb_grant_r : std_ulogic_vector(0 to NB_OF_MASTERS - 1);     --! arb grant reg
  
  -- //////////////////////////////////////////
  --               INTERNAL WIRES
  -- //////////////////////////////////////////

  signal arb_grant_s : std_ulogic_vector(0 to NB_OF_MASTERS - 1);
 
begin

  -- //////////////////////////////////////////
  --                COMB PROCESS
  -- //////////////////////////////////////////

  --
  -- ASSIGN GRANT SIGNALS
  --

  arb_grant_reg_o  <= arb_grant_r; -- registered grant
  arb_next_grant_o <= arb_grant_s; -- comb grant
  
  --
  -- ARB GRANT SIGNAL  
  --
  --! This process provides the arb grant
  --! signal with a fixed priority policy. 
  COMB_ARB_GRANT: process(arb_req_i,
                          arb_grant_r)

    variable stop_v : std_ulogic;
    variable busy_v : std_ulogic;

  begin

    stop_v := '0';
    busy_v := '0';

    for i in 0 to NB_OF_MASTERS - 1 loop

      if(arb_req_i(i) = arb_grant_r(i) and arb_grant_r(i) = '1') then
        busy_v := '1';
      end if;
		
    end loop;
	 
    -- busy / grant old master
    if(busy_v = '1') then
      arb_grant_s <= arb_grant_r;
		
    else
      -- grant with priority
      for i in 0 to NB_OF_MASTERS - 1 loop	 
        if(stop_v = '0' and arb_req_i(i) = '1') then
          arb_grant_s(i) <= '1';
          stop_v         := '1';  
          
        else
          arb_grant_s(i) <= '0';
        
        end if;    
      end loop;
		
    end if;

  end process COMB_ARB_GRANT;

  -- //////////////////////////////////////////
  --               CYCLE PROCESS
  -- //////////////////////////////////////////

  --
  -- ARBITER GRANT REGISTER
  --
  --! This process implements the arb grant register.
  CYCLE_ARB_GRANT: process(clk_i) 
  begin

    -- clock event
    if(clk_i'event and clk_i = '1') then
      
      -- sync reset
      if(rst_n_i = '0') then
        arb_grant_r <= (others => '0');
        
      else
        arb_grant_r <= arb_grant_s;
        
      end if;
      
    end if;

  end process CYCLE_ARB_GRANT;

end architecture be_wb_arbiter;


