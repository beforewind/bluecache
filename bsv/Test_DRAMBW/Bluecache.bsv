// Copyright (c) 2013 Quanta Research Cambridge, Inc.

// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use, copy,
// modify, merge, publish, distribute, sublicense, and/or sell copies
// of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
// BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
// ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import FIFO::*;
import FIFOF::*;
import Vector::*;
import GetPut::*;
import ClientServer::*;
import ClientServerHelper::*;

import Arith::*;
import BuildVector::*;
import ConnectalConfig::*;
// import ConnectalMemory::*;
// import MemTypes::*;
// import MemReadEngine::*;
// import MemWriteEngine::*;
// import Pipe::*;
import HostInterface::*; // for DataBusWidth

import TopPins::*;

import Connectable::*;

import DRAMCommon::*;

//import XilinxVC707DDR3::*;
`ifdef BSIM
import DDR3Sim::*;
`else
import DefaultValue::*;
import DDR3Controller::*;
import DDR3Common::*;
`endif
import DRAMController::*;


import Clocks::*;
import Xilinx::*;
`ifndef BSIM
import XilinxCells::*;
`endif




typedef 1 NumEngineServers;

`ifdef NumOutstandingRequests
typedef `NumOutstandingRequests NumOutstandingRequests;
`else
`ifdef BSIM
typedef 64 NumOutstandingRequests;
`else
typedef 16 NumOutstandingRequests;
`endif

`endif

typedef 14 NumOutstandingReadRequests;
typedef 14 NumOutstandingWriteRequests;

Integer memreadEngineBufferSize = 512*valueOf(NumOutstandingReadRequests);
Integer memwriteEngineBufferSize= 512*valueOf(NumOutstandingWriteRequests);

`ifdef DRAMSize
Integer dramSize = `DRAMSize;
`else
Integer dramSize = valueOf(TExp#(30));
`endif

interface BluecacheRequest;
   method Action start(Bit#(64) numBytes);
endinterface

interface Bluecache;
   interface BluecacheRequest request;
   interface Top_Pins pins;
endinterface

interface BluecacheIndication;
   method Action done(Bit#(64) numCycles);
endinterface

typedef TDiv#(DataBusWidth,32) DataBusWords;

//module mkBluecache#(BluecacheIndication indication, Clock clk250) (Bluecache);
module mkBluecache#(HostInterface host, BluecacheIndication indication) (Bluecache);
   
   /////////////DDR3 stuff/////////////
   DRAMControllerIfc dramController <- mkDRAMController();
   `ifdef BSIM
   let ddr3_ctrl_user <- mkDDR3Simulator;
   mkConnection(dramController.ddr3_cli, ddr3_ctrl_user);
   `else 
   Clock clk200 = host.tsys_clk_200mhz_buf;
   Clock ddr_buf = clk200;
   Reset ddr3ref_rst_n <- mkAsyncResetFromCR(4, ddr_buf );
   
   DDR3_Configure_1G ddr3_cfg = defaultValue;
   ddr3_cfg.reads_in_flight = 64;   // adjust as needed
   //DDR3_Controller_VC707 ddr3_ctrl <- mkDDR3Controller_VC707(ddr3_cfg, ddr_buf, clocked_by ddr_buf, reset_by ddr3ref_rst_n);
   DDR3_Controller_VC707_1GB ddr3_ctrl <- mkDDR3Controller_VC707_2_1(ddr3_cfg, ddr_buf, clocked_by ddr_buf, reset_by ddr3ref_rst_n);
      
   Clock ddr3clk = ddr3_ctrl.user.clock;
   Reset ddr3rstn = ddr3_ctrl.user.reset_n;
   
   let ddr_cli_200Mhz <- mkDDR3ClientSync(dramController.ddr3_cli, clockOf(dramController), resetOf(dramController), ddr3clk, ddr3rstn);
   mkConnection(ddr_cli_200Mhz, ddr3_ctrl.user);
   `endif
   
   FIFO#(DRAMReq) dramCmd <- mkFIFO;
   FIFO#(Bit#(512)) dramDta <- mkFIFO;
   
   DRAMClient dramCli = toClient(dramCmd, dramDta);
      
      
   mkConnection(dramCli, dramController);
   
   Reg#(Bit#(64)) byteCntRd <- mkReg(0);
   Reg#(Bit#(64)) byteCntWr <- mkReg(0);
   
   Reg#(Bool) rnw <- mkReg(False);
   
   Integer pageSz = 8192;
   Integer superPageSz = 8192*128;
   
   FIFO#(Bit#(64)) startQ <- mkFIFO;
   
   Reg#(Bit#(64)) cycles <- mkReg(0);
   rule incr;
      cycles <= cycles + 1;
   endrule
   
   Reg#(Bit#(64)) startCycle <- mkRegU();
   Reg#(Bit#(64)) lastCycle <- mkRegU();
   rule enqReq;
      let maxByte = startQ.first();
      lastCycle <= cycles;
      $display("cycle = %d, enqueing dramCmd rnw = %d, byteCntWr = %d, byteCntRd = %d, gap = %d, holes = %d", cycles, rnw, byteCntWr, byteCntRd, cycles!=lastCycle+1, cycles - lastCycle);
      if ( rnw ) begin
         //read

         dramCmd.enq(DRAMReq{rnw: rnw, addr: byteCntRd+fromInteger(superPageSz), numBytes: 64, data: ?});
         // if ( byteCntRd % fromInteger(pageSz) == fromInteger(pageSz - 64))
            rnw <= !rnw;
         if ( byteCntWr >= maxByte && byteCntRd + 64 >= maxByte) begin
            byteCntRd <= 0;
            byteCntWr <= 0;
            startQ.deq();
            indication.done(cycles - startCycle);
         end
         else begin
            byteCntRd <= byteCntRd + 64;
         end
      end
      else begin
         //write
         dramCmd.enq(DRAMReq{rnw: rnw, addr: byteCntWr, numBytes: 64, data: extend(byteCntWr)});
         // if ( byteCntWr % fromInteger(pageSz) == fromInteger(pageSz - 64))
            rnw <= !rnw;
         if ( byteCntRd >= maxByte && byteCntWr + 64 >= maxByte) begin
            byteCntRd <= 0;
            byteCntWr <= 0;
            startQ.deq();
            indication.done(cycles - startCycle);
         end
         else begin
            byteCntWr <= byteCntWr + 64;
         end

      end
   endrule
   
   rule deqData;
      let d <- toGet(dramDta).get();
   endrule
      
   interface BluecacheRequest request;
      method Action start(Bit#(64) numBytes);
         startQ.enq(numBytes);
         startCycle <= cycles;
      endmethod
   endinterface
   
   interface Top_Pins pins;
      `ifndef BSIM
      interface pins_ddr3 = ddr3_ctrl.ddr3;
      `endif
   endinterface
      
endmodule
//jfdaslfj;lasd
