module add4to2_unit;
  localparam integer EXHAUSTIVE_4BIT_VECTORS = 65536;
  localparam integer DIRECTED_8BIT_VECTORS = 7;
  localparam integer RANDOM_8BIT_VECTORS = 1024;

  reg [3:0] i1_4;
  reg [3:0] i2_4;
  reg [3:0] i3_4;
  reg [3:0] i4_4;
  wire [3:0] o1_4;
  wire [3:0] o2_4;

  reg [7:0] i1_8;
  reg [7:0] i2_8;
  reg [7:0] i3_8;
  reg [7:0] i4_8;
  wire [7:0] o1_8;
  wire [7:0] o2_8;

  integer first;
  integer second;
  integer third;
  integer fourth;
  integer random_vector;
  reg [31:0] random_state;
  reg [8:0] expected_4;
  reg [8:0] expected_8;

  rv64im_core_add_4to2 #(.BITS(4)) dut4 (
    .i1(i1_4), .i2(i2_4), .i3(i3_4), .i4(i4_4), .o1(o1_4), .o2(o2_4)
  );

  rv64im_core_add_4to2 #(.BITS(8)) dut8 (
    .i1(i1_8), .i2(i2_8), .i3(i3_8), .i4(i4_8), .o1(o1_8), .o2(o2_8)
  );

  task check_4bit;
    begin
      #1;
      expected_4 = i1_4 + i2_4 + i3_4 + i4_4;
      if ((o1_4 + o2_4) !== expected_4[3:0]) begin
        $display("ADD4TO2_FAIL bits=4 inputs=%h,%h,%h,%h outputs=%h,%h expected=%h",
                 i1_4, i2_4, i3_4, i4_4, o1_4, o2_4, expected_4[3:0]);
        $finish(1);
      end
    end
  endtask

  task check_8bit;
    begin
      #1;
      expected_8 = i1_8 + i2_8 + i3_8 + i4_8;
      if ((o1_8 + o2_8) !== expected_8[7:0]) begin
        $display("ADD4TO2_FAIL bits=8 inputs=%h,%h,%h,%h outputs=%h,%h expected=%h",
                 i1_8, i2_8, i3_8, i4_8, o1_8, o2_8, expected_8[7:0]);
        $finish(1);
      end
    end
  endtask

  task next_random_inputs;
    begin
      random_state = random_state * 32'd1664525 + 32'd1013904223;
      i1_8 = random_state[7:0];
      random_state = random_state * 32'd1664525 + 32'd1013904223;
      i2_8 = random_state[7:0];
      random_state = random_state * 32'd1664525 + 32'd1013904223;
      i3_8 = random_state[7:0];
      random_state = random_state * 32'd1664525 + 32'd1013904223;
      i4_8 = random_state[7:0];
    end
  endtask

  initial begin
    for (first = 0; first < 16; first = first + 1)
      for (second = 0; second < 16; second = second + 1)
        for (third = 0; third < 16; third = third + 1)
          for (fourth = 0; fourth < 16; fourth = fourth + 1) begin
            i1_4 = first;
            i2_4 = second;
            i3_4 = third;
            i4_4 = fourth;
            check_4bit();
          end

    i1_8 = 8'h00; i2_8 = 8'h00; i3_8 = 8'h00; i4_8 = 8'h00; check_8bit();
    i1_8 = 8'hff; i2_8 = 8'hff; i3_8 = 8'hff; i4_8 = 8'hff; check_8bit();
    i1_8 = 8'h01; i2_8 = 8'h00; i3_8 = 8'h00; i4_8 = 8'h00; check_8bit();
    i1_8 = 8'h80; i2_8 = 8'h00; i3_8 = 8'h00; i4_8 = 8'h00; check_8bit();
    i1_8 = 8'haa; i2_8 = 8'h55; i3_8 = 8'haa; i4_8 = 8'h55; check_8bit();
    i1_8 = 8'h7f; i2_8 = 8'h01; i3_8 = 8'h00; i4_8 = 8'h00; check_8bit();
    i1_8 = 8'hff; i2_8 = 8'h01; i3_8 = 8'h01; i4_8 = 8'h01; check_8bit();

    random_state = 32'h4a325f19;
    for (random_vector = 0; random_vector < RANDOM_8BIT_VECTORS;
         random_vector = random_vector + 1) begin
      next_random_inputs();
      check_8bit();
    end

    $display("ADD4TO2_EXHAUSTIVE_4BIT_VECTORS=%0d", EXHAUSTIVE_4BIT_VECTORS);
    $display("ADD4TO2_DIRECTED_8BIT_VECTORS=%0d", DIRECTED_8BIT_VECTORS);
    $display("ADD4TO2_RANDOM_8BIT_VECTORS=%0d", RANDOM_8BIT_VECTORS);
    $display("ADD4TO2_STANDALONE_TEST=PASS");
    $finish;
  end
endmodule
