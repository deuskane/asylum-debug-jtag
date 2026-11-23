-------------------------------------------------------------------------------
-- Title      : tb_bitbang_bfm_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_bitbang_bfm_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Last update: 2026-11-22
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Constants, types and helpers shared by the scenarios of tb_bitbang :
--  configuration of the TAP and of the TDR of the testbench, records between
--  the scenarios and the testbench (tb_req_t : stimuli, tb_rsp_t : outputs
--  of the DUT and answers collected by the monitor), and the bytes OpenOCD
--  sends (remote_bitbang driver over the bitbang driver of OpenOCD 0.12) :
--  one command (tb_send : on s_axis, or through the UART with the UVVM UART
--  BFM), TMS sequence (tb_tms), IR / DR scan (tb_scan), TDO read (tb_read).
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

library uvvm_util;
context uvvm_util.uvvm_util_context;

library bitvis_vip_uart;
use     bitvis_vip_uart.uart_bfm_pkg.all;

package tb_bitbang_bfm_pkg is

  constant C_TB_SCOPE     : string   := "TB_BITBANG";    -- Scope of the scenarios (C_SCOPE of uvvm_util is hidden by the C_SCOPE of the testbench)

  constant C_CLK_PERIOD   : time     := 10 ns;
  constant C_TIMEOUT      : time     := 1 ms;            -- Wait of s_axis_tready and of the answers to 'R'

  -- TAP of the testbench : IR of 5 bits, IDCODE ("00001"), BYPASS (all
  -- ones), one jtag_tdr_inout of 8 bits selected by C_IR_TDR
  constant C_IDCODE       : std_logic_vector(32-1 downto 0) := x"4A7C0E35";
  constant C_IR_WIDTH     : positive := 5;
  constant C_IR_IDCODE    : natural  := 1;
  constant C_IR_TDR       : natural  := 2;
  constant C_IR_BYPASS    : natural  := 2**C_IR_WIDTH-1;
  constant C_TDR_WIDTH    : positive := 8;

  -- Answers kept by the monitor (from the reset of the scenario)
  constant C_MAX_ANSWERS  : natural  := 256;

  -- UART of the scenario uart : 8 data bits, no parity, one stop bit, 16
  -- clock cycles per bit (cfg_baud_tick_cnt_max_i of uart_baud_rate_gen)
  constant C_UART_CNT_MAX : natural  := 15;
  constant C_UART_BIT     : time     := (C_UART_CNT_MAX+1)*C_CLK_PERIOD;
  constant C_UART_CONFIG  : t_uart_bfm_config;

  -- Stimuli of the scenarios
  type tb_req_t is record
    s_tdata         : std_logic_vector(8-1 downto 0);               -- Command to the DUT
    s_tvalid        : std_logic;
    m_tready        : std_logic;                                    -- Answers taken from the DUT
    tdr_data        : std_logic_vector(C_TDR_WIDTH-1 downto 0);     -- data_i of the TDR
    uart            : boolean;                                      -- true : commands and answers through the UART
    uart_rx         : std_logic;                                    -- Serial input of the UART (UART BFM)
  end record tb_req_t;

  constant C_TB_REQ_IDLE  : tb_req_t := (s_tdata  => x"00",
                                         s_tvalid => '0',
                                         m_tready => '1',
                                         tdr_data => (others => '0'),
                                         uart     => false,
                                         uart_rx  => '1');

  -- Outputs of the DUT, of the TAP and of the monitor
  type tb_rsp_t is record
    s_tready        : std_logic;
    m_tdata         : std_logic_vector(8-1 downto 0);
    m_tvalid        : std_logic;
    pins            : std_logic_vector(3-1 downto 0);               -- TCK, TMS, TDI
    trst_n          : std_logic;
    srst            : std_logic;
    blink           : std_logic;
    tlr             : std_logic;                                    -- tlr_o of the TAP
    ir              : std_logic_vector(C_IR_WIDTH-1 downto 0);      -- ir_o of the TAP
    tdr_data        : std_logic_vector(C_TDR_WIDTH-1 downto 0);     -- data_o of the TDR
    answer_cnt      : natural;                                      -- Answers taken since the reset
    answers         : std_logic_vector(0 to C_MAX_ANSWERS-1);       -- Their bits ('0' : 0, '1' : 1)
  end record tb_rsp_t;

  -- Byte of a command
  function to_byte(cmd : character) return std_logic_vector;

  -- One command : byte on s_axis, returns after the handshake (the outputs
  -- of the DUT change one delta cycle later) ; with tb_req.uart, UART frame,
  -- returns after the stop bit
  procedure tb_send(
    constant cmd          : in    character;
    signal   tb_req       : inout tb_req_t;
    signal   tb_rsp       : in    tb_rsp_t;
    signal   clk          : in    std_logic
    );

  -- '0'..'7' : write TCK, TMS, TDI
  procedure tb_write(
    constant tck          : in    std_logic;
    constant tms          : in    std_logic;
    constant tdi          : in    std_logic;
    signal   tb_req       : inout tb_req_t;
    signal   tb_rsp       : in    tb_rsp_t;
    signal   clk          : in    std_logic
    );

  -- Wait until num answers were taken since the reset
  procedure tb_wait_answers(
    constant num          : in    natural;
    constant msg          : in    string;
    signal   tb_rsp       : in    tb_rsp_t
    );

  -- 'R', then wait for its answer
  procedure tb_read(
    variable tdo          : out   std_logic;
    signal   tb_req       : inout tb_req_t;
    signal   tb_rsp       : in    tb_rsp_t;
    signal   clk          : in    std_logic
    );

  -- TCK cycles with the TMS sequence (left first), then TCK low, as
  -- bitbang_state_move of OpenOCD
  procedure tb_tms(
    constant tms          : in    std_logic_vector;
    signal   tb_req       : inout tb_req_t;
    signal   tb_rsp       : in    tb_rsp_t;
    signal   clk          : in    std_logic
    );

  -- IR scan (ir) or DR scan from Run-Test/Idle back to Run-Test/Idle, as
  -- bitbang_scan of OpenOCD : for each bit (LSB first) TCK low with TMS and
  -- TDI, 'R', TCK high ; data_out : the answers (TDO, LSB first)
  procedure tb_scan(
    constant ir           : in    boolean;
    constant data         : in    std_logic_vector;
    variable data_out     : out   std_logic_vector;
    signal   tb_req       : inout tb_req_t;
    signal   tb_rsp       : in    tb_rsp_t;
    signal   clk          : in    std_logic
    );

  -- IR scan of opcode, then check of ir_o
  procedure tb_write_ir(
    constant opcode       : in    natural;
    constant msg          : in    string;
    signal   tb_req       : inout tb_req_t;
    signal   tb_rsp       : in    tb_rsp_t;
    signal   clk          : in    std_logic
    );

  -- DR scan of data, then check of the bits shifted out
  procedure tb_check_dr(
    constant data         : in    std_logic_vector;
    constant data_exp     : in    std_logic_vector;
    constant msg          : in    string;
    signal   tb_req       : inout tb_req_t;
    signal   tb_rsp       : in    tb_rsp_t;
    signal   clk          : in    std_logic
    );

