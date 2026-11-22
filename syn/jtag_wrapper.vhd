-------------------------------------------------------------------------------
-- Title      : jtag_wrapper
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : jtag_wrapper.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Last update: 2026-11-22
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
-- Top of the lint and synthesis targets (lint_ghdl, lint_ghdl_synth_*,
-- syn_*) : jtag_tap, a user decoder (one opcode per TDR : 2 jtag_tdr_in,
-- 3 jtag_tdr_out, 4 jtag_tdr_inout), one TDR of each kind and a
-- jtag_pad_mux, with the generics of the target. The TDR_*_WIDTH generics
-- size the ports of the TDRs (unconstrained in the TDRs). The pad
-- multiplexer is independent of the TAP. IR_WIDTH >= 3.
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-11-22  1.0      mrosiere Created
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

library asylum;
use     asylum.jtag_pkg.all;

entity jtag_wrapper is
  generic (
    IR_WIDTH         : positive := 5                               -- Width of the instruction register (>= 3)
   ;TRST_ENABLE      : boolean  := true                            -- Use TRST*
   ;TDR_IN_WIDTH     : positive := 16                              -- Width of jtag_tdr_in
   ;TDR_OUT_WIDTH    : positive := 8                               -- Width of jtag_tdr_out
   ;TDR_INOUT_WIDTH  : positive := 8                               -- Width of jtag_tdr_inout
   ;NB_FUNC          : positive := 3                               -- Number of functions of jtag_pad_mux
   ;NB_PAD           : positive := 4                               -- Number of pads of jtag_pad_mux
  );
  port (
    -- Power-on reset (asynchronous, active low)
    arst_b_i         : in  std_logic
    -- JTAG pins
   ;jtag_ini_i       : in  jtag_ini_t
   ;jtag_tgt_o       : out jtag_tgt_t
    -- Test data registers (TCK domain)
   ;tdr_in_data_i    : in  std_logic_vector(TDR_IN_WIDTH   -1 downto 0)
   ;tdr_out_data_o   : out std_logic_vector(TDR_OUT_WIDTH  -1 downto 0)
   ;tdr_inout_data_i : in  std_logic_vector(TDR_INOUT_WIDTH-1 downto 0)
   ;tdr_inout_data_o : out std_logic_vector(TDR_INOUT_WIDTH-1 downto 0)
    -- Pad multiplexer
   ;sel_i            : in  natural range 0 to NB_FUNC-1
   ;func_out_i       : in  pad_array_t(0 to NB_FUNC-1)(NB_PAD-1 downto 0)
   ;func_oe_i        : in  pad_array_t(0 to NB_FUNC-1)(NB_PAD-1 downto 0)
   ;func_in_o        : out pad_array_t(0 to NB_FUNC-1)(NB_PAD-1 downto 0)
   ;pad_out_o        : out std_logic_vector(NB_PAD-1 downto 0)
   ;pad_oe_o         : out std_logic_vector(NB_PAD-1 downto 0)
   ;pad_in_i         : in  std_logic_vector(NB_PAD-1 downto 0)
  );
end entity jtag_wrapper;

architecture rtl of jtag_wrapper is

  -- Opcodes of the user decoder
  constant IR_TDR_IN    : std_logic_vector(IR_WIDTH-1 downto 0) := std_logic_vector(to_unsigned(2, IR_WIDTH));
  constant IR_TDR_OUT   : std_logic_vector(IR_WIDTH-1 downto 0) := std_logic_vector(to_unsigned(3, IR_WIDTH));
  constant IR_TDR_INOUT : std_logic_vector(IR_WIDTH-1 downto 0) := std_logic_vector(to_unsigned(4, IR_WIDTH));

  -- Pad inputs seen by the unselected functions : all ones
  constant PAD_IN_ONES  : std_logic_vector(NB_PAD-1 downto 0) := std_logic_vector(to_signed(-1, NB_PAD));

  signal   tck          : std_logic;
  signal   trst_b       : std_logic;
  signal   tlr          : std_logic;
  signal   ir           : std_logic_vector(IR_WIDTH-1 downto 0);
  signal   capture_dr   : std_logic;
  signal   shift_dr     : std_logic;
  signal   update_dr    : std_logic;
  signal   tdi          : std_logic;

  signal   sel_in       : std_logic;
  signal   sel_out      : std_logic;
  signal   sel_inout    : std_logic;
  signal   user_tdo_en  : std_logic;
  signal   user_tdo     : std_logic;
  signal   tdo_in       : std_logic;
  signal   tdo_out      : std_logic;
  signal   tdo_inout    : std_logic;

