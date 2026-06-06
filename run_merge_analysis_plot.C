// run_merge_analysis_plot.C

#include "TROOT.h"
#include <iostream>

void run_merge_analysis_plot()
{
  std::cout << "\n=== Loading analysis and plot macros ===" << std::endl;

  gROOT->ProcessLine(".L GEnRPAnalysis.C");
  gROOT->ProcessLine(".L PlotGEnRP.C");

  std::cout << "\n=== Running GEnRPAnalysis() ===" << std::endl;
  gROOT->ProcessLine("GEnRPAnalysis();");

  std::cout << "\n=== Running PlotGEnRP() ===" << std::endl;
  gROOT->ProcessLine("PlotGEnRP();");

  std::cout << "\n=== Done merge-analysis-plot stage ===" << std::endl;
}