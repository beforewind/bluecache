import GetPut::*;
import ClientServer::*;
import ClientServerHelper::*;
import Connectable::*;

import MemTypes::*;
import MemReadEngine::*;
import MemWriteEngine::*;
import Pipe::*;

import ParameterTypes::*;
import Vector::*;
import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;

typedef struct{
   Bit#(32) base;
   Bit#(32) numBursts;
   Bit#(32) lastBurstSz;
   Bit#(32) buffPtr;
} DMAReq deriving (Bits, Eq);

interface MemReadEngineClient#(numeric type userWidth);
   interface Get#(MemengineCmd)             request;
   interface PipeIn#(MemDataF#(userWidth)) data;
   interface PipeIn#(MemRequestCycles)     requestCycles;
endinterface

interface MemWriteEngineClient#(numeric type userWidth);
   interface Get#(MemengineCmd)       request;
   interface Put#(Bool)               done;
   interface PipeOut#(Bit#(userWidth)) data;
   interface PipeIn#(MemRequestCycles)     requestCycles;
endinterface

instance Connectable#(MemReadEngineClient#(dsz), MemReadEngineServer#(dsz));
   module mkConnection#(MemReadEngineClient#(dsz) src, MemReadEngineServer#(dsz) dst)(Empty);
      mkConnection(src.request, dst.request);
      mkConnection(toPut(src.data), toGet(dst.data));
      mkConnection(toPut(src.requestCycles), toGet(dst.requestCycles));
   endmodule
endinstance

instance Connectable#(MemWriteEngineClient#(dsz), MemWriteEngineServer#(dsz));
   module mkConnection#(MemWriteEngineClient#(dsz) src, MemWriteEngineServer#(dsz) dst)(Empty);
      mkConnection(src.request, dst.request);
      mkConnection(src.done, dst.done);
      mkConnection(toGet(src.data), toPut(dst.data));
      mkConnection(toPut(src.requestCycles), toGet(dst.requestCycles));
   endmodule
endinstance


   

interface DMAReadIfc;
   interface Server#(Tuple3#(Bit#(32), Bit#(32), Bit#(64)), Bool) server;
   interface MemReadEngineClient#(128) dmaClient;
   interface Get#(Bit#(128)) outPipe;
endinterface

// interface DMAReadVECIfc#(numeric type n);
//    interface Server#(Tuple3#(Bit#(32), Bit#(32), Bit#(64)), Bool) server;
//    interface Vector#(n,Client#(MemengineCmd,Bool)) dmaClients;
//    interface Vector#(n, Put#(Bit#(128))) inPipes;
//    interface Get#(Bit#(128)) outPipe;
// endinterface


interface DMAWriteIfc;
   interface Server#(Tuple3#(Bit#(32), Bit#(32), Bit#(64)), Bool) server;
   interface MemWriteEngineClient#(128) dmaClient;
   interface Put#(Bit#(128)) inPipe;
endinterface

typedef 256 BURSTLEN;
//typedef 128 BURSTLEN;
//Integer burstLen = valueOf(BURSTLEN);

