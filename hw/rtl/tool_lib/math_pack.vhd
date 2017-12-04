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
--! @file math_pack.vhd                                					
--! @brief Math Package    				
--! @author Lyonel Barthe
--! @version 1.0
--                                                                
-----------------------------------------------------------------
-----------------------------------------------------------------

--
-- Revision History
--
-- Version 1.0 12/02/2010 by Lyonel Barthe
-- Initial Release
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--
--! The package implements useful math functions.
--

--! Math Tools Package
package math_pack is

  -- //////////////////////////////////////////
  --                MATH TOOLS
  -- //////////////////////////////////////////

  --! This function returns the "pseudo" log2 of a 
  --! natural number. The result is rounding up. Note 
  --! that in case of data = 1, it returns 1. This 
  --! function was introduced to deal with VHDL 
  --! generics, giving the number of bits required 
  --! to implement an integer.
  --! Ex: 1 => 1
  --!     2 => 1
  --!     3 => 2
  --!     8 => 3
  --!     9 => 4
  pure function log2 
  (
    data : in natural --! data in
  ) 
  return natural;
    
  --! This function implements the reverse bit
  --! function of a std_ulogic_vector.
  pure function reverse_bit
  (
    data : in std_ulogic_vector --! data in 
  )
  return std_ulogic_vector;

  --! This function implements the boolean to
  --! natural conversion.
  pure function bool_to_nat
  (
    data : in boolean --! data in 
  )
  return natural;
  
  --! This function evaluates the cacheable memory width
  --! by taking into account the offset of the cache base 
  --! address (only if required).
  pure function eval_cache_mem_w 
  (
    cacheable_s  : in natural; --! cacheable memory size 
    base_adr_off : in natural  --! base address offset 
  ) 
  return natural;
  
  --! This function removes the warning "NUMERIC_STD.TO_INTEGER: 
  --! metavalue detected, returning 0" for simulation purpose only.
  pure function check_x
  (
    data : in std_ulogic_vector --! data in
  )
  return std_ulogic_vector;

end math_pack;

--! Math Tools Body
package body math_pack is 

  --! This function returns the "pseudo" log2 of a 
  --! natural number. The result is rounding up. Note 
  --! that in case of data = 1, it returns 1. This 
  --! function was introduced to deal with generic 
  --! statements, giving the number of bits required 
  --! to implement an integer.
  --! Ex: 1 => 1
  --!     2 => 1
  --!     3 => 2
  --!     8 => 3
  --!     9 => 4
  pure function log2 
  (
    data : in natural --! data in
  ) 
  return natural is
  
    variable j : natural;
    
  begin

    -- special case: 1 => return 1
    if(data = 1) then
      return 1;
    end if;

    -- init 
    j := 0;

    while (2**j < data)
      loop
        j := j+1;
      end loop;
    return j;

  end log2;
  
  --! This function implements the reverse bit
  --! mode of a std_ulogic_vector.
  pure function reverse_bit
  (
    data : in std_ulogic_vector  --! data in
  )
  return std_ulogic_vector is
  
    variable res_v : std_ulogic_vector(data'range);
    alias in_a     : std_ulogic_vector(data'reverse_range) is data;
        
  begin

    for i in data'range loop
      res_v(i) := in_a(i);
    end loop;

    return res_v;

  end reverse_bit;

  --! This function implements the boolean to
  --! natural conversion.
  pure function bool_to_nat
  (
    data : in boolean --! data in 
  )
  return natural is
  begin
  
    if(data = true) then
      return 1;

    else
      return 0;

    end if;

  end bool_to_nat;
  
  --! This function evaluates the cacheable memory width
  --! by taking into account the offset of the cache base 
  --! address (only if required).
  pure function eval_cache_mem_w 
  (
    cacheable_s  : in natural; --! cacheable memory size 
    base_adr_off : in natural  --! base address offset 
  ) 
  return natural is
  
    variable val : natural;
    
  begin

    -- special case: base address offset must be taken into account
    if(cacheable_s > base_adr_off) then
      val := log2(cacheable_s + base_adr_off);
    
      -- default
    else
      val := log2(cacheable_s);
      
    end if;
      
    return val;

  end eval_cache_mem_w;
  
  --! This function removes the warning "NUMERIC_STD.TO_INTEGER: 
  --! metavalue detected, returning 0" for simulation purpose only.
  pure function check_x
  (
    data : in std_ulogic_vector --! data in
  )
  return std_ulogic_vector is
  
    constant null_c : std_ulogic_vector(data'range) := (others => '0');
  
  begin
    
    -- synthesis translate_off
    if(is_x(data)) then
      return null_c;
    end if;
    -- synthesis translate_on
  
    return data;
  
  end check_x;
  
end math_pack;

