function [ldaObject pp]=mclda_tr(datafiles,predt,postdt,chidx,ftid,target,ft,ftmrk,act_flgtest)
%[ldaobject pp]=mclda_tr(datafiles,predt,postdt,chidx,ftid,target,ft,ftmrk,flgtest)
% Train multiclass LDA classifier for EEG BCI classification.
% 'datafiles' is cell array of o-data files containing the EEG data,
% 'predt' and 'postdt' are before-stimulus and after-stimulus epoch
% lengths, in seconds. 'chidx' is the array of indexes of the eeg-data
% channels to use. 'ftid' is feature pre-selection specifier. 'target' 
% is the set of targets to be included in the classification.
%
% This function follows Matlab's "classify" in implementing LDA solver and
% differs from it in that only it computes and stores the necessary
% matrices in the structure ldaobject. Otherwise one may use the function 
% mcxda_tr, which directly calls Matlab's "classify" and supports greater
% variety of discriminant functions to that effect.
%
% Feature pre-selection can be specified in one of three ways: 
% - if 'ftid' is empty, default slow-ERP will be used by selecting <=5Hz
%   real/imaginary Fourier amplitudes from ftprep features vector; 
% - 'ftid' can be an array of size 1 x n_feature specifying the features 
%    in the combined features vector from ftprep, such as produced by 
%    make_features; see help make_features for more information; 
% - 'ftid' can be a string of the form [fs][MET][cs][NUM].
%    [fs] is a single character feature-type selector, such as passed to
%    make_features, and can be one of the following
%    'tXXX' to use time-series features,
%    'sXXX' to use FT amplitude features (re/im), 
%    'aXXX' to use FT amplitude features (abs/angle), 
%    'pXXX' to use PSD features in quadratic form, 
%    'dXXX' to use PSD features in log (dB) form,
%    'eXXX' to use EEG band power features.
%    [MET] is a alphabetic specifier identifying the feature ranking to be 
%    used for ranking of features, can be one of the following
%    'xMUIxxx' to use Mutual Information-based ranking of features,
%    'xFRQxxx' to use low-pass frequency selector,
%    'xFRQxxx-xxx' to use band-pass frequency selector,
%    'xKLDxxx' to use Kullback-Leibler divergence ranking of features
%     (only use when length(target)==2)
%    'xCORxxx' to use Pearson correlation-based ranking of features 
%     (only use when length(target)==2)
%    [cs] is a single character specifying the type of method to use for
%    selecting the features by their rank, can be 
%    'XXXzNUM' to select top features based on a z-score-type threshold, in
%     which case features with rank-scores NUM times STD above rank-score
%     average are selected;
%    'XXXnNUM' to select a fixed number of features starting from highest
%     rank-scores in descending order;
%    [NUM] is the numerical threshold (if [cs]=='z') or the number of
%    features (if [cs]=='n') to be selected.
%
% mclda_tr returns a ldaobject for trained multiclass LDA and pp - an 
% array of train-validation-test performance values observed.
%
% Pass 'ft' and 'ftmrk' outputs of ftprep to prevent mclda_tr from 
% computing the features and instead train and test the classifier using 
% the supplied ft and ftmrk values. Set ft.tridx field to additionally 
% use only some of the examples in ft for training the classifier. 
% ft.tridx should be an index array (int or bool) selecting the required 
% examples from ft.ft or equivalent ft-feature-set. 
%
% Pass input parameter 'flgtest' to specify a fixed subset of examples 
% to be used as the 'fixed test set' (superior over the validation set); 
% this can be used for controlling overfitting in external regularization.
% 'flgtest' should be an index array (int or bool) selecting the required 
% (fixed test) examples from ft.ft or equivalent ft-feature-set.
%
% Example usage:
%  [ldaobj pp]=mclda_tr({'nkdeney-example.mat'},0,0.85,1:21,'smuin50',1:3);
%  [ldaobj pp]=mclda_tr({'nkdeney-example.mat'},0,0.85,1:21,'sfrqz5',1:3);
%
% See more examples in ftr_in1ch.m and ftr_out1ch.m.
%
% Y.Mishchenko (c) 2016

%Undocumented feature `global xvalsequential` is used to specify whether
%training/validation split should be randomized (false) or sequntial (true)


%% Parameters
xvalthr=0.70;     %train-validation split
testthr=0.1;      %train-validation--test split
nnmax=10000;      %max number of examples to draw for training
global xvalsequential 	%sequential/random train-validation split
global commonmode 	%common mode modifier
if isempty(xvalsequential) xvalsequential=false; end

if nargin<5 ftid=[]; end
if nargin<6 || isempty(target) target=[1 2]; end


%% Prepare features

fprintf('Preparing features...\n');

