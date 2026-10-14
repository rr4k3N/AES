-----------------------------------------------------------------------
-- aes256_axi : AXI wrapper around aes_256_cyph
--
--   S_AXI   : AXI4-Lite slave, control / key / status
--   S_AXIS  : 128-bit plaintext  in  (from AXI DMA MM2S)
--   M_AXIS  : 128-bit ciphertext out (to   AXI DMA S2MM)
--
-- Register map (32-bit, byte offsets)
--   0x00 CTRL    W  bit0 = KEY_LOAD   (start key expansion, self-clearing)
--                   bit1 = SOFT_RESET (flush pipeline + counters, self-clearing)
--   0x04 STATUS  R  bit0 = KEY_READY  (all 15 round keys valid)
--                   bit1 = BUSY       (blocks still in flight)
--                   bit2 = KEY_REJECTED (KEY_LOAD ignored because BUSY)
--   0x08 BLOCKS_IN   R  128-bit blocks accepted
--   0x0C BLOCKS_OUT  R  128-bit blocks delivered
--   0x10..0x2C KEY0..KEY7  W  key words, KEY0 = most significant word
--                             e.g. key 603DEB10 15CA71BE ... -> KEY0 = 0x603DEB10
--
-- Data byte order: memory byte 0 of each 16-byte block is AES byte 0.
-- The 128-bit stream word is byte-reversed in and out to guarantee that.
--
-- Flow control: the cipher pipeline cannot stall, so the wrapper only
-- accepts a block if there is guaranteed room for it in the output FIFO
-- (in_flight < FIFO_DEPTH).
--
-- Requires aes_256_cyph to have an extra output  key_ready_o  (= round_key_valid)
-- and PIPE_STAGES must equal the length of its vld shift register (29).
-----------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity aes256_axi is
  generic (
    FIFO_DEPTH  : integer := 64;   -- must be > PIPE_STAGES for full throughput
    PIPE_STAGES : integer := 29
  );
  port (
    aclk    : in  std_logic;
    aresetn : in  std_logic;

    -- AXI4-Lite slave
    s_axi_awaddr  : in  std_logic_vector(5 downto 0);
    s_axi_awvalid : in  std_logic;
    s_axi_awready : out std_logic;
    s_axi_wdata   : in  std_logic_vector(31 downto 0);
    s_axi_wstrb   : in  std_logic_vector(3 downto 0);
    s_axi_wvalid  : in  std_logic;
    s_axi_wready  : out std_logic;
    s_axi_bresp   : out std_logic_vector(1 downto 0);
    s_axi_bvalid  : out std_logic;
    s_axi_bready  : in  std_logic;
    s_axi_araddr  : in  std_logic_vector(5 downto 0);
    s_axi_arvalid : in  std_logic;
    s_axi_arready : out std_logic;
    s_axi_rdata   : out std_logic_vector(31 downto 0);
    s_axi_rresp   : out std_logic_vector(1 downto 0);
    s_axi_rvalid  : out std_logic;
    s_axi_rready  : in  std_logic;

    -- AXI4-Stream slave (plaintext)
    s_axis_tdata  : in  std_logic_vector(127 downto 0);
    s_axis_tvalid : in  std_logic;
    s_axis_tready : out std_logic;
    s_axis_tlast  : in  std_logic;

    -- AXI4-Stream master (ciphertext)
    m_axis_tdata  : out std_logic_vector(127 downto 0);
    m_axis_tkeep  : out std_logic_vector(15 downto 0);
    m_axis_tvalid : out std_logic;
    m_axis_tready : in  std_logic;
    m_axis_tlast  : out std_logic
  );

  -- interface hints for Vivado (used by "Add Module" / IP packager)
  attribute X_INTERFACE_INFO      : string;
  attribute X_INTERFACE_PARAMETER : string;
  attribute X_INTERFACE_INFO of aclk : signal is "xilinx.com:signal:clock:1.0 aclk CLK";
  attribute X_INTERFACE_PARAMETER of aclk : signal is
    "ASSOCIATED_BUSIF s_axi:s_axis:m_axis, ASSOCIATED_RESET aresetn";
  attribute X_INTERFACE_INFO of aresetn : signal is "xilinx.com:signal:reset:1.0 aresetn RST";
  attribute X_INTERFACE_PARAMETER of aresetn : signal is "POLARITY ACTIVE_LOW";

end entity aes256_axi;


