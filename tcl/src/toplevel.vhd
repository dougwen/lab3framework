library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity toplevel is
    Port (  --DOES NOT NEED CONSTRAINTS
        DDR_addr : inout STD_LOGIC_VECTOR ( 14 downto 0 );
        DDR_ba : inout STD_LOGIC_VECTOR ( 2 downto 0 );
        DDR_cas_n : inout STD_LOGIC;
        DDR_ck_n : inout STD_LOGIC;
        DDR_ck_p : inout STD_LOGIC;
        DDR_cke : inout STD_LOGIC;
        DDR_cs_n : inout STD_LOGIC;
        DDR_dm : inout STD_LOGIC_VECTOR ( 3 downto 0 );
        DDR_dq : inout STD_LOGIC_VECTOR ( 31 downto 0 );
        DDR_dqs_n : inout STD_LOGIC_VECTOR ( 3 downto 0 );
        DDR_dqs_p : inout STD_LOGIC_VECTOR ( 3 downto 0 );
        DDR_odt : inout STD_LOGIC;
        DDR_ras_n : inout STD_LOGIC;
        DDR_reset_n : inout STD_LOGIC;
        DDR_we_n : inout STD_LOGIC;
        FIXED_IO_ddr_vrn : inout STD_LOGIC;
        FIXED_IO_ddr_vrp : inout STD_LOGIC;
        FIXED_IO_mio : inout STD_LOGIC_VECTOR ( 53 downto 0 );
        FIXED_IO_ps_clk : inout STD_LOGIC;
        FIXED_IO_ps_porb : inout STD_LOGIC;
        FIXED_IO_ps_srstb : inout STD_LOGIC;

        --NEEDS CONSTRAINTS
        --Basic IO
        reset_pb : in STD_LOGIC;
        led : out STD_LOGIC_VECTOR ( 3 downto 0 );
        sw : in STD_LOGIC_VECTOR ( 3 downto 0 );
        --UART
        uart_rxd : in STD_LOGIC;
        uart_txd : out STD_LOGIC;
        --DACIF
        dac_sdata : out STD_LOGIC;
        dac_lrck : out STD_LOGIC;
        dac_bclk : out STD_LOGIC;
        dac_mclk : out STD_LOGIC;
        dac_muten : out STD_LOGIC;
        dac_scl : inout STD_LOGIC;
        dac_sda : inout STD_LOGIC
    );

end toplevel;


architecture Behavioral of toplevel is

    signal ctr : unsigned(2 downto 0);
    signal clk,rst : std_logic;
    --signal i_dac_sdata, i_dac_lrck, i_dac_bclk, i_dac_mclk, i_dac_muten, i_dac_latched_data : std_logic;
    --signal i_dac_data_word : std_logic_vector(31 downto 0);
    signal i_dac_sdata, i_dac_lrck, i_dac_bclk, i_dac_mclk, i_dac_muten  : std_logic;
    signal i_audiosamples_axis_tlast, i_audiosamples_axis_tready, i_audiosamples_axis_tvalid : std_logic;
    signal i_audiosamples_axis_tdata : std_logic_vector(31 downto 0);

    signal i_fclk_clk0 : std_logic;

    signal iic_rtl_scl_i : STD_LOGIC;
    signal iic_rtl_scl_o : STD_LOGIC;
    signal iic_rtl_scl_t : STD_LOGIC;
    signal iic_rtl_sda_i : STD_LOGIC;
    signal iic_rtl_sda_o : STD_LOGIC;
    signal iic_rtl_sda_t : STD_LOGIC;

    component IOBUF is
        port (
            I : in STD_LOGIC;
            O : out STD_LOGIC;
            T : in STD_LOGIC;
            IO : inout STD_LOGIC
        );
    end component IOBUF;


    type samples_lut is array ( integer range <> ) of std_logic_vector(15 downto 0);
    constant sine_table : samples_lut(0 to 7) := (
        0 => std_logic_vector(to_signed(0,16)),
        1 => std_logic_vector(to_signed(7070,16)),
        2 => std_logic_vector(to_signed(10000,16)),
        3 => std_logic_vector(to_signed(7070,16)),
        4 => std_logic_vector(to_signed(0,16)),
        5 => std_logic_vector(to_signed(-7070,16)),
        6 => std_logic_vector(to_signed(-10000,16)),
        7 => std_logic_vector(to_signed(-7070,16))
    );

    component lowlevel_dac_intfc is
        port (
            rst                 : in std_logic; -- active high asynchronous reset
            clk125              : in std_logic; -- the clock for all flops in your design
            data_word           : in std_logic_vector(31 downto 0); -- 32 bit input data
            sdata               : out std_logic; -- serial data out to the DAC
            lrck                : out std_logic;  -- a 50% duty cycle signal aligned as shown below
            bclk                : out std_logic; -- the dac clocks sdata on the rising edge of this clock
            mclk                : out std_logic; -- a 12.5MHz clock output with arbitrary phase
            latched_data        : out std_logic -- 1 clock wide pulse which indicates when you should change data_word
        );
    end component;

    component clkdivider is
        generic (divideby : natural := 2);
        port (  clk : in std_logic;
             reset : in std_logic;
             pulseout : out std_logic);
    end component;

    component proc_system is
        port (
            DDR_cas_n : inout STD_LOGIC;
            DDR_cke : inout STD_LOGIC;
            DDR_ck_n : inout STD_LOGIC;
            DDR_ck_p : inout STD_LOGIC;
            DDR_cs_n : inout STD_LOGIC;
            DDR_reset_n : inout STD_LOGIC;
            DDR_odt : inout STD_LOGIC;
            DDR_ras_n : inout STD_LOGIC;
            DDR_we_n : inout STD_LOGIC;
            DDR_ba : inout STD_LOGIC_VECTOR ( 2 downto 0 );
            DDR_addr : inout STD_LOGIC_VECTOR ( 14 downto 0 );
            DDR_dm : inout STD_LOGIC_VECTOR ( 3 downto 0 );
            DDR_dq : inout STD_LOGIC_VECTOR ( 31 downto 0 );
            DDR_dqs_n : inout STD_LOGIC_VECTOR ( 3 downto 0 );
            DDR_dqs_p : inout STD_LOGIC_VECTOR ( 3 downto 0 );
            FIXED_IO_mio : inout STD_LOGIC_VECTOR ( 53 downto 0 );
            FIXED_IO_ddr_vrn : inout STD_LOGIC;
            FIXED_IO_ddr_vrp : inout STD_LOGIC;
            FIXED_IO_ps_srstb : inout STD_LOGIC;
            FIXED_IO_ps_clk : inout STD_LOGIC;
            FIXED_IO_ps_porb : inout STD_LOGIC;

            fclk_clk0 : out STD_LOGIC;
            uart_rtl_rxd : in STD_LOGIC;
            uart_rtl_txd : out STD_LOGIC;
            leds_4bits_tri_o : out STD_LOGIC_VECTOR ( 3 downto 0 );
            sws_4bits_tri_i : in STD_LOGIC_VECTOR ( 3 downto 0 );
            iic_rtl_scl_i : in STD_LOGIC;
            iic_rtl_scl_o : out STD_LOGIC;
            iic_rtl_scl_t : out STD_LOGIC;
            iic_rtl_sda_i : in STD_LOGIC;
            iic_rtl_sda_o : out STD_LOGIC;
            iic_rtl_sda_t : out STD_LOGIC;
            audiosamples_axis_tdata : out STD_LOGIC_VECTOR ( 31 downto 0 );
            audiosamples_axis_tlast : out STD_LOGIC;
            audiosamples_axis_tready : in STD_LOGIC;
            audiosamples_axis_tvalid : out STD_LOGIC
        );
    end component proc_system;


