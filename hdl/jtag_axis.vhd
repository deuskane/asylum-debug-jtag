-------------------------------------------------------------------------------
-- Title      : jtag_axis
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : jtag_axis.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-26
-- Last update: 2026-11-26
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
-- AXI-Stream to JTAG bridge : a TAP of its own (jtag_tap, IR of
-- JTAG_AXIS_IR_WIDTH bits, IDCODE generic) and two dual-clock FIFOs
-- (fifo_async of asylum-component-fifo) between the TCK domain of the TAP
-- and clk_i. Names from the side of the system :
--  * TX (TX_ENABLE) : system -> JTAG. The system writes s_axis (clk_i), the
--    debugger reads the words with the instruction TX.
--  * RX (RX_ENABLE) : JTAG -> system. The debugger writes the words with
--    the instruction RX, the system reads m_axis (clk_i).
-- Instructions (jtag_pkg) :
--  * JTAG_AXIS_IR_CONFIG : 48-bit read only register, sizes and flags
--    (TX_ENABLE, TX empty, TX full, RX_ENABLE, RX empty, RX full,
--    DATA_WIDTH, DEPTH_TX, DEPTH_RX)
--  * JTAG_AXIS_IR_TX : DATA_WIDTH+1 bits. Capture-DR loads {word, valid}
--    (bit 0 : valid, the TX FIFO had a word) ; Update-DR removes the
--    captured word from the TX FIFO when it was valid.
--  * JTAG_AXIS_IR_RX : DATA_WIDTH+1 bits. Capture-DR loads bit 0 = accepted
--    (the RX FIFO has a free place) ; the bits DATA_WIDTH downto 1 shifted in
--    are written to the RX FIFO in Update-DR when accepted.
--  * IDCODE, BYPASS (any other opcode, the instruction of a disabled
--    direction included) : jtag_tap.
-- Clock domains : the TAP, the TDRs and one side of each FIFO run on TCK,
-- the AXI-Stream sides of the FIFOs on clk_i. The only crossings are the
-- Gray pointers of the two FIFOs (2 flip-flop synchronizers) : any TCK,
-- unrelated to clk_i (TCK pin or a TCK resynchronized on clk_i). The
-- flags of a scan come from the TCK side of the FIFOs : a word written on
-- s_axis is seen by the debugger after a few TCK edges, a free place of
-- the RX FIFO too.
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-11-26  1.0      mrosiere Created
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

library asylum;
use     asylum.jtag_pkg.all;
use     asylum.fifo_pkg.all;

entity jtag_axis is
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
end entity jtag_axis;

