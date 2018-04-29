%Batch file for analysis of NK experiment results.
%Edit the file to run over your set of data.
%
%Y.Mishchenko (c) 2015

%% definitions
%define experiment's prefix
prefix='nkdeney-yuriy-20151027';

%define m00 and omat filenames
nkdata='nkdeney-yuriy-20151027-eeg.m00';
odata='nkdeney-yuriy-20151027-o.mat';

%define nk-marker channel
nkmarker=22;

%define if will create spectrograms
fspectr=true;

%define useful trials and EEG channels
tridx=[5,4,3,2,1];      %ids of useful trials marker values
predt=0.0;          %epoch pre-length (prior-to-stimulus), sec
postdt=0.85;         %epoch post-length (post-to-stimulus), sec
chidx=1:21;         %data channels

alldata=sprintf('%s.mat',prefix);
dirname=sprintf('analysis-%s',prefix);

%% import data
close all
%set respective parameters to [] for auto; general format is
% o=nkimport(nkdata,odata,nkmarker,offset-o,offset-nk,1st-spike-polarity);
% see nkimport for more info
o=nkimport(nkdata,odata,nkmarker,[],[],[]);
uresp=input('\nIf import was successful, press y to proceed [y/n]:','s');
if(uresp=='n' || uresp=='N')
  return;
end

fprintf('Saving complete data to %s...\n',alldata);
save(alldata,'o');

mkdir(dirname);
savefigs(1:2,[dirname,'\alignment']);

%% run erp analysis
close all
nkanalysis_erp({alldata},tridx,chidx,[],dirname);

%% run spectrograms analysis
if(fspectr)
  TTs=1:7.25E5;   %may need to set this if data contains zero-segment 
                  %such as due to calibration performed before recording
                  %had been turned off, otherwise set to [ ]
  eegspectr(o,chidx,[],[],TTs,dirname)
end

%% run mui, r2 and kl graphs
close all
[MU chid freqid]=ftr_mui({alldata},predt,postdt,chidx); title('MUI GENERAL')
muiplots(MU,chid,freqid);  %channel-id/frequency plots for general MUI above
ntgt=length(tridx);
for ltgt=sort(tridx)
    MU=ftr_mui({alldata},predt,postdt,chidx,[],ltgt); 
    title(sprintf('MUI TGT=%i vs ALL',ltgt))
    KL=ftr_kld({alldata},predt,postdt,chidx,[],ltgt); 
    title(sprintf('KL-div TGT=%i vs ALL',ltgt))
    COR=ftr_r2({alldata},predt,postdt,chidx,[],ltgt); 
    title(sprintf('COR TGT=%i vs ALL',ltgt))
end
savefigs(1:5+3*ntgt,[dirname,'\ftimportance']);

%% run lc analysis
close all
ntgt=length(tridx);
for ltgt=sort(tridx)
    svm_lc({alldata},predt,postdt,chidx,[],ltgt); 
    title(sprintf('Learning Curve TGT=%i',ltgt))
end
savefigs(1:ntgt,[dirname,'\svmlc']);


%% run multiclass lc analysis
if(length(tridx)>2)
  close all
  ltgt=sort(tridx);
  gen_lc(@mcsvm_tr,{alldata},predt,postdt,chidx,[],ltgt);
  title(sprintf('Multiclass SVM Learning Curve'))
  savefigs(1,[dirname,'\svmmclc']);
end
