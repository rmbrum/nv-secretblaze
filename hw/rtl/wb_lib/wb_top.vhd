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
--! @file wb_top.vhd                                					
--! @brief WISHBONE Bus Top Level Entity 			
--! @author Lyonel Barthe
--! @version 1.0c
--                                                                
-----------------------------------------------------------------
-----------------------------------------------------------------

--
-- Revision History
--
-- Version 1.0c 17/05/2010 by Lyonel Barthe & Remi Busseuil
-- Added the slv_dec register to fix a bug
-- with the pipelined protocol 
-- Changed coding style 
--
-- Version 1.0b 30/06/2010 by Lyonel Barthe
-- Added STALL_I signal (WB Rev B4)
--
-- Version 1.0a 13/05/2010 by Lyonel Barthe
-- Stable version
--
-- Version 0.1 20/04/2010 by Lyonel Barthe
-- Initial Release
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library tool_lib;
use tool_lib.math_pack.all;

library wb_lib;
use wb_lib.wb_pack.all;

--
--! The module implements the top level entity of the
--! WISHBONE bus using the multiplexor logic interconnection 
--! scheme. The aim is to allow the connection between 
--! master and slave devices. This is a pure "generic" Rev B4 
--! implementation of the WISHBONE bus (not speed/area optimized).
--! Decoding is done after the arbitration (slower but requires
--! fewer gates). Note also that the (partial) decoding is done 
--! with BASE and HIGH addresses, allowing more flexibility.
--

--! WISHBONE Bus Top Level Entity
entity wb_top is
  generic
  (
    MEM_MAP         : wb_memory_map_t := (X"1000_0000", X"1FFF_FFFF",
                                          X"2000_0000", X"2FFF_FFFF",
                                          X"3000_0000", X"3FFF_FFFF",
                                          X"4000_0000", X"4FFF_FFFF",
                                          X"5000_0000", X"5FFF_FFFF");  --! WISHBONE memory map
    ADDRESS_DEC_W   : natural := 5;                                     --! width of the address decoder
    NB_OF_SLAVES    : natural := 5;                                     --! nb of slave devices
    NB_OF_MASTERS   : natural := 2                                      --! nb of master devices
  );
  port
  (
    wb_master_out_i : in wb_master_vector_o_t(0 to NB_OF_MASTERS - 1);  --! WISHBONE master outputs
    wb_master_in_o  : out wb_master_vector_i_t(0 to NB_OF_MASTERS - 1); --! WISHBONE master inputs
    wb_slave_out_i  : in wb_slave_vector_o_t(0 to NB_OF_SLAVES - 1);    --! WISHBONE slave outputs
    wb_slave_in_o   : out wb_slave_vector_i_t(0 to NB_OF_SLAVES - 1);   --! WISHBONE slave inputs
    wb_grant_o      : out std_ulogic_vector(0 to NB_OF_MASTERS - 1);    --! WISHBONE grant output
    wb_next_grant_o : out std_ulogic_vector(0 to NB_OF_MASTERS - 1);    --! WISHBONE next grant output
    clk_i           : in std_ulogic;                                    --! bus clock
    rst_n_i         : in std_ulogic                                     --! active-low reset signal       
  );
  
end wb_top;

--! WishBone Bus Top Level Architecture
architecture be_wb_top of wb_top is

  -- //////////////////////////////////////////
  --               INTERNAL REG
  -- //////////////////////////////////////////
  
  signal slv_dec_r        : std_ulogic_vector(0 to NB_OF_SLAVES - 1);

  -- //////////////////////////////////////////
  --               INTERNAL WIRES
  -- //////////////////////////////////////////
  
  signal mst_shared_bus_s : wb_master_bus_o_t; 
  signal slv_shared_bus_s : wb_slave_bus_o_t; 
  signal slv_dec_s        : std_ulogic_vector(0 to NB_OF_SLAVES - 1);
  signal arb_req_s        : std_ulogic_vector(0 to NB_OF_MASTERS - 1);
  signal arb_next_grant_s : std_ulogic_vector(0 to NB_OF_MASTERS - 1);
  signal arb_grant_reg_s  : std_ulogic_vector(0 to NB_OF_MASTERS - 1);
   
