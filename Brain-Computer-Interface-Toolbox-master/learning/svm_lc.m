function [prctrain prctest]=svm_lc(datafiles,predt,postdt,chidx,ftid,target)
%[prctrain prctest]=svm_lc(datafiles,predt,postdt,chidx,ftid,target)
% Calculate and graph learning curves for a two-target BCI classification, 
% for example such as right vs. left motion classification using EEG data 
% and SVM. 'datafiles' is cell array of o-data files containing the EEG
% data, 'predt' and 'postdt' are before-stimulus and after-stimulus epoch 
% lengths, in seconds. 'chidx' is the array of indexes of the eeg-data 
% channels to use. 'ftid' is the array of indexes of features in
% the full output of ftprep to use in classification (ie feature
% reduction vector). Pass an empty 'ftid' to default to low-pass 
% frequency filtering. 'target' is the target of classification in 
% one-vs-all setup.
%
% Example usage:
%  svm_lc({'nkdeney-example.mat'},0,0.85,1:21,[],2);
%
% Y.Mishchenko (c) 2015

%% Load data (merge listed experiments, example)
% datafiles={};

%old pilot data (EMOTIV), real motion left/right wrist
% datafiles={'pilot20141225.mat','pilot20141229.mat'};

%old pilot-1 data (EMOTIV), imaged motion left/right wrist
% datafiles={datafiles{:},'pilot20150618-1.mat','pilot20150618-2.mat'};
% datafiles={datafiles{:},'pilot20150618-3.mat','pilot20150618-4.mat'};

%old pilot-2 data (EMOTIV), real/img motion right wrist/left hand
% datafiles={datafiles{:},'pilot20150623-1.mat','pilot20150623-2.mat'};
% datafiles={datafiles{:},'pilot20150623-3.mat','pilot20150623-4.mat'};
% datafiles={datafiles{:},'pilot20150623-5.mat'};

%nk-pilot-1, real left/right wrist
% datafiles={datafiles{:},'pilot20150625-nk.mat'};

%nk-pilot-2, real left/right wrist
% datafiles={datafiles{:},'nkdeney-yuriy-20150916-ofull.mat'};

%set epoch parameters (example)
% predt=0.25;  %epoch pre-length (prior stimulus), sec
% postdt=0.85; %epoch post-length (post stimulus), sec
% chidx=1:21;   %data channels

% dt=ceil(0.65*frq);      %classified epoch length
% ddt=ceil(0.85*frq);     %classified epoch end relative to stimulus onset
% ofs=2.5*60*frq;         %excluded part of recording, 2.5min

fprintf('SVM-2B1-learning curves for EEG BCI...\n');
if(nargin<5) ftid=[]; end
if(nargin<6 || isempty(target)) target=1; end

%% Prepare data samples
fprintf('Preparing samples...\n');
[ft ftmrk]=ftprep(datafiles,predt,postdt,chidx,[],ftid);

%make features matrix
[eegsamples,ftmrk,ftidx]=make_features(ft,ftmrk,ftid);

%alternative MUI, KL and COR feature selections (example)
% ftidx=MU>=0.0267;       %mean(MU)+3*std(MU)
% ftidx=COR>=0.0135;      %mean+3*std
% ftidx=KL>=0.0707;       %mean+3*std
% ftidx=MU>=0.0267 | COR>=0.0301 | KL>=0.1090;
% ftidx=MU>=0.0267 & COR>=0.0301 & KL>=0.1090;

%% Finalize data
mrktargets=ismember(ftmrk,target);
nn=size(eegsamples,1);
fprintf('#########################\n');
fprintf('Total samples %i\n',size(eegsamples,1));
fprintf('Total features %i\n',size(eegsamples,2));
fprintf('#########################\n');



%% SCAN LOOP
Ntrains=50:50:floor(nn*3/4);
prctrain=zeros(5,length(Ntrains));
prctest=zeros(5,length(Ntrains));
prccnt=1;
for Ntrain=Ntrains
  
  for m=1:5
    %% Prepare & train SVM

    %split data into training/test sets
    act_flgtrain=rand(1,nn)<3/4;
    
    %restrict training samples count and mix training samples
    idx=find(act_flgtrain);
    idx=idx(randperm(length(idx)));
    idx=idx(1:min(length(idx),Ntrain));
    xeegsamples=eegsamples(idx,:);
    xmrktargets=mrktargets(idx);
    
    %train SVM
    options=optimset('MaxIter',10000);
    svm2=svmtrain(xeegsamples,xmrktargets,'Method','LS',...
      'QuadProg_Opts',options);
    
    %check performance on training set
    xtest=svmclassify(svm2,xeegsamples);
    fprintf('[%i:%i]Training %g\n',Ntrain,m,mean(xmrktargets==xtest));    
    
    %store training performance in this bin    
    prctrain(m,prccnt)=mean(xmrktargets==xtest);
    
    %% Cross-validation test SVM
    %read SVM model w2*x'-b2
    b2=svm2.Bias;
    w2=svm2.SupportVectors'*svm2.Alpha;
    w2=w2.*svm2.ScaleData.scaleFactor';
    b2=b2+svm2.ScaleData.shift*w2;
    w2=-w2;
    
    %select test samples
    idx=find(~act_flgtrain);
    xeegsamples=eegsamples(idx,:);
    xmrktargets=mrktargets(idx);    
    
    %obtain SVM values
    valsd=-b2+xeegsamples*w2;
    vals=xmrktargets;
    
    
    %check performance on test set
    bbef2=0.00;           %additional custom offset
    vals1=(sign(valsd-bbef2)+1)/2;
    p2=sum(vals==vals1)/length(vals);
    fprintf('[%i:%i]Test %g\n',Ntrain,m,p2);

    %store test performance in this bin
    prctest(m,prccnt)=p2;
  end
  
  prccnt=prccnt+1;
end

%% Graph learning curves
figure,errorbar(Ntrains,mean(prctest,1),std(prctest,[],1),'g'),hold on
errorbar(Ntrains,mean(prctrain,1),std(prctrain,[],1),'r')

end