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
--! @file sb_beval.vhd                                      					
--! @brief SecretBlaze Branch Evaluation Unit 
--! @author Lyonel Barthe
--! @version 1.0
--                                                                 
-----------------------------------------------------------------
-----------------------------------------------------------------

--
-- Revision History
--
-- Version 1.0 11/05/2011 by Lyonel Barthe
-- New implementation
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library sb_lib;
use sb_lib.sb_core_pack.all;

library config_lib;
use config_lib.sb_config.all;

--
--! This module implements the branch evaluation unit of the processor.
--

--! SecretBlaze Branch Evaluation Unit Entity
entity sb_beval is
 
  port
    (
      data_i    : in data_t;           --! branch data input
      control_i : in branch_control_t; --! branch control input
      status_o  : out branch_status_t  --! branch status output
    );  
  
end sb_beval;

--! SecretBlaze Branch Evaluation Unit Architecture
architecture be_sb_beval of sb_beval is

  -- //////////////////////////////////////////
  --               INTERNAL WIRE
  -- //////////////////////////////////////////
  
  signal status_s : branch_status_t;
   
begin

  -- //////////////////////////////////////////
  --                COMB PROCESS
  -- //////////////////////////////////////////

  --
  -- ASSIGN OUTPUT SIGNAL
  --

  status_o <= status_s;

  --
  -- BRANCH EVAL LOGIC
  --
  --! This comb process evaluates the branch 
  --! condition of the instruction being executed.
  COMB_BRANCH_EVAL: process(data_i,
                            control_i)
                                
    constant zero_c : data_t := (others =>'0');
    variable zero_v : std_ulogic;
    
  begin    
 
    -- compute zero condition
    if(data_i = zero_c) then 
      zero_v := '1';

    else
      zero_v := '0';

    end if;

    case control_i is

      when B_NOP =>
        status_s <= B_N_TAKEN;

      when BNC =>
        status_s <= B_TAKEN;
        
      when BEQ =>
        status_s <= zero_v;

      when BNE =>
        status_s <= not(zero_v);
        
      when BLT =>
        status_s <= data_i(data_t'left);
        
      when BLE =>
        status_s <= data_i(data_t'left) or zero_v;

      when BGT =>
        status_s <= not(data_i(data_t'left) or zero_v);

      when BGE =>
        status_s <= not(data_i(data_t'left));
      
      when others =>
        status_s <= 'X'; -- force X for speed & area optimization / unsafe implementation
        report "branch unit 1: illegal branch cond control code" severity warning;
        
    end case; 
    
  end process COMB_BRANCH_EVAL;
           
end be_sb_beval;

