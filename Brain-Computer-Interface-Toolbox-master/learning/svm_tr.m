function [svmObject pp]=svm_tr(datafiles,predt,postdt,chidx,ftid,target,ft,ftmrk,act_flgtest)
%[svmobject pp]=svm_tr(datafiles,predt,postdt,chidx,ftid,target,ft,ftmrk,flgtest)
%>>>>>>THIS FUNCTION IS DEPRECATED IN FAVOR OF mcsvm_tr<<<<<<
% Train SVM classifier for a two-target BCI classification, for example
% such as right vs. left motion classification using EEG data and SVM.
% 'datafiles' is cell array of o-data files containing the EEG data,
% 'predt' and 'postdt' are before-stimulus and after-stimulus epoch
% lengths, in seconds. 'chidx' is the array of indexes of the eeg-data
% channels to use. 'ftid' is the array of indexes of features in
% the full output of ftprep to use in classification (ie feature
% reduction vector). Pass an empty 'ftid' to default to low-pass
% frequency filtering. 'target' is the target of classification in
% one-vs-all setup. Returns svmobject for trained SVM and pp, an array
% of train-validation-test performance values.
%
% Pass 'ft' and 'ftmrk' outputs of ftprep to prevent svm_tr recomputing
% these, and just train and test the classifier. 'flgtest' can be set
% to use a fixed test set of samples, for external regularization testing.
% See examples of usage in ftr_in1ch.m and ftr_out1ch.m.
%
% Example usage:
%  [svmobj pp]=svm_tr({'nkdeney-example.mat'},0,0.85,1:21,[],2);
%
% Y.Mishchenko (c) 2015


%% Parameters
xvalthr=0.75;     %train-validation split
testthr=0.1;      %train-validation -- test split
nnmax=10000;      %max number of examples to draw for training
supressGraph=false; %supress plotting confusion matrix

if(nargin<5) ftid=[]; end
if(nargin<6 || isempty(target)) target=1; end


%% Prepare features

fprintf('Preparing features...\n');

%% Load data (merge all listed experiments, example)
%datafiles={};

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
% chidx=1:21;  %data channels

if(nargin<8 || isempty(ft) || isempty(ftmrk))
  [ft ftmrk]=ftprep(datafiles,predt,postdt,chidx,[],ftid);
else
  supressGraph=true;    %don't make confusion matrix plots
end

%make features
[eegsamples,ftmrk,ftidx]=make_features(ft,ftmrk,ftid);

%if trial-idx are passed, constrain samples to passed trials
if(isfield(ft,'tridx'))
  eegsamples=eegsamples(ft.tridx,:);
  ftmrk=ftmrk(ft.tridx);  
end

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

%set examples for test
if(nargin<9 || isempty(act_flgtest))
  act_flgtest=rand(1,nn)<testthr;
end

%% Prepare & train SVM
%training-validation split
act_flgtrain=rand(1,nn)<xvalthr;

%mix and restrict training samples count
idx=find(act_flgtrain & ~act_flgtest);
idx=idx(randperm(length(idx)));
idx=idx(1:min(length(idx),nnmax));
xeegsamples=eegsamples(idx,:);
xmrktargets=mrktargets(idx);

%train SVM
options=optimset('MaxIter',10000);
svm2=svmtrain(xeegsamples,xmrktargets,'Method','LS',...
  'QuadProg_Opts',options);

%read SVM model w2*x'-b2
b2=svm2.Bias;
w2=svm2.SupportVectors'*svm2.Alpha;
w2=w2.*svm2.ScaleData.scaleFactor';
b2=b2+svm2.ScaleData.shift*w2;
w2=-w2;

osvm=[];
osvm.w2=w2;
osvm.b2=b2;
osvm.bbef2=0;

%check performance vs. training set
xtest=svmclassify(svm2,xeegsamples);
p1=mean(xmrktargets==xtest);
fprintf('Training %g\n',p1);

%% X-validation
%select validation samples
idx=find(~act_flgtrain & ~act_flgtest);
xeegsamples=eegsamples(idx,:);
xmrktargets=mrktargets(idx);
vals=xmrktargets;

%check performance vs. validation set
vals1=ownclassify(osvm,xeegsamples);
p2=sum(vals==vals1)/length(vals);
fprintf('X-validation %g\n',p2);

%plot confusion matrix
[c cm]=confusion(vals',vals1');
fprintf('Confusion matrix (abs)\n');
disp(cm);
if(~supressGraph)
  fprintf('Ploting confusion matrix...\n');
  plotconfusion(vals',vals1');
  plotprc(valsd',vals);
end

%% Test
%select test samples
idx=find(act_flgtest);
xeegsamples=eegsamples(idx,:);
xmrktargets=mrktargets(idx);
vals=xmrktargets;

%check performance vs test set
vals1=ownclassify(osvm,xeegsamples);
p3=sum(vals==vals1)/length(vals);
fprintf('Test %g\n',p3);

%% Form SVM object
svmObject=[];
svmObject.target=target;
svmObject.predt=predt;
svmObject.postdt=postdt;
svmObject.ftidx=ftidx;
svmObject.w=osvm.w2;
svmObject.b=osvm.b2;
svmObject.bbef=osvm.bbef2;

%output train-validation-test errors
pp=[p1 p2 p3];


  %classify using SVM model object
  function labels=ownclassify(osvm,xeegsamples)    
    w2=osvm.w2;
    b2=osvm.b2;
    bbef2=osvm.bbef2;
    
    %obtain SVM values
    valsd=-b2+xeegsamples*w2;
    labels=(sign(valsd-bbef2)+1)/2;
  end


end
