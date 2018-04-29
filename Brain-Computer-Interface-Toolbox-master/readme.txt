This is a brief EEG BCI analysis toolbox 
contents explanation. Do 'help tool-name'
from Matlab to get more information about
specific tools from this toolbox.

/                    [toolbox root directory]
  settoolbox.m
    used to setup toolbox's path

/3dRobotArm         [3D robotic arm simulator]
  puma3d_control.m
    tool for controlling puma3d robotic arm simulator
  puma3d_getdt.m
    tool for calculating 6d coordinates for puma3d 
    robotic arm simulator for a given motion
  puma3d.m
    puma3d robotic arm simulator main file

/acqusition         [data acquisition related tools]
  edk.dll
  edkErrorCode.h
  edk.h
  edk_utils.dll
  EmoStateDLL.h
    EMOTIV EPOC acquisition library DLL
  emologger3.m
    EMOTIV EPOC data acquisition script

/acqusition/nk-arduino  [arduino trigger files]
  Serial.ino
    C program for arduino-based trigger
  readme.txt
    short explanations for the arduino-based
    trigger setup and operations

/acqusition/nk-ui       [Nihon Kohden data acqusition scripts]
  leftfingers.png
  leftfoot.png
  lefthand.png
  left.png
  pass.png
  rightfingers.png
  rightfoot.png
  righthand.png
  right.png
  tongue.png
  wait.png
    graphics for nkExperimentMotor scripts
  nkExperimentMotor_1.m
    synchronized left/right/leg/tongue motion 
    experiment script for Nihon Kohden
  nkExperimentMotor_2.m
    synchronized five hand-finger motion 
    experiment script for Nihon Kohden
  nkExperimentMotor_3.m
    asynchronized free left/right motion 
    experiment script for Nihon Kohden
  nkExperimentMotorC34.m
    legacy left/right hand motion experiment 
    script for Nihon Kohden

/analysis           [EEG BCI data analysis tools]
  copyfigure.m
    copy content of a figure in matlab
  savefigs.m
    save a set of figures automatically 
    in matlab
  KLDz.m
    calculating KL-divergence using 
    histogram binning
  MUI2.m
    calculating mutual information using 
    histogram binning    
  MUI.m
    calculating mutual information using 
    nearest-neighbor KL method
  MUIz2.m
    calculating mutual information using 
    histogram binning when one of the 
    variables is discrete        
  MUIz.m
    calculating mutual information using 
    nearest-neighbor KL method when one 
    of the variables is discrete        
  muivsedst.m
    calculating electrode-electrode MUI vs
    geodesic distance graph
  muivsmrk.m
    calculating electrode raw signal and 
    target marker 
  plotprc.m
    plot operating curves using a 
    classifier output
  trials_erp.m
    calculate average ERP for EEG data
  trials_make.m
    form trials data structures for EEG data
  trials_norm.m
    normalize EEG trials to zero mean
  trials_pdf.m
    calculate raw EEG signal PDF for EEG data
  trials_show.m
    show trials for EEG data
  eegspectr.m
    calculates spectrograms, band and overall 
    spectra for EEG data

/ftrating           [EEG BCI feature ranking tools]
  ftprep.m
    prepare Fourier-Transform features for an
    EEG BCI experiment data
  ftr_in1ch.m
    add-one-in EEG channels ranking
  ftr_out1ch.m
    take-one-out EEG channels ranking
  ftr_kld.m
    KL-divergence based EEG features ranking    
  ftr_mui.m
    Mutual information based EEG features ranking
  ftr_r2.m
    Correlation based EEG features ranking

/learning           [EEG BCI training/learning tools]
  svm_lc.m
    calculate learning curves for SVM classifier
    for an EEG BCI experiment data
  svm_tr.m
    calculate single SVM classifier for an 
    EEG BCI experiment data

/super              [batch scripts and similar]
  nkimport.m
    automatically import Nihon Kohden data into
    EMOTIV EPOC o-data file format
  nkanalysis_erp.m
    batch analysis for average ERP and other
    average signal signatures for o-data
  nkanalysis_batch.m
    batch analysis of Nihon Kohden data for 
    a EEG BCI experiment