end package tb_bitbang_bfm_pkg;

package body tb_bitbang_bfm_pkg is

  function uart_config return t_uart_bfm_config is
    variable v_config : t_uart_bfm_config := C_UART_BFM_CONFIG_DEFAULT;
  begin
    v_config.bit_time := C_UART_BIT;
    v_config.parity   := PARITY_NONE;
    return v_config;
  end function uart_config;

  constant C_UART_CONFIG  : t_uart_bfm_config := uart_config;

  function to_byte(cmd : character) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(character'pos(cmd), 8));
  end function to_byte;

  procedure tb_send(
    constant cmd          : in    character;
    signal   tb_req       : inout tb_req_t;
    signal   tb_rsp       : in    tb_rsp_t;
    signal   clk          : in    std_logic
    ) is
  begin
    if tb_req.uart
    then
      uart_transmit(data_value => to_byte(cmd),
                    msg        => "Command '" & cmd & "'",
                    tx         => tb_req.uart_rx,
                    config     => C_UART_CONFIG,
                    scope      => C_TB_SCOPE);
    else
      tb_req.s_tdata  <= to_byte(cmd);
      tb_req.s_tvalid <= '1';
      wait until rising_edge(clk) and tb_rsp.s_tready = '1' for C_TIMEOUT;
      if not (rising_edge(clk) and tb_rsp.s_tready = '1')
      then
        alert(ERROR, "Command '" & cmd & "' not taken (s_axis_tready low)", C_TB_SCOPE);
      end if;
      tb_req.s_tvalid <= '0';
    end if;
  end procedure tb_send;

  procedure tb_write(
    constant tck          : in    std_logic;
    constant tms          : in    std_logic;
    constant tdi          : in    std_logic;
    signal   tb_req       : inout tb_req_t;
    signal   tb_rsp       : in    tb_rsp_t;
    signal   clk          : in    std_logic
    ) is
    constant C_CMD        : natural := character'pos('0') + to_integer(unsigned'(tck & tms & tdi));
  begin
    tb_send(character'val(C_CMD), tb_req, tb_rsp, clk);
  end procedure tb_write;

  procedure tb_wait_answers(
    constant num          : in    natural;
    constant msg          : in    string;
    signal   tb_rsp       : in    tb_rsp_t
    ) is
  begin
    if tb_rsp.answer_cnt < num
    then
      wait until tb_rsp.answer_cnt >= num for C_TIMEOUT;
    end if;
    if tb_rsp.answer_cnt /= num
    then
      alert(ERROR, "Answers to 'R' : " & integer'image(tb_rsp.answer_cnt) & " instead of " & integer'image(num) & ". " & msg, C_TB_SCOPE);
    end if;
  end procedure tb_wait_answers;

  procedure tb_read(
    variable tdo          : out   std_logic;
    signal   tb_req       : inout tb_req_t;
    signal   tb_rsp       : in    tb_rsp_t;
    signal   clk          : in    std_logic
    ) is
    constant C_FIRST      : natural := tb_rsp.answer_cnt;
  begin
    tb_send('R', tb_req, tb_rsp, clk);
    tb_wait_answers(C_FIRST+1, "'R'", tb_rsp);
    tdo := tb_rsp.answers(C_FIRST);
  end procedure tb_read;

  procedure tb_tms(
    constant tms          : in    std_logic_vector;
    signal   tb_req       : inout tb_req_t;
    signal   tb_rsp       : in    tb_rsp_t;
    signal   clk          : in    std_logic
    ) is
  begin
    for i in tms'range loop
      tb_write('0', tms(i), '0', tb_req, tb_rsp, clk);
      tb_write('1', tms(i), '0', tb_req, tb_rsp, clk);
    end loop;
    tb_write('0', tms(tms'right), '0', tb_req, tb_rsp, clk);
  end procedure tb_tms;

  procedure tb_scan(
    constant ir           : in    boolean;
    constant data         : in    std_logic_vector;
    variable data_out     : out   std_logic_vector;
    signal   tb_req       : inout tb_req_t;
    signal   tb_rsp       : in    tb_rsp_t;
    signal   clk          : in    std_logic
    ) is
    alias    v_data       : std_logic_vector(data'length-1 downto 0) is data;
    variable v_out        : std_logic_vector(data'length-1 downto 0);
    variable v_tms        : std_logic;
    constant C_FIRST      : natural := tb_rsp.answer_cnt;
  begin
    -- Run-Test/Idle -> Select-DR -> (Select-IR) -> Capture -> Shift
    if ir
    then
      tb_tms("1100", tb_req, tb_rsp, clk);
    else
      tb_tms("100" , tb_req, tb_rsp, clk);
    end if;

    -- Shift, the last bit with TMS = 1 (Exit1)
    for i in 0 to data'length-1 loop
      v_tms := '1' when i = data'length-1 else '0';
      tb_write('0', v_tms, v_data(i), tb_req, tb_rsp, clk);
      tb_send ('R', tb_req, tb_rsp, clk);
      tb_write('1', v_tms, v_data(i), tb_req, tb_rsp, clk);
    end loop;

    -- Exit1 -> Update -> Run-Test/Idle
    tb_tms("10", tb_req, tb_rsp, clk);

    tb_wait_answers(C_FIRST+data'length, "Scan of " & integer'image(data'length) & " bits", tb_rsp);
    for i in 0 to data'length-1 loop
      v_out(i) := tb_rsp.answers(C_FIRST+i);
    end loop;
    data_out := v_out;
  end procedure tb_scan;

  procedure tb_write_ir(
    constant opcode       : in    natural;
    constant msg          : in    string;
    signal   tb_req       : inout tb_req_t;
    signal   tb_rsp       : in    tb_rsp_t;
    signal   clk          : in    std_logic
    ) is
    constant C_OPCODE     : std_logic_vector(C_IR_WIDTH-1 downto 0) := std_logic_vector(to_unsigned(opcode, C_IR_WIDTH));
    variable v_out        : std_logic_vector(C_IR_WIDTH-1 downto 0);
  begin
    tb_scan(true, C_OPCODE, v_out, tb_req, tb_rsp, clk);
    check_value(v_out, std_logic_vector(to_unsigned(1, C_IR_WIDTH)), ERROR, "Capture-IR read by 'R' (IR scan " & msg & ")", C_TB_SCOPE);
    check_value(tb_rsp.ir, C_OPCODE, ERROR, "ir_o after the IR scan " & msg, C_TB_SCOPE);
  end procedure tb_write_ir;

  procedure tb_check_dr(
    constant data         : in    std_logic_vector;
    constant data_exp     : in    std_logic_vector;
    constant msg          : in    string;
    signal   tb_req       : inout tb_req_t;
    signal   tb_rsp       : in    tb_rsp_t;
    signal   clk          : in    std_logic
    ) is
    variable v_out        : std_logic_vector(data'length-1 downto 0);
  begin
    tb_scan(false, data, v_out, tb_req, tb_rsp, clk);
    check_value(v_out, data_exp, ERROR, "DR scan read by 'R' : " & msg, C_TB_SCOPE);
  end procedure tb_check_dr;

end package body tb_bitbang_bfm_pkg;
