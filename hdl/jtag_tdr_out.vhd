-------------------------------------------------------------------------------
-- Title      : jtag_tdr_out
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : jtag_tdr_out.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Last update: 2026-11-22
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
-- JTAG test data register, parallel output only (IEEE 1149.1, TCK domain) :
-- Shift-DR shifts TDI in (LSB first) and the previous content out on TDO,
-- Update-DR copies the shift register to data_o, held otherwise. Capture-DR
-- has no effect : a scan returns the bits shifted in by the previous scan.
-- Only when selected (sel_i = 1, decoded from ir_o of jtag_tap). Shift on
-- the rising edge, update on the falling edge of TCK. The width is the width
-- of data_o (unconstrained). trst_b_i clears both registers, Test-Logic-Reset
-- clears data_o.
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-11-22  1.0      mrosiere Created
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;

entity jtag_tdr_out is
  port (
    -- TAP (TCK domain, outputs of jtag_tap)
    tck_i          : in  std_logic
   ;trst_b_i       : in  std_logic                                -- Power-on reset and TRST*, active low
   ;tlr_i          : in  std_logic                                -- Test-Logic-Reset
   ;sel_i          : in  std_logic                                -- 1 : register selected by the instruction
   ;capture_dr_i   : in  std_logic                                -- Capture-DR (not used, same ports as the other TDRs)
   ;shift_dr_i     : in  std_logic                                -- Shift-DR
   ;update_dr_i    : in  std_logic                                -- Update-DR
   ;tdi_i          : in  std_logic
   ;tdo_o          : out std_logic                                -- LSB of the shift register, to user_tdo_i
    -- Parallel interface (TCK domain)
   ;data_o         : out std_logic_vector                         -- Updated in Update-DR (any width and range)
  );
end entity jtag_tdr_out;

architecture rtl of jtag_tdr_out is

  constant WIDTH    : positive := data_o'length;

  signal   shift_r  : std_logic_vector(WIDTH-1 downto 0);
  signal   data_r   : std_logic_vector(WIDTH-1 downto 0);

begin  -- architecture rtl

  -----------------------------------------------------------------------------
  -- Shift register : shift on the rising edge of TCK, when
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
        if shift_dr_i = '1'
        then
          shift_r <= tdi_i & shift_r(WIDTH-1 downto 1);
        end if;
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Update register : copy of the shift register on the falling edge of TCK
  -- in Update-DR, when selected ; cleared in Test-Logic-Reset
  -----------------------------------------------------------------------------
  process(tck_i, trst_b_i)
  begin
    if trst_b_i = '0'
    then
      data_r  <= (others => '0');
    elsif falling_edge(tck_i)
    then
      if tlr_i = '1'
      then
        data_r  <= (others => '0');
      elsif sel_i = '1' and update_dr_i = '1'
      then
        data_r  <= shift_r;
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Outputs
  -----------------------------------------------------------------------------
  tdo_o   <= shift_r(0);
  data_o  <= data_r;

end architecture rtl;