architecture rtl of aes256_axi is

  type key_array   is array (0 to 7) of std_logic_vector(31 downto 0);
  type fifo_mem_t  is array (0 to FIFO_DEPTH - 1) of std_logic_vector(128 downto 0);

  function bswap128 (x : std_logic_vector(127 downto 0)) return std_logic_vector is
    variable y : std_logic_vector(127 downto 0);
  begin
    for i in 0 to 15 loop
      y(8*i + 7 downto 8*i) := x(127 - 8*i downto 120 - 8*i);
    end loop;
    return y;
  end function bswap128;

  -- AXI-Lite
  signal awready_r, wready_r, bvalid_r : std_logic := '0';
  signal arready_r, rvalid_r           : std_logic := '0';
  signal rdata_r                       : std_logic_vector(31 downto 0) := (others => '0');

  -- control
  signal key_regs     : key_array := (others => (others => '0'));
  signal key_load_p   : std_logic := '0';
  signal soft_rst_p   : std_logic := '0';
  signal key_rejected : std_logic := '0';
  signal status       : std_logic_vector(31 downto 0);

  -- cipher
  signal rst_c        : std_logic;
  signal c_data_i     : std_logic_vector(127 downto 0);
  signal c_valid_i    : std_logic;
  signal c_key_i      : std_logic_vector(255 downto 0);
  signal c_key_valid  : std_logic := '0';
  signal c_key_ready  : std_logic;
  signal c_valid_o    : std_logic;
  signal c_data_o     : std_logic_vector(127 downto 0);

  -- stream / fifo
  signal s_tready_i   : std_logic;
  signal m_tvalid_i   : std_logic;
  signal accept, pop  : std_logic;
  signal in_flight    : integer range 0 to FIFO_DEPTH := 0;
  signal fifo_cnt     : integer range 0 to FIFO_DEPTH := 0;
  signal wr_ptr       : integer range 0 to FIFO_DEPTH - 1 := 0;
  signal rd_ptr       : integer range 0 to FIFO_DEPTH - 1 := 0;
  signal fifo_mem     : fifo_mem_t := (others => (others => '0'));
  signal fifo_q       : std_logic_vector(128 downto 0);
  signal last_pipe    : std_logic_vector(0 to PIPE_STAGES - 1) := (others => '0');
  signal blocks_in    : unsigned(31 downto 0) := (others => '0');
  signal blocks_out   : unsigned(31 downto 0) := (others => '0');

