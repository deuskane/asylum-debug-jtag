-------------------------------------------------------------------------------
-- Title      : jtag_pad_mux
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : jtag_pad_mux.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Last update: 2026-11-22
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
-- Pad multiplexer : NB_FUNC functions share a group of NB_PAD pads (e.g. a
-- UART, a debug UART and a JTAG chain on the pads of a UART). sel_i selects
-- the function that drives the pads (outputs and output enables) and sees
-- the pad inputs ; the other functions see PAD_IN_DEFAULT on their inputs.
-- Combinational, no clock.
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-11-22  1.0      mrosiere Created
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;

library asylum;
use     asylum.jtag_pkg.all;

entity jtag_pad_mux is
  generic (
    NB_FUNC          : positive := 3                               -- Number of functions
   ;NB_PAD           : positive := 4                               -- Number of pads
   ;PAD_IN_DEFAULT   : std_logic_vector(NB_PAD-1 downto 0)         -- Pad inputs seen by the unselected functions
  );
  port (
    sel_i            : in  natural range 0 to NB_FUNC-1            -- Selected function
    -- Functions : one element per function, one bit per pad
   ;func_out_i       : in  pad_array_t(0 to NB_FUNC-1)(NB_PAD-1 downto 0) -- Pad outputs
   ;func_oe_i        : in  pad_array_t(0 to NB_FUNC-1)(NB_PAD-1 downto 0) -- Pad output enables
   ;func_in_o        : out pad_array_t(0 to NB_FUNC-1)(NB_PAD-1 downto 0) -- Pad inputs
    -- Pads
   ;pad_out_o        : out std_logic_vector(NB_PAD-1 downto 0)
   ;pad_oe_o         : out std_logic_vector(NB_PAD-1 downto 0)
   ;pad_in_i         : in  std_logic_vector(NB_PAD-1 downto 0)
  );
end entity jtag_pad_mux;

architecture rtl of jtag_pad_mux is

begin  -- architecture rtl

  -----------------------------------------------------------------------------
  -- Pads driven by the selected function
  -----------------------------------------------------------------------------
  pad_out_o <= func_out_i(sel_i);
  pad_oe_o  <= func_oe_i (sel_i);

  -----------------------------------------------------------------------------
  -- Pad inputs : to the selected function, PAD_IN_DEFAULT to the others
  -----------------------------------------------------------------------------
  gen_func : for f in 0 to NB_FUNC-1
  generate
    func_in_o(f) <= pad_in_i when sel_i = f else
                    PAD_IN_DEFAULT;
  end generate gen_func;

end architecture rtl;