begin  -- architecture rtl

  -----------------------------------------------------------------------------
  -- TAP
  -----------------------------------------------------------------------------
  ins_tap : jtag_tap
    generic map
    (IR_WIDTH        => IR_WIDTH
    ,TRST_ENABLE     => TRST_ENABLE
    )
    port map
    (arst_b_i        => arst_b_i
    ,jtag_ini_i      => jtag_ini_i
    ,jtag_tgt_o      => jtag_tgt_o
    ,tck_o           => tck
    ,trst_b_o        => trst_b
    ,tlr_o           => tlr
    ,ir_o            => ir
    ,capture_dr_o    => capture_dr
    ,shift_dr_o      => shift_dr
    ,update_dr_o     => update_dr
    ,tdi_o           => tdi
    ,user_tdo_en_i   => user_tdo_en
    ,user_tdo_i      => user_tdo
    );

  -----------------------------------------------------------------------------
  -- User decoder
  -----------------------------------------------------------------------------
  sel_in      <= '1' when ir = IR_TDR_IN    else '0';
  sel_out     <= '1' when ir = IR_TDR_OUT   else '0';
  sel_inout   <= '1' when ir = IR_TDR_INOUT else '0';

  user_tdo_en <= sel_in or sel_out or sel_inout;
  user_tdo    <= tdo_in  when sel_in  = '1' else
                 tdo_out when sel_out = '1' else
                 tdo_inout;

  -----------------------------------------------------------------------------
  -- Test data registers
  -----------------------------------------------------------------------------
  ins_tdr_in : jtag_tdr_in
    port map
    (tck_i           => tck
    ,trst_b_i        => trst_b
    ,sel_i           => sel_in
    ,capture_dr_i    => capture_dr
    ,shift_dr_i      => shift_dr
    ,update_dr_i     => update_dr
    ,tdi_i           => tdi
    ,tdo_o           => tdo_in
    ,data_i          => tdr_in_data_i
    );

  ins_tdr_out : jtag_tdr_out
    port map
    (tck_i           => tck
    ,trst_b_i        => trst_b
    ,tlr_i           => tlr
    ,sel_i           => sel_out
    ,capture_dr_i    => capture_dr
    ,shift_dr_i      => shift_dr
    ,update_dr_i     => update_dr
    ,tdi_i           => tdi
    ,tdo_o           => tdo_out
    ,data_o          => tdr_out_data_o
    );

  ins_tdr_inout : jtag_tdr_inout
    port map
    (tck_i           => tck
    ,trst_b_i        => trst_b
    ,tlr_i           => tlr
    ,sel_i           => sel_inout
    ,capture_dr_i    => capture_dr
    ,shift_dr_i      => shift_dr
    ,update_dr_i     => update_dr
    ,tdi_i           => tdi
    ,tdo_o           => tdo_inout
    ,data_i          => tdr_inout_data_i
    ,data_o          => tdr_inout_data_o
    );

  -----------------------------------------------------------------------------
  -- Pad multiplexer
  -----------------------------------------------------------------------------
  ins_pad_mux : jtag_pad_mux
    generic map
    (NB_FUNC         => NB_FUNC
    ,NB_PAD          => NB_PAD
    ,PAD_IN_DEFAULT  => PAD_IN_ONES
    )
    port map
    (sel_i           => sel_i
    ,func_out_i      => func_out_i
    ,func_oe_i       => func_oe_i
    ,func_in_o       => func_in_o
    ,pad_out_o       => pad_out_o
    ,pad_oe_o        => pad_oe_o
    ,pad_in_i        => pad_in_i
    );

end architecture rtl;