begin

  ----------------------------------------------------------------
  -- cipher core
  ----------------------------------------------------------------
  rst_c    <= (not aresetn) or soft_rst_p;
  c_key_i  <= key_regs(0) & key_regs(1) & key_regs(2) & key_regs(3) &
              key_regs(4) & key_regs(5) & key_regs(6) & key_regs(7);
  c_data_i <= bswap128(s_axis_tdata);
  c_valid_i <= accept;

  u_aes : entity work.aes_256_cyph
    port map (
      clk          => aclk,
      rst          => rst_c,
      data_i       => c_data_i,
      valid_i      => c_valid_i,
      key_i        => c_key_i,
      key_valid    => c_key_valid,
      key_ready_o  => c_key_ready,
      cyph_valid_o => c_valid_o,
      cyph_data_o  => c_data_o
    );

  ----------------------------------------------------------------
  -- stream handshakes
  ----------------------------------------------------------------
  s_tready_i    <= '1' when (c_key_ready = '1' and in_flight < FIFO_DEPTH) else '0';
  s_axis_tready <= s_tready_i;
  accept        <= s_axis_tvalid and s_tready_i;

  m_tvalid_i    <= '1' when fifo_cnt /= 0 else '0';
  m_axis_tvalid <= m_tvalid_i;
  pop           <= m_tvalid_i and m_axis_tready;

  fifo_q        <= fifo_mem(rd_ptr);
  m_axis_tdata  <= bswap128(fifo_q(127 downto 0));
  m_axis_tlast  <= fifo_q(128);
  m_axis_tkeep  <= (others => '1');

  -- FIFO storage (no reset -> infers distributed RAM)
  fifo_write : process (aclk)
  begin
    if rising_edge(aclk) then
      if c_valid_o = '1' then
        fifo_mem(wr_ptr) <= last_pipe(PIPE_STAGES - 1) & c_data_o;
      end if;
    end if;
  end process fifo_write;

  -- pointers, counters, key-load gating, tlast delay line
  ctrl : process (aclk)
  begin
    if rising_edge(aclk) then
      if aresetn = '0' or soft_rst_p = '1' then
        wr_ptr       <= 0;
        rd_ptr       <= 0;
        fifo_cnt     <= 0;
        in_flight    <= 0;
        blocks_in    <= (others => '0');
        blocks_out   <= (others => '0');
        last_pipe    <= (others => '0');
        c_key_valid  <= '0';
        key_rejected <= '0';
      else
        -- tlast travels beside the data (same latency as the cipher's valid)
        last_pipe <= s_axis_tlast & last_pipe(0 to PIPE_STAGES - 2);

        -- key load, only when the pipeline is empty
        c_key_valid <= '0';
        if key_load_p = '1' then
          if in_flight = 0 then
            c_key_valid  <= '1';
            key_rejected <= '0';
          else
            key_rejected <= '1';
          end if;
        end if;

        -- fifo write pointer
        if c_valid_o = '1' then
          if wr_ptr = FIFO_DEPTH - 1 then wr_ptr <= 0; else wr_ptr <= wr_ptr + 1; end if;
        end if;

        -- fifo read pointer
        if pop = '1' then
          if rd_ptr = FIFO_DEPTH - 1 then rd_ptr <= 0; else rd_ptr <= rd_ptr + 1; end if;
        end if;

        -- fifo occupancy
        if c_valid_o = '1' and pop = '0' then
          fifo_cnt <= fifo_cnt + 1;
        elsif c_valid_o = '0' and pop = '1' then
          fifo_cnt <= fifo_cnt - 1;
        end if;

        -- blocks accepted but not yet delivered (pipeline + fifo)
        if accept = '1' and pop = '0' then
          in_flight <= in_flight + 1;
        elsif accept = '0' and pop = '1' then
          in_flight <= in_flight - 1;
        end if;

        if accept = '1' then blocks_in  <= blocks_in  + 1; end if;
        if pop    = '1' then blocks_out <= blocks_out + 1; end if;
      end if;
    end if;
  end process ctrl;

  ----------------------------------------------------------------
  -- status register
  ----------------------------------------------------------------
  status(31 downto 3) <= (others => '0');
  status(2)           <= key_rejected;
  status(1)           <= '1' when in_flight /= 0 else '0';
  status(0)           <= c_key_ready;

  ----------------------------------------------------------------
  -- AXI4-Lite slave
  ----------------------------------------------------------------
  s_axi_awready <= awready_r;
  s_axi_wready  <= wready_r;
  s_axi_bvalid  <= bvalid_r;
  s_axi_bresp   <= "00";
  s_axi_arready <= arready_r;
  s_axi_rvalid  <= rvalid_r;
  s_axi_rresp   <= "00";
  s_axi_rdata   <= rdata_r;

  axil : process (aclk)
    variable widx : integer range 0 to 15;
  begin
    if rising_edge(aclk) then
      if aresetn = '0' then
        awready_r  <= '0';
        wready_r   <= '0';
        bvalid_r   <= '0';
        arready_r  <= '0';
        rvalid_r   <= '0';
        rdata_r    <= (others => '0');
        key_load_p <= '0';
        soft_rst_p <= '0';
        key_regs   <= (others => (others => '0'));
      else
        -- defaults (pulses)
        key_load_p <= '0';
        soft_rst_p <= '0';
        awready_r  <= '0';
        wready_r   <= '0';
        arready_r  <= '0';

        ---------------- write channel ----------------
        -- cycle 0: both address and data present -> raise ready for one cycle
        if awready_r = '0' and s_axi_awvalid = '1' and s_axi_wvalid = '1' and bvalid_r = '0' then
          awready_r <= '1';
          wready_r  <= '1';
        end if;

        -- cycle 1: handshake happens, perform the write, answer next cycle
        if awready_r = '1' and s_axi_awvalid = '1' and s_axi_wvalid = '1' then
          widx := to_integer(unsigned(s_axi_awaddr(5 downto 2)));
          if widx = 0 then
            if s_axi_wdata(0) = '1' then key_load_p <= '1'; end if;
            if s_axi_wdata(1) = '1' then soft_rst_p <= '1'; end if;
          elsif widx >= 4 and widx <= 11 then
            key_regs(widx - 4) <= s_axi_wdata;
          end if;
          bvalid_r <= '1';
        elsif bvalid_r = '1' and s_axi_bready = '1' then
          bvalid_r <= '0';
        end if;

        ---------------- read channel -----------------
        -- cycle 0: address present -> raise arready for one cycle
        if arready_r = '0' and s_axi_arvalid = '1' and rvalid_r = '0' then
          arready_r <= '1';
        end if;

        -- cycle 1: handshake happens, present data next cycle
        if arready_r = '1' and s_axi_arvalid = '1' and rvalid_r = '0' then
          rvalid_r <= '1';
          case to_integer(unsigned(s_axi_araddr(5 downto 2))) is
            when 1      => rdata_r <= status;
            when 2      => rdata_r <= std_logic_vector(blocks_in);
            when 3      => rdata_r <= std_logic_vector(blocks_out);
            when others => rdata_r <= (others => '0');
          end case;
        elsif rvalid_r = '1' and s_axi_rready = '1' then
          rvalid_r <= '0';
        end if;

      end if;
    end if;
  end process axil;

end architecture rtl;