begin

  -- //////////////////////////////////////////
  --              COMPONENT LINK
  -- //////////////////////////////////////////

  WB_ARB: entity wb_lib.wb_arbiter(be_wb_arbiter)
    generic map
    (
      NB_OF_MASTERS    => NB_OF_MASTERS
      )
    port map
    ( 
      arb_req_i        => arb_req_s,
      arb_grant_reg_o  => arb_grant_reg_s,
      arb_next_grant_o => arb_next_grant_s,
      clk_i            => clk_i,
      rst_n_i          => rst_n_i
    );

  -- //////////////////////////////////////////
  --                COMB PROCESS
  -- //////////////////////////////////////////

  --
  -- ASSIGN NEXT GRANT OUTPUTS
  -- 

  wb_grant_o      <= arb_grant_reg_s;
  wb_next_grant_o <= arb_next_grant_s;
  
  -- //////////////////////////////////////////
  --              MASTERS TO SLAVES
  -- //////////////////////////////////////////
  
  --
  -- ASSIGN ARBITER REQUESTS
  --

  GEN_ARB_REQ: for i in 0 to NB_OF_MASTERS - 1 generate
  begin

    arb_req_s(i) <= wb_master_out_i(i).cyc_o;

  end generate GEN_ARB_REQ;

  --
  -- MASTER DATA MUXES
  --
  --! This process implements master muxes, required
  --! to select appropriate master signals for a WB
  --! bus operation. The bus arbiter provides the 
  --! grant signal. 
  COMB_MST_DATA_MUX: process(arb_grant_reg_s,
                             wb_master_out_i,
                             wb_master_out_i(0), 
                             wb_master_out_i(1)) 

   
  begin  
   
    -- default
    mst_shared_bus_s.cyc_o <= '0';
    mst_shared_bus_s.stb_o <= '0';
    mst_shared_bus_s.we_o  <= 'X';
    mst_shared_bus_s.sel_o <= (others =>'X');
    mst_shared_bus_s.adr_o <= (others =>'X');
    mst_shared_bus_s.dat_o <= (others =>'X');
    mst_shared_bus_s.cti_o <= (others =>'X');
    mst_shared_bus_s.bte_o <= (others =>'X');
    mst_shared_bus_s.bl_o  <= (others =>'X');    
    
    for i in 0 to NB_OF_MASTERS - 1 loop

      -- grant master 
      if(arb_grant_reg_s(i) = '1') then -- registered
        mst_shared_bus_s.cyc_o <= wb_master_out_i(i).cyc_o;
        mst_shared_bus_s.stb_o <= wb_master_out_i(i).stb_o;
        mst_shared_bus_s.we_o  <= wb_master_out_i(i).we_o;
        mst_shared_bus_s.sel_o <= wb_master_out_i(i).sel_o;
        mst_shared_bus_s.adr_o <= wb_master_out_i(i).adr_o;
        mst_shared_bus_s.dat_o <= wb_master_out_i(i).dat_o;
        mst_shared_bus_s.cti_o <= wb_master_out_i(i).cti_o;
        mst_shared_bus_s.bte_o <= wb_master_out_i(i).bte_o;
        mst_shared_bus_s.bl_o  <= wb_master_out_i(i).bl_o;                
      end if;	
      
    end loop;
    
  end process COMB_MST_DATA_MUX;

  --
  -- PARTIAL ADDRESS DECODER
  --
  --! This comb process implements the slave address 
  --! decoder of the WB bus. By default, it uses a partial
  --! address decoder to meet embedded requirements.
  --! Note that the loop statement is used for repetition
  --! of logic in order to generate a full-parallel decoder.
  COMB_SLV_ADDRESS_DECODER: process(mst_shared_bus_s.adr_o)

    alias adr_dec_a : std_ulogic_vector(ADDRESS_DEC_W - 1 downto 0) is
       mst_shared_bus_s.adr_o(WB_BUS_ADR_W - 1 downto WB_BUS_ADR_W - ADDRESS_DEC_W);

  begin
    
    for i in 0 to NB_OF_SLAVES - 1 loop

      -- grant slave if BASE_ADD <= CURRENT_ADD <= HIGH_ADD
      if((adr_dec_a >= MEM_MAP(2*i)(WB_BUS_ADR_W - 1 downto WB_BUS_ADR_W - ADDRESS_DEC_W)) 
          and (adr_dec_a <= MEM_MAP(2*i+1)(WB_BUS_ADR_W - 1 downto WB_BUS_ADR_W - ADDRESS_DEC_W))) then   
        slv_dec_s(i) <= '1';

      else
        slv_dec_s(i) <= '0';

      end if;
      
    end loop;

  end process COMB_SLV_ADDRESS_DECODER;

  --
  -- GENERATE MASTER TO SLAVES 
  --
  
  SLAVE_INTERCO_GEN: for i in 0 to NB_OF_SLAVES - 1 generate
  begin

    wb_slave_in_o(i).clk_i <= clk_i;        -- basic syscon
    wb_slave_in_o(i).rst_i <= not(rst_n_i); -- basic syscon

    wb_slave_in_o(i).cyc_i <= (mst_shared_bus_s.cyc_o and slv_dec_s(i));
    wb_slave_in_o(i).stb_i <= (mst_shared_bus_s.stb_o and mst_shared_bus_s.cyc_o and slv_dec_s(i)); 
    wb_slave_in_o(i).we_i  <= mst_shared_bus_s.we_o;
    wb_slave_in_o(i).sel_i <= mst_shared_bus_s.sel_o;
    wb_slave_in_o(i).adr_i <= mst_shared_bus_s.adr_o;
    wb_slave_in_o(i).dat_i <= mst_shared_bus_s.dat_o;
    wb_slave_in_o(i).cti_i <= mst_shared_bus_s.cti_o;
    wb_slave_in_o(i).bte_i <= mst_shared_bus_s.bte_o;
    wb_slave_in_o(i).bl_i  <= mst_shared_bus_s.bl_o;    
    
  end generate SLAVE_INTERCO_GEN;
 
  -- //////////////////////////////////////////
  --              SLAVES TO MASTERS
  -- //////////////////////////////////////////

  --
  -- SLAVE DATA MUX
  --
  --! This process implements the slave data output mux, 
  --! required to select the result of the appropriate 
  --! slave device.
  COMB_SLV_DATA_MUX: process(slv_dec_r,
                             wb_slave_out_i,
                             wb_slave_out_i(0),
                             wb_slave_out_i(1), 
                             wb_slave_out_i(2), 
                             wb_slave_out_i(3),
                             wb_slave_out_i(4))

  begin

   -- default
   slv_shared_bus_s.dat_o <= (others => 'X');

   for i in 0 to NB_OF_SLAVES - 1 loop

     -- attach slave 
     if(slv_dec_r(i) = '1') then                   
       slv_shared_bus_s.dat_o <= wb_slave_out_i(i).dat_o;
     end if;	
     
   end loop;
   
  end process COMB_SLV_DATA_MUX;

  --
  -- SLAVE OR LOGIC
  --
  --! This process implements the ack, err, rty, and stall
  --! signals of the shared slave bus by ORing other slave
  --! signals.
  COMB_SLV_OR: process(wb_slave_out_i,
                       wb_slave_out_i(0), 
                       wb_slave_out_i(1), 
                       wb_slave_out_i(2), 
                       wb_slave_out_i(3),
                       wb_slave_out_i(4)) 

    variable ack_v   : std_ulogic;
    variable err_v   : std_ulogic;
    variable rty_v   : std_ulogic;
    variable stall_v : std_ulogic; 

  begin

    -- init
    ack_v   := '0';
    err_v   := '0';
    rty_v   := '0';
    stall_v := '0';

    for i in 0 to NB_OF_SLAVES - 1 loop

      ack_v   := ack_v   or wb_slave_out_i(i).ack_o;
      err_v   := err_v   or wb_slave_out_i(i).err_o;
      rty_v   := rty_v   or wb_slave_out_i(i).rty_o;
      stall_v := stall_v or wb_slave_out_i(i).stall_o;
    
    end loop;

    -- assign outputs
    slv_shared_bus_s.ack_o   <= ack_v;
    slv_shared_bus_s.err_o   <= err_v;
    slv_shared_bus_s.rty_o   <= rty_v;
    slv_shared_bus_s.stall_o <= stall_v;

  end process COMB_SLV_OR;
    
  --
  -- GENERATE SLAVE TO MASTERS 
  --
  
  MASTER_INTERCO_GEN: for i in 0 to NB_OF_MASTERS - 1 generate
  begin

    wb_master_in_o(i).clk_i   <= clk_i;        -- basic syscon
    wb_master_in_o(i).rst_i   <= not(rst_n_i); -- basic syscon

    wb_master_in_o(i).ack_i   <= (slv_shared_bus_s.ack_o   and arb_grant_reg_s(i)); 
    wb_master_in_o(i).err_i   <= (slv_shared_bus_s.err_o   and arb_grant_reg_s(i)); 
    wb_master_in_o(i).rty_i   <= (slv_shared_bus_s.rty_o   and arb_grant_reg_s(i)); 
    wb_master_in_o(i).stall_i <= (slv_shared_bus_s.stall_o and arb_grant_reg_s(i)); 
    wb_master_in_o(i).dat_i   <= slv_shared_bus_s.dat_o;

  end generate MASTER_INTERCO_GEN;

  -- //////////////////////////////////////////
  --               CYCLE PROCESS
  -- //////////////////////////////////////////

  --
  -- SLV DEC REGISTER
  --
  --! This process implements the slv dec register
  --! used to support the pipelined revision of the
  --! WISHBONE protocol. 
  CYCLE_SLV_DEC_REG: process(clk_i) 
  begin

    -- clock event
    if(clk_i'event and clk_i = '1') then
      
      -- sync reset
      if(rst_n_i = '0') then
        slv_dec_r <= (others => '0');
        
      elsif(mst_shared_bus_s.cyc_o = '1' and mst_shared_bus_s.stb_o = '1') then
        slv_dec_r <= slv_dec_s;
        
      end if;
      
    end if;

  end process CYCLE_SLV_DEC_REG;
  
end be_wb_top;