begin

    clk <= i_fclk_clk0;
    rst <= reset_pb;

    --Map internal/external
    dac_sdata <= i_dac_sdata;
    dac_lrck <= i_dac_lrck;
    dac_bclk <= i_dac_bclk;
    dac_mclk <= i_dac_mclk;
    dac_muten <= i_dac_muten;

    i_dac_muten <= '1';

    proc_system_i: component proc_system
        port map (
            DDR_addr(14 downto 0) => DDR_addr(14 downto 0),
            DDR_ba(2 downto 0) => DDR_ba(2 downto 0),
            DDR_cas_n => DDR_cas_n,
            DDR_ck_n => DDR_ck_n,
            DDR_ck_p => DDR_ck_p,
            DDR_cke => DDR_cke,
            DDR_cs_n => DDR_cs_n,
            DDR_dm(3 downto 0) => DDR_dm(3 downto 0),
            DDR_dq(31 downto 0) => DDR_dq(31 downto 0),
            DDR_dqs_n(3 downto 0) => DDR_dqs_n(3 downto 0),
            DDR_dqs_p(3 downto 0) => DDR_dqs_p(3 downto 0),
            DDR_odt => DDR_odt,
            DDR_ras_n => DDR_ras_n,
            DDR_reset_n => DDR_reset_n,
            DDR_we_n => DDR_we_n,
            FIXED_IO_ddr_vrn => FIXED_IO_ddr_vrn,
            FIXED_IO_ddr_vrp => FIXED_IO_ddr_vrp,
            FIXED_IO_mio(53 downto 0) => FIXED_IO_mio(53 downto 0),
            FIXED_IO_ps_clk => FIXED_IO_ps_clk,
            FIXED_IO_ps_porb => FIXED_IO_ps_porb,
            FIXED_IO_ps_srstb => FIXED_IO_ps_srstb,
            fclk_clk0 => i_fclk_clk0,
            leds_4bits_tri_o(3 downto 0) => led(3 downto 0),
            sws_4bits_tri_i(3 downto 0) => sw(3 downto 0),
            uart_rtl_rxd => uart_rxd,
            uart_rtl_txd => uart_txd,
            iic_rtl_scl_i => iic_rtl_scl_i,
            iic_rtl_scl_o => iic_rtl_scl_o,
            iic_rtl_scl_t => iic_rtl_scl_t,
            iic_rtl_sda_i => iic_rtl_sda_i,
            iic_rtl_sda_o => iic_rtl_sda_o,
            iic_rtl_sda_t => iic_rtl_sda_t,
            audiosamples_axis_tdata(31 downto 0) => i_audiosamples_axis_tdata(31 downto 0),
            audiosamples_axis_tlast =>i_audiosamples_axis_tlast,
            audiosamples_axis_tready => i_audiosamples_axis_tready,
            audiosamples_axis_tvalid => i_audiosamples_axis_tvalid
        );

    iic_rtl_scl_iobuf: component IOBUF
        port map (
            I => iic_rtl_scl_o,
            IO => dac_scl,
            O => iic_rtl_scl_i,
            T => iic_rtl_scl_t
        );
    iic_rtl_sda_iobuf: component IOBUF
        port map (
            I => iic_rtl_sda_o,
            IO => dac_sda,
            O => iic_rtl_sda_i,
            T => iic_rtl_sda_t
        );

    dacif : component lowlevel_dac_intfc
        port map (
            rst => rst,
            clk125 => clk,
            data_word => i_audiosamples_axis_tdata,
            sdata => i_dac_sdata,
            lrck => i_dac_lrck,
            bclk => i_dac_bclk,
            mclk => i_dac_mclk,
            latched_data => i_audiosamples_axis_tready
        );

end Behavioral;