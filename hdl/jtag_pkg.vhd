-------------------------------------------------------------------------------
-- Title      : jtag_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : jtag_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Last update: 2026-11-22
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description: Types and components of the JTAG IP : JTAG pins (jtag_ini_t,
--              jtag_tgt_t), TAP, test data registers, pad multiplexer,
--              remote_bitbang JTAG master, AXI-Stream to JTAG bridge
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-11-22  1.0      mrosiere Created (JTAG pins from WardRV_pkg)
-- 2026-11-22  1.1      mrosiere jtag_bitbang
-- 2026-11-26  1.2      mrosiere jtag_axis (constants, component)
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;

package jtag_pkg is

  -- JTAG pins, debugger to target
  type jtag_ini_t is record
    tck          : std_logic;
    trst_n       : std_logic;                                      -- TRST*, active low (optional)
    tms          : std_logic;
    tdi          : std_logic;
  end record jtag_ini_t;

  -- JTAG pins, target to debugger : TDO and its output enable (tri-state at
  -- the pad)
  type jtag_tgt_t is record
    tdo          : std_logic;
    tdo_en       : std_logic;
  end record jtag_tgt_t;

  -- Pads of the functions of jtag_pad_mux : one element per function, one
  -- bit per pad
  type pad_array_t is array (natural range <>) of std_logic_vector;

  -- jtag_axis : width of the instruction register, opcodes of the user
  -- instructions (IDCODE "00001", every other opcode BYPASS), width of the
  -- CONFIG register
  constant JTAG_AXIS_IR_WIDTH     : positive := 5;
  constant JTAG_AXIS_IR_CONFIG    : std_logic_vector(JTAG_AXIS_IR_WIDTH-1 downto 0) := "00010";
  constant JTAG_AXIS_IR_TX        : std_logic_vector(JTAG_AXIS_IR_WIDTH-1 downto 0) := "00011";
  constant JTAG_AXIS_IR_RX        : std_logic_vector(JTAG_AXIS_IR_WIDTH-1 downto 0) := "00100";
  constant JTAG_AXIS_CONFIG_WIDTH : positive := 48;

-- [COMPONENT_INSERT][BEGIN]
component jtag_axis is
  generic (
    DATA_WIDTH       : positive                        := 8           -- Width of the words (1 to 255)
   ;TX_ENABLE        : boolean                         := true        -- Direction system -> JTAG
   ;RX_ENABLE        : boolean                         := true        -- Direction JTAG -> system
   ;DEPTH_TX         : positive                        := 4           -- Words of the TX FIFO (power of 2)
   ;DEPTH_RX         : positive                        := 4           -- Words of the RX FIFO (power of 2)
   ;IDCODE           : std_logic_vector(32-1 downto 0) := x"10004001"
  );
  port (
    -- Clock and reset (asynchronous, active low : TAP and FIFOs)
    clk_i            : in  std_logic
   ;arst_b_i         : in  std_logic
    -- JTAG pins (TRST* used : tie trst_n to 1 without TRST* pin)
   ;jtag_ini_i       : in  jtag_ini_t
   ;jtag_tgt_o       : out jtag_tgt_t
    -- TX : words of the system to the debugger
   ;s_axis_tdata_i   : in  std_logic_vector(DATA_WIDTH-1 downto 0)
   ;s_axis_tvalid_i  : in  std_logic
   ;s_axis_tready_o  : out std_logic
    -- RX : words of the debugger to the system
   ;m_axis_tdata_o   : out std_logic_vector(DATA_WIDTH-1 downto 0)
   ;m_axis_tvalid_o  : out std_logic
   ;m_axis_tready_i  : in  std_logic
  );
end component jtag_axis;

component jtag_bitbang is
  port (
    -- Clock and Reset
    clk_i            : in  std_logic
   ;arst_b_i         : in  std_logic
    -- Commands of OpenOCD (bytes of the remote_bitbang protocol)
   ;s_axis_tdata_i   : in  std_logic_vector(8-1 downto 0)
   ;s_axis_tvalid_i  : in  std_logic
   ;s_axis_tready_o  : out std_logic
    -- Answers to 'R' ('0' or '1')
   ;m_axis_tdata_o   : out std_logic_vector(8-1 downto 0)
   ;m_axis_tvalid_o  : out std_logic
   ;m_axis_tready_i  : in  std_logic
    -- JTAG pins (TCK is a register of the clk domain)
   ;jtag_ini_o       : out jtag_ini_t
   ;jtag_tgt_i       : in  jtag_tgt_t
    -- System reset request (SRST, active high) and LED
   ;srst_o           : out std_logic
   ;blink_o          : out std_logic
  );
end component jtag_bitbang;

component jtag_pad_mux is
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
end component jtag_pad_mux;

component jtag_tap is
  generic (
    IR_WIDTH       : positive                        := 5         -- Width of the instruction register (>= 2)
   ;IDCODE_VALUE   : std_logic_vector(32-1 downto 0) := x"10000001"
   ;TRST_ENABLE    : boolean                         := true      -- Use TRST*
  );
  port (
    -- Power-on reset (asynchronous, active low)
    arst_b_i       : in  std_logic
    -- JTAG pins
   ;jtag_ini_i     : in  jtag_ini_t
   ;jtag_tgt_o     : out jtag_tgt_t
    -- User data registers (TCK domain)
   ;tck_o          : out std_logic
   ;trst_b_o       : out std_logic                                -- Power-on reset and TRST*
   ;tlr_o          : out std_logic                                -- Test-Logic-Reset
   ;ir_o           : out std_logic_vector(IR_WIDTH-1 downto 0)    -- Instruction, to the user decoder
   ;capture_dr_o   : out std_logic                                -- Capture-DR
   ;shift_dr_o     : out std_logic                                -- Shift-DR
   ;update_dr_o    : out std_logic                                -- Update-DR
   ;tdi_o          : out std_logic
   ;user_tdo_en_i  : in  std_logic                                -- 1 : ir_o is a user instruction
   ;user_tdo_i     : in  std_logic                                -- LSB of the selected user register
  );
end component jtag_tap;

component jtag_tdr_in is
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
end component jtag_tdr_in;

component jtag_tdr_inout is
  port (
    -- TAP (TCK domain, outputs of jtag_tap)
    tck_i          : in  std_logic
   ;trst_b_i       : in  std_logic                                -- Power-on reset and TRST*, active low
   ;tlr_i          : in  std_logic                                -- Test-Logic-Reset
   ;sel_i          : in  std_logic                                -- 1 : register selected by the instruction
   ;capture_dr_i   : in  std_logic                                -- Capture-DR
   ;shift_dr_i     : in  std_logic                                -- Shift-DR
   ;update_dr_i    : in  std_logic                                -- Update-DR
   ;tdi_i          : in  std_logic
   ;tdo_o          : out std_logic                                -- LSB of the shift register, to user_tdo_i
    -- Parallel interface (TCK domain)
   ;data_i         : in  std_logic_vector                         -- Captured in Capture-DR (any width and range)
   ;data_o         : out std_logic_vector                         -- Updated in Update-DR (width of data_i)
  );
end component jtag_tdr_inout;

component jtag_tdr_out is
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
end component jtag_tdr_out;

-- [COMPONENT_INSERT][END]

end package jtag_pkg;