(*synthesize*)
module mkDMAReader(DMAReadIfc);
   
   Reg#(Bit#(32)) burstCnt <- mkReg(0);
 
   FIFO#(MemengineCmd) dmaReqQ <- mkFIFO();
   //FIFO#(MemengineCmd) dmaReqQ <- mkSizedFIFO(128);
   //FIFO#(Bool) dmaRespQ <- mkFIFO;
   FIFOF#(MemDataF#(128)) dmaRespQ <- mkFIFOF;
   Reg#(Bit#(32)) respCnt <- mkReg(0);
   FIFO#(Bit#(32)) respMaxQ <- mkSizedFIFO(128);
   
   FIFO#(DMAReq) reqQ <- mkSizedFIFO(128);
   FIFO#(Bool) doneQ <- mkFIFO();
   
   //FIFO#(Bit#(128)) inQ <- mkFIFO();
   //FIFO#(Bit#(128)) outQ <- mkFIFO();
  
   rule drive_read;

      let args = reqQ.first();
      let buffPtr = args.buffPtr;
      let lastBurstSz = args.lastBurstSz;
      let numBursts = args.numBursts;
      let base = args.base;
      //$display("drRdRq: base = %d, burstCnt = %d, numBursts = %d, lastBurstSz = %d", base, burstCnt, numBursts, lastBurstSz);
      if ( burstCnt + 1 == numBursts ) begin
         //dmaReqQ.enq(MemengineCmd{tag: 0, sglId:buffPtr, base:extend(base+(burstCnt<<7)), len:truncate(lastBurstSz), burstLen:truncate(lastBurstSz)});
         dmaReqQ.enq(MemengineCmd{tag: 0, sglId:buffPtr, base:extend(base+(burstCnt<<valueof(TLog#(BURSTLEN)))), len:truncate(lastBurstSz), burstLen:truncate(lastBurstSz)});
         reqQ.deq();
         burstCnt <= 0;
      end
      else begin
         //$display("Normal request");
         //dmaReqQ.enq(MemengineCmd{tag: 0, sglId:buffPtr, base:extend(base+(burstCnt<<7)), len:128, burstLen:128});
         dmaReqQ.enq(MemengineCmd{tag: 0, sglId:buffPtr, base:extend(base+(burstCnt<<valueof(TLog#(BURSTLEN)))), len:fromInteger(valueOf(BURSTLEN)), burstLen:fromInteger(valueOf(BURSTLEN))});
         burstCnt <= burstCnt + 1;
      end
   endrule

   Reg#(Bit#(32)) rsCnt <- mkReg(0);
   FIFO#(Bit#(128)) outDtaQ <- mkFIFO();
   rule finish_fifo;
      let md <- toGet(dmaRespQ).get();
      outDtaQ.enq(md.data);
      
      // $display("%m, byteCnt = %d, get data = %h", md.data);
   
      // if (md.last) doneQ.enq(True);
      let respMax = respMaxQ.first();
      if ( md.last ) begin
         if (respCnt + 1 == respMax) begin
            respMaxQ.deq();
            $display("DMA Reader Done Ack, reqCnt = %d, respMax = %d", rsCnt, respMax);
            rsCnt <= rsCnt + 1;
            doneQ.enq(True);
            respCnt <= 0;
         end
         else begin
            respCnt <= respCnt + 1;
         end
      end
   endrule
   
   /*Reg#(Bit#(32)) byteCnt <- mkReg(0);
   FIFO#(Tuple2#(Bit#(32),Bit#(32))) byteMaxQ <- mkSizedFIFO(16);
   rule filter_data;
      let byteMax = tpl_1(byteMaxQ.first());
      let numBytes = tpl_2(byteMaxQ.first());
      let d <- toGet(inQ).get();
      
      $display("DMA Reader Getting Data %h, byteCnt = %d", d, byteCnt);
      
      if ( byteCnt < numBytes)
         outQ.enq(d);
      
      if (byteCnt + 16 == byteMax) begin
         byteMaxQ.deq();
         byteCnt <= 0;
      end
      else begin
         byteCnt <= byteCnt + 16;
      end
   endrule*/
   Reg#(Bit#(32)) rdCnt <- mkReg(0);
   interface Server server;
      interface Put request;
         method Action put(Tuple3#(Bit#(32), Bit#(32), Bit#(64)) v);
            let rp = tpl_1(v);
            let base = tpl_2(v);
            let nBytes = tpl_3(v);
            rdCnt <= rdCnt + 1;
            $display("DMAHelper read request, rp = %d, base = %d, nBytes = %d, reqCnt = %d",rp, base, nBytes, rdCnt);
            //Bit#(32) numBursts = truncate(nBytes >> 7);
            Bit#(32) numBursts = truncate(nBytes >> valueOf(TLog#(BURSTLEN)));
           

            Bit#(32) buffPtr;
   
            Bit#(TLog#(BURSTLEN)) lastBurstSz_trunc;
   
            Bit#(32) reqBytes = truncate(nBytes);
            if ( nBytes[3:0] == 0 ) begin
               //lastBurstSz = extend(nBytes[6:0]);
               lastBurstSz_trunc = truncate(nBytes);
            end
            else begin
               //    lastBurstSz = (extend(nBytes[6:4])+1)<<4;
               lastBurstSz_trunc = ((truncate(nBytes)>>4) + 1) << 4;
               reqBytes = ((reqBytes >> 4) + 1 ) << 4;
            end
      
            Bit#(32) lastBurstSz = extend(lastBurstSz_trunc);
            //if ( nBytes[6:0] != 0) begin
            Bit#(TLog#(BURSTLEN)) remainder = truncate(nBytes);
            //if ( nBytes[valueOf(TSub#(TLog#(BURSTLEN),1)):0] != 0) begin
            if ( remainder != 0 )
               numBursts = numBursts + 1;
            else
               //lastBurstSz = 128;
               lastBurstSz = fromInteger(valueOf(BURSTLEN));
      
            buffPtr = rp;
   
            //lastBurstSz = 128;
   
            //byteMaxQ.enq(tuple2(numBursts << 7, truncate(nBytes)));
            Bit#(TLog#(BURSTLEN)) baseRemainder = truncate(base);
            if ( baseRemainder != 0 ) begin
               $display("base is not word aligned");
               $finish();
            end
   
            //dmaReqQ.enq(MemengineCmd{tag: 0, sglId:rp, base:base, len: reqBytes, burstLen:fromInteger(valueOf(BURSTLEN))});
      
            reqQ.enq(DMAReq{numBursts: numBursts, lastBurstSz: extend(lastBurstSz), buffPtr: buffPtr, base: base});
            respMaxQ.enq(numBursts);
            //respMaxQ.enq(nBytes);
         endmethod
      endinterface
      interface Get response = toGet(doneQ);
   endinterface
   
   //interface Put inPipe = toPut(inQ);
   interface Get outPipe = toGet(outDtaQ);


   // interface Client dmaClient = toClient(dmaReqQ, dmaRespQ);
   interface MemReadEngineClient dmaClient;
      interface Get request = toGet(dmaReqQ);
      interface PipeIn data = toPipeIn(dmaRespQ);
      interface PipeIn requestCycles = ?;
   endinterface
   
endmodule

// //(*synthesize*)
// module mkDMAReader_Vec(DMAReadVECIfc#(n));
   
//    Reg#(Bit#(32)) burstCnt <- mkReg(0);
 
//    Vector#(n, FIFO#(MemengineCmd)) dmaReqQs <- replicateM(mkFIFO());
//    Vector#(n, FIFO#(Bool)) dmaRespQs <- replicateM(mkSizedFIFO(4));
//    Reg#(Bit#(32)) respCnt <- mkReg(0);
//    FIFO#(Bit#(32)) respMaxQ <- mkSizedFIFO(128);
   
//    FIFO#(DMAReq) reqQ <- mkSizedFIFO(128);
//    FIFO#(Bool) doneQ <- mkSizedFIFO(128);
   
//    Vector#(n, FIFO#(Bit#(128))) inQs <- replicateM(mkFIFO());
//    FIFO#(Bit#(128)) outQ <- mkFIFO();
   
//    Reg#(Bit#(TLog#(n))) engSel <- mkReg(0);
//    FIFO#(Tuple2#(Bit#(TLog#(n)),Bit#(32))) byteMaxQ <- mkSizedFIFO(valueOf(n)*4);
//    FIFO#(Bit#(TLog#(n))) nextdmaResp <- mkSizedFIFO(valueOf(n)*4);
//    rule drive_read;

//       let args = reqQ.first();
//       let buffPtr = args.buffPtr;
//       let lastBurstSz = args.lastBurstSz;
//       let numBursts = args.numBursts;
//       let base = args.base;
//       //$display("drRdRq: engSel = %d, base = %d, burstCnt = %d, numBursts = %d, lastBurstSz = %d", engSel, base, burstCnt, numBursts, lastBurstSz);
//       if ( burstCnt + 1 == numBursts ) begin
//          dmaReqQs[engSel].enq(MemengineCmd{sglId:buffPtr, base:extend(base+(burstCnt<<7)), len:truncate(lastBurstSz), burstLen:truncate(lastBurstSz)});
//          reqQ.deq();
//          byteMaxQ.enq(tuple2(engSel, lastBurstSz));
//          nextdmaResp.enq(engSel);
//          burstCnt <= 0;
//          engSel <= engSel + 1;
//       end
//       else begin
//          //$display("Normal request");
//          dmaReqQs[engSel].enq(MemengineCmd{sglId:buffPtr, base:extend(base+(burstCnt<<7)), len:128, burstLen:128});
//          burstCnt <= burstCnt + 1;
//          byteMaxQ.enq(tuple2(engSel, 128));
//          nextdmaResp.enq(engSel);
//          engSel <= engSel + 1;
//       end
//    endrule

//    Reg#(Bit#(32)) rsCnt <- mkReg(0);
//    rule finish_fifo;
//       let sel <- toGet(nextdmaResp).get();
//       let rv1 <- toGet(dmaRespQs[sel]).get();
//       let respMax = respMaxQ.first();
//       if (respCnt + 1 == respMax) begin
//          respMaxQ.deq();
//          //$display("DMA Reader Done Ack, reqCnt = %d, respMax = %d", rsCnt, respMax);
//          rsCnt <= rsCnt + 1;
//          doneQ.enq(True);
//          respCnt <= 0;
//       end
//       else begin
//          respCnt <= respCnt + 1;
//       end
//    endrule
   
//    Reg#(Bit#(32)) byteCnt <- mkReg(0);
   
//    rule filter_data;
//       let sel = tpl_1(byteMaxQ.first());
//       let byteMax = tpl_2(byteMaxQ.first());
//       let d <- toGet(inQs[sel]).get();
      
//       //$display("DMA Reader Getting Data %h, byteCnt = %d", d, byteCnt);
      
//       outQ.enq(d);
      
//       if (byteCnt + 16 >= byteMax) begin
//          byteMaxQ.deq();
//          byteCnt <= 0;
//       end
//       else begin
//          byteCnt <= byteCnt + 16;
//       end
//    endrule
   
//    Vector#(n,Client#(MemengineCmd,Bool)) dmaClis;
//    for ( Integer i = 0; i < valueOf(n); i = i+1 ) begin
//       dmaClis[i] = toClient(dmaReqQs[i], dmaRespQs[i]);
//    end
   
//    Vector#(n, Put#(Bit#(128))) ins;
//    for ( Integer i = 0; i < valueOf(n); i=i+1 ) begin
//       ins[i] = toPut(inQs[i]);
//    end
   

   
//    Reg#(Bit#(32)) rdCnt <- mkReg(0);
   
//    interface Server server;
//       interface Put request;
//          method Action put(Tuple3#(Bit#(32), Bit#(32), Bit#(64)) v);
//             let rp = tpl_1(v);
//             let base = tpl_2(v);
//             let nBytes = tpl_3(v);
//             rdCnt <= rdCnt + 1;
//             //$display("DMAHelper read request, rp = %d, base = %d, nBytes = %d, reqCnt = %d",rp, base, nBytes, rdCnt);
//             Bit#(32) numBursts = truncate(nBytes >> 7);
           
//             Bit#(32) lastBurstSz;
//             Bit#(32) buffPtr;
//             if ( nBytes[3:0] == 0 )
//                lastBurstSz = extend(nBytes[6:0]);
//             else
//                lastBurstSz = (extend(nBytes[6:4])+1)<<4;
      
//             if ( nBytes[6:0] != 0) begin
//                numBursts = numBursts + 1;
//             end
//             else begin
//                lastBurstSz = 128;
//             end
      
//             buffPtr = rp;
   
//             //lastBurstSz = 128;
   
//             //byteMaxQ.enq(tuple2(numBursts << 7, truncate(nBytes)));
         
//             if ( base[6:0] != 0 ) begin
//                $display("base is not word aligned");
//                $finish();
//             end
      
//             reqQ.enq(DMAReq{numBursts: numBursts, lastBurstSz: lastBurstSz, buffPtr: buffPtr, base: base});
//             respMaxQ.enq(numBursts);
//          endmethod
//       endinterface
//       interface Get response = toGet(doneQ);
//    endinterface
   
//    interface Put inPipes = ins;
//    interface Get outPipe = toGet(outQ);


//    interface Client dmaClients = dmaClis;
   
// endmodule


(*synthesize*)
module mkDMAWriter(DMAWriteIfc);
   Reg#(Bit#(32)) burstCnt <- mkReg(0);
   
   Reg#(Bit#(32)) burstIterCnt <- mkReg(0);
  
   FIFO#(Bool) doneQ <- mkFIFO;
   
   FIFO#(MemengineCmd) dmaReqQ <- mkFIFO;
   FIFO#(Bool) dmaRespQ <- mkFIFO;
   
      
   FIFO#(Tuple4#(Bit#(32), Bit#(32), Bit#(32), Bit#(32))) cmdQ <- mkSizedFIFO(numStages);
   FIFO#(Bit#(32)) numOfRespQ <- mkSizedFIFO(numStages);
   
   rule drive_write;
      let v = cmdQ.first;
      let buffPtr = tpl_1(v);
      let numBursts = tpl_2(v);
      let lastBurstSz = tpl_3(v);
      let base = tpl_4(v);
      
      //$display("drWrRq: base = %d, burstCnt = %d, numBursts = %d, lastBurstSz", base, burstCnt, numBursts, lastBurstSz);
      if ( burstCnt +1 == numBursts ) begin
         //$display("Last request");
         dmaReqQ.enq(MemengineCmd{tag:0, sglId:buffPtr, base:extend(base+(burstCnt<<7)), len:truncate(lastBurstSz), burstLen:truncate(lastBurstSz)});
         burstCnt <= 0;
         cmdQ.deq();
      end
      else if ( burstCnt + 1 < numBursts) begin
         //$display("Normal request");
         dmaReqQ.enq(MemengineCmd{tag:0, sglId:buffPtr, base:extend(base+(burstCnt<<7)), len:128, burstLen:128});
         burstCnt <= burstCnt + 1;
      end
            
   endrule
   
   
   rule write_finish;
      let numOfResp = numOfRespQ.first();
      //$display("write_finish %d, %d", burstIterCnt, numOfResp);
      //if ( numOfResp > 0) 
      let v <- toGet(dmaRespQ).get();
      if ( burstIterCnt + 1 < numOfResp) begin
         burstIterCnt <= burstIterCnt + 1;
      end
      else  begin
         doneQ.enq(True);
         burstIterCnt <= 0;
         numOfRespQ.deq();
      end
   endrule
   
   FIFOF#(Bit#(128)) inDtaQ <- mkFIFOF();
   // FIFO#(MemData#(128)) writeDataQ <- mkFIFO();
   // rule enqDta;
   //    let d <- toGet(inDtaQ).get();
   //    writeDataQ.enq(unpack(d));
   // endrule
   
   
   interface Server server;
      interface Put request;
         method Action put(Tuple3#(Bit#(32), Bit#(32), Bit#(64)) v);
            let wp = tpl_1(v);
            let base = tpl_2(v);
            let nBytes = tpl_3(v);
            
            //$display("DMAHelper write request, wp = %d, base = %d, nBytes = %d", wp, base, nBytes);

   
            Bit#(32) numBursts = truncate(nBytes >> 7);
           
            Bit#(32) lastBurstSz;
            if ( nBytes[3:0] == 0 )
               lastBurstSz = extend(nBytes[6:0]);
            else
               lastBurstSz = (extend(nBytes[6:4])+1)<<4;
               
            if ( nBytes[6:0] != 0) begin
               numBursts = numBursts + 1;
            end
            else begin
               lastBurstSz = 128;
            end
      
            if ( base[6:0] != 0 ) begin
               $display("base is not word aligned");
               $finish();
            end
            cmdQ.enq(tuple4(wp, numBursts, lastBurstSz, base));
            numOfRespQ.enq(numBursts);
         endmethod
      endinterface
      interface Get response = toGet(doneQ);
   endinterface



   //interface Client dmaClient = toClient(dmaReqQ, dmaRespQ);
   interface MemWriteEngineClient dmaClient;
      interface Get request = toGet(dmaReqQ);
      interface Put done = toPut(dmaRespQ);
      interface PipeOut data = toPipeOut(inDtaQ);
      interface PipeIn requestCycles = ?;
   endinterface
   interface Put inPipe = toPut(inDtaQ);      
endmodule
