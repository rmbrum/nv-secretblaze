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
--! @file sim_config.vhd                                					
--! @brief Simulation Configuration Package   				
--! @author Lyonel Barthe
--! @version 1.0
--                                                                
-----------------------------------------------------------------
-----------------------------------------------------------------

--
-- Revision History
--
-- Version 1.0 08/2012 by Lyonel Barthe
-- Stable version
--

library ieee;
use ieee.std_logic_1164.all;

--
--! Simulation settings of the SecretBlaze-based SoC.
--
--! Simulation Configuration Package
package sim_config is

  -- //////////////////////////////////////////
  --               SIM SETTINGS
  -- //////////////////////////////////////////

--  constant USER_SIMULATION_MODE : string := "TRUE";                                    --! simulation mode setting ("TRUE","FALSE")  
  constant USER_SIMULATION_MODE : string := "FALSE";                                   --! simulation mode setting ("TRUE","FALSE")
  constant USER_TB_FILE_PATH    : string := "../designs/digilent_s6_atlys_board/tb/";   --! tb files path
  constant USER_UART_OUT_FILE   : string := USER_TB_FILE_PATH & "uart_output.txt";      --! UART output text file

end sim_config;

