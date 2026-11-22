-------------------------------------------------------------------------------
-- Title      : jtag_tdr_in
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : jtag_tdr_in.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Last update: 2026-11-22
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
-- JTAG test data register, parallel input only (IEEE 1149.1, TCK domain) :
-- Capture-DR loads data_i in the shift register, Shift-DR shifts it out on
-- TDO (LSB first) while TDI is shifted in, Update-DR has no effect. Only
-- when selected (sel_i = 1, decoded from ir_o of jtag_tap). Capture and
-- shift on the rising edge of TCK. The width is the width of data_i
-- (unconstrained). The shift register is cleared by trst_b_i.
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-11-22  1.0      mrosiere Created
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;

entity jtag_tdr_in is
  port (
    -- TAP (TCK domain, outputs of jtag_tap)
    tck_i          : in  std_logic
   ;trst_b_i       : in  std_logic                                -- Power-on reset and TRST*, active low
   ;sel_i          : in  std_logic                                -- 1 : register selected by the instruction
   ;capture_dr_i   : in  std_logic                                -- Capture-DR
   ;shift_dr_i     : in  std_logic                                -- Shift-DR
   ;update_dr_i    : in  std_logic                                -- Update-DR (not used, same ports as the other TDRs)
   ;tdi_i          : in  std_logic
   ;tdo_o          : out std_logic                                -- LSB of the shift register, to user_tdo_i
    -- Parallel interface (TCK domain)
   ;data_i         : in  std_logic_vector                         -- Captured in Capture-DR (any width and range)
  );
end entity jtag_tdr_in;

architecture rtl of jtag_tdr_in is

  constant WIDTH    : positive := data_i'length;

  signal   shift_r  : std_logic_vector(WIDTH-1 downto 0);

begin  -- architecture rtl

  -----------------------------------------------------------------------------
  -- Shift register : capture and shift on the rising edge of TCK, when
  -- selected
  -----------------------------------------------------------------------------
  process(tck_i, trst_b_i)
  begin
    if trst_b_i = '0'
    then
      shift_r <= (others => '0');
    elsif rising_edge(tck_i)
    then
      if sel_i = '1'
      then
        if capture_dr_i = '1'
        then
          shift_r <= data_i;
        elsif shift_dr_i = '1'
        then
          shift_r <= tdi_i & shift_r(WIDTH-1 downto 1);
        end if;
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Outputs
  -----------------------------------------------------------------------------
  tdo_o   <= shift_r(0);

end architecture rtl;
