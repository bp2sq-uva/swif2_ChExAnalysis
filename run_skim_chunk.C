// run_skim_chunk.C

#include "TROOT.h"
#include <iostream>

void run_skim_chunk(int mode,
                    const char *filelist,
                    const char *outfile)
{
  std::cout << "\n=== Loading SkimGEnRP.C ===" << std::endl;
  gROOT->ProcessLine(".L SkimGEnRP.C");

  std::cout << "\n=== Running skim chunk ===" << std::endl;
  std::cout << "mode     = " << mode << std::endl;
  std::cout << "filelist = " << filelist << std::endl;
  std::cout << "outfile  = " << outfile << std::endl;

  gROOT->ProcessLine(
    Form("SkimGEnRP(%d, \"%s\", \"%s\");",
         mode, filelist, outfile)
  );

  std::cout << "\n=== Done skim chunk ===" << std::endl;
}