architecture rtl of jtag_axis is

  constant ZERO         : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
  constant TX_EN        : std_logic_vector(0 downto 0) := std_logic_vector(to_unsigned(boolean'pos(TX_ENABLE), 1));
  constant RX_EN        : std_logic_vector(0 downto 0) := std_logic_vector(to_unsigned(boolean'pos(RX_ENABLE), 1));

  -- TAP (TCK domain)
  signal   tck          : std_logic;
  signal   trst_b       : std_logic;
  signal   tlr          : std_logic;
  signal   ir           : std_logic_vector(JTAG_AXIS_IR_WIDTH-1 downto 0);
  signal   capture_dr   : std_logic;
  signal   shift_dr     : std_logic;
  signal   update_dr    : std_logic;
  signal   tdi          : std_logic;
  signal   user_tdo_en  : std_logic;
  signal   user_tdo     : std_logic;

  -- Instruction decoder
  signal   sel_config   : std_logic;
  signal   sel_tx       : std_logic;
  signal   sel_rx       : std_logic;

  -- CONFIG
  signal   config       : std_logic_vector(JTAG_AXIS_CONFIG_WIDTH-1 downto 0);
  signal   config_tdo   : std_logic;

  -- TX : TCK side of the TX FIFO
  signal   tx_tdata     : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal   tx_tvalid    : std_logic;
  signal   tx_tready    : std_logic;
  signal   tx_empty     : std_logic;
  signal   tx_full      : std_logic;
  signal   tx_valid_r   : std_logic;                                -- Valid word captured by the scan
  signal   tx_tdo       : std_logic;

  -- RX : TCK side of the RX FIFO
  signal   rx_tdata     : std_logic_vector(DATA_WIDTH downto 0);    -- Bits shifted in (bit 0 not used)
  signal   rx_tvalid    : std_logic;
  signal   rx_tready    : std_logic;
  signal   rx_empty     : std_logic;
  signal   rx_full      : std_logic;
  signal   rx_ready_r   : std_logic;                                -- Free place captured by the scan
  signal   rx_tdo       : std_logic;

begin  -- architecture rtl

  assert DATA_WIDTH < 2**8 and DEPTH_TX < 2**16 and DEPTH_RX < 2**16
    report "jtag_axis : DATA_WIDTH (8 bits) or DEPTH_TX / DEPTH_RX (16 bits) too large for CONFIG" severity failure;

  -----------------------------------------------------------------------------
  -- TAP
  -----------------------------------------------------------------------------
  ins_tap : jtag_tap
    generic map
    (IR_WIDTH        => JTAG_AXIS_IR_WIDTH
    ,IDCODE_VALUE    => IDCODE
    ,TRST_ENABLE     => true
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
  -- Instruction decoder : TX and RX only when their direction is enabled
  -----------------------------------------------------------------------------
  sel_config  <= '1' when ir = JTAG_AXIS_IR_CONFIG                else '0';
  sel_tx      <= '1' when ir = JTAG_AXIS_IR_TX     and TX_ENABLE  else '0';
  sel_rx      <= '1' when ir = JTAG_AXIS_IR_RX     and RX_ENABLE  else '0';

  user_tdo_en <= sel_config or sel_tx or sel_rx;
  user_tdo    <= config_tdo when sel_config = '1' else
                 tx_tdo     when sel_tx     = '1' else
                 rx_tdo;

  -----------------------------------------------------------------------------
  -- CONFIG : flags of the TCK side of the FIFOs, sizes
  -----------------------------------------------------------------------------
  config <= std_logic_vector(to_unsigned(DEPTH_RX  , 16)) &
            std_logic_vector(to_unsigned(DEPTH_TX  , 16)) &
            std_logic_vector(to_unsigned(DATA_WIDTH,  8)) &
            '0' & rx_full & rx_empty & RX_EN &
            '0' & tx_full & tx_empty & TX_EN;

  ins_tdr_config : jtag_tdr_in
    port map
    (tck_i           => tck
    ,trst_b_i        => trst_b
    ,sel_i           => sel_config
    ,capture_dr_i    => capture_dr
    ,shift_dr_i      => shift_dr
    ,update_dr_i     => update_dr
    ,tdi_i           => tdi
    ,tdo_o           => config_tdo
    ,data_i          => config
    );

  -----------------------------------------------------------------------------
  -- TX : s_axis (clk_i) -> FIFO -> TX register (TCK)
  -----------------------------------------------------------------------------
  gen_tx: if TX_ENABLE
  generate
    signal tx_capture : std_logic_vector(DATA_WIDTH downto 0);
  begin
    ins_fifo_tx : fifo_async
      generic map
      (WIDTH                 => DATA_WIDTH
      ,DEPTH                 => DEPTH_TX
      )
      port map
      (arst_b_i              => arst_b_i
      ,s_clk_i               => clk_i
      ,s_axis_tvalid_i       => s_axis_tvalid_i
      ,s_axis_tready_o       => s_axis_tready_o
      ,s_axis_tdata_i        => s_axis_tdata_i
      ,s_axis_nb_elt_empty_o => open
      ,s_axis_full_o         => open
      ,s_axis_empty_o        => open
      ,m_clk_i               => tck
      ,m_axis_tvalid_o       => tx_tvalid
      ,m_axis_tready_i       => tx_tready
      ,m_axis_tdata_o        => tx_tdata
      ,m_axis_nb_elt_full_o  => open
      ,m_axis_full_o         => tx_full
      ,m_axis_empty_o        => tx_empty
      );

    -- Capture-DR : {word, valid}, the word forced to 0 when not valid (the
    -- RAM word of an empty FIFO may be the one being written)
    tx_capture <= (tx_tdata and (tx_tdata'range => tx_tvalid)) & tx_tvalid;

    ins_tdr_tx : jtag_tdr_in
      port map
      (tck_i           => tck
      ,trst_b_i        => trst_b
      ,sel_i           => sel_tx
      ,capture_dr_i    => capture_dr
      ,shift_dr_i      => shift_dr
      ,update_dr_i     => update_dr
      ,tdi_i           => tdi
      ,tdo_o           => tx_tdo
      ,data_i          => tx_capture
      );

    -- The captured word is removed in Update-DR (the rising edge of TCK
    -- that leaves Update-DR) when it was valid
    process(tck, trst_b)
    begin
      if trst_b = '0'
      then
        tx_valid_r <= '0';
      elsif rising_edge(tck)
      then
        if sel_tx = '1' and capture_dr = '1'
        then
          tx_valid_r <= tx_tvalid;
        end if;
      end if;
    end process;

    tx_tready <= sel_tx and update_dr and tx_valid_r;
  end generate gen_tx;

  gen_tx_b: if not TX_ENABLE
  generate
    s_axis_tready_o <= '0';
    tx_tdo          <= '0';
    tx_empty        <= '1';
    tx_full         <= '1';
  end generate gen_tx_b;

  -----------------------------------------------------------------------------
  -- RX : RX register (TCK) -> FIFO -> m_axis (clk_i)
  -----------------------------------------------------------------------------
  gen_rx: if RX_ENABLE
  generate
    signal rx_capture : std_logic_vector(DATA_WIDTH downto 0);
  begin
    -- Capture-DR : bit 0 = accepted (free place in the RX FIFO)
    rx_capture <= ZERO & rx_tready;

    ins_tdr_rx : jtag_tdr_inout
      port map
      (tck_i           => tck
      ,trst_b_i        => trst_b
      ,tlr_i           => tlr
      ,sel_i           => sel_rx
      ,capture_dr_i    => capture_dr
      ,shift_dr_i      => shift_dr
      ,update_dr_i     => update_dr
      ,tdi_i           => tdi
      ,tdo_o           => rx_tdo
      ,data_i          => rx_capture
      ,data_o          => rx_tdata
      );

    -- The word shifted in is written in Update-DR (data_o updated on the
    -- falling edge, written on the rising edge that leaves Update-DR) when
    -- the FIFO had a free place in Capture-DR : only this bridge writes the
    -- FIFO, the place is still free
    process(tck, trst_b)
    begin
      if trst_b = '0'
      then
        rx_ready_r <= '0';
      elsif rising_edge(tck)
      then
        if sel_rx = '1' and capture_dr = '1'
        then
          rx_ready_r <= rx_tready;
        end if;
      end if;
    end process;

    rx_tvalid <= sel_rx and update_dr and rx_ready_r;

    ins_fifo_rx : fifo_async
      generic map
      (WIDTH                 => DATA_WIDTH
      ,DEPTH                 => DEPTH_RX
      )
      port map
      (arst_b_i              => arst_b_i
      ,s_clk_i               => tck
      ,s_axis_tvalid_i       => rx_tvalid
      ,s_axis_tready_o       => rx_tready
      ,s_axis_tdata_i        => rx_tdata(DATA_WIDTH downto 1)
      ,s_axis_nb_elt_empty_o => open
      ,s_axis_full_o         => rx_full
      ,s_axis_empty_o        => rx_empty
      ,m_clk_i               => clk_i
      ,m_axis_tvalid_o       => m_axis_tvalid_o
      ,m_axis_tready_i       => m_axis_tready_i
      ,m_axis_tdata_o        => m_axis_tdata_o
      ,m_axis_nb_elt_full_o  => open
      ,m_axis_full_o         => open
      ,m_axis_empty_o        => open
      );
  end generate gen_rx;

  gen_rx_b: if not RX_ENABLE
  generate
    m_axis_tdata_o  <= (others => '0');
    m_axis_tvalid_o <= '0';
    rx_tdo          <= '0';
    rx_empty        <= '1';
    rx_full         <= '1';
  end generate gen_rx_b;

end architecture rtl;