if nargin<8 || isempty(ft) || isempty(ftmrk)
  [ft ftmrk]=ftprep(datafiles,predt,postdt,chidx,commonmode,ftid);
end

%make features
[eegsamples,ftmrk]=make_features(ft,ftmrk,ftid);

%if trial-idx are passed, constrain samples to specified trials
if isfield(ft,'tridx')
  eegsamples=eegsamples(ft.tridx,:);
  ftmrk=ftmrk(ft.tridx);
end

%% Finalize data
target=sort(target);
ttidx=ismember(ftmrk,target);
eegsamples=eegsamples(ttidx,:);
mrktargets=ftmrk(ttidx);
nn=size(eegsamples,1);

fprintf('#########################\n');
fprintf('Total samples %i\n',size(eegsamples,1));
fprintf('Total features %i\n',size(eegsamples,2));
fprintf('#########################\n');

%set examples for test
if nargin<9 || isempty(act_flgtest)
  act_flgtest=rand(1,nn)<testthr;
end

%% Prepare features
%{Training-validation split is shared among classifiers, refactor}
%training-validation split
if xvalsequential
  fprintf('Sequential x-validation split\n');
  act_flgtrain=((1:nn)/nn)<xvalthr;
else
  fprintf('Random x-validation split\n');
  act_flgtrain=rand(1,nn)<xvalthr;
end

%form example sets
%normalize data
msamples=mean(eegsamples,1);
ssamples=std(eegsamples,[],1)+1E-12;
eegsamples=bsxfun(@minus,eegsamples,msamples);
eegsamples=bsxfun(@rdivide,eegsamples,ssamples);

%mix and restrict training samples count
idx=find(act_flgtrain & ~act_flgtest);
idx=idx(randperm(length(idx)));
idx=idx(1:min(length(idx),nnmax));
xeegsamples=eegsamples(idx,:);
xmrktargets=mrktargets(idx);

%select feature-set
ftidx_=parse_ftid(ftid,ft,xeegsamples,xmrktargets,target);
xeegsamples=xeegsamples(:,ftidx_);
xeegsamples=xeegsamples+1E-6*randn(size(xeegsamples));


%train LDA
tic

%compute class means
ngroups=length(target);
gmeans = NaN(ngroups, size(xeegsamples,2));
for k = 1:length(target)
    gmeans(k,:) = mean(xeegsamples(xmrktargets==target(k),:),1);
end

%compute cov-square root and variances
n=length(xmrktargets);
[gindex,groups] = grp2idx(xmrktargets);
A=xeegsamples - gmeans(gindex,:);
[Q,R] = qr(A, 0);
R = R / sqrt(n);

toc

olda=[];
olda.ftidx=ftidx_;
olda.means=gmeans;
olda.R=R;
olda.meantrf=msamples;
olda.stdtrf=ssamples;

%check performance on training set
xtest=ownclassify(olda,eegsamples(idx,:));
p1=mean(xmrktargets==xtest);
fprintf('Training %g\n',p1);

%% X-validation
%select test samples
idx=find(~act_flgtrain & ~act_flgtest);
xeegsamples=eegsamples(idx,:);
xmrktargets=mrktargets(idx);

%obtain mnSVM values
vals1=ownclassify(olda,xeegsamples);
vals=xmrktargets;

%check performance on validation set
p2=sum(vals==vals1)/length(vals);
fprintf('X-validation %g\n',p2);


%% Test
%select test samples
idx=find(act_flgtest);
xeegsamples=eegsamples(idx,:);
xmrktargets=mrktargets(idx);

%obtain SVM values
vals1=ownclassify(olda,xeegsamples);
vals=xmrktargets;

%check performance on test set
p3=sum(vals==vals1)/length(vals);
fprintf('Test %g\n',p3);

%% Form SVM object
ldaObject=olda;
ldaObject.target=target;
ldaObject.predt=predt;
ldaObject.postdt=postdt;
ldaObject.chidx=chidx;
ldaObject.ftid=ftid;
ldaObject.ftidx=ftidx_;

%output train-validation-test errors
pp=[p1 p2 p3];


  %classify using SVM model object
  function labels=ownclassify(olda,xeegsamples)
    nt=size(xeegsamples,1); %number of samples    
    nc=size(olda.means,1);  %number of classes
    scores=nan(nt,nc);    %each classes' score  
    
    ftidx=olda.ftidx;
    gmeans=olda.means;
    R=olda.R;
    
    xxeegsamples=xeegsamples(:,ftidx);
    
    for kk = 1:length(target)
      warning off all
      A = bsxfun(@minus,xxeegsamples, gmeans(kk,:)) / R;
      warning on all
      scores(:,kk) = - .5*sum(A .* A, 2);
    end
        
    [g labels]=max(scores,[],2);
    labels=reshape(target(labels),[],1);
  end

end
