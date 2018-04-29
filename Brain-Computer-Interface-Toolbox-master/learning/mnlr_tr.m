function [mnlrObject pp]=mnlr_tr(datafiles,predt,postdt,chidx,ftid,target,ft,ftmrk,act_flgtest)
%[mnlrobject pp]=mnlr_tr(datafiles,predt,postdt,chidx,ftid,target[,ft,ftmrk,flgtest])
% Train multinomial logistic regression for a EEG BCI data.
% 'datafiles' is cell array of o-data files containing the EEG data,
% 'predt' and 'postdt' are before-stimulus and after-stimulus epoch
% lengths, in seconds. 'chidx' is the array of indexes of the eeg-data
% channels to use. 'ftid' is the array of indexes of features in
% the full output of ftprep to use (ie feature reduction vector, pass an 
% empty 'ftid' to default-low-pass frequency features). 
% 'targets' is the set of targets for classification. 
% Returns mnlrobject for trained multinomial regression and pp, an array
% of train-validation-test performance values.
%
% Pass 'ft' and 'ftmrk' output of previous ftprep to prevent recomputing
% of these and only train the regression using that data. 'flgtest' boolean 
% array can be set to restrict the set of samples to be used in training, 
% if certain samples are used outside of mnlr_tr for regularization 
% validation. For these options, see the examples of usage in ftr_in1ch.m 
% and ftr_out1ch.m.
%
% Example usage:
%  [mnlrobj pp]=mnlr_tr({'nkdeney-example.mat'},0,0.85,1:21,[],2);
%
% Y.Mishchenko (c) 2015

%Undocumented feature `global xvalsequential` is used to specify whether
%training/validation split should be randomized (false) or sequntial (true)
%Undocumented feature `commonomode`

%% Parameters
xvalthr=0.75;     %train-validation split
testthr=0.1;      %train-validation -- test split
nnmax=10000;      %max number of examples to draw for training
supressGraph=false; %supress plotting confusion matrix
global xvalsequential commonmode %sequential/random train-validation split
if isempty(xvalsequential) xvalsequential=false; end

if(nargin<5) ftid=[]; end
if(nargin<6 || isempty(target)) target=1; end


%% Prepare features

fprintf('Preparing features...\n');

%% Load data (merge all listed experiments, example)
%compute features
if(nargin<8 || isempty(ft) || isempty(ftmrk))
  [ft ftmrk]=ftprep(datafiles,predt,postdt,chidx,commonmode,ftid);
else
  supressGraph=true;    %don't make confusion matrix plots in batch runs
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
target=sort(target);
ttidx=ismember(ftmrk,target);
eegsamples=eegsamples(ttidx,:);
mrktargets=ftmrk(ttidx);
nn=size(eegsamples,1);
eegsamples=[ones(nn,1),eegsamples];

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
if xvalsequential
  fprintf('Sequential x-validation split\n');
  act_flgtrain=((1:nn)/nn)<xvalthr;
else
  fprintf('Random x-validation split\n');
  act_flgtrain=rand(1,nn)<xvalthr;
end

%mix and restrict training samples count
idx=find(act_flgtrain & ~act_flgtest);
idx=idx(randperm(length(idx)));
idx=idx(1:min(length(idx),nnmax));
xeegsamples=eegsamples(idx,:);
xmrktargets=mrktargets(idx);


%adjust ftid if char
if ischar(ftid)
  feature_type=ftid(1); ftid=ftid(2:end);
  selector_type=ftid(1:3);
  cutoff_type=ftid(4);
  cutoff_value=str2double(ftid(5:end));
end

%{feature pre-selection is shared across classifiers, refactor this out}
%rank features if requested
if ischar(ftid)
  fprintf('Ranking features (%s)...\n',selector_type);
  
  num=cutoff_value;
  if strcmpi(selector_type,'MUI') %mui based selector
    ranks=xftr_mui(xeegsamples,xmrktargets,target);
    m=mean(ranks); s=std(ranks);
  elseif strcmpi(selector_type,'FRQ') %FRQ based selector
    if feature_type=='e'
      ranks=-ft.freqeeg;
    elseif feature_type=='p' || feature_type=='d'
      ranks=-ft.freqid;
    elseif feature_type=='s' || feature_type=='a'
      ranks=-[ft.freqid,ft.freqid];
    elseif feature_type=='t'
      ranks=zeros(size(xeegsamples,2),1);
    else
      fprintf('Cannot use FRQ selector with this feature-set, quiting...\n');
      return          
    end
    m=0; s=1; num=-cutoff_value;  %descend->ascend
    cutoff_type='z';
  else  %default slow-ERP selector
    fprintf('Unrecognized ftid specifier, quiting...\n');
    return
  end
  
  [g rankids]=sort(ranks,'descend');
  if(strcmpi(cutoff_type,'z'))
    nids=find((g-m)/s>=num,1,'Last');
  else
    nids=min(size(xeegsamples,2),num);
  end
  
  fprintf('Pre-selected %i\n',nids);
else
  nids=size(xeegsamples,2);
  rankids=1:nids;
end

ftidx=rankids;
ftnum=nids;

%restrict training samples to only such containing targets
ftidx_=sort(ftidx(1:ftnum));
xeegsamples=xeegsamples(:,ftidx_);

%train mnlr
fprintf('Training multinomial logistic regression... ');
warning off all
tic
B=mnrfit(xeegsamples,xmrktargets);
toc
warning on all

%check performance on training set
ptest=mnrval(B,xeegsamples);
[grb,xtest]=max(ptest,[],2);
vals1=target(xtest);
p1=mean(xmrktargets==vals1(:));
fprintf('Training %g\n',p1);

%% X-validation
%select test samples
idx=find(~act_flgtrain & ~act_flgtest);
xeegsamples=eegsamples(idx,ftidx_);
xmrktargets=mrktargets(idx);

%obtain validation values
ptest=mnrval(B,xeegsamples);
[grb,xtest]=max(ptest,[],2);
vals1=target(xtest);
vals=xmrktargets;
p2=sum(vals==vals1(:))/length(vals);
fprintf('X-validation %g\n',p2);

% %plot confusion matrix -- no confusion matrix on multinominal
% [c cm]=confusion(vals',vals1(:)');
% fprintf('Confusion matrix (abs)\n');
% disp(cm);
% if(~supressGraph)
%   fprintf('Ploting confusion matrix...\n');
%   plotconfusion(vals',vals1');
%   plotprc(valsd',vals);
% end

%% Test
%select test samples
idx=find(act_flgtest);
xeegsamples=eegsamples(idx,ftidx_);
xmrktargets=mrktargets(idx);

%obtain validation values
ptest=mnrval(B,xeegsamples);
[grb,xtest]=max(ptest,[],2);
vals1=target(xtest);
vals=xmrktargets;

%check performance on test set
p3=sum(vals==vals1(:))/length(vals);
fprintf('Test %g\n',p3);

%% Form SVM object
mnlrObject=[];
mnlrObject.target=target;
mnlrObject.B=B;
mnlrObject.predt=predt;
mnlrObject.postdt=postdt;
mnlrObject.ftid=ftid;
mnlrObject.ftidx=ftidx_;

%output train-validation-test errors
pp=[p1 p2 p3];
end
