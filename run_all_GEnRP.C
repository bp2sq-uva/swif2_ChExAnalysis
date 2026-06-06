#include "TROOT.h"
#include <iostream>

void run_all_GEnRP()
{
  std::cout << "\n=== Loading macros ===" << std::endl;

  gROOT->ProcessLine(".L SkimGEnRP.C");
  gROOT->ProcessLine(".L GEnRPAnalysis.C");
  gROOT->ProcessLine(".L PlotGEnRP.C");

  std::cout << "\n=== Step 1: SkimGEnRP(mode = 1) ===" << std::endl;
  gROOT->ProcessLine("SkimGEnRP(1);");

  std::cout << "\n=== Step 2: GEnRPAnalysis() ===" << std::endl;
  gROOT->ProcessLine("GEnRPAnalysis();");

  std::cout << "\n=== Step 3: PlotGEnRP() ===" << std::endl;
  gROOT->ProcessLine("PlotGEnRP();");

  std::cout << "\n=== Done ===" << std::endl;
}