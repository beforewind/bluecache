#ifndef _TESTMEMREAD_H_
#define _TESTMEMREAD_H_

#include "BluecacheRequest.h"
#include "BluecacheIndication.h"
#include <string.h>


#include <stdlib.h>     /* srand, rand */
#include <assert.h>

#include <math.h>
#include <iostream>

#define ALLOC_SZ (1<<20)

#define DMABUF_SZ (1<<13)


class BluecacheIndication : public BluecacheIndicationWrapper
{
public:

  virtual void done(uint64_t numCycles){
    fprintf(stderr, "Main:: %ld FPGA cycles\n", numCycles);
  }

  BluecacheIndication(int id) : BluecacheIndicationWrapper(id){}
};
BluecacheIndication* deviceIndication = 0;
int runtest(int argc, const char ** argv)
{
  fprintf(stderr, "Main::%s %s\n", __DATE__, __TIME__);
  BluecacheRequestProxy *device = new BluecacheRequestProxy(IfcNames_BluecacheRequestS2H);
  deviceIndication = new BluecacheIndication(IfcNames_BluecacheIndicationH2S);

  device->start(ALLOC_SZ);
  while ( true ){
    sleep(1);
  }
  exit(0);
}
#endif // _TESTMEMREAD_H_
